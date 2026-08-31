import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/local_voucher_service.dart';
import '../models/voucher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  int _selectedDays = 30;
  int _dataLimit = 0;
  int _devicesAllowed = 1;

  VoucherCode? _lastGenerated;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Carregar vouchers salvos
    context.read<LocalVoucherService>().init();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _generateVoucher() {
    final service = context.read<LocalVoucherService>();
    final quantity = int.tryParse(_quantityController.text) ?? 1;

    if (quantity <= 0 || quantity > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade deve ser entre 1 e 100')),
      );
      return;
    }

    final voucher = service.generateVoucher(
      validityDays: _selectedDays,
      dataLimitMb: _dataLimit,
      devicesAllowed: _devicesAllowed,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _lastGenerated = voucher);

    // Limpar campos
    _descriptionController.clear();
    _notesController.clear();

    // Ir para aba de vouchers
    _tabController.animateTo(1);
  }

  void _copyCode(VoucherCode voucher) {
    Clipboard.setData(ClipboardData(text: voucher.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Código ${voucher.code} copiado!')),
    );
  }

  void _shareViaWhatsApp(VoucherCode voucher) {
    final message = '''
*Código de Acesso - Guest WiFi*

Código: *${voucher.code}*
Validade: ${voucher.formattedExpiry}
${voucher.dataLimitMb > 0 ? 'Limite de dados: ${voucher.dataLimitMb} MB' : 'Dados ilimitados'}

Use este código para se conectar à rede Guest WiFi.
''';

    Share.share(message);
  }

  void _revokeVoucher(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar Voucher'),
        content: const Text('Deseja realmente revogar este código?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<LocalVoucherService>().revokeVoucher(id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest WiFi Voucher'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: 'Gerar'),
            Tab(icon: Icon(Icons.list), text: 'Vouchers'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGenerateTab(),
          _buildListTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card de Geração
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gerar Código de Acesso',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Quantidade
                  TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      hintText: '1',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Nome do Visitante
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Visitante (opcional)',
                      hintText: 'Nome ou identificação',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Validade
                  Text(
                    'Período de Validade',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ValidityPeriod.periods.map((period) {
                      final isSelected = _selectedDays == period.days;
                      return ChoiceChip(
                        label: Text(period.label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedDays = period.days);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Limite de dados
                  Text(
                    'Limite de Dados',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _dataLimit,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.data_usage),
                      border: OutlineInputBorder(),
                    ),
                    items: DataLimit.limits.map((limit) {
                      return DropdownMenuItem(
                        value: limit.mb,
                        child: Text(limit.label),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _dataLimit = value ?? 0),
                  ),
                  const SizedBox(height: 16),

                  // Dispositivos permitidos
                  Text(
                    'Dispositivos por Código',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _devicesAllowed,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.devices),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 dispositivo')),
                      DropdownMenuItem(value: 2, child: Text('2 dispositivos')),
                      DropdownMenuItem(value: 3, child: Text('3 dispositivos')),
                      DropdownMenuItem(value: 5, child: Text('5 dispositivos')),
                    ],
                    onChanged: (value) => setState(() => _devicesAllowed = value ?? 1),
                  ),
                  const SizedBox(height: 16),

                  // Observações
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                      hintText: 'Anotações internas',
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Botão Gerar
                  FilledButton.icon(
                    onPressed: _generateVoucher,
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('Gerar Código'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Último gerado
          if (_lastGenerated != null) ...[
            _buildResultCard(_lastGenerated!),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(VoucherCode voucher) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Código Gerado!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Código em destaque
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    'Código de Acesso',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    voucher.code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Validade: ${voucher.formattedExpiry}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyCode(voucher),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareViaWhatsApp(voucher),
                    icon: const Icon(Icons.share),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // QR Code
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Escaneie para acessar',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: 'Código: ${voucher.code}\nValidade: ${voucher.formattedExpiry}',
                      version: QrVersions.auto,
                      size: 150,
                      backgroundColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab() {
    return Consumer<LocalVoucherService>(
      builder: (context, service, _) {
        if (service.vouchers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Nenhum voucher gerado ainda',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => service.init(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: service.vouchers.length,
            itemBuilder: (context, index) {
              final voucher = service.vouchers[index];
              return _buildVoucherListItem(voucher);
            },
          ),
        );
      },
    );
  }

  Widget _buildVoucherListItem(VoucherCode voucher) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          voucher.status == 'revoked'
              ? Icons.cancel
              : voucher.isExpired
                  ? Icons.timer_off
                  : Icons.check_circle,
          color: voucher.statusColor,
        ),
        title: Text(
          voucher.code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (voucher.description != null)
              Text(voucher.description!),
            Text('Expira: ${voucher.formattedExpiry}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'copy':
                _copyCode(voucher);
                break;
              case 'share':
                _shareViaWhatsApp(voucher);
                break;
              case 'revoke':
                _revokeVoucher(voucher.id);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copiar'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text('WhatsApp'),
                dense: true,
              ),
            ),
            if (voucher.isActive)
              const PopupMenuItem(
                value: 'revoke',
                child: ListTile(
                  leading: Icon(Icons.cancel, color: Colors.red),
                  title: Text('Revogar', style: TextStyle(color: Colors.red)),
                  dense: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return Consumer<LocalVoucherService>(
      builder: (context, service, _) {
        final stats = service.statistics;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatCard('Total', stats['total']!, Colors.blue, Icons.confirmation_number),
              const SizedBox(height: 12),
              _buildStatCard('Ativos', stats['active']!, Colors.green, Icons.check_circle),
              const SizedBox(height: 12),
              _buildStatCard('Expirados', stats['expired']!, Colors.orange, Icons.timer_off),
              const SizedBox(height: 12),
              _buildStatCard('Revogados', stats['revoked']!, Colors.red, Icons.cancel),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

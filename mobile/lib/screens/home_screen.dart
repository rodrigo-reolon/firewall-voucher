import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/voucher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  
  int _selectedDays = 30;
  int _dataLimit = 0;
  int _devicesAllowed = 1;
  
  bool _isLoading = false;
  String? _errorMessage;
  VoucherCode? _lastGenerated;
  List<VoucherCode> _recentVouchers = [];
  VoucherStats? _stats;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadRecentVouchers(),
      _loadStatistics(),
    ]);
  }

  Future<void> _loadRecentVouchers() async {
    try {
      final auth = context.read<AuthService>();
      final api = ApiService(auth);
      final result = await api.listVouchers(limit: 10);
      if (mounted) {
        setState(() => _recentVouchers = result['vouchers'] as List<VoucherCode>);
      }
    } catch (e) {
      // Silenciar erro não crítico
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final auth = context.read<AuthService>();
      final api = ApiService(auth);
      final stats = await api.getStatistics();
      if (mounted) {
        setState(() => _stats = stats);
      }
    } catch (e) {
      // Silenciar
    }
  }

  Future<void> _generateVoucher() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastGenerated = null;
    });

    try {
      final auth = context.read<AuthService>();
      final api = ApiService(auth);
      
      final request = VoucherRequest(
        quantity: int.tryParse(_quantityController.text) ?? 1,
        validityDays: _selectedDays,
        dataLimitMb: _dataLimit,
        devicesAllowed: _devicesAllowed,
        visitorName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      final voucher = await api.generateVoucher(request);
      
      setState(() => _lastGenerated = voucher);
      await _loadData();
      
      // Limpar campos
      _nameController.clear();
      _notesController.clear();
      
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyCode() {
    if (_lastGenerated == null) return;
    Clipboard.setData(ClipboardData(text: _lastGenerated!.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado!')),
    );
  }

  void _shareViaWhatsApp() {
    if (_lastGenerated == null) return;

    final message = '''
*Código de Acesso - Guest WiFi*

Código: *${_lastGenerated!.code}*
Validade: ${_lastGenerated!.formattedExpiry}
${_lastGenerated!.dataLimitMb > 0 ? 'Limite de dados: ${_lastGenerated!.dataLimitMb} MB' : 'Dados ilimitados'}

Use este código para se conectar à rede Guest WiFi.
''';

    Share.share(message);
  }

  void _shareCode(VoucherCode voucher) {
    final message = '''
*Código de Acesso - Guest WiFi*

Código: *${voucher.code}*
Validade: ${voucher.formattedExpiry}
${voucher.dataLimitMb > 0 ? 'Limite de dados: ${voucher.dataLimitMb} MB' : 'Dados ilimitados'}

Use este código para se conectar à rede Guest WiFi.
''';

    Share.share(message);
  }

  void _copyCodeFromVoucher(VoucherCode voucher) {
    Clipboard.setData(ClipboardData(text: voucher.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Código ${voucher.code} copiado!')),
    );
  }

  Future<void> _revokeVoucher(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar Voucher'),
        content: Text('Deseja realmente revogar o código $code?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final auth = context.read<AuthService>();
        final api = ApiService(auth);
        await api.revokeVoucher(code);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Código $code revogado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e')),
          );
        }
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthService>().logout();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotspot Voucher'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                context.read<AuthService>().username ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: 'Gerar'),
            Tab(icon: Icon(Icons.list), text: 'Vouchers'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Estatísticas'),
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
          _buildGenerationCard(),
          const SizedBox(height: 24),

          // Último gerado
          if (_lastGenerated != null) ...[
            _buildResultCard(_lastGenerated!),
            const SizedBox(height: 16),
          ],

          // Mensagem de erro
          if (_errorMessage != null) ...[
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerationCard() {
    return Card(
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
              controller: _nameController,
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

            // Limite de dados (0 = ilimitado)
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
              items: const [
                DropdownMenuItem(value: 0, child: Text('Ilimitado')),
                DropdownMenuItem(value: 100, child: Text('100 MB')),
                DropdownMenuItem(value: 500, child: Text('500 MB')),
                DropdownMenuItem(value: 1000, child: Text('1 GB')),
                DropdownMenuItem(value: 5000, child: Text('5 GB')),
              ],
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
              onPressed: _isLoading ? null : _generateVoucher,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.vpn_key),
              label: Text(_isLoading ? 'Gerando...' : 'Gerar Código'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
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
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Código Gerado!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
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
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareViaWhatsApp,
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
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _recentVouchers.isEmpty
          ? const Center(
              child: Text('Nenhum voucher gerado ainda'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recentVouchers.length,
              itemBuilder: (context, index) {
                final voucher = _recentVouchers[index];
                return _buildVoucherListItem(voucher);
              },
            ),
    );
  }

  Widget _buildVoucherListItem(VoucherCode voucher) {
    Color statusColor;
    IconData statusIcon;
    
    switch (voucher.status) {
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'expired':
        statusColor = Colors.orange;
        statusIcon = Icons.timer_off;
        break;
      case 'revoked':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'used':
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
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
                _copyCodeFromVoucher(voucher);
                break;
              case 'share':
                _shareCode(voucher);
                break;
              case 'revoke':
                _revokeVoucher(voucher.code);
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
            if (voucher.status == 'active')
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
    if (_stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatCard('Total', _stats!.total, Colors.blue, Icons.confirmation_number),
          const SizedBox(height: 12),
          _buildStatCard('Ativos', _stats!.active, Colors.green, Icons.check_circle),
          const SizedBox(height: 12),
          _buildStatCard('Expirados', _stats!.expired, Colors.orange, Icons.timer_off),
          const SizedBox(height: 12),
          _buildStatCard('Revogados', _stats!.revoked, Colors.red, Icons.cancel),
          const SizedBox(height: 12),
          _buildStatCard('Usados', _stats!.used, Colors.purple, Icons.done_all),
        ],
      ),
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

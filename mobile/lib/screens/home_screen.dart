import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/voucher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  int _selectedHours = 8;
  Voucher? _generatedVoucher;
  bool _isLoading = false;
  String? _errorMessage;
  List<Voucher> _recentVouchers = [];

  @override
  void initState() {
    super.initState();
    _loadRecentVouchers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentVouchers() async {
    final auth = context.read<AuthService>();
    final api = ApiService(auth);
    
    try {
      final vouchers = await api.listVouchers();
      setState(() => _recentVouchers = vouchers.take(5).toList());
    } catch (e) {
      // Silenciar erro - não crítico
    }
  }

  Future<void> _generateVoucher() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedVoucher = null;
    });

    final auth = context.read<AuthService>();
    final api = ApiService(auth);

    try {
      final request = VoucherRequest(
        visitorName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        validityHours: _selectedHours,
        dataQuotaMb: 500,
        accessProfile: 'Guest',
      );

      final voucher = await api.generateVoucher(request);
      
      setState(() {
        _generatedVoucher = voucher;
      });

      // Atualizar lista
      _loadRecentVouchers();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyCredentials() {
    if (_generatedVoucher == null) return;

    final text =
        'Usuário: ${_generatedVoucher!.username}\nSenha: ${_generatedVoucher!.password}';
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credenciais copiadas!')),
    );
  }

  void _shareViaWhatsApp() {
    if (_generatedVoucher == null) return;

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final expiresFormatted = dateFormat.format(
      DateTime.parse(_generatedVoucher!.expiresAt),
    );

    final message = '''
*Acesso à Rede Visitante*

Usuário: ${_generatedVoucher!.username}
Senha: ${_generatedVoucher!.password}
Validade: $expiresFormatted

Conecte-se à rede Guest-WiFi usando as credenciais acima.
''';

    Share.share(message);
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
        title: const Text('Firewall Voucher'),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de Geração
            _buildGenerationCard(),
            const SizedBox(height: 24),

            // Card do Voucher Gerado (se houver)
            if (_generatedVoucher != null) ...[
              _buildVoucherCard(_generatedVoucher!),
              const SizedBox(height: 24),
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
              'Gerar Novo Voucher',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // Campo Nome do Visitante
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Visitante (opcional)',
                hintText: 'Nome do visitante',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),

            // Seletor de Validade
            Text(
              'Tempo de Validade',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ValidityPeriod.periods.map((period) {
                final isSelected = _selectedHours == period.hours;
                return ChoiceChip(
                  label: Text(period.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedHours = period.hours);
                    }
                  },
                );
              }).toList(),
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
              label: Text(_isLoading ? 'Gerando...' : 'Gerar Acesso'),
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

  Widget _buildVoucherCard(Voucher voucher) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final expiresFormatted = dateFormat.format(DateTime.parse(voucher.expiresAt));

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
                  'Voucher Gerado com Sucesso!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Credenciais
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _buildCredentialRow('Usuário', voucher.username),
                  const Divider(),
                  _buildCredentialRow('Senha', voucher.password),
                  const Divider(),
                  _buildCredentialRow('Validade', expiresFormatted),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyCredentials,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar Acesso'),
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
                    Text(
                      'Escaneie para acessar',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: voucher.qrCodeData ??
                          'Usuário: ${voucher.username}\nSenha: ${voucher.password}',
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

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        SelectableText(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/sophos_voucher_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  List<Map<String, String>> _hotspots = [];
  List<Map<String, String>> _definitions = [];

  String? _selectedHotspot;
  String? _selectedDefinition;

  List<String> _lastGeneratedCodes = [];
  bool _isLoading = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHotspots();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHotspots() async {
    setState(() => _isLoading = true);
    try {
      final service = context.read<SophosVoucherService>();
      final hotspots = await service.listHotspots();
      if (mounted) {
        setState(() {
          _hotspots = hotspots;
          if (hotspots.isNotEmpty) {
            _selectedHotspot = hotspots.first['name'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDefinitions() async {
    if (_selectedHotspot == null) return;
    try {
      final service = context.read<SophosVoucherService>();
      final definitions = await service.listVoucherDefinitions(_selectedHotspot!);
      if (mounted) {
        setState(() {
          _definitions = definitions;
          if (definitions.isNotEmpty) {
            _selectedDefinition = definitions.first['name'];
          }
        });
      }
    } catch (e) {
      // Ignorar erro
    }
  }

  Future<void> _generateVouchers() async {
    if (_selectedHotspot == null || _selectedDefinition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione hotspot e definição')),
      );
      return;
    }

    final quantityText = _quantityController.text;
    final quantity = int.tryParse(quantityText) ?? 1;
    if (quantity < 1 || quantity > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade deve ser entre 1 e 50')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _lastGeneratedCodes.clear();
    });

    try {
      final service = context.read<SophosVoucherService>();
      final codes = await service.generateVouchers(
        hotspotName: _selectedHotspot!,
        definitionName: _selectedDefinition!,
        amount: quantity,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      );

      if (mounted) {
        setState(() => _lastGeneratedCodes = codes);
        _descriptionController.clear();
        _tabController.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${codes.length} voucher(s) gerado(s)!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Código $code copiado!')),
    );
  }

  void _shareViaWhatsApp(String code) {
    final message = '*Código de Acesso - Guest WiFi*\n\nCódigo: *$code*\n\nUse este código para se conectar à rede Guest WiFi.';
    Share.share(message);
  }

  void _revokeVoucher(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar Voucher'),
        content: Text('Deseja revogar $code?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<SophosVoucherService>().revokeVoucher(_selectedHotspot!, code);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
              }
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
        title: const Text('Reolon Visitantes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<SophosVoucherService>().disconnect(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: 'Gerar'),
            Tab(icon: Icon(Icons.list), text: 'Vouchers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGenerateTab(),
          _buildListTab(),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Gerar Vouchers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  if (_hotspots.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedHotspot,
                      decoration: const InputDecoration(labelText: 'Hotspot', prefixIcon: Icon(Icons.wifi), border: OutlineInputBorder()),
                      items: _hotspots.map((h) => DropdownMenuItem(value: h['name'], child: Text(h['label'] ?? h['name'] ?? ''))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedHotspot = v;
                          _definitions.clear();
                          _selectedDefinition = null;
                        });
                        _loadDefinitions();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_definitions.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedDefinition,
                      decoration: const InputDecoration(labelText: 'Definição', prefixIcon: Icon(Icons.timer), border: OutlineInputBorder()),
                      items: _definitions.map((d) => DropdownMenuItem(value: d['name'], child: Text(d['label'] ?? d['name'] ?? ''))).toList(),
                      onChanged: (v) => setState(() => _selectedDefinition = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Quantidade', hintText: '1-50', prefixIcon: Icon(Icons.format_list_numbered)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Descrição (opcional)', hintText: 'Nome do visitante', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _generateVouchers,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        : const Icon(Icons.vpn_key),
                    label: Text(_isLoading ? 'Gerando...' : 'Gerar Vouchers'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_lastGeneratedCodes.isNotEmpty) ...[
            Card(
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
                        Text('Vouchers Gerados!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._lastGeneratedCodes.map((code) => Card(
                          child: ListTile(
                            title: Text(code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 20)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyCode(code)),
                                IconButton(icon: const Icon(Icons.share, color: Colors.green), onPressed: () => _shareViaWhatsApp(code)),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListTab() {
    return Consumer<SophosVoucherService>(
      builder: (context, service, _) {
        if (service.vouchers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Nenhum voucher encontrado', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => service.refreshVouchers(_selectedHotspot),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: service.vouchers.length,
            itemBuilder: (context, index) {
              final voucher = service.vouchers[index];
              final code = voucher['code'] ?? '';
              final description = voucher['description'] ?? '';
              final status = voucher['status'] ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    status.toLowerCase() == 'active' ? Icons.check_circle : Icons.cancel,
                    color: status.toLowerCase() == 'active' ? Colors.green : Colors.red,
                  ),
                  title: Text(code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: description.isNotEmpty ? Text(description) : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'copy':
                          _copyCode(code);
                          break;
                        case 'share':
                          _shareViaWhatsApp(code);
                          break;
                        case 'revoke':
                          _revokeVoucher(code);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy), title: Text('Copiar'), dense: true)),
                      const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share), title: Text('WhatsApp'), dense: true)),
                      const PopupMenuItem(value: 'revoke', child: ListTile(leading: Icon(Icons.cancel, color: Colors.red), title: Text('Revogar', style: TextStyle(color: Colors.red)), dense: true)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

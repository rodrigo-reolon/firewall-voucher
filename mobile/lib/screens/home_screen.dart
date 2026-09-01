import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/sophos_voucher_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  List<Map<String, String>> _hotspots = [];
  String? _selectedHotspot;
  List<String> _lastGeneratedCodes = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadHotspots() async {
    try {
      final service = context.read<SophosVoucherService>();
      final hotspots = await service.listHotspots();
      if (mounted) {
        setState(() {
          _hotspots = hotspots;
          if (hotspots.isNotEmpty) _selectedHotspot = hotspots.first['name'];
        });
      }
    } catch (_) {}
  }

  Future<void> _generate() async {
    if (_selectedHotspot == null) return;
    setState(() => _isLoading = true);
    try {
      final service = context.read<SophosVoucherService>();
      final codes = await service.generateVouchers(
        hotspotName: _selectedHotspot!,
        definitionName: 'default',
        amount: int.tryParse(_quantityController.text) ?? 1,
      );
      if (mounted) setState(() => _lastGeneratedCodes = codes);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reolon Visitantes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_hotspots.isNotEmpty)
                  DropdownButton<String>(
                    value: _selectedHotspot,
                    items: _hotspots.map((h) => DropdownMenuItem(value: h['name'], child: Text(h['name'] ?? ''))).toList(),
                    onChanged: (v) => setState(() => _selectedHotspot = v),
                  ),
                TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'Quantidade')),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _isLoading ? null : _generate, child: Text(_isLoading ? 'Gerando...' : 'Gerar')),
              ],
            ),
          ),
          if (_lastGeneratedCodes.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _lastGeneratedCodes.length,
                itemBuilder: (context, index) {
                  final code = _lastGeneratedCodes[index];
                  return ListTile(
                    title: Text(code),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

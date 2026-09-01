import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sophos_portal_service.dart';

/// Serviço de vouchers do Sophos Hotspot.
/// 
/// Gera códigos VÁLIDOS acessando diretamente o User Portal do Sophos.
/// Os códigos são criados pelo próprio firewall, garantindo compatibilidade.
class SophosVoucherService extends ChangeNotifier {
  static const String _configKey = 'sophos_config';
  
  SophosPortalService? _portal;
  List<Map<String, dynamic>> _vouchers = [];
  bool _isConnected = false;
  String? _lastError;

  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  List<Map<String, dynamic>> get vouchers => List.unmodifiable(_vouchers);

  /// Configura a conexão com o Sophos
  Future<void> configure({
    required String portalUrl,
    required String username,
    required String password,
    bool verifySsl = false,
  }) async {
    _portal = SophosPortalService(
      portalUrl: portalUrl,
      username: username,
      password: password,
      verifySsl: verifySsl,
    );

    // Salvar configuração
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode({
      'portal_url': portalUrl,
      'username': username,
      'password': password, // Em produção, usar secure storage
      'verify_ssl': verifySsl,
    }));
  }

  /// Carrega configuração salva
  Future<bool> loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);
      
      if (jsonStr != null) {
        final config = jsonDecode(jsonStr);
        _portal = SophosPortalService(
          portalUrl: config['portal_url'],
          username: config['username'],
          password: config['password'],
          verifySsl: config['verify_ssl'] ?? false,
        );
        return true;
      }
    } catch (e) {
      debugPrint('Erro ao carregar config: $e');
    }
    return false;
  }

  /// Conecta ao portal e faz login
  Future<bool> connect() async {
    _lastError = null;
    
    if (_portal == null) {
      _lastError = 'Configure a conexão primeiro';
      return false;
    }

    try {
      await _portal!.login();
      _isConnected = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      _lastError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Lista hotspots disponíveis
  Future<List<Map<String, String>>> listHotspots() async {
    if (_portal == null) throw Exception('Não conectado');
    return await _portal!.listHotspots();
  }

  /// Lista definições de voucher
  Future<List<Map<String, String>>> listVoucherDefinitions(String hotspotName) async {
    if (_portal == null) throw Exception('Não conectado');
    return await _portal!.listVoucherDefinitions(hotspotName);
  }

  /// Gera vouchers VÁLIDOS no Sophos
  Future<List<String>> generateVouchers({
    required String hotspotName,
    required String definitionName,
    required int amount,
    String? description,
  }) async {
    if (_portal == null) throw Exception('Não conectado');
    
    try {
      final codes = await _portal!.generateVouchers(
        hotspotName: hotspotName,
        definitionName: definitionName,
        amount: amount,
        description: description,
      );

      // Atualizar lista de vouchers
      await refreshVouchers(hotspotName);
      
      return codes;
    } catch (e) {
      _lastError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    }
  }

  /// Atualiza lista de vouchers
  Future<void> refreshVouchers([String? hotspotName]) async {
    if (_portal == null) return;
    
    try {
      _vouchers = await _portal!.listVouchers(hotspotName: hotspotName);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao atualizar vouchers: $e');
    }
  }

  /// Revoga/deleta um voucher
  Future<void> revokeVoucher(String hotspotName, String voucherCode) async {
    if (_portal == null) throw Exception('Não conectado');
    
    await _portal!.deleteVoucher(hotspotName, voucherCode);
    await refreshVouchers(hotspotName);
  }

  /// Desconecta do portal
  Future<void> disconnect() async {
    if (_portal != null) {
      await _portal!.logout();
    }
    _isConnected = false;
    _vouchers.clear();
    notifyListeners();
  }

  /// Limpar configuração
  Future<void> clearConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    _portal = null;
    _isConnected = false;
    _vouchers.clear();
    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voucher.dart';

/// Serviço local para gerenciamento de vouchers.
/// 
/// Armazena códigos no SharedPreferences (local no celular).
/// Não requer servidor - tudo é feito diretamente no app.
class LocalVoucherService extends ChangeNotifier {
  static const String _storageKey = 'voucher_codes';
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  
  List<VoucherCode> _vouchers = [];
  bool _isLoading = false;

  List<VoucherCode> get vouchers => List.unmodifiable(_vouchers);
  bool get isLoading => _isLoading;

  /// Inicializa o serviço e carrega vouchers salvos
  Future<void> init() async {
    await _loadVouchers();
  }

  /// Gera um novo código de voucher
  VoucherCode generateVoucher({
    int validityDays = 30,
    int dataLimitMb = 0,
    int devicesAllowed = 1,
    String? description,
    String? notes,
  }) {
    final code = _generateUniqueCode();
    final voucher = VoucherCode.create(
      code: code,
      description: description,
      validityDays: validityDays,
      dataLimitMb: dataLimitMb,
      devicesAllowed: devicesAllowed,
      notes: notes,
    );

    _vouchers.insert(0, voucher);
    _saveVouchers();
    notifyListeners();
    
    return voucher;
  }

  /// Gera múltiplos vouchers de uma vez
  List<VoucherCode> generateMultiple({
    int quantity = 1,
    int validityDays = 30,
    int dataLimitMb = 0,
    int devicesAllowed = 1,
    String? description,
  }) {
    final List<VoucherCode> newVouchers = [];
    
    for (int i = 0; i < quantity; i++) {
      final voucher = generateVoucher(
        validityDays: validityDays,
        dataLimitMb: dataLimitMb,
        devicesAllowed: devicesAllowed,
        description: description,
      );
      newVouchers.add(voucher);
    }
    
    return newVouchers;
  }

  /// Revoga um voucher
  void revokeVoucher(String id) {
    final index = _vouchers.indexWhere((v) => v.id == id);
    if (index != -1) {
      final old = _vouchers[index];
      _vouchers[index] = VoucherCode(
        id: old.id,
        code: old.code,
        description: old.description,
        validityDays: old.validityDays,
        dataLimitMb: old.dataLimitMb,
        devicesAllowed: old.devicesAllowed,
        status: 'revoked',
        createdAt: old.createdAt,
        expiresAt: old.expiresAt,
        notes: old.notes,
      );
      _saveVouchers();
      notifyListeners();
    }
  }

  /// Remove um voucher da lista
  void deleteVoucher(String id) {
    _vouchers.removeWhere((v) => v.id == id);
    _saveVouchers();
    notifyListeners();
  }

  /// Busca voucher por código
  VoucherCode? findByCode(String code) {
    try {
      return _vouchers.firstWhere((v) => v.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Estatísticas
  Map<String, int> get statistics {
    int active = 0, expired = 0, revoked = 0;
    
    for (final v in _vouchers) {
      if (v.status == 'revoked') {
        revoked++;
      } else if (v.isExpired) {
        expired++;
      } else {
        active++;
      }
    }
    
    return {
      'total': _vouchers.length,
      'active': active,
      'expired': expired,
      'revoked': revoked,
    };
  }

  /// Limpa vouchers expirados/revogados antigos (mais de 30 dias)
  void cleanupOldVouchers() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _vouchers.removeWhere((v) => 
      (v.status == 'revoked' || v.isExpired) && 
      v.createdAt.isBefore(cutoff)
    );
    _saveVouchers();
    notifyListeners();
  }

  // =============================================
  // PERSISTÊNCIA
  // =============================================

  Future<void> _loadVouchers() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _vouchers = jsonList.map((j) => VoucherCode.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Erro ao carregar vouchers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveVouchers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_vouchers.map((v) => v.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('Erro ao salvar vouchers: $e');
    }
  }

  // =============================================
  // GERAÇÃO DE CÓDIGO
  // =============================================

  String _generateUniqueCode({int length = 8}) {
    final random = Random.secure();
    
    for (int attempt = 0; attempt < 100; attempt++) {
      final code = String.fromCharCodes(
        Iterable.generate(length, (_) => _alphabet.codeUnitAt(random.nextInt(_alphabet.length)))
      );
      
      // Verificar se já existe
      if (!_vouchers.any((v) => v.code == code)) {
        return code;
      }
    }
    
    throw Exception('Não foi possível gerar código único');
  }
}

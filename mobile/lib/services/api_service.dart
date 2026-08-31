import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/voucher.dart';

/// Serviço de comunicação com o backend (Middleware FastAPI)
class ApiService {
  final AuthService _authService;
  final String _baseUrl;

  ApiService(this._authService, {String? baseUrl})
      : _baseUrl = baseUrl ?? 'http://10.0.2.2:8000';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authService.token != null)
          'Authorization': 'Bearer ${_authService.token}',
      };

  /// Gera um novo voucher no Sophos via middleware
  Future<Voucher> generateVoucher(VoucherRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/vouchers/generate'),
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Voucher.fromJson(data);
      } else if (response.statusCode == 401) {
        await _authService.logout();
        throw Exception('Sessão expirada. Faça login novamente.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Erro ao gerar voucher');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Sessão expirada')) {
        rethrow;
      }
      throw Exception('Erro de conexão com o servidor: $e');
    }
  }

  /// Lista vouchers ativos
  Future<List<Voucher>> listVouchers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/vouchers/list'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> vouchersJson = data['vouchers'] ?? [];
        return vouchersJson.map((json) => Voucher.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        await _authService.logout();
        throw Exception('Sessão expirada. Faça login novamente.');
      } else {
        throw Exception('Erro ao listar vouchers');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Sessão expirada')) {
        rethrow;
      }
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Revoga um voucher
  Future<void> revokeVoucher(String username) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/vouchers/revoke/$username'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          await _authService.logout();
          throw Exception('Sessão expirada');
        }
        throw Exception('Erro ao revogar voucher');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Sessão expirada')) {
        rethrow;
      }
      throw Exception('Erro de conexão: $e');
    }
  }
}

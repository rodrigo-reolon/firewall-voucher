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

  /// Gera um novo código de voucher no Hotspot
  Future<VoucherCode> generateVoucher(VoucherRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/vouchers/generate'),
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return VoucherCode.fromJson(data);
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

  /// Gera múltiplos vouchers de uma vez
  Future<List<VoucherCode>> generateBatchVouchers(VoucherRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/vouchers/generate-batch'),
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => VoucherCode.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        await _authService.logout();
        throw Exception('Sessão expirada. Faça login novamente.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Erro ao gerar vouchers');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Sessão expirada')) {
        rethrow;
      }
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Lista vouchers com filtro opcional
  Future<Map<String, dynamic>> listVouchers({String? status, int limit = 50, int offset = 0}) async {
    try {
      String url = '$_baseUrl/api/v1/vouchers/list?limit=$limit&offset=$offset';
      if (status != null) url += '&status_filter=$status';

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> vouchersJson = data['vouchers'] ?? [];
        final vouchers = vouchersJson.map((json) => VoucherCode.fromJson(json)).toList();
        return {
          'total': data['total'] ?? 0,
          'vouchers': vouchers,
        };
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

  /// Busca um voucher pelo código
  Future<VoucherCode> getVoucher(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/vouchers/$code'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return VoucherCode.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        await _authService.logout();
        throw Exception('Sessão expirada');
      } else if (response.statusCode == 404) {
        throw Exception('Voucher não encontrado');
      } else {
        throw Exception('Erro ao buscar voucher');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Sessão expirada')) {
        rethrow;
      }
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Revoga um voucher
  Future<void> revokeVoucher(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/vouchers/revoke'),
        headers: _headers,
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          await _authService.logout();
          throw Exception('Sessão expirada');
        } else if (response.statusCode == 404) {
          throw Exception('Voucher não encontrado');
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

  /// Busca estatísticas
  Future<VoucherStats> getStatistics() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/vouchers/stats/summary'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return VoucherStats.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        await _authService.logout();
        throw Exception('Sessão expirada');
      } else {
        throw Exception('Erro ao buscar estatísticas');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Sessão expirada')) {
        rethrow;
      }
      throw Exception('Erro de conexão: $e');
    }
  }
}

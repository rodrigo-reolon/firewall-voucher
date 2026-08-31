import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/voucher.dart';

/// Serviço de autenticação e gerenciamento de sessão
class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'jwt_token';
  static const String _usernameKey = 'username';
  static const String _roleKey = 'role';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  String? _username;
  String? _role;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get username => _username;
  String? get role => _role;

  /// Inicializa o serviço e verifica se há token salvo
  Future<void> init() async {
    _token = await _storage.read(key: _tokenKey);
    _username = await _storage.read(key: _usernameKey);
    _role = await _storage.read(key: _roleKey);
    _isAuthenticated = _token != null;
    notifyListeners();
  }

  /// Realiza login e salva o token
  Future<void> login(String username, String password, {String? baseUrl}) async {
    final apiUrl = baseUrl ?? 'http://10.0.2.2:8000';
    
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(data);

        _token = authResponse.accessToken;
        _username = authResponse.username;
        _role = authResponse.role;
        _isAuthenticated = true;

        // Salvar token de forma segura
        await _storage.write(key: _tokenKey, value: _token);
        await _storage.write(key: _usernameKey, value: _username);
        await _storage.write(key: _roleKey, value: _role);

        notifyListeners();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Erro ao fazer login');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Realiza logout e limpa dados
  Future<void> logout() async {
    _token = null;
    _username = null;
    _role = null;
    _isAuthenticated = false;

    await _storage.deleteAll();
    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/voucher.dart';

class SophosPortalService {
  final String portalUrl;
  final String username;
  final String password;
  final bool verifySsl;

  final Map<String, String> _cookies = {};
  String? _csrfToken;

  SophosPortalService({
    required this.portalUrl,
    required this.username,
    required this.password,
    this.verifySsl = false,
  });

  http.Client _createClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => !verifySsl;
    return IOClient(httpClient);
  }

  void _updateCookies(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final parts = setCookie.split(',');
      for (final part in parts) {
        final segments = part.split(';');
        for (final segment in segments) {
          if (segment.trim().contains('=')) {
            final eqIndex = segment.trim().indexOf('=');
            final name = segment.trim().substring(0, eqIndex).trim();
            final value = segment.trim().substring(eqIndex + 1).trim();
            if (name.toLowerCase() != 'path' &&
                name.toLowerCase() != 'expires' &&
                name.toLowerCase() != 'httponly' &&
                name.toLowerCase() != 'secure') {
              _cookies[name] = value;
            }
          }
        }
      }
    }
  }

  Map<String, String> _headers({Map<String, String>? extra}) {
    final cookieStr = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    return {
      'Cookie': cookieStr,
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      if (extra != null) ...extra,
    };
  }

  Future<void> login() async {
    final client = _createClient();
    try {
      // GET inicial para obter cookies
      final getResponse = await client.get(Uri.parse('$portalUrl/'), headers: {'User-Agent': 'Mozilla/5.0'});
      _updateCookies(getResponse);

      // POST login
      final loginResponse = await client.post(
        Uri.parse('$portalUrl/userportal/login.php'),
        headers: _headers(extra: {'Content-Type': 'application/x-www-form-urlencoded'}),
        body: {
          'username': username,
          'password': password,
          'login_username': '',
          'mode': '1',
          'loginbutton': 'Login'
        },
      );

      _updateCookies(loginResponse);

      if (loginResponse.statusCode == 302) {
        final location = loginResponse.headers['location'] ?? '';
        if (location.contains('logout')) {
          return; // Login bem sucedido
        }
      }

      final body = loginResponse.body.toLowerCase();
      if (body.contains('invalid') || body.contains('incorrect') || body.contains('failed')) {
        throw Exception('Credenciais inválidas');
      }
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, String>>> listHotspots() async {
    final client = _createClient();
    try {
      final response = await client.get(
        Uri.parse('$portalUrl/userportal/index.php?action=hotspots'),
        headers: _headers(),
      );
      _updateCookies(response);
      return _parseHotspots(response.body);
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, String>>> listVoucherDefinitions(String hotspotName) async {
    final client = _createClient();
    try {
      final response = await client.get(
        Uri.parse('$portalUrl/userportal/index.php?action=hotspots&hotspot=$hotspotName'),
        headers: _headers(),
      );
      _updateCookies(response);
      return _parseVoucherDefinitions(response.body);
    } finally {
      client.close();
    }
  }

  Future<List<String>> generateVouchers({
    required String hotspotName,
    required String definitionName,
    required int amount,
    String? description,
  }) async {
    final client = _createClient();
    try {
      final response = await client.post(
        Uri.parse('$portalUrl/userportal/index.php'),
        headers: _headers(extra: {'Content-Type': 'application/x-www-form-urlencoded'}),
        body: {
          'action': 'create_vouchers',
          'hotspot': hotspotName,
          'voucher_definition': definitionName,
          'amount': amount.toString(),
          'description': description ?? '',
        },
      );
      _updateCookies(response);
      if (response.statusCode != 200) throw Exception('Falha ao gerar vouchers');
      return _parseGeneratedVouchers(response.body);
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, dynamic>>> listVouchers({String? hotspotName}) async {
    final client = _createClient();
    try {
      var url = '$portalUrl/userportal/index.php?action=hotspots&tab=vouchers';
      if (hotspotName != null) url += '&hotspot=$hotspotName';
      final response = await client.get(Uri.parse(url), headers: _headers());
      _updateCookies(response);
      return _parseVoucherList(response.body);
    } finally {
      client.close();
    }
  }

  Future<void> deleteVoucher(String hotspotName, String voucherCode) async {
    final client = _createClient();
    try {
      await client.post(
        Uri.parse('$portalUrl/userportal/index.php'),
        headers: _headers(extra: {'Content-Type': 'application/x-www-form-urlencoded'}),
        body: {
          'action': 'delete_voucher',
          'hotspot': hotspotName,
          'voucher_code': voucherCode,
        },
      );
    } finally {
      client.close();
    }
  }

  Future<void> logout() async {
    final client = _createClient();
    try {
      await client.get(Uri.parse('$portalUrl/userportal/webpages/logout.jsp'), headers: _headers());
    } finally {
      client.close();
      _cookies.clear();
      _csrfToken = null;
    }
  }

  List<Map<String, String>> _parseHotspots(String html) {
    final List<Map<String, String>> hotspots = [];
    final regex = RegExp(r'<option[^>]*value=["\']([^"\']+)["\'][^>]*>([^<]+)</option>', caseSensitive: false);
    for (final match in regex.allMatches(html)) {
      final name = match.group(1)?.trim();
      final label = match.group(2)?.trim();
      if (name != null && name.isNotEmpty && !name.toLowerCase().contains('choose')) {
        hotspots.add({'name': name, 'label': label ?? name});
      }
    }
    return hotspots;
  }

  List<Map<String, String>> _parseVoucherDefinitions(String html) {
    final List<Map<String, String>> definitions = [];
    final regex = RegExp(r'<option[^>]*value=["\']([^"\']+)["\'][^>]*>([^<]+)</option>', caseSensitive: false);
    for (final match in regex.allMatches(html)) {
      final name = match.group(1)?.trim();
      final label = match.group(2)?.trim();
      if (name != null && name.isNotEmpty) {
        definitions.add({'name': name, 'label': label ?? name});
      }
    }
    return definitions;
  }

  List<String> _parseGeneratedVouchers(String html) {
    final List<String> codes = [];
    final regex = RegExp(r'\b([A-Z0-9]{8})\b');
    for (final match in regex.allMatches(html)) {
      final code = match.group(1);
      if (code != null && !codes.contains(code)) codes.add(code);
    }
    return codes;
  }

  List<Map<String, dynamic>> _parseVoucherList(String html) {
    final List<Map<String, dynamic>> vouchers = [];
    final rowRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
    final cellRegex = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true, caseSensitive: false);
    for (final rowMatch in rowRegex.allMatches(html)) {
      final cells = cellRegex.allMatches(rowMatch.group(1)!).map((m) => m.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '').toList();
      if (cells.length >= 3) {
        vouchers.add({'code': cells[0], 'description': cells.length > 1 ? cells[1] : '', 'status': cells.length > 2 ? cells[2] : ''});
      }
    }
    return vouchers;
  }
}

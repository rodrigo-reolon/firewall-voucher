import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import '../models/voucher.dart';

/// Serviço que acessa diretamente o User Portal do Sophos Firewall
/// para gerar vouchers válidos no formato aceito pelo Captive Portal.
///
/// O portal do usuário (porta 223) é o único método oficial para gerar
/// vouchers que são aceitos pelo Hotspot. Este serviço automatiza
/// o processo de login e geração via scraping do portal.
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
    final cookieStr = _cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
    return {
      'Cookie': cookieStr,
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      if (_csrfToken != null) 'X-CSRF-Token': _csrfToken!,
      if (extra != null) ...extra,
    };
  }

  Future<void> login() async {
    final client = _createClient();

    try {
      final getResponse = await client.get(
        Uri.parse('$portalUrl/'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      );
      _updateCookies(getResponse);
      _csrfToken = _extractCsrfToken(getResponse.body);

      final loginResponse = await client.post(
        Uri.parse('$portalUrl/index.php'),
        headers: _headers(
          extra: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        body: {
          'action': 'login',
          'username': username,
          'password': password,
          if (_csrfToken != null) 'csrf_token': _csrfToken!,
        },
      );

      _updateCookies(loginResponse);

      if (loginResponse.statusCode != 200) {
        throw Exception('Falha no login: HTTP ${loginResponse.statusCode}');
      }

      final body = loginResponse.body.toLowerCase();
      if (body.contains('invalid') ||
          body.contains('incorrect') ||
          body.contains('failed')) {
        throw Exception('Credenciais inválidas');
      }

      final newToken = _extractCsrfToken(loginResponse.body);
      if (newToken != null) {
        _csrfToken = newToken;
      }
    } finally {
      client.close();
    }
  }

  String? _extractCsrfToken(String html) {
    // Procurar por: <input type="hidden" name="csrf_token" value="..." />
    var regex = RegExp(
      r'<input[^>]*name=["\']csrf_token["\'][^>]*value=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    var match = regex.firstMatch(html);
    if (match != null) return match.group(1);

    // Alternativa: name="token"
    regex = RegExp(
      r'<input[^>]*name=["\']token["\'][^>]*value=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    match = regex.firstMatch(html);
    if (match != null) return match.group(1);

    // Alternativa: meta name="csrf-token"
    regex = RegExp(
      r'<meta[^>]*name=["\']csrf-token["\'][^>]*content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    match = regex.firstMatch(html);
    if (match != null) return match.group(1);

    return null;
  }

  Future<List<Map<String, String>>> listHotspots() async {
    final client = _createClient();

    try {
      final response = await client.get(
        Uri.parse('$portalUrl/index.php?action=hotspots'),
        headers: _headers(),
      );

      _updateCookies(response);
      _csrfToken = _extractCsrfToken(response.body) ?? _csrfToken;

      return _parseHotspots(response.body);
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, String>>> listVoucherDefinitions(
      String hotspotName) async {
    final client = _createClient();

    try {
      final response = await client.get(
        Uri.parse(
            '$portalUrl/index.php?action=hotspots&hotspot=${Uri.encodeComponent(hotspotName)}'),
        headers: _headers(),
      );

      _updateCookies(response);
      _csrfToken = _extractCsrfToken(response.body) ?? _csrfToken;

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
        Uri.parse('$portalUrl/index.php'),
        headers: _headers(
          extra: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        body: {
          'action': 'create_vouchers',
          'hotspot': hotspotName,
          'voucher_definition': definitionName,
          'amount': amount.toString(),
          'description': description ?? '',
          if (_csrfToken != null) 'csrf_token': _csrfToken!,
        },
      );

      _updateCookies(response);
      _csrfToken = _extractCsrfToken(response.body) ?? _csrfToken;

      if (response.statusCode != 200) {
        throw Exception('Falha ao gerar vouchers: HTTP ${response.statusCode}');
      }

      return _parseGeneratedVouchers(response.body);
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, dynamic>>> listVouchers({
    String? hotspotName,
  }) async {
    final client = _createClient();

    try {
      var url = '$portalUrl/index.php?action=hotspots&tab=vouchers';
      if (hotspotName != null) {
        url += '&hotspot=${Uri.encodeComponent(hotspotName)}';
      }

      final response = await client.get(
        Uri.parse(url),
        headers: _headers(),
      );

      _updateCookies(response);
      _csrfToken = _extractCsrfToken(response.body) ?? _csrfToken;

      return _parseVoucherList(response.body);
    } finally {
      client.close();
    }
  }

  Future<void> deleteVoucher(String hotspotName, String voucherCode) async {
    final client = _createClient();

    try {
      final response = await client.post(
        Uri.parse('$portalUrl/index.php'),
        headers: _headers(
          extra: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        body: {
          'action': 'delete_voucher',
          'hotspot': hotspotName,
          'voucher_code': voucherCode,
          if (_csrfToken != null) 'csrf_token': _csrfToken!,
        },
      );

      _updateCookies(response);
      _csrfToken = _extractCsrfToken(response.body) ?? _csrfToken;
    } finally {
      client.close();
    }
  }

  Future<void> logout() async {
    final client = _createClient();

    try {
      await client.get(
        Uri.parse('$portalUrl/index.php?action=logout'),
        headers: _headers(),
      );
    } finally {
      client.close();
      _cookies.clear();
      _csrfToken = null;
    }
  }

  List<Map<String, String>> _parseHotspots(String html) {
    final List<Map<String, String>> hotspots = [];

    final regex = RegExp(
      r'<option[^>]*value=["\']([^"\']+)["\'][^>]*>([^<]+)</option>',
      caseSensitive: false,
    );

    for (final match in regex.allMatches(html)) {
      final name = match.group(1)?.trim();
      final label = match.group(2)?.trim();
      if (name != null && name.isNotEmpty && !name.startsWith('Choose')) {
        hotspots.add({'name': name, 'label': label ?? name});
      }
    }

    return hotspots;
  }

  List<Map<String, String>> _parseVoucherDefinitions(String html) {
    final List<Map<String, String>> definitions = [];

    final regex = RegExp(
      r'<option[^>]*value=["\']([^"\']+)["\'][^>]*>([^<]+)</option>',
      caseSensitive: false,
    );

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
      if (code != null && !codes.contains(code)) {
        codes.add(code);
      }
    }

    return codes;
  }

  List<Map<String, dynamic>> _parseVoucherList(String html) {
    final List<Map<String, dynamic>> vouchers = [];

    final rowRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
    final cellRegex = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true, caseSensitive: false);

    for (final rowMatch in rowRegex.allMatches(html)) {
      final cells = cellRegex
          .allMatches(rowMatch.group(1)!)
          .map((m) => m.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '')
          .toList();

      if (cells.length >= 3) {
        vouchers.add({
          'code': cells.isNotEmpty ? cells[0] : '',
          'description': cells.length > 1 ? cells[1] : '',
          'status': cells.length > 2 ? cells[2] : '',
        });
      }
    }

    return vouchers;
  }
}

/// Modelos de dados para o app Firewall Voucher
library models;

/// Representa um voucher de acesso gerado
class Voucher {
  final String username;
  final String password;
  final String expiresAt;
  final int validityHours;
  final String? visitorName;
  final String accessProfile;
  final String status;
  final String createdAt;
  final String? qrCodeData;

  Voucher({
    required this.username,
    required this.password,
    required this.expiresAt,
    required this.validityHours,
    this.visitorName,
    required this.accessProfile,
    required this.status,
    required this.createdAt,
    this.qrCodeData,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      expiresAt: json['expires_at'] ?? '',
      validityHours: json['validity_hours'] ?? 8,
      visitorName: json['visitor_name'],
      accessProfile: json['access_profile'] ?? 'Guest',
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] ?? '',
      qrCodeData: json['qr_code_data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'expires_at': expiresAt,
      'validity_hours': validityHours,
      'visitor_name': visitorName,
      'access_profile': accessProfile,
      'status': status,
      'created_at': createdAt,
      'qr_code_data': qrCodeData,
    };
  }

  bool get isActive => status == 'active';
  bool get isExpired => DateTime.parse(expiresAt).isBefore(DateTime.now());
}

/// Dados para requisição de geração de voucher
class VoucherRequest {
  final String? visitorName;
  final int validityHours;
  final int dataQuotaMb;
  final String accessProfile;

  VoucherRequest({
    this.visitorName,
    this.validityHours = 8,
    this.dataQuotaMb = 500,
    this.accessProfile = 'Guest',
  });

  Map<String, dynamic> toJson() {
    return {
      'visitor_name': visitorName,
      'validity_hours': validityHours,
      'data_quota_mb': dataQuotaMb,
      'access_profile': accessProfile,
    };
  }
}

/// Resposta de autenticação
class AuthResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String username;
  final String role;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.username,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      expiresIn: json['expires_in'] ?? 0,
      username: json['username'] ?? '',
      role: json['role'] ?? 'operator',
    );
  }
}

/// Períodos de validade disponíveis
class ValidityPeriod {
  final int hours;
  final String label;

  const ValidityPeriod(this.hours, this.label);

  static const List<ValidityPeriod> periods = [
    ValidityPeriod(1, '1 hora'),
    ValidityPeriod(4, '4 horas'),
    ValidityPeriod(8, '8 horas'),
    ValidityPeriod(24, '24 horas'),
    ValidityPeriod(168, '7 dias'),
  ];
}

/// Modelos de dados para o app Firewall Voucher - Hotspot
library models;

import 'package:intl/intl.dart';

/// Representa um código de voucher do Hotspot
class VoucherCode {
  final int? id;
  final String code;
  final String? description;
  final String? definitionName;
  final int validityDays;
  final int dataLimitMb;
  final int devicesAllowed;
  final String status;
  final String createdAt;
  final String expiresAt;
  final String? createdBy;
  final String? notes;

  VoucherCode({
    this.id,
    required this.code,
    this.description,
    this.definitionName,
    required this.validityDays,
    required this.dataLimitMb,
    required this.devicesAllowed,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.createdBy,
    this.notes,
  });

  factory VoucherCode.fromJson(Map<String, dynamic> json) {
    return VoucherCode(
      id: json['id'],
      code: json['code'] ?? '',
      description: json['description'],
      definitionName: json['definition_name'],
      validityDays: json['validity_days'] ?? 30,
      dataLimitMb: json['data_limit_mb'] ?? 0,
      devicesAllowed: json['devices_allowed'] ?? 1,
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] ?? '',
      expiresAt: json['expires_at'] ?? '',
      createdBy: json['created_by'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'definition_name': definitionName,
      'validity_days': validityDays,
      'data_limit_mb': dataLimitMb,
      'devices_allowed': devicesAllowed,
      'status': status,
      'created_at': createdAt,
      'expires_at': expiresAt,
      'created_by': createdBy,
      'notes': notes,
    };
  }

  bool get isActive => status == 'active';
  bool get isExpired => DateTime.parse(expiresAt).isBefore(DateTime.now());
  bool get isRevoked => status == 'revoked';
  bool get isUsed => status == 'used';

  String get formattedExpiry {
    try {
      final date = DateTime.parse(expiresAt);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return expiresAt;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return isExpired ? 'Expirado' : 'Ativo';
      case 'expired':
        return 'Expirado';
      case 'revoked':
        return 'Revogado';
      case 'used':
        return 'Usado';
      default:
        return status;
    }
  }
}

/// Dados para requisição de geração de voucher
class VoucherRequest {
  final int quantity;
  final String? definitionName;
  final int validityDays;
  final int dataLimitMb;
  final int devicesAllowed;
  final String? visitorName;
  final String? notes;

  VoucherRequest({
    this.quantity = 1,
    this.definitionName,
    this.validityDays = 30,
    this.dataLimitMb = 0,
    this.devicesAllowed = 1,
    this.visitorName,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'definition_name': definitionName,
      'validity_days': validityDays,
      'data_limit_mb': dataLimitMb,
      'devices_allowed': devicesAllowed,
      'visitor_name': visitorName,
      'notes': notes,
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
  final int days;
  final String label;

  const ValidityPeriod(this.days, this.label);

  static const List<ValidityPeriod> periods = [
    ValidityPeriod(1, '1 dia'),
    ValidityPeriod(7, '7 dias'),
    ValidityPeriod(15, '15 dias'),
    ValidityPeriod(30, '30 dias'),
    ValidityPeriod(90, '90 dias'),
  ];
}

/// Estatísticas dos vouchers
class VoucherStats {
  final int total;
  final int active;
  final int expired;
  final int revoked;
  final int used;

  VoucherStats({
    required this.total,
    required this.active,
    required this.expired,
    required this.revoked,
    required this.used,
  });

  factory VoucherStats.fromJson(Map<String, dynamic> json) {
    return VoucherStats(
      total: json['total'] ?? 0,
      active: json['active'] ?? 0,
      expired: json['expired'] ?? 0,
      revoked: json['revoked'] ?? 0,
      used: json['used'] ?? 0,
    );
  }
}

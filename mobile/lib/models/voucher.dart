/// Modelos de dados para o app Guest WiFi Voucher
library models;

import 'package:intl/intl.dart';

/// Representa um código de voucher gerado localmente
class VoucherCode {
  final String id;
  final String code;
  final String? description;
  final int validityDays;
  final int dataLimitMb;
  final int devicesAllowed;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? notes;

  VoucherCode({
    required this.id,
    required this.code,
    this.description,
    required this.validityDays,
    this.dataLimitMb = 0,
    this.devicesAllowed = 1,
    this.status = 'active',
    required this.createdAt,
    required this.expiresAt,
    this.notes,
  });

  factory VoucherCode.create({
    required String code,
    String? description,
    int validityDays = 30,
    int dataLimitMb = 0,
    int devicesAllowed = 1,
    String? notes,
  }) {
    final now = DateTime.now();
    return VoucherCode(
      id: now.millisecondsSinceEpoch.toString(),
      code: code,
      description: description,
      validityDays: validityDays,
      dataLimitMb: dataLimitMb,
      devicesAllowed: devicesAllowed,
      status: 'active',
      createdAt: now,
      expiresAt: now.add(Duration(days: validityDays)),
      notes: notes,
    );
  }

  bool get isActive => status == 'active' && !isExpired;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isRevoked => status == 'revoked';

  String get formattedExpiry {
    return DateFormat('dd/MM/yyyy').format(expiresAt);
  }

  String get statusLabel {
    if (status == 'revoked') return 'Revogado';
    if (isExpired) return 'Expirado';
    return 'Ativo';
  }

  Color get statusColor {
    if (status == 'revoked') return Colors.red;
    if (isExpired) return Colors.orange;
    return Colors.green;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'validity_days': validityDays,
      'data_limit_mb': dataLimitMb,
      'devices_allowed': devicesAllowed,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory VoucherCode.fromJson(Map<String, dynamic> json) {
    return VoucherCode(
      id: json['id'],
      code: json['code'],
      description: json['description'],
      validityDays: json['validity_days'] ?? 30,
      dataLimitMb: json['data_limit_mb'] ?? 0,
      devicesAllowed: json['devices_allowed'] ?? 1,
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      notes: json['notes'],
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

/// Limites de dados disponíveis
class DataLimit {
  final int mb;
  final String label;

  const DataLimit(this.mb, this.label);

  static const List<DataLimit> limits = [
    DataLimit(0, 'Ilimitado'),
    DataLimit(100, '100 MB'),
    DataLimit(500, '500 MB'),
    DataLimit(1000, '1 GB'),
    DataLimit(5000, '5 GB'),
  ];
}

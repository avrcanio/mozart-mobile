class SupplierDto {
  const SupplierDto({
    required this.id,
    required this.name,
    this.defaultPaymentTypeId,
  });

  final int id;
  final String name;

  /// Backend FK / nested object for the supplier's default payment type (narudžbe).
  final int? defaultPaymentTypeId;

  factory SupplierDto.fromJson(Map<String, dynamic> json) {
    return SupplierDto(
      id: _asInt(json['id']),
      name: (json['name'] ?? json['supplier_name'] ?? '').toString(),
      defaultPaymentTypeId: _optionalFk(
            json['default_payment_type'] ??
                json['default_payment_type_id'] ??
                json['payment_type'],
          ) ??
          _optionalFk(json['payment_type_id']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _optionalFk(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map) {
      final rawId = value['id'];
      if (rawId == null) {
        return null;
      }
      final parsed = _asInt(rawId);
      return parsed == 0 ? null : parsed;
    }
    final parsed = _asInt(value);
    return parsed == 0 ? null : parsed;
  }
}

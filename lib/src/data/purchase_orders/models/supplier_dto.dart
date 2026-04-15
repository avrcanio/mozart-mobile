class SupplierDto {
  const SupplierDto({
    required this.id,
    required this.name,
    this.defaultPaymentTypeId,
  });

  final int id;
  final String name;
  final int? defaultPaymentTypeId;

  factory SupplierDto.fromJson(Map<String, dynamic> json) {
    return SupplierDto(
      id: _asInt(json['id']),
      name: (json['name'] ?? json['supplier_name'] ?? '').toString(),
      defaultPaymentTypeId: _asNullableInt(
        json['default_payment_type'] ?? json['defaultPaymentType'],
      ),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}

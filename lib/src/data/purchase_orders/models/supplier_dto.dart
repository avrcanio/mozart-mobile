class SupplierDto {
  const SupplierDto({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory SupplierDto.fromJson(Map<String, dynamic> json) {
    return SupplierDto(
      id: _asInt(json['id']),
      name: (json['name'] ?? json['supplier_name'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}

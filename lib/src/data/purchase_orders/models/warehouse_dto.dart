import '../../../domain/warehouse_option.dart';

class WarehouseDto {
  const WarehouseDto({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory WarehouseDto.fromJson(Map<String, dynamic> json) {
    return WarehouseDto(
      id: _asInt(json['id'] ?? json['rm_id']),
      name: (json['name'] ?? '').toString().trim(),
    );
  }

  WarehouseOption toDomain() {
    return WarehouseOption(
      id: id,
      name: name.isEmpty ? 'Skladiste #$id' : name,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}

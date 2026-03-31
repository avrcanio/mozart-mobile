class PaymentTypeDto {
  const PaymentTypeDto({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory PaymentTypeDto.fromJson(Map<String, dynamic> json) {
    return PaymentTypeDto(
      id: _asInt(json['id']),
      name: (json['name'] ?? json['label'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}

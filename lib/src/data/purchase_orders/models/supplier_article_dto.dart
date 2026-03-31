class SupplierArticleDto {
  const SupplierArticleDto({
    required this.id,
    required this.name,
    required this.unitOfMeasureId,
    required this.unitName,
    required this.defaultPrice,
  });

  final int id;
  final String name;
  final int unitOfMeasureId;
  final String unitName;
  final double defaultPrice;

  factory SupplierArticleDto.fromJson(Map<String, dynamic> json) {
    return SupplierArticleDto(
      id: _asInt(
        json['id'] ?? json['artikl'] ?? json['artikl_id'] ?? json['rm_id'],
      ),
      name: (json['artikl_name'] ?? json['name'] ?? json['article_name'] ?? '')
          .toString()
          .trim(),
      unitOfMeasureId: _asInt(
        json['unit_of_measure'] ??
            json['unit']?['rm_id'] ??
            json['unit']?['id'] ??
            json['unit_id'],
      ),
      unitName: (json['unit_name'] ??
              json['unit']?['name'] ??
              json['unit_of_measure_name'] ??
              '')
          .toString()
          .trim(),
      defaultPrice: _asDouble(
        json['price'] ?? json['unit_price'] ?? json['default_price'],
      ),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}

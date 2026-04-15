class SupplierArticleDto {
  const SupplierArticleDto({
    required this.id,
    required this.name,
    required this.unitOfMeasureId,
    required this.unitName,
    required this.defaultPrice,
    required this.vatRate,
    required this.depositAmount,
    this.thumbnailUrl,
    this.categoryId,
    this.categoryName,
    this.categorySortOrder,
    this.categoryPath = const <String>[],
    this.sortGroupKey,
  });

  final int id;
  final String name;
  final int unitOfMeasureId;
  final String unitName;
  final double defaultPrice;
  final double vatRate;
  final double depositAmount;
  final String? thumbnailUrl;
  final int? categoryId;
  final String? categoryName;
  final int? categorySortOrder;
  final List<String> categoryPath;
  final String? sortGroupKey;

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
      unitName:
          (json['unit_name'] ??
                  json['unit']?['name'] ??
                  json['unit_of_measure_name'] ??
                  '')
              .toString()
              .trim(),
      defaultPrice: _asDouble(
        json['price'] ?? json['unit_price'] ?? json['default_price'],
      ),
      vatRate: _asDouble(json['vat_rate'] ?? json['vatRate']),
      depositAmount: _asDouble(json['deposit_amount'] ?? json['depositAmount']),
      thumbnailUrl: _asString(
        json['image_50x75'] ??
            json['image'] ??
            json['thumbnail_url'] ??
            json['thumbnailUrl'] ??
            json['thumbnail'] ??
            json['image_url'],
      ),
      categoryId: _asNullableInt(
        json['category_id'] ?? json['category']?['id'] ?? json['categoryId'],
      ),
      categoryName: _asString(
        json['category_name'] ??
            json['category']?['name'] ??
            json['categoryName'],
      ),
      categorySortOrder: _asNullableInt(
        json['category_sort_order'] ??
            json['category']?['sort_order'] ??
            json['categorySortOrder'],
      ),
      categoryPath: _asCategoryPath(
        json['category_path'] ??
            json['categoryPath'] ??
            json['category']?['path'] ??
            json['category_breadcrumb'],
      ),
      sortGroupKey: _asString(json['sort_group_key'] ?? json['sortGroupKey']),
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

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  static String? _asString(dynamic value) {
    final normalized = (value ?? '').toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static List<String> _asCategoryPath(dynamic value) {
    if (value is List) {
      return value
          .map((segment) => segment.toString().trim())
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
    }
    final normalized = _asString(value);
    if (normalized == null) {
      return const <String>[];
    }
    return normalized
        .split(RegExp(r'\s*>\s*|\s*/\s*|\s*-\s*'))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }
}

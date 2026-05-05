class SupplierArticleDto {
  const SupplierArticleDto({
    required this.id,
    required this.referenceId,
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
    this.packagingPath,
    this.packagingLevels = const <SupplierArticlePackagingLevelDto>[],
    this.sortGroupKey,
  });

  final int id;
  final int referenceId;
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
  final String? packagingPath;
  final List<SupplierArticlePackagingLevelDto> packagingLevels;
  final String? sortGroupKey;

  SupplierArticleDto copyWith({
    int? id,
    int? referenceId,
    String? name,
    int? unitOfMeasureId,
    String? unitName,
    double? defaultPrice,
    double? vatRate,
    double? depositAmount,
    String? thumbnailUrl,
    int? categoryId,
    String? categoryName,
    int? categorySortOrder,
    List<String>? categoryPath,
    String? packagingPath,
    List<SupplierArticlePackagingLevelDto>? packagingLevels,
    String? sortGroupKey,
  }) {
    return SupplierArticleDto(
      id: id ?? this.id,
      referenceId: referenceId ?? this.referenceId,
      name: name ?? this.name,
      unitOfMeasureId: unitOfMeasureId ?? this.unitOfMeasureId,
      unitName: unitName ?? this.unitName,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      vatRate: vatRate ?? this.vatRate,
      depositAmount: depositAmount ?? this.depositAmount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categorySortOrder: categorySortOrder ?? this.categorySortOrder,
      categoryPath: categoryPath ?? this.categoryPath,
      packagingPath: packagingPath ?? this.packagingPath,
      packagingLevels: packagingLevels ?? this.packagingLevels,
      sortGroupKey: sortGroupKey ?? this.sortGroupKey,
    );
  }

  factory SupplierArticleDto.fromJson(Map<String, dynamic> json) {
    final thumbnailUrl = _asString(
      json['image_50x75'] ??
          json['image'] ??
          json['thumbnail_url'] ??
          json['thumbnailUrl'] ??
          json['thumbnail'] ??
          json['image_url'],
    );
    final referenceResolution = _resolveReferenceIdWithSource(json, thumbnailUrl);
    final resolvedId = _asInt(
      json['id'] ?? json['artikl'] ?? json['artikl_id'] ?? json['rm_id'],
    );
    // Debug trace for supplier catalog/detail article identity resolution.
    // ignore: avoid_print
    print(
      '[po-article-dto] parse '
      'resolvedId=$resolvedId '
      'referenceId=${referenceResolution.id} '
      'referenceSource=${referenceResolution.source} '
      'name="${(json['artikl_name'] ?? json['name'] ?? json['article_name'] ?? '').toString().trim()}" '
      'thumbnailUrl=${thumbnailUrl ?? ""} '
      'hasPackagingLevels=${json['packaging_levels'] is List ? (json['packaging_levels'] as List).length : 0}',
    );
    return SupplierArticleDto(
      id: resolvedId,
      referenceId: referenceResolution.id,
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
      thumbnailUrl: thumbnailUrl,
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
      packagingPath: _asString(
        json['packaging_path'] ?? json['packagingPath'],
      ),
      packagingLevels: _asPackagingLevels(
        json['packaging_levels'] ?? json['packagingLevels'],
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

  static List<SupplierArticlePackagingLevelDto> _asPackagingLevels(
    dynamic value,
  ) {
    if (value is! List) {
      return const <SupplierArticlePackagingLevelDto>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => SupplierArticlePackagingLevelDto.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: true)
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  }

  static _ReferenceIdResolution _resolveReferenceIdWithSource(
    Map<String, dynamic> json,
    String? thumbnailUrl,
  ) {
    final directValue = _asNullableInt(
      json['artikl_rm_id'] ??
          json['rm_id'] ??
          json['artikl'] ??
          json['artikl_id'] ??
          json['article_id'] ??
          json['articleId'],
    );
    if (directValue != null && directValue > 0) {
      return _ReferenceIdResolution(id: directValue, source: 'direct-rm-id');
    }
    final imageDerivedId = _extractArticleIdFromMediaUrl(
      thumbnailUrl ??
          _asString(json['image_46x75']) ??
          _asString(json['image_125x200']) ??
          _asString(json['image']) ??
          _asString(json['image_url']),
    );
    if (imageDerivedId != null && imageDerivedId > 0) {
      return _ReferenceIdResolution(id: imageDerivedId, source: 'image-url');
    }
    return _ReferenceIdResolution(
      id: _asInt(
        json['id'] ??
            json['artikl_rm_id'] ??
            json['artikl'] ??
            json['artikl_id'] ??
            json['rm_id'],
      ),
      source: 'fallback-id',
    );
  }

  static int? _extractArticleIdFromMediaUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final match = RegExp(r'/api/artikli/(\d+)/').firstMatch(value);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }
}

class _ReferenceIdResolution {
  const _ReferenceIdResolution({required this.id, required this.source});

  final int id;
  final String source;
}

class SupplierArticlePackagingLevelDto {
  const SupplierArticlePackagingLevelDto({
    required this.id,
    required this.sortOrder,
    required this.unitOfMeasureId,
    required this.unitName,
    required this.levelName,
    required this.isBase,
    required this.baseQuantityTotal,
    this.containsPrevious,
  });

  final int id;
  final int sortOrder;
  final int unitOfMeasureId;
  final String unitName;
  final String levelName;
  final bool isBase;
  final double baseQuantityTotal;
  final double? containsPrevious;

  int get storageKey {
    if (unitOfMeasureId > 0) {
      return unitOfMeasureId;
    }
    if (id > 0) {
      return id;
    }
    return sortOrder + 1;
  }

  String get displayName {
    if (unitName.trim().isNotEmpty) {
      return unitName.trim();
    }
    return levelName.trim();
  }

  factory SupplierArticlePackagingLevelDto.fromJson(Map<String, dynamic> json) {
    final sortOrder = SupplierArticleDto._asInt(
      json['sort_order'] ?? json['sortOrder'],
    );
    final id =
        SupplierArticleDto._asNullableInt(
          json['id'] ?? json['packaging_level_id'] ?? json['packagingLevelId'],
        ) ??
        (sortOrder + 1);
    return SupplierArticlePackagingLevelDto(
      id: id,
      sortOrder: sortOrder,
      unitOfMeasureId:
          SupplierArticleDto._asNullableInt(
            json['unit_of_measure'] ??
                json['unitOfMeasure'] ??
                json['unit']?['id'],
          ) ??
          0,
      unitName:
          (json['unit_name'] ??
                  json['unitName'] ??
                  json['unit']?['name'] ??
                  '')
              .toString()
              .trim(),
      levelName: (json['level_name'] ?? json['levelName'] ?? '')
          .toString()
          .trim(),
      isBase:
          json['is_base'] == true ||
          json['isBase'] == true ||
          sortOrder == 0,
      baseQuantityTotal: SupplierArticleDto._asDouble(
        json['base_quantity_total'] ?? json['baseQuantityTotal'],
      ),
      containsPrevious: _asNullableDouble(
        json['contains_previous'] ?? json['containsPrevious'],
      ),
    );
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

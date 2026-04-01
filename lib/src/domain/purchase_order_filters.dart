class PurchaseOrderFilters {
  const PurchaseOrderFilters({
    this.statuses = const <String>[],
    this.supplierId,
    this.orderedFrom,
    this.orderedTo,
  });

  final List<String> statuses;
  final int? supplierId;
  final DateTime? orderedFrom;
  final DateTime? orderedTo;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      supplierId != null ||
      orderedFrom != null ||
      orderedTo != null;

  PurchaseOrderFilters copyWith({
    List<String>? statuses,
    int? supplierId,
    DateTime? orderedFrom,
    DateTime? orderedTo,
    bool clearStatus = false,
    bool clearSupplier = false,
    bool clearOrderedFrom = false,
    bool clearOrderedTo = false,
  }) {
    return PurchaseOrderFilters(
      statuses: clearStatus ? const <String>[] : (statuses ?? this.statuses),
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      orderedFrom: clearOrderedFrom ? null : (orderedFrom ?? this.orderedFrom),
      orderedTo: clearOrderedTo ? null : (orderedTo ?? this.orderedTo),
    );
  }

  Map<String, String> toQueryParameters() {
    return <String, String>{
      if (supplierId != null) 'supplier': '$supplierId',
      if (orderedFrom != null) 'ordered_from': _formatDate(orderedFrom!),
      if (orderedTo != null) 'ordered_to': _formatDate(orderedTo!),
    };
  }

  Iterable<MapEntry<String, String>> toRepeatedQueryParameters() sync* {
    for (final status in statuses) {
      if (_hasText(status)) {
        yield MapEntry<String, String>('status', status.trim());
      }
    }
    final singleValueParameters = toQueryParameters();
    for (final entry in singleValueParameters.entries) {
      yield entry;
    }
  }

  static String _formatDate(DateTime value) {
    final normalized = value.toLocal();
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

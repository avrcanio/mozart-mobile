class PurchaseOrderFilters {
  const PurchaseOrderFilters({
    this.status,
    this.supplierId,
    this.orderedFrom,
    this.orderedTo,
  });

  final String? status;
  final int? supplierId;
  final DateTime? orderedFrom;
  final DateTime? orderedTo;

  bool get hasActiveFilters =>
      _hasText(status) ||
      supplierId != null ||
      orderedFrom != null ||
      orderedTo != null;

  PurchaseOrderFilters copyWith({
    String? status,
    int? supplierId,
    DateTime? orderedFrom,
    DateTime? orderedTo,
    bool clearStatus = false,
    bool clearSupplier = false,
    bool clearOrderedFrom = false,
    bool clearOrderedTo = false,
  }) {
    return PurchaseOrderFilters(
      status: clearStatus ? null : (status ?? this.status),
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      orderedFrom: clearOrderedFrom ? null : (orderedFrom ?? this.orderedFrom),
      orderedTo: clearOrderedTo ? null : (orderedTo ?? this.orderedTo),
    );
  }

  Map<String, String> toQueryParameters() {
    return <String, String>{
      if (_hasText(status)) 'status': status!.trim(),
      if (supplierId != null) 'supplier': '$supplierId',
      if (orderedFrom != null) 'ordered_from': _formatDate(orderedFrom!),
      if (orderedTo != null) 'ordered_to': _formatDate(orderedTo!),
    };
  }

  static String _formatDate(DateTime value) {
    final normalized = value.toLocal();
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.vendor,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
    required this.buyer,
  });

  final String id;
  final String vendor;
  final String status;
  final double total;
  final String currency;
  final DateTime createdAt;
  final String buyer;
}

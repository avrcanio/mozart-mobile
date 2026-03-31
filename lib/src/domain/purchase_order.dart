class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.supplierName,
    required this.paymentTypeName,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
    required this.lines,
  });

  final int id;
  final String reference;
  final String status;
  final String supplierName;
  final String paymentTypeName;
  final double totalAmount;
  final String currency;
  final DateTime? createdAt;
  final List<PurchaseOrderLine> lines;

  double get receivedQuantity =>
      lines.fold(0, (sum, line) => sum + line.receivedQuantity);

  double get remainingQuantity =>
      lines.fold(0, (sum, line) => sum + line.remainingQuantity);
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.id,
    required this.articleName,
    required this.quantity,
    required this.receivedQuantity,
    required this.remainingQuantity,
    required this.unitPrice,
  });

  final int id;
  final String articleName;
  final double quantity;
  final double receivedQuantity;
  final double remainingQuantity;
  final double unitPrice;
}

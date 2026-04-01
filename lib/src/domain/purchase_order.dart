class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.reference,
    required this.supplierId,
    required this.status,
    required this.statusLabel,
    required this.supplierName,
    required this.paymentTypeId,
    required this.paymentTypeName,
    required this.totalAmount,
    this.totalNetAmount = 0,
    this.totalGrossAmount = 0,
    this.totalDepositAmount = 0,
    this.createdBy = '',
    this.sentAt,
    this.updatedAt,
    this.receiptCreated = false,
    this.history = const <PurchaseOrderHistoryEntry>[],
    required this.currency,
    required this.orderedAt,
    required this.lines,
  });

  final int id;
  final String reference;
  final int supplierId;
  final String status;
  final String statusLabel;
  final String supplierName;
  final int? paymentTypeId;
  final String paymentTypeName;
  final double totalAmount;
  final double totalNetAmount;
  final double totalGrossAmount;
  final double totalDepositAmount;
  final String createdBy;
  final DateTime? sentAt;
  final DateTime? updatedAt;
  final bool receiptCreated;
  final List<PurchaseOrderHistoryEntry> history;
  final String currency;
  final DateTime? orderedAt;
  final List<PurchaseOrderLine> lines;

  double get receivedQuantity =>
      lines.fold(0, (sum, line) => sum + line.receivedQuantity);

  double get remainingQuantity =>
      lines.fold(0, (sum, line) => sum + line.remainingQuantity);

  bool get canSend => status == 'created';
}

class PurchaseOrderHistoryEntry {
  const PurchaseOrderHistoryEntry({
    required this.title,
    required this.description,
    required this.occurredAt,
  });

  final String title;
  final String description;
  final DateTime? occurredAt;
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.id,
    required this.articleId,
    required this.articleName,
    required this.unitOfMeasureId,
    required this.unitName,
    required this.baseGroup,
    required this.quantity,
    required this.receivedQuantity,
    required this.remainingQuantity,
    required this.unitPrice,
  });

  final int id;
  final int articleId;
  final String articleName;
  final int unitOfMeasureId;
  final String unitName;
  final String baseGroup;
  final double quantity;
  final double receivedQuantity;
  final double remainingQuantity;
  final double unitPrice;
}

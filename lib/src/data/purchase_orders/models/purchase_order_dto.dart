import '../../../domain/purchase_order.dart';

class PurchaseOrderDto {
  const PurchaseOrderDto({
    required this.id,
    required this.reference,
    required this.status,
    required this.statusLabel,
    required this.supplierName,
    required this.paymentTypeName,
    required this.totalAmount,
    required this.currency,
    required this.orderedAt,
    required this.lines,
  });

  final int id;
  final String reference;
  final String status;
  final String statusLabel;
  final String supplierName;
  final String paymentTypeName;
  final double totalAmount;
  final String currency;
  final DateTime? orderedAt;
  final List<PurchaseOrderLineDto> lines;

  factory PurchaseOrderDto.fromJson(Map<String, dynamic> json) {
    final rawLines = json['items'] ?? json['lines'] ?? <dynamic>[];
    final lines = rawLines is List
        ? rawLines
            .whereType<Map<String, dynamic>>()
            .map(PurchaseOrderLineDto.fromJson)
            .toList()
        : <PurchaseOrderLineDto>[];

    return PurchaseOrderDto(
      id: _asInt(json['id']),
      reference: (json['reference'] ??
              json['code'] ??
              json['number'] ??
              json['id'] ??
              '')
          .toString(),
      status: (json['status'] ?? 'unknown').toString(),
      statusLabel: _asLabel(
        json['status_display'],
        fallback: json['status'],
        emptyFallback: 'Nepoznato',
      ),
      supplierName: (json['supplier_name'] ??
              json['supplier']?['name'] ??
              json['supplier'] ??
              '')
          .toString()
          .trim(),
      paymentTypeName: (json['payment_type_name'] ??
              json['payment_type']?['name'] ??
              json['payment_type'] ??
              '')
          .toString()
          .trim(),
      totalAmount: _asDouble(
        json['total_gross'] ??
            json['gross_total'] ??
            json['total_amount'] ??
            json['total'] ??
            json['total_net'],
      ),
      currency: (json['currency'] ?? 'EUR').toString(),
      orderedAt: _asDateTime(json['ordered_at'] ?? json['created_at']),
      lines: lines,
    );
  }

  PurchaseOrder toDomain() {
    return PurchaseOrder(
      id: id,
      reference: reference,
      status: status,
      statusLabel: statusLabel,
      supplierName: supplierName.isEmpty ? 'Nepoznati dobavljac' : supplierName,
      paymentTypeName:
          paymentTypeName.isEmpty ? 'Nije definirano' : paymentTypeName,
      totalAmount: totalAmount,
      currency: currency,
      orderedAt: orderedAt,
      lines: lines.map((line) => line.toDomain()).toList(),
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

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static String _asLabel(
    dynamic value, {
    dynamic fallback,
    required String emptyFallback,
  }) {
    final primary = value?.toString().trim() ?? '';
    if (primary.isNotEmpty) {
      return primary;
    }
    final secondary = fallback?.toString().trim() ?? '';
    if (secondary.isNotEmpty) {
      return secondary;
    }
    return emptyFallback;
  }
}

class PurchaseOrderLineDto {
  const PurchaseOrderLineDto({
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

  factory PurchaseOrderLineDto.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderLineDto(
      id: PurchaseOrderDto._asInt(json['id']),
      articleName: (json['article_name'] ??
              json['artikl_name'] ??
              json['item_name'] ??
              '')
          .toString(),
      quantity: PurchaseOrderDto._asDouble(json['quantity']),
      receivedQuantity: PurchaseOrderDto._asDouble(
        json['received_quantity'] ?? json['received_qty'],
      ),
      remainingQuantity: PurchaseOrderDto._asDouble(
        json['remaining_quantity'] ?? json['remaining_qty'],
      ),
      unitPrice: PurchaseOrderDto._asDouble(
        json['unit_price'] ?? json['price'],
      ),
    );
  }

  PurchaseOrderLine toDomain() {
    return PurchaseOrderLine(
      id: id,
      articleName: articleName,
      quantity: quantity,
      receivedQuantity: receivedQuantity,
      remainingQuantity: remainingQuantity,
      unitPrice: unitPrice,
    );
  }
}

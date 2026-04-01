import '../../../domain/purchase_order.dart';

class PurchaseOrderDto {
  const PurchaseOrderDto({
    required this.id,
    required this.reference,
    required this.supplierId,
    required this.status,
    required this.statusLabel,
    required this.supplierName,
    required this.paymentTypeId,
    required this.paymentTypeName,
    required this.totalAmount,
    required this.totalNetAmount,
    required this.totalGrossAmount,
    required this.totalDepositAmount,
    required this.createdBy,
    required this.sentAt,
    required this.updatedAt,
    required this.receiptCreated,
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
      supplierId: _asInt(
        json['supplier'] is Map<String, dynamic>
            ? json['supplier']['id'] ?? json['supplier']['rm_id']
            : json['supplier'],
      ),
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
      paymentTypeId: _asNullableInt(
        json['payment_type'] is Map<String, dynamic>
            ? json['payment_type']['id']
            : json['payment_type'],
      ),
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
      totalNetAmount: _asDouble(json['total_net'] ?? json['net_total']),
      totalGrossAmount: _asDouble(
        json['total_gross'] ?? json['gross_total'] ?? json['total_amount'],
      ),
      totalDepositAmount: _asDouble(
        json['total_deposit'] ?? json['deposit_total'],
      ),
      createdBy: (json['created_by'] ?? '').toString().trim(),
      sentAt: _asDateTime(json['sent_at']),
      updatedAt: _asDateTime(json['updated_at']),
      receiptCreated: _asBool(json['primka_created']),
      currency: (json['currency'] ?? 'EUR').toString(),
      orderedAt: _asDateTime(json['ordered_at'] ?? json['created_at']),
      lines: lines,
    );
  }

  PurchaseOrder toDomain() {
    return PurchaseOrder(
      id: id,
      reference: reference,
      supplierId: supplierId,
      status: status,
      statusLabel: statusLabel,
      supplierName: supplierName.isEmpty ? 'Nepoznati dobavljac' : supplierName,
      paymentTypeId: paymentTypeId,
      paymentTypeName:
          paymentTypeName.isEmpty ? 'Nije definirano' : paymentTypeName,
      totalAmount: totalAmount,
      totalNetAmount: totalNetAmount,
      totalGrossAmount: totalGrossAmount == 0 ? totalAmount : totalGrossAmount,
      totalDepositAmount: totalDepositAmount,
      createdBy: createdBy,
      sentAt: sentAt,
      updatedAt: updatedAt,
      receiptCreated: receiptCreated,
      history: _buildHistory(),
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

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1';
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

  List<PurchaseOrderHistoryEntry> _buildHistory() {
    final entries = <PurchaseOrderHistoryEntry>[
      PurchaseOrderHistoryEntry(
        title: 'Narudžba kreirana',
        description: createdBy.isEmpty
            ? 'Narudžba je evidentirana u sustavu.'
            : 'Kreirao: $createdBy',
        occurredAt: orderedAt,
      ),
    ];

    if (sentAt != null) {
      entries.add(
        PurchaseOrderHistoryEntry(
          title: 'Narudžba poslana',
          description: 'Narudžba je poslana dobavljaču.',
          occurredAt: sentAt,
        ),
      );
    }

    if (receiptCreated) {
      entries.add(
        PurchaseOrderHistoryEntry(
          title: 'Primka kreirana',
          description: 'Za ovu narudzbu je kreirana primka robe.',
          occurredAt: updatedAt,
        ),
      );
    }

    final currentStatusAt = updatedAt ?? sentAt ?? orderedAt;
    final hasDistinctCurrentStatus = entries.every(
      (entry) =>
          entry.title != 'Trenutni status' ||
          entry.description != statusLabel ||
          entry.occurredAt != currentStatusAt,
    );
    if (statusLabel.trim().isNotEmpty && hasDistinctCurrentStatus) {
      entries.add(
        PurchaseOrderHistoryEntry(
          title: 'Trenutni status',
          description: statusLabel,
          occurredAt: currentStatusAt,
        ),
      );
    }

    entries.sort((left, right) {
      final leftAt = left.occurredAt;
      final rightAt = right.occurredAt;
      if (leftAt == null && rightAt == null) {
        return 0;
      }
      if (leftAt == null) {
        return 1;
      }
      if (rightAt == null) {
        return -1;
      }
      return rightAt.compareTo(leftAt);
    });

    return entries;
  }
}

class PurchaseOrderLineDto {
  const PurchaseOrderLineDto({
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

  factory PurchaseOrderLineDto.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderLineDto(
      id: PurchaseOrderDto._asInt(json['id']),
      articleId: PurchaseOrderDto._asInt(
        json['artikl'] ?? json['article_id'] ?? json['artikl_id'],
      ),
      articleName: (json['article_name'] ??
              json['artikl_name'] ??
              json['item_name'] ??
              '')
          .toString(),
      unitOfMeasureId: PurchaseOrderDto._asInt(
        json['unit_of_measure'] ??
            json['unit']?['rm_id'] ??
            json['unit']?['id'] ??
            json['unit_id'],
      ),
      unitName: (json['unit_name'] ??
              json['unit']?['name'] ??
              json['unit_of_measure_name'] ??
              '')
          .toString(),
      baseGroup: (json['base_group'] ?? '').toString(),
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
      articleId: articleId,
      articleName: articleName,
      unitOfMeasureId: unitOfMeasureId,
      unitName: unitName,
      baseGroup: baseGroup,
      quantity: quantity,
      receivedQuantity: receivedQuantity,
      remainingQuantity: remainingQuantity,
      unitPrice: unitPrice,
    );
  }
}

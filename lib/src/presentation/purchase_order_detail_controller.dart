import 'package:flutter/foundation.dart';

import '../data/purchase_orders/purchase_order_repository.dart';
import '../domain/purchase_order.dart';

class PurchaseOrderDetailState {
  const PurchaseOrderDetailState({
    required this.isLoading,
    required this.order,
    required this.errorMessage,
  });

  const PurchaseOrderDetailState.initial()
      : isLoading = false,
        order = null,
        errorMessage = null;

  final bool isLoading;
  final PurchaseOrder? order;
  final String? errorMessage;

  bool get hasContent => order != null;

  PurchaseOrderDetailState copyWith({
    bool? isLoading,
    PurchaseOrder? order,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PurchaseOrderDetailState(
      isLoading: isLoading ?? this.isLoading,
      order: order ?? this.order,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PurchaseOrderDetailController
    extends ValueNotifier<PurchaseOrderDetailState> {
  PurchaseOrderDetailController({required PurchaseOrderRepository repository})
      : _repository = repository,
        super(const PurchaseOrderDetailState.initial());

  final PurchaseOrderRepository _repository;

  Future<void> load({
    required int id,
    required String authToken,
  }) async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final order = await _repository.fetchPurchaseOrderDetail(
        id: id,
        authToken: authToken,
      );
      value = value.copyWith(
        isLoading: false,
        order: order,
        clearError: true,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage:
            'Detalji narudzbe trenutno nisu dostupni. Pokusajte ponovno.',
      );
    }
  }
}

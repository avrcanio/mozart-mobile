import 'package:flutter/foundation.dart';

import '../data/purchase_orders/purchase_order_repository.dart';
import '../domain/purchase_order.dart';

class PurchaseOrdersState {
  const PurchaseOrdersState({
    required this.isLoading,
    required this.orders,
    required this.errorMessage,
  });

  const PurchaseOrdersState.initial()
      : isLoading = false,
        orders = const <PurchaseOrder>[],
        errorMessage = null;

  final bool isLoading;
  final List<PurchaseOrder> orders;
  final String? errorMessage;

  PurchaseOrdersState copyWith({
    bool? isLoading,
    List<PurchaseOrder>? orders,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PurchaseOrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PurchaseOrdersController extends ValueNotifier<PurchaseOrdersState> {
  PurchaseOrdersController({required PurchaseOrderRepository repository})
      : _repository = repository,
        super(const PurchaseOrdersState.initial());

  final PurchaseOrderRepository _repository;

  Future<void> load(String authToken) async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _repository.fetchPurchaseOrders(authToken: authToken);
      value = value.copyWith(
        isLoading: false,
        orders: orders,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }
}

import 'package:flutter/foundation.dart';

import '../data/purchase_orders/purchase_order_repository.dart';
import '../domain/purchase_order.dart';

class PurchaseOrderDetailState {
  const PurchaseOrderDetailState({
    required this.isLoading,
    required this.isSending,
    required this.order,
    required this.errorMessage,
    required this.actionMessage,
    required this.actionErrorMessage,
  });

  const PurchaseOrderDetailState.initial()
      : isLoading = false,
        isSending = false,
        order = null,
        errorMessage = null,
        actionMessage = null,
        actionErrorMessage = null;

  final bool isLoading;
  final bool isSending;
  final PurchaseOrder? order;
  final String? errorMessage;
  final String? actionMessage;
  final String? actionErrorMessage;

  bool get hasContent => order != null;

  PurchaseOrderDetailState copyWith({
    bool? isLoading,
    bool? isSending,
    PurchaseOrder? order,
    String? errorMessage,
    String? actionMessage,
    String? actionErrorMessage,
    bool clearError = false,
    bool clearActionMessage = false,
    bool clearActionError = false,
  }) {
    return PurchaseOrderDetailState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      order: order ?? this.order,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionMessage:
          clearActionMessage ? null : (actionMessage ?? this.actionMessage),
      actionErrorMessage: clearActionError
          ? null
          : (actionErrorMessage ?? this.actionErrorMessage),
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
    value = value.copyWith(
      isLoading: true,
      clearError: true,
      clearActionMessage: true,
      clearActionError: true,
    );
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

  Future<bool> send({
    required int id,
    required String authToken,
  }) async {
    value = value.copyWith(
      isSending: true,
      clearActionMessage: true,
      clearActionError: true,
    );
    try {
      await _repository.sendPurchaseOrder(
        orderId: id,
        authToken: authToken,
      );
      final order = await _repository.fetchPurchaseOrderDetail(
        id: id,
        authToken: authToken,
      );
      value = value.copyWith(
        isSending: false,
        order: order,
        actionMessage: 'Narudzba je uspjesno poslana.',
        clearActionError: true,
      );
      return true;
    } catch (_) {
      value = value.copyWith(
        isSending: false,
        actionErrorMessage:
            'Slanje narudzbe nije uspjelo. Pokusajte ponovno.',
      );
      return false;
    }
  }
}

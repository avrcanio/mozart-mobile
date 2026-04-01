import 'package:flutter/foundation.dart';

import '../data/http/api_client.dart';
import '../data/purchase_orders/purchase_order_repository.dart';
import '../domain/purchase_order.dart';

class PurchaseOrderDetailState {
  const PurchaseOrderDetailState({
    required this.isLoading,
    required this.isSending,
    required this.isUpdatingPrice,
    required this.activePriceItemId,
    required this.order,
    required this.errorMessage,
    required this.actionMessage,
    required this.actionErrorMessage,
  });

  const PurchaseOrderDetailState.initial()
      : isLoading = false,
        isSending = false,
        isUpdatingPrice = false,
        activePriceItemId = null,
        order = null,
        errorMessage = null,
        actionMessage = null,
        actionErrorMessage = null;

  final bool isLoading;
  final bool isSending;
  final bool isUpdatingPrice;
  final int? activePriceItemId;
  final PurchaseOrder? order;
  final String? errorMessage;
  final String? actionMessage;
  final String? actionErrorMessage;

  bool get hasContent => order != null;

  PurchaseOrderDetailState copyWith({
    bool? isLoading,
    bool? isSending,
    bool? isUpdatingPrice,
    int? activePriceItemId,
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
      isUpdatingPrice: isUpdatingPrice ?? this.isUpdatingPrice,
      activePriceItemId: activePriceItemId ?? this.activePriceItemId,
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
            'Detalji narud\u017Ebe trenutno nisu dostupni. Poku\u0161ajte ponovno.',
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
        actionMessage: 'Narud\u017Eba je uspje\u0161no poslana.',
        clearActionError: true,
      );
      return true;
    } catch (_) {
      value = value.copyWith(
        isSending: false,
        actionErrorMessage:
            'Slanje narud\u017Ebe nije uspjelo. Poku\u0161ajte ponovno.',
      );
      return false;
    }
  }

  Future<bool> adjustItemPrice({
    required int orderId,
    required int itemId,
    required String price,
    required String currency,
    required String reason,
    required String authToken,
  }) async {
    value = value.copyWith(
      isUpdatingPrice: true,
      activePriceItemId: itemId,
      clearActionMessage: true,
      clearActionError: true,
    );
    try {
      await _repository.patchItemPrice(
        itemId: itemId,
        price: price,
        currency: currency,
        reason: reason,
        authToken: authToken,
      );
      final order = await _repository.fetchPurchaseOrderDetail(
        id: orderId,
        authToken: authToken,
      );
      value = value.copyWith(
        isUpdatingPrice: false,
        activePriceItemId: null,
        order: order,
        actionMessage: 'Cijena stavke je uspješno ažurirana.',
        clearActionError: true,
      );
      return true;
    } on ApiException catch (error) {
      value = value.copyWith(
        isUpdatingPrice: false,
        activePriceItemId: null,
        actionErrorMessage: error.message,
      );
      return false;
    } catch (_) {
      value = value.copyWith(
        isUpdatingPrice: false,
        activePriceItemId: null,
        actionErrorMessage: 'Promjena cijene nije uspjela. Pokušajte ponovno.',
      );
      return false;
    }
  }
}

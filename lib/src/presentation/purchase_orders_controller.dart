import 'package:flutter/foundation.dart';

import '../data/purchase_orders/purchase_order_repository.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_filters.dart';
import '../data/purchase_orders/models/supplier_dto.dart';
import 'connectivity_feedback.dart';

class PurchaseOrdersState {
  const PurchaseOrdersState({
    required this.isLoading,
    required this.orders,
    required this.suppliers,
    required this.filters,
    required this.isLoadingSuppliers,
    required this.errorMessage,
  });

  const PurchaseOrdersState.initial()
      : isLoading = false,
        orders = const <PurchaseOrder>[],
        suppliers = const <SupplierDto>[],
        filters = const PurchaseOrderFilters(),
        isLoadingSuppliers = false,
        errorMessage = null;

  final bool isLoading;
  final List<PurchaseOrder> orders;
  final List<SupplierDto> suppliers;
  final PurchaseOrderFilters filters;
  final bool isLoadingSuppliers;
  final String? errorMessage;

  bool get hasContent => orders.isNotEmpty;
  bool get hasActiveFilters => filters.hasActiveFilters;

  PurchaseOrdersState copyWith({
    bool? isLoading,
    List<PurchaseOrder>? orders,
    List<SupplierDto>? suppliers,
    PurchaseOrderFilters? filters,
    bool? isLoadingSuppliers,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PurchaseOrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      suppliers: suppliers ?? this.suppliers,
      filters: filters ?? this.filters,
      isLoadingSuppliers: isLoadingSuppliers ?? this.isLoadingSuppliers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PurchaseOrdersController extends ValueNotifier<PurchaseOrdersState> {
  PurchaseOrdersController({required PurchaseOrderRepository repository})
      : _repository = repository,
        super(const PurchaseOrdersState.initial());

  final PurchaseOrderRepository _repository;

  Future<void> load(
    String authToken, {
    PurchaseOrderFilters? filters,
  }) async {
    final effectiveFilters = filters ?? value.filters;
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _repository.fetchPurchaseOrders(
        authToken: authToken,
        filters: effectiveFilters,
      );
      value = value.copyWith(
        isLoading: false,
        orders: orders,
        filters: effectiveFilters,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: isConnectivityIssue(error)
            ? connectivityIssueMessage
            : 'Narudzbe trenutno nisu dostupne. Osvjezite prikaz i pokusajte ponovno.',
      );
    }
  }

  Future<void> applyFilters(
    String authToken,
    PurchaseOrderFilters filters,
  ) async {
    await load(authToken, filters: filters);
  }

  Future<void> resetFilters(String authToken) async {
    await load(authToken, filters: const PurchaseOrderFilters());
  }

  Future<void> ensureSuppliersLoaded(String authToken) async {
    if (value.suppliers.isNotEmpty || value.isLoadingSuppliers) {
      return;
    }

    value = value.copyWith(isLoadingSuppliers: true);
    try {
      final suppliers = await _repository.fetchSuppliers(authToken: authToken);
      value = value.copyWith(
        suppliers: suppliers,
        isLoadingSuppliers: false,
      );
    } catch (_) {
      value = value.copyWith(isLoadingSuppliers: false);
    }
  }
}

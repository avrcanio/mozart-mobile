import 'package:flutter/foundation.dart';

import '../data/purchase_orders/purchase_order_repository.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_filters.dart';
import '../data/purchase_orders/models/supplier_dto.dart';
import 'connectivity_feedback.dart';

class PurchaseOrdersState {
  const PurchaseOrdersState({
    required this.isLoading,
    required this.isLoadingMore,
    required this.orders,
    required this.suppliers,
    required this.filters,
    required this.isLoadingSuppliers,
    required this.currentPage,
    required this.totalCount,
    required this.loadMoreErrorMessage,
    required this.errorMessage,
  });

  const PurchaseOrdersState.initial()
      : isLoading = false,
        isLoadingMore = false,
        orders = const <PurchaseOrder>[],
        suppliers = const <SupplierDto>[],
        filters = const PurchaseOrderFilters(),
        isLoadingSuppliers = false,
        currentPage = 0,
        totalCount = 0,
        loadMoreErrorMessage = null,
        errorMessage = null;

  final bool isLoading;
  final bool isLoadingMore;
  final List<PurchaseOrder> orders;
  final List<SupplierDto> suppliers;
  final PurchaseOrderFilters filters;
  final bool isLoadingSuppliers;
  final int currentPage;
  final int totalCount;
  final String? loadMoreErrorMessage;
  final String? errorMessage;

  bool get hasContent => orders.isNotEmpty;
  bool get hasActiveFilters => filters.hasActiveFilters;
  bool get hasMorePages => orders.length < totalCount;

  PurchaseOrdersState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<PurchaseOrder>? orders,
    List<SupplierDto>? suppliers,
    PurchaseOrderFilters? filters,
    bool? isLoadingSuppliers,
    int? currentPage,
    int? totalCount,
    String? loadMoreErrorMessage,
    String? errorMessage,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return PurchaseOrdersState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      orders: orders ?? this.orders,
      suppliers: suppliers ?? this.suppliers,
      filters: filters ?? this.filters,
      isLoadingSuppliers: isLoadingSuppliers ?? this.isLoadingSuppliers,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      loadMoreErrorMessage: clearLoadMoreError
          ? null
          : (loadMoreErrorMessage ?? this.loadMoreErrorMessage),
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
    value = value.copyWith(
      isLoading: true,
      clearError: true,
      clearLoadMoreError: true,
    );
    try {
      final page = await _repository.fetchPurchaseOrdersPage(
        authToken: authToken,
        filters: effectiveFilters,
      );
      value = value.copyWith(
        isLoading: false,
        orders: page.orders,
        filters: effectiveFilters,
        currentPage: 1,
        totalCount: page.count,
        clearError: true,
        clearLoadMoreError: true,
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

  Future<void> loadMore(String authToken) async {
    if (value.isLoading || value.isLoadingMore || !value.hasMorePages) {
      return;
    }

    value = value.copyWith(
      isLoadingMore: true,
      clearLoadMoreError: true,
    );
    try {
      final nextPage = value.currentPage + 1;
      final page = await _repository.fetchPurchaseOrdersPage(
        authToken: authToken,
        filters: value.filters,
        page: nextPage,
      );
      value = value.copyWith(
        isLoadingMore: false,
        orders: <PurchaseOrder>[
          ...value.orders,
          ...page.orders,
        ],
        currentPage: nextPage,
        totalCount: page.count,
        clearLoadMoreError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: isConnectivityIssue(error)
            ? connectivityIssueMessage
            : 'Dodatne narudzbe trenutno nisu dostupne. Pokusajte ponovno.',
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

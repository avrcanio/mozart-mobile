import '../../domain/purchase_order.dart';
import '../../domain/purchase_order_filters.dart';
import '../../domain/warehouse_option.dart';
import '../http/api_client.dart';
import 'models/payment_type_dto.dart';
import 'models/purchase_order_dto.dart';
import 'models/supplier_article_dto.dart';
import 'models/supplier_dto.dart';
import 'models/warehouse_dto.dart';

class PurchaseOrderRepository {
  PurchaseOrderRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Uri get listEndpoint => _apiClient.endpoint(path: '/api/purchase-orders/');

  Uri detailEndpoint(int id) => _apiClient.endpoint(path: '/api/purchase-orders/$id/');

  Uri get suppliersEndpoint => _apiClient.endpoint(path: '/api/suppliers/');

  Uri get paymentTypesEndpoint => _apiClient.endpoint(path: '/api/payment-types/');

  Uri get warehousesEndpoint => _apiClient.endpoint(path: '/api/warehouses/');

  Uri supplierArticlesEndpoint(int supplierId) =>
      _apiClient.endpoint(path: '/api/suppliers/$supplierId/artikli/');

  Uri patchPriceEndpoint(int itemId) =>
      _apiClient.endpoint(path: '/api/purchase-order-items/$itemId/price/');

  Uri warehouseInputsEndpoint(int orderId) =>
      _apiClient.endpoint(path: '/api/purchase-orders/$orderId/warehouse-inputs/');

  Uri sendEndpoint(int orderId) =>
      _apiClient.endpoint(path: '/api/purchase-orders/$orderId/send/');

  Future<PurchaseOrderPage> fetchPurchaseOrdersPage({
    required String authToken,
    PurchaseOrderFilters filters = const PurchaseOrderFilters(),
    int page = 1,
  }) async {
    final json = await _apiClient.getJson(
      '/api/purchase-orders/',
      authToken: authToken,
      queryParameters: <String, String>{
        ...filters.toQueryParameters(),
        if (page > 1) 'page': '$page',
      },
      queryParametersList: filters.toRepeatedQueryParameters(),
    );
    final orders = (json['results'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PurchaseOrderDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();

    return PurchaseOrderPage(
      count: _asCount(json['count'], fallback: orders.length),
      orders: orders,
      nextPageUrl: _asNextPageUrl(json['next']),
      previousPageUrl: _asNextPageUrl(json['previous']),
    );
  }

  Future<PurchaseOrderPage> fetchPurchaseOrdersPageByUrl({
    required String authToken,
    required String pageUrl,
  }) async {
    final json = await _apiClient.getJsonUri(
      Uri.parse(pageUrl),
      authToken: authToken,
    );
    final orders = (json['results'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PurchaseOrderDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();

    return PurchaseOrderPage(
      count: _asCount(json['count'], fallback: orders.length),
      orders: orders,
      nextPageUrl: _asNextPageUrl(json['next']),
      previousPageUrl: _asNextPageUrl(json['previous']),
    );
  }

  Future<List<PurchaseOrder>> fetchPurchaseOrders({
    required String authToken,
    PurchaseOrderFilters filters = const PurchaseOrderFilters(),
    int page = 1,
  }) async {
    final purchaseOrderPage = await fetchPurchaseOrdersPage(
      authToken: authToken,
      filters: filters,
      page: page,
    );
    return purchaseOrderPage.orders;
  }

  Future<PurchaseOrder> fetchPurchaseOrderDetail({
    required int id,
    required String authToken,
  }) async {
    final json = await _apiClient.getJson(
      '/api/purchase-orders/$id/',
      authToken: authToken,
    );
    return PurchaseOrderDto.fromJson(json).toDomain();
  }

  Future<List<SupplierDto>> fetchSuppliers({
    required String authToken,
  }) async {
    final jsonList = await _apiClient.getJsonList(
      '/api/suppliers/',
      authToken: authToken,
    );
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(SupplierDto.fromJson)
        .toList();
  }

  Future<List<PaymentTypeDto>> fetchPaymentTypes({
    required String authToken,
  }) async {
    final jsonList = await _apiClient.getJsonList(
      '/api/payment-types/',
      authToken: authToken,
    );
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(PaymentTypeDto.fromJson)
        .toList();
  }

  Future<List<WarehouseOption>> fetchWarehouses({
    required String authToken,
  }) async {
    final jsonList = await _apiClient.getJsonList(
      '/api/warehouses/',
      authToken: authToken,
    );
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(WarehouseDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();
  }

  Future<void> patchItemPrice({
    required int itemId,
    required String price,
    required String currency,
    required String reason,
    required String authToken,
  }) async {
    await _apiClient.patchJson(
      '/api/purchase-order-items/$itemId/price/',
      authToken: authToken,
      body: <String, dynamic>{
        'price': price,
        'currency': currency,
        'reason': reason,
      },
    );
  }

  Future<void> createWarehouseInput({
    required int orderId,
    required Map<String, dynamic> payload,
    required String authToken,
  }) async {
    await _apiClient.postJson(
      '/api/purchase-orders/$orderId/warehouse-inputs/',
      authToken: authToken,
      body: payload,
    );
  }

  Future<void> sendPurchaseOrder({
    required int orderId,
    required String authToken,
  }) async {
    await _apiClient.postJson(
      '/api/purchase-orders/$orderId/send/',
      authToken: authToken,
      body: const <String, dynamic>{},
    );
  }

  Future<List<SupplierArticleDto>> fetchSupplierArticles({
    required int supplierId,
    required String authToken,
  }) async {
    final jsonList = await _apiClient.getJsonList(
      '/api/suppliers/$supplierId/artikli/',
      authToken: authToken,
    );
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(SupplierArticleDto.fromJson)
        .toList();
  }

  Future<PurchaseOrder> createPurchaseOrder({
    required Map<String, dynamic> payload,
    required String authToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/purchase-orders/',
      authToken: authToken,
      body: payload,
    );
    return PurchaseOrderDto.fromJson(json).toDomain();
  }

  Future<PurchaseOrder> updatePurchaseOrder({
    required int orderId,
    required Map<String, dynamic> payload,
    required String authToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/purchase-orders/$orderId/',
      authToken: authToken,
      body: payload,
    );
    return PurchaseOrderDto.fromJson(json).toDomain();
  }

  static int _asCount(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  static String? _asNextPageUrl(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}

class PurchaseOrderPage {
  const PurchaseOrderPage({
    required this.count,
    required this.orders,
    required this.nextPageUrl,
    required this.previousPageUrl,
  });

  final int count;
  final List<PurchaseOrder> orders;
  final String? nextPageUrl;
  final String? previousPageUrl;
}

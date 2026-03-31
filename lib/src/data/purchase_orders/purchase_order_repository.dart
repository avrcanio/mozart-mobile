import '../../domain/purchase_order.dart';
import '../../domain/purchase_order_filters.dart';
import '../http/api_client.dart';
import 'models/payment_type_dto.dart';
import 'models/purchase_order_dto.dart';
import 'models/supplier_article_dto.dart';
import 'models/supplier_dto.dart';

class PurchaseOrderRepository {
  PurchaseOrderRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Uri get listEndpoint => _apiClient.endpoint('/api/purchase-orders/');

  Uri detailEndpoint(int id) => _apiClient.endpoint('/api/purchase-orders/$id/');

  Uri get suppliersEndpoint => _apiClient.endpoint('/api/suppliers/');

  Uri get paymentTypesEndpoint => _apiClient.endpoint('/api/payment-types/');

  Uri supplierArticlesEndpoint(int supplierId) =>
      _apiClient.endpoint('/api/suppliers/$supplierId/artikli/');

  Uri patchPriceEndpoint(int itemId) =>
      _apiClient.endpoint('/api/purchase-order-items/$itemId/price/');

  Uri warehouseInputsEndpoint(int orderId) =>
      _apiClient.endpoint('/api/purchase-orders/$orderId/warehouse-inputs/');

  Uri sendEndpoint(int orderId) =>
      _apiClient.endpoint('/api/purchase-orders/$orderId/send/');

  Future<List<PurchaseOrder>> fetchPurchaseOrders({
    required String authToken,
    PurchaseOrderFilters filters = const PurchaseOrderFilters(),
  }) async {
    final jsonList = await _apiClient.getJsonList(
      '/api/purchase-orders/',
      authToken: authToken,
      queryParameters: filters.toQueryParameters(),
    );
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(PurchaseOrderDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();
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

  Future<void> patchItemPrice({
    required int itemId,
    required double price,
    required String authToken,
  }) async {
    await _apiClient.patchJson(
      '/api/purchase-order-items/$itemId/price/',
      authToken: authToken,
      body: <String, dynamic>{'price': price},
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
}

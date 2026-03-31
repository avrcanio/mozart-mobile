import '../../domain/purchase_order.dart';
import '../http/api_client.dart';

class PurchaseOrderRepository {
  PurchaseOrderRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Uri get listEndpoint => _apiClient.endpoint('/api/purchase-orders/');

  Uri detailEndpoint(String id) => _apiClient.endpoint('/api/purchase-orders/$id/');

  Future<List<PurchaseOrder>> fetchPurchaseOrders() async {
    return <PurchaseOrder>[
      PurchaseOrder(
        id: 'PO-2048',
        vendor: 'Adriatic Components',
        status: 'Needs approval',
        total: 18420.50,
        currency: 'EUR',
        createdAt: DateTime(2026, 3, 29),
        buyer: 'Marta Peric',
      ),
      PurchaseOrder(
        id: 'PO-2052',
        vendor: 'Nordic Steel',
        status: 'In transit',
        total: 9275.00,
        currency: 'EUR',
        createdAt: DateTime(2026, 3, 27),
        buyer: 'Ivan Juric',
      ),
      PurchaseOrder(
        id: 'PO-2055',
        vendor: 'Blue Harbor Supply',
        status: 'Draft',
        total: 3120.75,
        currency: 'EUR',
        createdAt: DateTime(2026, 3, 26),
        buyer: 'Ana Kovac',
      ),
    ];
  }
}

import '../../domain/dashboard_summary.dart';
import '../mailbox/mailbox_repository.dart';
import '../purchase_orders/purchase_order_repository.dart';
import '../../domain/purchase_order_filters.dart';

class DashboardRepository {
  DashboardRepository({
    required MailboxRepository mailboxRepository,
    required PurchaseOrderRepository purchaseOrderRepository,
  })  : _mailboxRepository = mailboxRepository,
        _purchaseOrderRepository = purchaseOrderRepository;

  final MailboxRepository _mailboxRepository;
  final PurchaseOrderRepository _purchaseOrderRepository;

  Future<DashboardSummary> fetchSummary({
    required String authToken,
  }) async {
    final futures = await Future.wait<dynamic>([
      _mailboxRepository.fetchMessagesPage(authToken: authToken),
      _purchaseOrderRepository.fetchPurchaseOrdersPage(authToken: authToken),
      _purchaseOrderRepository.fetchPurchaseOrdersPage(
        authToken: authToken,
        filters: const PurchaseOrderFilters(status: 'created'),
      ),
    ]);

    final mailboxPage = futures[0] as MailboxPage;
    final ordersPage = futures[1] as PurchaseOrderPage;
    final pendingApprovalPage = futures[2] as PurchaseOrderPage;

    return DashboardSummary(
      openPurchaseOrders: ordersPage.count,
      pendingApprovals: pendingApprovalPage.count,
      totalMessages: mailboxPage.count,
      activeWarehouses: 0,
    );
  }
}

import '../../domain/dashboard_summary.dart';
import '../mailbox/mailbox_repository.dart';
import '../purchase_orders/purchase_order_repository.dart';

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
    final messages = await _mailboxRepository.fetchMessages(authToken: authToken);
    final orders = await _purchaseOrderRepository.fetchPurchaseOrders(
      authToken: authToken,
    );

    return DashboardSummary(
      openPurchaseOrders: orders.length,
      pendingApprovals: orders
          .where((order) => order.status.toLowerCase().contains('approval'))
          .length,
      unreadMessages: messages.where((message) => !message.isRead).length,
      activeWarehouses: 0,
    );
  }
}

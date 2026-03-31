class DashboardSummary {
  const DashboardSummary({
    required this.openPurchaseOrders,
    required this.pendingApprovals,
    required this.unreadMessages,
    required this.activeWarehouses,
  });

  final int openPurchaseOrders;
  final int pendingApprovals;
  final int unreadMessages;
  final int activeWarehouses;
}

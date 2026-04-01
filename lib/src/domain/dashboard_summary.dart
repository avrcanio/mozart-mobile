class DashboardSummary {
  const DashboardSummary({
    required this.openPurchaseOrders,
    required this.pendingApprovals,
    required this.totalMessages,
    required this.activeWarehouses,
  });

  final int openPurchaseOrders;
  final int pendingApprovals;
  final int totalMessages;
  final int activeWarehouses;
}

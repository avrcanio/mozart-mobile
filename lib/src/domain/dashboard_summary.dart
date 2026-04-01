class DashboardSummary {
  const DashboardSummary({
    required this.confirmedOrders,
    required this.createdAndSentOrders,
    required this.totalMessages,
    required this.activeWarehouses,
  });

  final int confirmedOrders;
  final int createdAndSentOrders;
  final int totalMessages;
  final int activeWarehouses;
}

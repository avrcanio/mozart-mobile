import '../../domain/dashboard_summary.dart';
import '../http/api_client.dart';

class DashboardRepository {
  DashboardRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Uri get summaryEndpoint => _apiClient.endpoint('/api/dashboard/');

  Future<DashboardSummary> fetchSummary() async {
    return const DashboardSummary(
      openPurchaseOrders: 18,
      pendingApprovals: 5,
      unreadMessages: 12,
      activeWarehouses: 4,
    );
  }
}

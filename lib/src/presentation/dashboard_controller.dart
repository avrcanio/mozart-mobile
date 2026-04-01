import 'package:flutter/foundation.dart';

import '../data/dashboard/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';
import 'connectivity_feedback.dart';

class DashboardState {
  const DashboardState({
    required this.isLoading,
    required this.summary,
    required this.errorMessage,
  });

  const DashboardState.initial()
      : isLoading = false,
        summary = null,
        errorMessage = null;

  final bool isLoading;
  final DashboardSummary? summary;
  final String? errorMessage;

  bool get hasContent => summary != null;

  DashboardState copyWith({
    bool? isLoading,
    DashboardSummary? summary,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DashboardController extends ValueNotifier<DashboardState> {
  DashboardController({required DashboardRepository repository})
      : _repository = repository,
        super(const DashboardState.initial());

  final DashboardRepository _repository;

  Future<void> load(String authToken) async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final summary = await _repository.fetchSummary(authToken: authToken);
      value = value.copyWith(
        isLoading: false,
        summary: summary,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: isConnectivityIssue(error)
            ? connectivityIssueMessage
            : 'Dashboard trenutno nije dostupan. Pokusajte osvjeziti podatke.',
      );
    }
  }
}

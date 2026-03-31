import 'package:flutter/material.dart';

import '../data/auth/auth_repository.dart';
import '../data/dashboard/dashboard_repository.dart';
import '../data/mailbox/mailbox_repository.dart';
import '../data/purchase_orders/purchase_order_repository.dart';
import '../domain/dashboard_summary.dart';
import '../domain/mail_message.dart';
import '../domain/purchase_order.dart';
import '../domain/user_session.dart';

class SessionState {
  const SessionState({
    required this.isLoading,
    required this.session,
    required this.dashboardSummary,
    required this.messages,
    required this.purchaseOrders,
    required this.errorMessage,
  });

  const SessionState.initial()
      : isLoading = false,
        session = null,
        dashboardSummary = null,
        messages = const <MailMessage>[],
        purchaseOrders = const <PurchaseOrder>[],
        errorMessage = null;

  final bool isLoading;
  final UserSession? session;
  final DashboardSummary? dashboardSummary;
  final List<MailMessage> messages;
  final List<PurchaseOrder> purchaseOrders;
  final String? errorMessage;

  bool get isAuthenticated => session != null;

  SessionState copyWith({
    bool? isLoading,
    UserSession? session,
    DashboardSummary? dashboardSummary,
    List<MailMessage>? messages,
    List<PurchaseOrder>? purchaseOrders,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return SessionState(
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : (session ?? this.session),
      dashboardSummary: dashboardSummary ?? this.dashboardSummary,
      messages: messages ?? this.messages,
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SessionController extends ValueNotifier<SessionState> {
  SessionController({
    required AuthRepository authRepository,
    required DashboardRepository dashboardRepository,
    required MailboxRepository mailboxRepository,
    required PurchaseOrderRepository purchaseOrderRepository,
  })  : _authRepository = authRepository,
        _dashboardRepository = dashboardRepository,
        _mailboxRepository = mailboxRepository,
        _purchaseOrderRepository = purchaseOrderRepository,
        super(const SessionState.initial());

  final AuthRepository _authRepository;
  final DashboardRepository _dashboardRepository;
  final MailboxRepository _mailboxRepository;
  final PurchaseOrderRepository _purchaseOrderRepository;

  Future<void> restore() async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _authRepository.restoreSession();
      if (session == null) {
        value = value.copyWith(isLoading: false, clearSession: true);
        return;
      }
      await _loadAuthenticatedState(session);
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        clearSession: true,
        errorMessage: 'Unable to restore the saved session.',
      );
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _authRepository.login(
        username: username,
        password: password,
      );
      await _loadAuthenticatedState(session);
    } on AuthException catch (error) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: error.message,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Login failed. Verify the mobile token contract.',
      );
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    value = const SessionState.initial();
  }

  Future<void> refresh() async {
    final session = value.session;
    if (session == null) {
      return;
    }
    value = value.copyWith(isLoading: true, clearError: true);
    await _loadAuthenticatedState(session);
  }

  Future<void> _loadAuthenticatedState(UserSession session) async {
    final summary = await _dashboardRepository.fetchSummary();
    final messages = await _mailboxRepository.fetchMessages();
    final purchaseOrders = await _purchaseOrderRepository.fetchPurchaseOrders();

    value = value.copyWith(
      isLoading: false,
      session: session,
      dashboardSummary: summary,
      messages: messages,
      purchaseOrders: purchaseOrders,
      clearError: true,
    );
  }
}

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    required SessionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope not found in widget tree.');
    return scope!.notifier!;
  }
}

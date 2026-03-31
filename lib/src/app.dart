import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/auth/auth_repository.dart';
import 'data/auth/auth_storage.dart';
import 'data/dashboard/dashboard_repository.dart';
import 'data/http/api_client.dart';
import 'data/mailbox/mailbox_repository.dart';
import 'data/purchase_orders/purchase_order_repository.dart';
import 'presentation/app_services_scope.dart';
import 'presentation/app_view.dart';
import 'presentation/session_scope.dart';

class MozartMobileApp extends StatefulWidget {
  const MozartMobileApp({super.key});

  @override
  State<MozartMobileApp> createState() => _MozartMobileAppState();
}

class _MozartMobileAppState extends State<MozartMobileApp> {
  late final ApiClient _apiClient;
  late final AuthStorage _authStorage;
  late final AuthRepository _authRepository;
  late final MailboxRepository _mailboxRepository;
  late final PurchaseOrderRepository _purchaseOrderRepository;
  late final DashboardRepository _dashboardRepository;
  late final AppServices _services;
  late final SessionController _sessionController;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authStorage = SecureAuthStorage();
    _authRepository = AuthRepository(
      apiClient: _apiClient,
      storage: _authStorage,
    );
    _mailboxRepository = MailboxRepository(apiClient: _apiClient);
    _purchaseOrderRepository = PurchaseOrderRepository(apiClient: _apiClient);
    _dashboardRepository = DashboardRepository(
      mailboxRepository: _mailboxRepository,
      purchaseOrderRepository: _purchaseOrderRepository,
    );
    _services = AppServices(
      dashboardRepository: _dashboardRepository,
      mailboxRepository: _mailboxRepository,
      purchaseOrderRepository: _purchaseOrderRepository,
    );
    _sessionController = SessionController(
      authRepository: _authRepository,
    )..restore();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: _services,
      child: SessionScope(
        controller: _sessionController,
        child: MaterialApp(
          title: 'Mozart Mobile',
          theme: buildMozartTheme(),
          debugShowCheckedModeBanner: false,
          home: const AppView(),
        ),
      ),
    );
  }
}

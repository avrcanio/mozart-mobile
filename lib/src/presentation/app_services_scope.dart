import 'package:flutter/widgets.dart';

import '../data/dashboard/dashboard_repository.dart';
import '../data/mailbox/mailbox_repository.dart';
import '../data/purchase_orders/purchase_order_repository.dart';

class AppServices {
  const AppServices({
    required this.dashboardRepository,
    required this.mailboxRepository,
    required this.purchaseOrderRepository,
  });

  final DashboardRepository dashboardRepository;
  final MailboxRepository mailboxRepository;
  final PurchaseOrderRepository purchaseOrderRepository;
}

class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    required this.services,
    required super.child,
    super.key,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppServicesScope>();
    assert(scope != null, 'AppServicesScope not found in widget tree.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) {
    return services != oldWidget.services;
  }
}

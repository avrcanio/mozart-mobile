import 'package:flutter/material.dart';

import 'app_services_scope.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/server_connection_screen.dart';
import 'session_scope.dart';

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SessionScope.of(context);
    final services = AppServicesScope.of(context);

    return ValueListenableBuilder<SessionState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (state.isAuthenticated) {
          return HomeScreen(
            session: state.session!,
            dashboardRepository: services.dashboardRepository,
            mailboxRepository: services.mailboxRepository,
            purchaseOrderRepository: services.purchaseOrderRepository,
          );
        }

        if (!state.hasConfiguredServer) {
          return ServerConnectionScreen(state: state);
        }

        return LoginScreen(state: state);
      },
    );
  }
}

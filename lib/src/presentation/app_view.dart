import 'package:flutter/material.dart';

import 'app_services_scope.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/server_connection_screen.dart';
import 'screens/server_setup_screen.dart';
import 'session_scope.dart';

class AppView extends StatelessWidget {
  const AppView({
    required this.hasConfiguredServer,
    required this.isConfigLoading,
    required this.onSubmitServerUrl,
    this.serverUrlErrorMessage,
    this.currentServerUrl,
    this.onChangeServer,
    super.key,
  });

  final bool hasConfiguredServer;
  final bool isConfigLoading;
  final ValueChanged<String> onSubmitServerUrl;
  final String? serverUrlErrorMessage;
  final String? currentServerUrl;
  final VoidCallback? onChangeServer;

  @override
  Widget build(BuildContext context) {
    if (!hasConfiguredServer) {
      return ServerSetupScreen(
        isLoading: isConfigLoading,
        errorMessage: serverUrlErrorMessage,
        initialValue: currentServerUrl ?? '',
        onSubmit: onSubmitServerUrl,
      );
    }

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

        return LoginScreen(
          state: state,
          currentServerUrl: currentServerUrl,
          onChangeServer: onChangeServer,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'session_scope.dart';

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SessionScope.of(context);

    return ValueListenableBuilder<SessionState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (state.isAuthenticated) {
          return HomeScreen(state: state);
        }

        return LoginScreen(state: state);
      },
    );
  }
}

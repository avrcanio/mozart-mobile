import 'package:flutter/material.dart';

import '../data/auth/auth_repository.dart';
import '../domain/user_session.dart';

class SessionState {
  const SessionState({
    required this.isLoading,
    required this.session,
    required this.errorMessage,
  });

  const SessionState.initial()
      : isLoading = false,
        session = null,
        errorMessage = null;

  final bool isLoading;
  final UserSession? session;
  final String? errorMessage;

  bool get isAuthenticated => session != null;

  SessionState copyWith({
    bool? isLoading,
    UserSession? session,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return SessionState(
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SessionController extends ValueNotifier<SessionState> {
  SessionController({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        super(const SessionState.initial());

  final AuthRepository _authRepository;

  Future<void> restore() async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _authRepository.restoreSession();
      value = value.copyWith(
        isLoading: false,
        session: session,
        clearSession: session == null,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        clearSession: true,
        errorMessage: error.toString(),
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
      value = value.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
      );
    } on AuthException catch (error) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: error.message,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Login failed. Check the backend contract and API URL.',
      );
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    value = const SessionState.initial();
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

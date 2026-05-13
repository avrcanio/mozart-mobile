import 'dart:async';

import 'package:flutter/material.dart';

import '../data/auth/auth_repository.dart';
import '../domain/user_session.dart';
import '../push/purchase_order_fcm.dart';

class SessionState {
  const SessionState({
    required this.isLoading,
    required this.session,
    required this.errorMessage,
    required this.apiBaseUrl,
  });

  const SessionState.initial()
      : isLoading = false,
        session = null,
        errorMessage = null,
        apiBaseUrl = '';

  final bool isLoading;
  final UserSession? session;
  final String? errorMessage;
  final String apiBaseUrl;

  bool get isAuthenticated => session != null;
  bool get hasConfiguredServer => apiBaseUrl.trim().isNotEmpty;

  SessionState copyWith({
    bool? isLoading,
    UserSession? session,
    String? errorMessage,
    String? apiBaseUrl,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return SessionState(
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
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
      final storedBaseUrl = await _authRepository.readStoredBaseUrl();
      final resolvedBaseUrl = storedBaseUrl?.trim() ?? '';
      if (resolvedBaseUrl.isNotEmpty) {
        _authRepository.configureBaseUrl(resolvedBaseUrl);
      }
      final session = await _authRepository.restoreSession();
      value = value.copyWith(
        isLoading: false,
        session: session,
        apiBaseUrl: resolvedBaseUrl,
        clearSession: session == null,
      );
      if (session != null) {
        unawaited(subscribeMozzartPurchaseOrdersTopic());
      }
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        clearSession: true,
        clearError: true,
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
      unawaited(subscribeMozzartPurchaseOrdersTopic());
    } on AuthException catch (error) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: error.message,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Prijava nije uspjela. Provjerite korisnicke podatke i pokusajte ponovno.',
      );
    }
  }

  Future<void> saveServer(String baseUrl) async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.saveBaseUrl(baseUrl);
      value = value.copyWith(
        isLoading: false,
        apiBaseUrl: baseUrl.trim(),
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
        errorMessage: 'Spremanje servera nije uspjelo. Pokusajte ponovno.',
      );
    }
  }

  Future<void> clearServer() async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.clearBaseUrl();
      value = value.copyWith(
        isLoading: false,
        apiBaseUrl: '',
        clearError: true,
      );
    } catch (_) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: 'Brisanje servera nije uspjelo. Pokusajte ponovno.',
      );
    }
  }

  Future<void> logout() async {
    await _authRepository.logout(authToken: value.session?.token);
    value = value.copyWith(
      isLoading: false,
      clearSession: true,
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

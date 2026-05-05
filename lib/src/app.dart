import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_config/app_config_storage.dart';
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
  late final AuthStorage _authStorage;
  late final AppConfigStorage _appConfigStorage;
  ApiClient? _apiClient;
  AuthRepository? _authRepository;
  MailboxRepository? _mailboxRepository;
  PurchaseOrderRepository? _purchaseOrderRepository;
  DashboardRepository? _dashboardRepository;
  AppServices? _services;
  SessionController? _sessionController;
  bool _isBootstrapping = true;
  bool _isConfigLoading = false;
  bool _isChangingServer = false;
  String? _currentServerUrl;
  String? _serverUrlErrorMessage;

  @override
  void initState() {
    super.initState();
    _authStorage = SecureAuthStorage();
    _appConfigStorage = SecureAppConfigStorage();
    _bootstrap();
  }

  @override
  void dispose() {
    _sessionController?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final savedUrl = await _appConfigStorage.readApiBaseUrl();
    final resolvedUrl = resolveApiBaseUrl(savedUrl);

    if (!mounted) {
      return;
    }

    setState(() {
      _currentServerUrl = savedUrl;
      _serverUrlErrorMessage = null;
      _rebuildServicesForBaseUrl(resolvedUrl);
      _isBootstrapping = false;
    });

    if (savedUrl != null && savedUrl.isNotEmpty) {
      unawaited(_sessionController!.restore());
    }
  }

  void _rebuildServicesForBaseUrl(String baseUrl) {
    _sessionController?.dispose();

    _apiClient = ApiClient(baseUrl: baseUrl);
    _authRepository = AuthRepository(
      apiClient: _apiClient!,
      storage: _authStorage,
    );
    _mailboxRepository = MailboxRepository(apiClient: _apiClient!);
    _purchaseOrderRepository = PurchaseOrderRepository(apiClient: _apiClient!);
    _dashboardRepository = DashboardRepository(
      mailboxRepository: _mailboxRepository!,
      purchaseOrderRepository: _purchaseOrderRepository!,
    );
    _services = AppServices(
      dashboardRepository: _dashboardRepository!,
      mailboxRepository: _mailboxRepository!,
      purchaseOrderRepository: _purchaseOrderRepository!,
    );
    _sessionController = SessionController(
      authRepository: _authRepository!,
    );
  }

  Future<void> _submitServerUrl(String value) async {
    final existingSession = _sessionController?.value.session;

    setState(() {
      _isConfigLoading = true;
      _serverUrlErrorMessage = null;
    });

    try {
      final normalizedUrl = normalizeApiBaseUrl(value);
      final validationClient = ApiClient(baseUrl: normalizedUrl);
      await validationClient.probeReachability();

      if (_isChangingServer && existingSession != null) {
        await _authRepository?.logout(authToken: existingSession.token);
      } else {
        await _authStorage.clearToken();
      }

      await _appConfigStorage.saveApiBaseUrl(normalizedUrl);
      if (!mounted) {
        return;
      }

      setState(() {
        _currentServerUrl = normalizedUrl;
        _serverUrlErrorMessage = null;
        _isChangingServer = false;
        _rebuildServicesForBaseUrl(normalizedUrl);
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _serverUrlErrorMessage = error.message;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _serverUrlErrorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConfigLoading = false;
        });
      }
    }
  }

  void _startServerChange() {
    setState(() {
      _isChangingServer = true;
      _serverUrlErrorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping || _services == null || _sessionController == null) {
      return MaterialApp(
        title: 'FS Ordino',
        theme: buildMozartTheme(),
        debugShowCheckedModeBanner: false,
        locale: const Locale('hr', 'HR'),
        supportedLocales: const [
          Locale('hr', 'HR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return AppServicesScope(
      services: _services!,
      child: SessionScope(
        controller: _sessionController!,
        child: MaterialApp(
          title: 'FS Ordino',
          theme: buildMozartTheme(),
          debugShowCheckedModeBanner: false,
          locale: const Locale('hr', 'HR'),
          supportedLocales: const [
            Locale('hr', 'HR'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppView(
            hasConfiguredServer:
                _currentServerUrl != null && _currentServerUrl!.isNotEmpty &&
                !_isChangingServer,
            isConfigLoading: _isConfigLoading,
            currentServerUrl: _currentServerUrl,
            serverUrlErrorMessage: _serverUrlErrorMessage,
            onSubmitServerUrl: _submitServerUrl,
            onChangeServer: _startServerChange,
          ),
        ),
      ),
    );
  }
}

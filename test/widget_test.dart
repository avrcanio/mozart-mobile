import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mozart_mobile/src/core/theme/app_theme.dart';
import 'package:mozart_mobile/src/data/auth/auth_repository.dart';
import 'package:mozart_mobile/src/data/auth/auth_storage.dart';
import 'package:mozart_mobile/src/data/dashboard/dashboard_repository.dart';
import 'package:mozart_mobile/src/data/http/api_client.dart';
import 'package:mozart_mobile/src/data/mailbox/mailbox_repository.dart';
import 'package:mozart_mobile/src/data/purchase_orders/purchase_order_repository.dart';
import 'package:mozart_mobile/src/presentation/app_services_scope.dart';
import 'package:mozart_mobile/src/presentation/app_view.dart';
import 'package:mozart_mobile/src/presentation/session_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('hr_HR');
  });

  testWidgets('renders login shell when unauthenticated', (tester) async {
    final harness = await _createHarness(
      responses: const <String, _FakeResponse>{},
    );

    await tester.pumpWidget(harness.app);
    await tester.pump();

    expect(find.text('Mozart Mobile'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('boots into authenticated dashboard with restored session', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, _FakeResponse>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 7,
          'username': 'root',
          'email': 'root@mozart.local',
          'first_name': 'Mozart',
          'last_name': 'Operator',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'subject': 'Daily digest',
            'from_email': 'office@mozart.local',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T10:15:00Z',
            'attachments_count': 0,
          },
        ]),
        'GET /api/purchase-orders/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 15,
            'reference': 'PO-15',
            'supplier_name': 'Adriatic Trade',
            'status': 'draft',
            'status_display': 'Draft',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[],
          },
        ]),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Mozart Operator'), findsAtLeastNWidgets(1));
    expect(find.text('Open POs'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('renders mailbox list from mapped backend data', (tester) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, _FakeResponse>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 3,
          'username': 'root',
          'email': 'root@mozart.local',
          'first_name': '',
          'last_name': '',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 501,
            'subject': '',
            'from_email': 'nabava@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T08:45:00Z',
            'attachments_count': 2,
          },
        ]),
        'GET /api/purchase-orders/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 88,
            'reference': 'PO-88',
            'supplier_name': 'Warehouse One',
            'status': 'sent',
            'status_display': 'Sent',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'total_gross': '99.99',
            'items': <Map<String, dynamic>>[],
          },
        ]),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mailbox'));
    await tester.pumpAndSettle();

    expect(find.textContaining('nabava@mozart.hr'), findsOneWidget);
    expect(find.textContaining('01.04.2026.'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('opens mailbox detail view from mapped backend data', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, _FakeResponse>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 9,
          'username': 'root',
          'email': 'root@mozart.local',
          'first_name': 'Mail',
          'last_name': 'User',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 700,
            'subject': 'Nova ponuda',
            'from_email': 'nabava@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T08:45:00Z',
            'attachments_count': 1,
          },
        ]),
        'GET /api/mailbox/messages/700/': _jsonResponse(<String, dynamic>{
          'id': 700,
          'subject': 'Nova ponuda',
          'from_email': 'nabava@mozart.hr',
          'to_emails': 'root@mozart.local',
          'cc_emails': 'manager@mozart.local',
          'sent_at': '2026-04-01T08:45:00Z',
          'body_text': 'Detalji ponude za tjednu nabavu.',
          'attachments': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'filename': 'ponuda.pdf',
              'content_type': 'application/pdf',
              'size': 2048,
              'file_url': 'https://example.test/media/ponuda.pdf',
            },
          ],
        }),
        'GET /api/purchase-orders/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 88,
            'reference': 'PO-88',
            'supplier_name': 'Warehouse One',
            'status': 'sent',
            'status_display': 'Sent',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'total_gross': '99.99',
            'items': <Map<String, dynamic>>[],
          },
        ]),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mailbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nova ponuda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Message Detail'), findsOneWidget);
    expect(find.text('Detalji ponude za tjednu nabavu.'), findsOneWidget);
    expect(find.text('manager@mozart.local'), findsOneWidget);
    expect(find.text('ponuda.pdf'), findsOneWidget);
    expect(find.text('Kopiraj link'), findsOneWidget);
  });

  testWidgets('renders purchase order list from mapped backend data', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, _FakeResponse>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 4,
          'username': 'root',
          'email': 'root@mozart.local',
          'first_name': 'Ana',
          'last_name': 'Admin',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'subject': 'ok',
            'from_email': 'mail@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T08:45:00Z',
            'attachments_count': 0,
          },
        ]),
        'GET /api/purchase-orders/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 2048,
            'reference': 'PO-2048',
            'supplier_name': 'Blue Harbor Supply',
            'status': 'approved',
            'status_display': 'Approved',
            'payment_type_name': 'Karticno',
            'ordered_at': '2026-04-02T11:30:00Z',
            'total_gross': '18420.50',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'received_quantity': '4.0000',
                'remaining_quantity': '6.0000',
                'price': '12.00',
              },
            ],
          },
        ]),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders'));
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-2048'), findsWidgets);
    expect(find.textContaining('Blue Harbor Supply'), findsWidgets);
    expect(find.textContaining('18.420,50'), findsWidgets);
    expect(find.textContaining('Approved'), findsWidgets);
  });

  testWidgets('shows user-facing error state when purchase orders fail', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, _FakeResponse>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 4,
          'username': 'root',
          'email': 'root@mozart.local',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'subject': 'ok',
            'from_email': 'mail@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T08:45:00Z',
            'attachments_count': 0,
          },
        ]),
        'GET /api/purchase-orders/': _FakeResponse(
          statusCode: 500,
          body: jsonEncode(<String, dynamic>{'detail': 'Server error'}),
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Narudzbe nisu dostupne'), findsOneWidget);
    expect(find.text('Pokusaj ponovno'), findsOneWidget);
  });

  testWidgets('returns to login and clears token when restored session is invalid', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'expired-token',
      responses: <String, _FakeResponse>{
        'GET /api/me/': _FakeResponse(
          statusCode: 401,
          body: jsonEncode(<String, dynamic>{'detail': 'Invalid token'}),
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(await harness.storage.readToken(), isNull);
  });

  testWidgets('applies and resets purchase order filters on mobile', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, _FakeResponse>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 4,
          'username': 'root',
          'email': 'root@mozart.local',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'subject': 'ok',
            'from_email': 'mail@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T08:45:00Z',
            'attachments_count': 0,
          },
        ]),
        'GET /api/purchase-orders/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'reference': 'PO-BASE',
            'supplier_name': 'Blue Harbor Supply',
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'total_gross': '99.99',
            'items': <Map<String, dynamic>>[],
          },
        ]),
        'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{'id': 2, 'name': 'Blue Harbor Supply'},
          <String, dynamic>{'id': 3, 'name': 'Coffee Logistics'},
        ]),
        'GET /api/purchase-orders/?status=sent&supplier=2&ordered_from=2026-04-02&ordered_to=2026-04-03':
            _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 2048,
                'reference': 'PO-FILTERED',
                'supplier_name': 'Blue Harbor Supply',
                'status': 'sent',
                'status_display': 'Poslana',
                'payment_type_name': 'Karticno',
                'ordered_at': '2026-04-02T11:30:00Z',
                'total_gross': '18420.50',
                'items': <Map<String, dynamic>>[],
              },
            ]),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filteri'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-filter-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poslana').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-filter-supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Harbor Supply').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('po-filter-ordered-from')),
      '2026-04-02',
    );
    await tester.enterText(
      find.byKey(const Key('po-filter-ordered-to')),
      '2026-04-03',
    );

    await tester.tap(find.text('Primijeni'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-FILTERED'), findsOneWidget);
    expect(find.text('Status: Poslana'), findsOneWidget);
    expect(find.text('Dobavljac: Blue Harbor Supply'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-BASE'), findsOneWidget);
    expect(find.text('Status: Poslana'), findsNothing);
  });

  testWidgets('logout removes persisted token', (tester) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, _FakeResponse>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 7,
          'username': 'root',
          'email': 'root@mozart.local',
          'first_name': 'Mozart',
          'last_name': 'Operator',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'subject': 'Daily digest',
            'from_email': 'office@mozart.local',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T10:15:00Z',
            'attachments_count': 0,
          },
        ]),
        'GET /api/purchase-orders/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 15,
            'reference': 'PO-15',
            'supplier_name': 'Adriatic Trade',
            'status': 'draft',
            'status_display': 'Draft',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[],
          },
        ]),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(await harness.storage.readToken(), isNull);
  });

  testWidgets('sends eligible purchase order and refreshes detail state', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, dynamic>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 7,
          'username': 'root',
          'email': 'root@mozart.local',
          'first_name': 'Mozart',
          'last_name': 'Operator',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'subject': 'Daily digest',
            'from_email': 'office@mozart.local',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T10:15:00Z',
            'attachments_count': 0,
          },
        ]),
        'GET /api/purchase-orders/': <_FakeResponse>[
          _jsonListResponse(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 33,
              'reference': 'PO-SEND',
              'supplier_name': 'Adriatic Trade',
              'status': 'created',
              'status_display': 'Kreirana',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ]),
          _jsonListResponse(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 33,
              'reference': 'PO-SEND',
              'supplier_name': 'Adriatic Trade',
              'status': 'sent',
              'status_display': 'Poslana',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ]),
        ],
        'GET /api/purchase-orders/33/': <_FakeResponse>[
          _jsonResponse(<String, dynamic>{
            'id': 33,
            'reference': 'PO-SEND',
            'supplier_name': 'Adriatic Trade',
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[],
          }),
          _jsonResponse(<String, dynamic>{
            'id': 33,
            'reference': 'PO-SEND',
            'supplier_name': 'Adriatic Trade',
            'status': 'sent',
            'status_display': 'Poslana',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[],
          }),
        ],
        'POST /api/purchase-orders/33/send/': _jsonResponse(
          <String, dynamic>{},
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-SEND').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Posalji narudzbu'), findsOneWidget);

    await tester.tap(find.text('Posalji narudzbu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Narudzba je uspjesno poslana.'), findsOneWidget);
    expect(find.text('Posalji narudzbu'), findsNothing);
    expect(find.text('Poslana'), findsWidgets);
  });

  test('creates purchase order with expected payload mapping', () async {
    ApiRequest? capturedRequest;
    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'POST /api/purchase-orders/': (ApiRequest request) {
            capturedRequest = request;
            return _jsonResponse(<String, dynamic>{
              'id': 91,
              'reference': 'PO-NEW',
              'supplier': 2,
              'supplier_name': 'Blue Harbor Supply',
              'status': 'created',
              'status_display': 'Kreirana',
              'payment_type': 5,
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-05T09:30:00Z',
              'total_gross': '120.00',
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'artikl': 77,
                  'artikl_name': 'Coffee beans',
                  'quantity': '3.0000',
                  'unit_of_measure': 1,
                  'unit_name': 'kg',
                  'price': '12.50',
                  'received_quantity': '0.0000',
                  'remaining_quantity': '3.0000',
                  'base_group': '',
                },
              ],
            });
          },
        }),
      ),
    );

    await repository.createPurchaseOrder(
      authToken: 'saved-token',
      payload: <String, dynamic>{
        'supplier': 2,
        'payment_type': 5,
        'ordered_at': '2026-04-05T09:30:00Z',
        'status': 'created',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'artikl': 77,
            'quantity': '3',
            'unit_of_measure': 1,
            'price': '12.50',
          },
        ],
      },
    );

    final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
    expect(body['supplier'], 2);
    expect(body['payment_type'], 5);
    expect(body['status'], 'created');
    expect((body['items'] as List).single['artikl'], 77);
    expect((body['items'] as List).single['unit_of_measure'], 1);
  });

  test('updates purchase order with expected payload mapping', () async {
    ApiRequest? capturedRequest;
    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'PUT /api/purchase-orders/44/': (ApiRequest request) {
            capturedRequest = request;
            return _jsonResponse(<String, dynamic>{
              'id': 44,
              'reference': 'PO-EDIT',
              'supplier': 2,
              'supplier_name': 'Blue Harbor Supply',
              'status': 'created',
              'status_display': 'Kreirana',
              'payment_type': 6,
              'payment_type_name': 'Karticno',
              'ordered_at': '2026-04-05T09:30:00Z',
              'total_gross': '130.00',
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 7,
                  'artikl': 77,
                  'artikl_name': 'Coffee beans',
                  'quantity': '4.0000',
                  'unit_of_measure': 1,
                  'unit_name': 'kg',
                  'price': '13.00',
                  'received_quantity': '0.0000',
                  'remaining_quantity': '4.0000',
                  'base_group': '',
                },
              ],
            });
          },
        }),
      ),
    );

    await repository.updatePurchaseOrder(
      orderId: 44,
      authToken: 'saved-token',
      payload: <String, dynamic>{
        'supplier': 2,
        'payment_type': 6,
        'ordered_at': '2026-04-05T09:30:00Z',
        'status': 'created',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7,
            'artikl': 77,
            'quantity': '4',
            'unit_of_measure': 1,
            'price': '13.00',
          },
        ],
      },
    );

    final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
    expect(body['payment_type'], 6);
    expect((body['items'] as List).single['id'], 7);
    expect((body['items'] as List).single['price'], '13.00');
  });
}

Future<_Harness> _createHarness({
  required Map<String, dynamic> responses,
  String? savedToken,
}) async {
  final transport = _FakeTransport(responses);
  final apiClient = ApiClient(
    baseUrl: 'https://example.test',
    transport: transport,
  );
  final storage = InMemoryAuthStorage();
  if (savedToken != null) {
    await storage.saveToken(savedToken);
  }

  final authRepository = AuthRepository(
    apiClient: apiClient,
    storage: storage,
  );
  final mailboxRepository = MailboxRepository(apiClient: apiClient);
  final purchaseOrderRepository = PurchaseOrderRepository(apiClient: apiClient);
  final dashboardRepository = DashboardRepository(
    mailboxRepository: mailboxRepository,
    purchaseOrderRepository: purchaseOrderRepository,
  );
  final sessionController = SessionController(authRepository: authRepository)
    ..restore();

  final app = AppServicesScope(
    services: AppServices(
      dashboardRepository: dashboardRepository,
      mailboxRepository: mailboxRepository,
      purchaseOrderRepository: purchaseOrderRepository,
    ),
    child: SessionScope(
      controller: sessionController,
      child: MaterialApp(
        theme: buildMozartTheme(),
        home: const AppView(),
      ),
    ),
  );

  return _Harness(
    app: app,
    controller: sessionController,
    storage: storage,
  );
}

_FakeResponse _jsonResponse(Map<String, dynamic> json) {
  return _FakeResponse(statusCode: 200, body: jsonEncode(json));
}

_FakeResponse _jsonListResponse(List<Map<String, dynamic>> json) {
  return _FakeResponse(
    statusCode: 200,
    body: jsonEncode(<String, dynamic>{'results': json}),
  );
}

class _Harness {
  const _Harness({
    required this.app,
    required this.controller,
    required this.storage,
  });

  final Widget app;
  final SessionController controller;
  final AuthStorage storage;
}

class _FakeResponse {
  const _FakeResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class _FakeTransport implements ApiTransport {
  const _FakeTransport(this.responses);

  final Map<String, dynamic> responses;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final key = request.uri.hasQuery
        ? '${request.method} ${request.uri.path}?${request.uri.query}'
        : '${request.method} ${request.uri.path}';
    final candidate = responses[key];
    if (candidate == null) {
      throw StateError('Missing fake response for $key');
    }

    late final _FakeResponse response;
    if (candidate is _FakeResponse) {
      response = candidate;
    } else if (candidate is List<_FakeResponse> && candidate.isNotEmpty) {
      response = candidate.removeAt(0);
    } else if (candidate is _FakeResponse Function(ApiRequest)) {
      response = candidate(request);
    } else {
      throw StateError('Invalid fake response for $key');
    }

    return ApiResponse(
      request: request,
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}

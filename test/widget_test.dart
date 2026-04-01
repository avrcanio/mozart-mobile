import 'dart:convert';
import 'dart:async';

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
import 'package:mozart_mobile/src/domain/purchase_order.dart';
import 'package:mozart_mobile/src/domain/user_session.dart';
import 'package:mozart_mobile/src/presentation/app_services_scope.dart';
import 'package:mozart_mobile/src/presentation/app_view.dart';
import 'package:mozart_mobile/src/presentation/session_scope.dart';
import 'package:mozart_mobile/src/presentation/screens/purchase_order_form_screen.dart';

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
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Mozart Operator'), findsAtLeastNWidgets(1));
    expect(find.text('Purchase Orders'), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('dashboard uses backend counts instead of first-page list length', (
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
        'GET /api/mailbox/messages/': _jsonPaginatedResponse(
          count: 27,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 101,
              'subject': 'Daily digest',
              'from_email': 'office@mozart.local',
              'to_emails': 'root@mozart.local',
              'sent_at': '2026-04-01T10:15:00Z',
              'attachments_count': 0,
            },
          ],
        ),
        'GET /api/purchase-orders/': _jsonPaginatedResponse(
          count: 14,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 15,
              'reference': 'PO-15',
              'supplier_name': 'Adriatic Trade',
              'status': 'sent',
              'status_display': 'Poslana',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ],
        ),
        'GET /api/purchase-orders/?status=created': _jsonPaginatedResponse(
          count: 3,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 19,
              'reference': 'PO-19',
              'supplier_name': 'Adriatic Trade',
              'status': 'created',
              'status_display': 'Kreirana',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ],
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('14'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Purchase Orders'), findsWidgets);
    expect(find.text('Created POs'), findsOneWidget);
    expect(find.text('Open POs'), findsNothing);
    expect(find.text('Approvals'), findsNothing);
    expect(find.text('Warehouses'), findsNothing);
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

    expect(find.text('Detalji poruke'), findsOneWidget);
    expect(find.text('Detalji ponude za tjednu nabavu.'), findsOneWidget);
    expect(find.text('manager@mozart.local'), findsOneWidget);
    expect(find.text('ponuda.pdf'), findsOneWidget);
    expect(find.text('Kopiraj link'), findsOneWidget);
  });

  testWidgets('uses html fallback messaging in mailbox detail when body text is missing', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, dynamic>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 9,
          'username': 'root',
          'email': 'root@mozart.local',
          'first_name': 'Mail',
          'last_name': 'User',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 701,
            'subject': 'HTML poruka',
            'from_email': 'nabava@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T08:45:00Z',
            'attachments_count': 0,
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
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
        'GET /api/mailbox/messages/701/': _jsonResponse(<String, dynamic>{
          'id': 701,
          'subject': 'HTML poruka',
          'from_email': 'nabava@mozart.hr',
          'to_emails': 'root@mozart.local',
          'sent_at': '2026-04-01T08:45:00Z',
          'body_text': '',
          'body_html': '<p>HTML fallback content</p>',
          'attachments': <Map<String, dynamic>>[],
        }),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mailbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HTML poruka'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji poruke'), findsOneWidget);
    expect(
      find.textContaining('tekstualni fallback'),
      findsOneWidget,
    );
    expect(find.text('<p>HTML fallback content</p>'), findsOneWidget);
    expect(find.text('Prilozi (0)'), findsOneWidget);
  });

  testWidgets('shows mailbox detail retry state on fetch error', (tester) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, dynamic>{
        'GET /api/me/': _jsonResponse(<String, dynamic>{
          'id': 9,
          'username': 'root',
          'email': 'root@mozart.local',
          'first_name': 'Mail',
          'last_name': 'User',
        }),
        'GET /api/mailbox/messages/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 702,
            'subject': 'Broken detail',
            'from_email': 'nabava@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T08:45:00Z',
            'attachments_count': 0,
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
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
        'GET /api/mailbox/messages/702/': _FakeResponse(
          statusCode: 500,
          body: jsonEncode(<String, dynamic>{'detail': 'Server error'}),
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mailbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Broken detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji poruke nisu dostupni'), findsOneWidget);
    expect(find.text('Pokusaj ponovno'), findsOneWidget);
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

    await tester.tap(find.text('Purchase Orders').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-2048'), findsWidgets);
    expect(find.textContaining('Blue Harbor Supply'), findsWidgets);
    expect(find.textContaining('18.420,50'), findsWidgets);
    expect(find.textContaining('Approved'), findsWidgets);
  });

  testWidgets('renders purchase order detail summary and line items', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, dynamic>{
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
            'status': 'confirmed',
            'status_display': 'Potvrdena',
            'payment_type_name': 'Karticno',
            'ordered_at': '2026-04-02T11:30:00Z',
            'total_gross': '18420.50',
            'items': <Map<String, dynamic>>[],
          },
        ]),
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
        'GET /api/purchase-orders/2048/': _jsonResponse(<String, dynamic>{
          'id': 2048,
          'reference': 'PO-2048',
          'supplier': 2,
          'supplier_name': 'Blue Harbor Supply',
          'status': 'confirmed',
          'status_display': 'Potvrdena',
          'payment_type': 6,
          'payment_type_name': 'Karticno',
          'ordered_at': '2026-04-02T11:30:00Z',
          'currency': 'EUR',
          'total_net': '15000.00',
          'total_gross': '18420.50',
          'total_deposit': '85.00',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 7,
              'artikl': 77,
              'artikl_name': 'Coffee beans',
              'quantity': '10.0000',
              'unit_of_measure': 1,
              'unit_name': 'kg',
              'price': '12.00',
              'received_quantity': '4.0000',
              'remaining_quantity': '6.0000',
              'base_group': '',
            },
          ],
        }),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-2048').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji narudzbe'), findsOneWidget);
    expect(find.text('Narudzba PO-2048'), findsOneWidget);
    expect(find.text('Blue Harbor Supply'), findsWidgets);
    expect(find.text('Ukupni iznosi'), findsOneWidget);
    expect(find.textContaining('EUR 15.000,00'), findsOneWidget);
    expect(find.textContaining('EUR 18.420,50'), findsOneWidget);
    expect(find.textContaining('EUR 85,00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Coffee beans'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Coffee beans'), findsOneWidget);
    expect(find.textContaining('Kolicina: 10 kg'), findsOneWidget);
    expect(find.textContaining('Preostalo: 6'), findsOneWidget);
  });

  testWidgets('shows purchase order detail retry state on fetch error', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, dynamic>{
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
            'id': 2048,
            'reference': 'PO-2048',
            'supplier_name': 'Blue Harbor Supply',
            'status': 'confirmed',
            'status_display': 'Potvrdena',
            'payment_type_name': 'Karticno',
            'ordered_at': '2026-04-02T11:30:00Z',
            'total_gross': '18420.50',
            'items': <Map<String, dynamic>>[],
          },
        ]),
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
        'GET /api/purchase-orders/2048/': _FakeResponse(
          statusCode: 500,
          body: jsonEncode(<String, dynamic>{'detail': 'Server error'}),
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-2048').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji nisu dostupni'), findsOneWidget);
    expect(find.text('Pokusaj ponovno'), findsOneWidget);
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

    await tester.tap(find.text('Purchase Orders').last);
    await tester.pumpAndSettle();

    expect(find.text('Narudzbe nisu dostupne'), findsOneWidget);
    expect(find.text('Pokusaj ponovno'), findsOneWidget);
  });

  testWidgets('shows retryable error state when purchase orders time out', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      requestTimeout: const Duration(milliseconds: 10),
      responses: <String, dynamic>{
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
        'GET /api/purchase-orders/': _delayedResponse(
          const Duration(milliseconds: 50),
          _jsonListResponse(<Map<String, dynamic>>[]),
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders').last);
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

    await tester.tap(find.text('Purchase Orders').last);
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

  testWidgets('shows friendly empty state for filtered purchase orders', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, dynamic>{
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
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[
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
          ],
        ),
        'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{'id': 2, 'name': 'Blue Harbor Supply'},
        ]),
        'GET /api/purchase-orders/?status=sent': _jsonPaginatedResponse(
          count: 0,
          results: <Map<String, dynamic>>[],
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filteri'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-filter-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poslana').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Primijeni'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Nema aktivnih narudzbi'), findsOneWidget);
    expect(find.text('Status: Poslana'), findsOneWidget);
  });

  testWidgets('keeps purchase order filters active after create flow refresh', (
    tester,
  ) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, dynamic>{
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
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[
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
          ],
        ),
        'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{'id': 2, 'name': 'Blue Harbor Supply'},
        ]),
        'GET /api/payment-types/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{'id': 5, 'name': 'Virman'},
        ]),
        'GET /api/suppliers/2/artikli/': _jsonListResponse(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 77,
              'artikl_name': 'Coffee beans',
              'unit_of_measure': 1,
              'unit_name': 'kg',
              'price': '12.50',
            },
          ],
        ),
        'POST /api/purchase-orders/': _jsonResponse(<String, dynamic>{
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
          'items': <Map<String, dynamic>>[],
        }),
        'GET /api/purchase-orders/?status=sent': <_FakeResponse>[
          _jsonPaginatedResponse(
            count: 1,
            results: <Map<String, dynamic>>[
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
            ],
          ),
          _jsonPaginatedResponse(
            count: 1,
            results: <Map<String, dynamic>>[
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
            ],
          ),
        ],
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchase Orders').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filteri'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-filter-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poslana').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Primijeni'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-FILTERED'), findsOneWidget);
    expect(find.text('Status: Poslana'), findsOneWidget);

    await tester.tap(find.text('Nova'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-form-supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Harbor Supply').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-form-payment-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Virman').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dodaj stavku'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('po-line-0-quantity')), '1');
    await tester.scrollUntilVisible(
      find.byKey(const Key('po-form-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('po-form-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-FILTERED'), findsOneWidget);
    expect(find.text('Status: Poslana'), findsOneWidget);
    expect(find.textContaining('PO-BASE'), findsNothing);
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

    await tester.tap(find.text('Purchase Orders').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-SEND').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji narudzbe'), findsOneWidget);
    expect(find.text('Posalji narudzbu'), findsOneWidget);

    await tester.tap(find.text('Posalji narudzbu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Narudzba je uspjesno poslana.'), findsOneWidget);
    expect(find.text('Posalji narudzbu'), findsNothing);
    expect(find.text('Poslana'), findsWidgets);
  });

  testWidgets(
    'edits purchase order safely when historical article is missing from supplier lookup',
    (tester) async {
      ApiRequest? capturedRequest;
      final repository = PurchaseOrderRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 2, 'name': 'Blue Harbor Supply'},
            ]),
            'GET /api/payment-types/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 5, 'name': 'Virman'},
            ]),
            'GET /api/suppliers/2/artikli/': _jsonListResponse(
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 88,
                  'artikl_name': 'Fresh item',
                  'unit_of_measure': 1,
                  'unit_name': 'kg',
                  'price': '11.00',
                },
              ],
            ),
            'PUT /api/purchase-orders/44/': (ApiRequest request) {
              capturedRequest = request;
              return _jsonResponse(<String, dynamic>{
                'id': 44,
                'reference': 'PO-EDIT',
                'supplier': 2,
                'supplier_name': 'Blue Harbor Supply',
                'status': 'created',
                'status_display': 'Kreirana',
                'payment_type': 5,
                'payment_type_name': 'Virman',
                'ordered_at': '2026-04-05T09:30:00Z',
                'total_gross': '130.00',
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 7,
                    'artikl': 77,
                    'artikl_name': 'Historical item',
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

      const session = UserSession(
        token: 'saved-token',
        username: 'root',
        fullName: 'Mozart Operator',
        email: 'root@mozart.local',
      );

      const initialOrder = PurchaseOrder(
        id: 44,
        reference: 'PO-EDIT',
        supplierId: 2,
        status: 'created',
        statusLabel: 'Kreirana',
        supplierName: 'Blue Harbor Supply',
        paymentTypeId: 5,
        paymentTypeName: 'Virman',
        totalAmount: 130,
        currency: 'EUR',
        orderedAt: null,
        lines: <PurchaseOrderLine>[
          PurchaseOrderLine(
            id: 7,
            articleId: 77,
            articleName: 'Historical item',
            unitOfMeasureId: 1,
            unitName: 'kg',
            baseGroup: '',
            quantity: 4,
            receivedQuantity: 0,
            remainingQuantity: 4,
            unitPrice: 13,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildMozartTheme(),
          home: PurchaseOrderFormScreen(
            session: session,
            repository: repository,
            initialOrder: initialOrder,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Historical item'), findsWidgets);
      expect(
        find.textContaining('vise nije u aktivnom katalogu dobavljaca'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('po-form-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('po-form-save')));
      await tester.pumpAndSettle();

      final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
      expect((body['items'] as List).single['artikl'], 77);
      expect((body['items'] as List).single['id'], 7);
    },
  );

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

  test('maps request timeout to retryable api exception', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      requestTimeout: const Duration(milliseconds: 10),
      transport: _NeverCompletesTransport(),
    );

    await expectLater(
      () => client.getJson('/api/purchase-orders/', authToken: 'saved-token'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Zahtjev je istekao. Provjerite vezu i pokusajte ponovno.',
        ),
      ),
    );
  });

  testWidgets('accepts Croatian decimal input in purchase order form', (
    tester,
  ) async {
    ApiRequest? capturedRequest;
    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
            <String, dynamic>{'id': 2, 'name': 'Blue Harbor Supply'},
          ]),
          'GET /api/payment-types/': _jsonListResponse(<Map<String, dynamic>>[
            <String, dynamic>{'id': 5, 'name': 'Virman'},
          ]),
          'GET /api/suppliers/2/artikli/': _jsonListResponse(
            <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 77,
                'artikl_name': 'Coffee beans',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '12.50',
              },
            ],
          ),
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
                  'quantity': '1.5000',
                  'unit_of_measure': 1,
                  'unit_name': 'kg',
                  'price': '12.50',
                  'received_quantity': '0.0000',
                  'remaining_quantity': '1.5000',
                  'base_group': '',
                },
              ],
            });
          },
        }),
      ),
    );

    const session = UserSession(
      token: 'saved-token',
      username: 'root',
      fullName: 'Mozart Operator',
      email: 'root@mozart.local',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMozartTheme(),
        home: PurchaseOrderFormScreen(
          session: session,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-form-supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Harbor Supply').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-form-payment-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Virman').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dodaj stavku'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('po-line-0-quantity')), '1,5');
    await tester.enterText(find.byKey(const Key('po-line-0-price')), '12,50');

    await tester.scrollUntilVisible(
      find.byKey(const Key('po-form-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('po-form-save')));
    await tester.pumpAndSettle();

    final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
    expect((body['items'] as List).single['quantity'], '1.5');
    expect((body['items'] as List).single['price'], '12.50');
  });
}

Future<_Harness> _createHarness({
  required Map<String, dynamic> responses,
  String? savedToken,
  Duration requestTimeout = const Duration(seconds: 15),
}) async {
  final transport = _FakeTransport(responses);
  final apiClient = ApiClient(
    baseUrl: 'https://example.test',
    transport: transport,
    requestTimeout: requestTimeout,
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
  return _jsonPaginatedResponse(count: json.length, results: json);
}

_FakeResponse _jsonPaginatedResponse({
  required int count,
  required List<Map<String, dynamic>> results,
}) {
  return _FakeResponse(
    statusCode: 200,
    body: jsonEncode(<String, dynamic>{
      'count': count,
      'results': results,
    }),
  );
}

Future<_FakeResponse> Function(ApiRequest) _delayedResponse(
  Duration delay,
  _FakeResponse response,
) {
  return (_) async {
    await Future<void>.delayed(delay);
    return response;
  };
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
    final exactKey = request.uri.hasQuery
        ? '${request.method} ${request.uri.path}?${request.uri.query}'
        : '${request.method} ${request.uri.path}';
    final fallbackKey = '${request.method} ${request.uri.path}';
    final exactCandidate = responses[exactKey];
    final fallbackCandidate = responses[fallbackKey];
    final candidate = exactCandidate ??
        (request.uri.hasQuery && fallbackCandidate is List<_FakeResponse>
            ? null
            : fallbackCandidate);
    if (candidate == null) {
      throw StateError('Missing fake response for $exactKey');
    }

    late final _FakeResponse response;
    if (candidate is _FakeResponse) {
      response = candidate;
    } else if (candidate is List<_FakeResponse> && candidate.isNotEmpty) {
      response = candidate.removeAt(0);
    } else if (candidate is _FakeResponse Function(ApiRequest)) {
      response = candidate(request);
    } else if (candidate is Future<_FakeResponse> Function(ApiRequest)) {
      response = await candidate(request);
    } else {
      throw StateError('Invalid fake response for $exactKey');
    }

    return ApiResponse(
      request: request,
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}

class _NeverCompletesTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) {
    final completer = Completer<ApiResponse>();
    return completer.future;
  }
}

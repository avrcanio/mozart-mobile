import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ordino/src/core/theme/app_theme.dart';
import 'package:ordino/src/data/auth/auth_repository.dart';
import 'package:ordino/src/data/auth/auth_storage.dart';
import 'package:ordino/src/data/dashboard/dashboard_repository.dart';
import 'package:ordino/src/data/http/api_client.dart';
import 'package:ordino/src/data/mailbox/mailbox_repository.dart';
import 'package:ordino/src/data/purchase_orders/purchase_order_repository.dart';
import 'package:ordino/src/domain/purchase_order.dart';
import 'package:ordino/src/domain/user_session.dart';
import 'package:ordino/src/presentation/app_services_scope.dart';
import 'package:ordino/src/presentation/app_view.dart';
import 'package:ordino/src/presentation/connectivity_feedback.dart';
import 'package:ordino/src/presentation/screens/mailbox_detail_screen.dart';
import 'package:ordino/src/presentation/screens/purchase_order_detail_screen.dart';
import 'package:ordino/src/presentation/session_scope.dart';
import 'package:ordino/src/presentation/screens/purchase_order_receipt_screen.dart';
import 'package:ordino/src/presentation/screens/purchase_order_form_screen.dart';

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

    expect(find.text('Ordino'), findsOneWidget);
    expect(find.text('Prijava'), findsOneWidget);
  });

  testWidgets('boots into authenticated dashboard with restored session', (
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

    expect(find.text('Početna'), findsWidgets);
    expect(find.byKey(const Key('home-avatar-initials')), findsOneWidget);
    expect(find.text('MO'), findsOneWidget);
    expect(find.text('Narudžbe'), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('shows active screen title and avatar menu in app header', (
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

    expect(find.text('Ordino'), findsNothing);
    expect(
      find.text('Pregled najvaznijih obaveza i stanja za danasnji rad.'),
      findsNothing,
    );
    expect(find.text('Brzi pregled'), findsNothing);
    expect(find.byKey(const Key('home-avatar-menu')), findsOneWidget);
    expect(find.byKey(const Key('home-avatar-initials')), findsOneWidget);
    expect(find.text('root'), findsNothing);
    expect(find.text('Mozart Operator'), findsNothing);

    await tester.tap(find.byKey(const Key('home-avatar-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Odjava'), findsOneWidget);
  });

  testWidgets('dashboard metric cards navigate to matching tabs', (
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
          count: 3,
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
        'GET /api/purchase-orders/?status=confirmed': _jsonPaginatedResponse(
          count: 14,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 15,
              'reference': 'PO-15',
              'supplier_name': 'Adriatic Trade',
              'status': 'confirmed',
              'status_display': 'Potvrđena',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ],
        ),
        'GET /api/purchase-orders/?status=created&status=sent':
            _jsonPaginatedResponse(
              count: 2,
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

    await tester.tap(find.text('Poruke').first);
    await tester.pumpAndSettle();
    expect(find.text('Poruke'), findsWidgets);

    await tester.tap(_navigationDestinationFinder('Početna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Potvrđene').first);
    await tester.pumpAndSettle();
    expect(find.text('Narudžbe'), findsWidgets);
    expect(find.text('Status: Potvrđena'), findsOneWidget);

    await tester.tap(_navigationDestinationFinder('Početna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kreirane i poslane').first);
    await tester.pumpAndSettle();
    expect(find.text('Narudžbe'), findsWidgets);
    expect(find.text('Status: Kreirana'), findsOneWidget);
    expect(find.text('Status: Poslana'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads each home tab independently', (
    tester,
  ) async {
    var dashboardCreatedCount = 1;
    var mailboxLoadCount = 0;
    var purchaseOrderLoadCount = 0;

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
        'GET /api/mailbox/messages/': (ApiRequest request) {
          mailboxLoadCount += 1;
          return _jsonPaginatedResponse(
            count: 3,
            results: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 100 + mailboxLoadCount,
                'subject': 'Mail batch $mailboxLoadCount',
                'from_email': 'office@mozart.local',
                'to_emails': 'root@mozart.local',
                'sent_at': '2026-04-01T10:15:00Z',
                'attachments_count': 0,
              },
            ],
          );
        },
        'GET /api/purchase-orders/': (ApiRequest request) {
          purchaseOrderLoadCount += 1;
          return _jsonPaginatedResponse(
            count: 5,
            results: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 15,
                'reference': 'PO-$purchaseOrderLoadCount',
                'supplier_name': 'Adriatic Trade',
                'status': 'sent',
                'status_display': 'Poslana',
                'payment_type_name': 'Virman',
                'ordered_at': '2026-04-01T09:30:00Z',
                'total_gross': '145.50',
                'items': <Map<String, dynamic>>[],
              },
            ],
          );
        },
        'GET /api/purchase-orders/?status=confirmed': (ApiRequest request) {
          dashboardCreatedCount += 1;
          return _jsonPaginatedResponse(
            count: dashboardCreatedCount,
            results: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 19,
                'reference': 'PO-CONFIRMED',
                'supplier_name': 'Adriatic Trade',
                'status': 'confirmed',
                'status_display': 'Potvrđena',
                'payment_type_name': 'Virman',
                'ordered_at': '2026-04-01T09:30:00Z',
                'total_gross': '145.50',
                'items': <Map<String, dynamic>>[],
              },
            ],
          );
        },
        'GET /api/purchase-orders/?status=created&status=sent':
            _jsonPaginatedResponse(
              count: 4,
              results: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 25,
                  'reference': 'PO-CREATED',
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

    String visibleTextStartingWith(String prefix) {
      for (final widget in tester.widgetList<Text>(find.byType(Text))) {
        final data = widget.data;
        if (data != null && data.startsWith(prefix)) {
          return data;
        }
      }
      throw StateError('No visible text starting with $prefix');
    }

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsWidgets);

    await tester.tap(_navigationDestinationFinder('Poruke'));
    await tester.pumpAndSettle();
    final initialMailboxSubject = visibleTextStartingWith('Mail batch ');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final refreshedMailboxSubject = visibleTextStartingWith('Mail batch ');
    expect(refreshedMailboxSubject, isNot(initialMailboxSubject));

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();
    final initialOrderReference = visibleTextStartingWith('PO-');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final refreshedOrderReference = visibleTextStartingWith('PO-');
    expect(refreshedOrderReference, isNot(initialOrderReference));
  });

  testWidgets(
    'dashboard uses backend counts instead of first-page list length',
    (tester) async {
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
          'GET /api/purchase-orders/?status=confirmed': _jsonPaginatedResponse(
            count: 14,
            results: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 19,
                'reference': 'PO-19',
                'supplier_name': 'Adriatic Trade',
                'status': 'confirmed',
                'status_display': 'Potvrđena',
                'payment_type_name': 'Virman',
                'ordered_at': '2026-04-01T09:30:00Z',
                'total_gross': '145.50',
                'items': <Map<String, dynamic>>[],
              },
            ],
          ),
          'GET /api/purchase-orders/?status=created&status=sent':
              _jsonPaginatedResponse(
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

      expect(find.text('14'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('Poruke'), findsWidgets);
      expect(find.text('Potvrđene'), findsOneWidget);
      expect(find.text('Kreirane i poslane'), findsOneWidget);
      expect(find.text('Open POs'), findsNothing);
      expect(find.text('Approvals'), findsNothing);
      expect(find.text('Warehouses'), findsNothing);
    },
  );

  testWidgets('renders mailbox list from mapped backend data', (tester) async {
    final harness = await _createHarness(
      savedToken: 'saved-token',
      responses: <String, dynamic>{
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
          <String, dynamic>{
            'id': 502,
            'subject': 'Kasnija poruka',
            'from_email': 'office@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-02T10:15:00Z',
            'attachments_count': 0,
          },
          <String, dynamic>{
            'id': 503,
            'subject': 'Poruka bez datuma',
            'from_email': 'warehouse@mozart.hr',
            'to_emails': 'root@mozart.local',
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
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(_navigationDestinationFinder('Poruke'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pregledajte nove poruke i priloge na jednom mjestu.'),
      findsNothing,
    );
    expect(find.text('02.04.2026.'), findsOneWidget);
    expect(find.text('01.04.2026.'), findsWidgets);
    expect(find.text('Bez datuma'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Kasnija poruka')).dy,
      lessThan(tester.getTopLeft(find.textContaining('nabava@mozart.hr')).dy),
    );
    expect(find.textContaining('nabava@mozart.hr'), findsOneWidget);
    expect(find.text('01.04.2026.'), findsOneWidget);
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

    await tester.tap(_navigationDestinationFinder('Poruke'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nova ponuda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji poruke'), findsOneWidget);
    expect(find.text('Detalji ponude za tjednu nabavu.'), findsOneWidget);
    expect(find.text('manager@mozart.local'), findsOneWidget);
    expect(find.text('ponuda.pdf'), findsOneWidget);
    expect(find.text('Otvori prilog'), findsOneWidget);
    expect(find.text('Kopiraj link'), findsOneWidget);
  });

  testWidgets('opens mailbox attachment via injected launcher', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Uri? openedUri;
    final repository = MailboxRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
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
      _testMaterialApp(
        home: MailboxDetailScreen(
          messageId: 700,
          session: session,
          repository: repository,
          attachmentLauncher: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openAttachmentButton = find.widgetWithText(
      FilledButton,
      'Otvori prilog',
    );
    await tester.ensureVisible(openAttachmentButton);
    await tester.tap(openAttachmentButton);
    await tester.pumpAndSettle();

    expect(openedUri, Uri.parse('https://example.test/media/ponuda.pdf'));
    expect(
      find.text('Prilog se otvara u vanjskoj aplikaciji.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows fallback snackbar when mailbox attachment cannot be opened',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MailboxRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'GET /api/mailbox/messages/701/': _jsonResponse(<String, dynamic>{
              'id': 701,
              'subject': 'Nova ponuda',
              'from_email': 'nabava@mozart.hr',
              'to_emails': 'root@mozart.local',
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
        _testMaterialApp(
          home: MailboxDetailScreen(
            messageId: 701,
            session: session,
            repository: repository,
            attachmentLauncher: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openAttachmentButton = find.widgetWithText(
        FilledButton,
        'Otvori prilog',
      );
      await tester.ensureVisible(openAttachmentButton);
      await tester.tap(openAttachmentButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Prilog nije moguce otvoriti. Kopirajte link i pokusajte ponovno.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders cleaned html mail content instead of raw Word markup', (
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
          'body_html': '''
            <html xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
              <head>
                <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-2">
                <style>
                  @font-face {font-family:Aptos;}
                  p.MsoNormal {margin:0cm;font-size:11.0pt;font-family:"Aptos",sans-serif;}
                </style>
              </head>
              <body>
                <div class="WordSection1">
                  <p class="MsoNormal"><strong>RACUNI</strong></p>
                  <p class="MsoNormal">Pregled posiljatelja, primatelja i sadrzaja poruke.</p>
                  <p class="MsoNormal">
                    <a href="https://example.test/poruka">Otvori poruku u pregledniku</a>
                  </p>
                  <p class="MsoNormal">
                    <img src="https://example.test/logo.png" alt="Logo dobavljaca" />
                  </p>
                </div>
              </body>
            </html>
          ''',
          'attachments': <Map<String, dynamic>>[],
        }),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(_navigationDestinationFinder('Poruke'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HTML poruka'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji poruke'), findsOneWidget);
    expect(find.text('RACUNI'), findsOneWidget);
    expect(
      find.text('Pregled posiljatelja, primatelja i sadrzaja poruke.'),
      findsWidgets,
    );
    expect(find.text('Otvori poruku u pregledniku'), findsOneWidget);
    expect(find.textContaining('<html xmlns:v='), findsNothing);
    expect(find.textContaining('@font-face'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Prilozi ('), findsNothing);
  });

  testWidgets(
    'renders cleaned plain-text html without fallback notice when content is readable',
    (tester) async {
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
          'GET /api/mailbox/messages/': _jsonListResponse(
            <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 702,
                'subject': 'Fallback poruka',
                'from_email': 'nabava@mozart.hr',
                'to_emails': 'root@mozart.local',
                'sent_at': '2026-04-01T08:45:00Z',
                'attachments_count': 0,
              },
            ],
          ),
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
          'GET /api/mailbox/messages/702/': _jsonResponse(<String, dynamic>{
            'id': 702,
            'subject': 'Fallback poruka',
            'from_email': 'nabava@mozart.hr',
            'to_emails': 'root@mozart.local',
            'sent_at': '2026-04-01T08:45:00Z',
            'body_text': 'Ovo je tekstualni fallback poruke.',
            'body_html':
                '<html><head></head><body>Ovo je tekstualni fallback poruke.</body></html>',
            'attachments': <Map<String, dynamic>>[],
          }),
        },
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(_navigationDestinationFinder('Poruke'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fallback poruka'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Detalji poruke'), findsOneWidget);
      expect(find.text('Ovo je tekstualni fallback poruke.'), findsOneWidget);
      expect(
        find.textContaining('nije bila dovoljno cista za bogatiji prikaz'),
        findsNothing,
      );
      expect(find.textContaining('<html><head>'), findsNothing);
    },
  );

  testWidgets(
    'does not show html fallback notice for readable quoted plain-text mail',
    (tester) async {
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
          'GET /api/mailbox/messages/': _jsonListResponse(
            <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 703,
                'subject': 'RE: Narudzba #117',
                'from_email': 'narudzbe@koktel.hr',
                'to_emails': 'narudzbe@sibenik1983.hr',
                'sent_at': '2026-03-17T13:25:00Z',
                'attachments_count': 0,
              },
            ],
          ),
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
          'GET /api/mailbox/messages/703/': _jsonResponse(<String, dynamic>{
            'id': 703,
            'subject': 'RE: Narudzba #117',
            'from_email': 'Narudzbe Koktel <narudzbe@koktel.hr>',
            'to_emails': 'Mozart Caffe Narudzbe <narudzbe@sibenik1983.hr>',
            'sent_at': '2026-03-17T13:25:00Z',
            'body_text': '''
Nema hidre vital još uvijek....

-----Izvorna poruka-----
Pošiljatelj: Mozart Caffe Narudzbe <narudzbe@sibenik1983.hr>
Poslano: 17. ožujka 2026. 13:23
Primatelj: Narudzbe Koktel <narudzbe@koktel.hr>
Predmet: Narudzba #117

U prilogu se nalazi narudzba 117.

Molimo potvrdite primitak narudžbe klikom na sljedeći link: https://mozart.sibenik1983.hr/orders/confirm/Gb_4CbpUCV8O558Wo7gWUtVFXIVLw_micp6YylWOVds/
          ''',
            'body_html': '<html><head></head><body></body></html>',
            'attachments': <Map<String, dynamic>>[],
          }),
        },
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(_navigationDestinationFinder('Poruke'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('RE: Narudzba #117'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Detalji poruke'), findsOneWidget);
      expect(find.textContaining('Nema hidre vital'), findsOneWidget);
      expect(
        find.textContaining('mozart.sibenik1983.hr/orders/confirm/'),
        findsOneWidget,
      );
      expect(
        find.textContaining('nije bila dovoljno cista za bogatiji prikaz'),
        findsNothing,
      );
      expect(find.textContaining('Prilozi ('), findsNothing);
      expect(find.text('Poruka nema priloga.'), findsNothing);
    },
  );

  testWidgets('shows mailbox detail retry state on fetch error', (
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

    await tester.tap(_navigationDestinationFinder('Poruke'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Broken detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji poruke nisu dostupni'), findsOneWidget);
    expect(find.text('Pokušaj ponovno'), findsOneWidget);
  });

  testWidgets('loads additional mailbox pages on demand', (tester) async {
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
        'GET /api/mailbox/messages/': _jsonPaginatedResponse(
          count: 3,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 801,
              'subject': 'Inbox one',
              'from_email': 'nabava@mozart.hr',
              'to_emails': 'root@mozart.local',
              'sent_at': '2026-04-01T08:45:00Z',
              'attachments_count': 0,
            },
            <String, dynamic>{
              'id': 802,
              'subject': 'Inbox two',
              'from_email': 'office@mozart.hr',
              'to_emails': 'root@mozart.local',
              'sent_at': '2026-04-01T09:45:00Z',
              'attachments_count': 1,
            },
          ],
        ),
        'GET /api/mailbox/messages/?page=2': _jsonPaginatedResponse(
          count: 3,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 803,
              'subject': 'Inbox three',
              'from_email': 'warehouse@mozart.hr',
              'to_emails': 'root@mozart.local',
              'sent_at': '2026-04-01T10:45:00Z',
              'attachments_count': 0,
            },
          ],
        ),
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

    await tester.tap(_navigationDestinationFinder('Poruke'));
    await tester.pumpAndSettle();

    expect(find.text('Inbox one'), findsOneWidget);
    expect(find.text('Inbox two'), findsOneWidget);
    expect(find.text('Inbox three'), findsNothing);
    expect(find.text('Učitaj još'), findsOneWidget);
    expect(find.text('Prikazano 2 od 3 poruka.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mailbox-load-more')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Inbox three'), findsOneWidget);
    expect(find.text('Učitaj još'), findsNothing);
  });

  testWidgets('preserves mailbox detail navigation after loading more pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        'GET /api/mailbox/messages/': _jsonPaginatedResponse(
          count: 3,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 801,
              'subject': 'Inbox one',
              'from_email': 'nabava@mozart.hr',
              'to_emails': 'root@mozart.local',
              'sent_at': '2026-04-01T08:45:00Z',
              'attachments_count': 0,
            },
            <String, dynamic>{
              'id': 802,
              'subject': 'Inbox two',
              'from_email': 'office@mozart.hr',
              'to_emails': 'root@mozart.local',
              'sent_at': '2026-04-01T09:45:00Z',
              'attachments_count': 1,
            },
          ],
        ),
        'GET /api/mailbox/messages/?page=2': _jsonPaginatedResponse(
          count: 3,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 803,
              'subject': 'Inbox three',
              'from_email': 'warehouse@mozart.hr',
              'to_emails': 'root@mozart.local',
              'sent_at': '2026-04-01T10:45:00Z',
              'attachments_count': 0,
            },
          ],
        ),
        'GET /api/mailbox/messages/803/': _jsonResponse(<String, dynamic>{
          'id': 803,
          'subject': 'Inbox three',
          'from_email': 'warehouse@mozart.hr',
          'to_emails': 'root@mozart.local',
          'sent_at': '2026-04-01T10:45:00Z',
          'body_text': 'Older message detail after pagination.',
          'attachments': <Map<String, dynamic>>[],
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

    await tester.tap(_navigationDestinationFinder('Poruke'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('mailbox-load-more')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('mailbox-load-more')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox three'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji poruke'), findsOneWidget);
    expect(find.text('Older message detail after pagination.'), findsOneWidget);
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
            'status': 'confirmed',
            'status_display': 'Potvrđena',
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
          <String, dynamic>{
            'id': 2049,
            'reference': 'PO-2049',
            'supplier_name': 'Alpha Market',
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type_name': 'Gotovina',
            'ordered_at': '2026-04-02T08:30:00Z',
            'total_gross': '150.00',
            'items': <Map<String, dynamic>>[],
          },
          <String, dynamic>{
            'id': 2050,
            'reference': 'PO-2050',
            'supplier_name': 'Fructus d.o.o.',
            'status': 'received_all',
            'status_display': 'Sve stavke s narudžbe su zaprimljene',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T11:30:00Z',
            'total_gross': '95.10',
            'items': <Map<String, dynamic>>[],
          },
        ]),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pratite narudžbe, statuse i osnovne detalje isporuke.'),
      findsNothing,
    );
    expect(find.text('02.04.2026.'), findsOneWidget);
    expect(find.text('01.04.2026.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('PO-2049')).dy,
      lessThan(tester.getTopLeft(find.textContaining('PO-2048')).dy),
    );
    expect(
      tester.getTopLeft(find.textContaining('PO-2048')).dy,
      lessThan(tester.getTopLeft(find.textContaining('PO-2050')).dy),
    );
    expect(find.textContaining('PO-2048'), findsWidgets);
    expect(find.textContaining('Blue Harbor Supply'), findsWidgets);
    expect(find.text('18.420,50 €'), findsOneWidget);
    expect(find.text('150,00 €'), findsOneWidget);
    expect(find.text('95,10 €'), findsOneWidget);
    expect(find.textContaining('02.04.2026. 11:30'), findsNothing);
    expect(find.textContaining('Approved'), findsNothing);
    expect(find.byKey(const Key('po-status-badge-2048')), findsOneWidget);
    expect(find.byKey(const Key('po-status-badge-2049')), findsOneWidget);
    expect(find.byKey(const Key('po-status-badge-2050')), findsOneWidget);
    expect(find.byKey(const Key('po-payment-badge-2048')), findsOneWidget);
    expect(find.byKey(const Key('po-payment-badge-2049')), findsOneWidget);
    expect(find.byKey(const Key('po-payment-badge-2050')), findsOneWidget);

    final createdBadge = tester.widget<Container>(
      find.byKey(const Key('po-status-badge-2049')),
    );
    final receivedAllBadge = tester.widget<Container>(
      find.byKey(const Key('po-status-badge-2050')),
    );
    expect(
      (createdBadge.decoration! as BoxDecoration).color,
      equals(Colors.white),
    );
    expect(
      (receivedAllBadge.decoration! as BoxDecoration).color,
      equals(const Color(0xFFDCF4E4)),
    );
  });

  testWidgets(
    'filters out representation payment type in purchase order form',
    (tester) async {
      final repository = PurchaseOrderRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'name': 'Fructus d.o.o.'},
            ]),
            'GET /api/payment-types/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 4, 'name': 'Reprezentacija'},
              <String, dynamic>{'id': 5, 'name': 'Virman'},
              <String, dynamic>{'id': 6, 'name': 'Gotovina'},
            ]),
          }),
        ),
      );

      await tester.pumpWidget(
        _testMaterialApp(
          home: PurchaseOrderFormScreen(
            session: const UserSession(
              token: 'token',
              username: 'root',
              fullName: 'Root User',
              email: 'root@mozart.local',
            ),
            repository: repository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('po-form-payment-type')));
      await tester.pumpAndSettle();

      expect(find.text('Virman').last, findsOneWidget);
      expect(find.text('Gotovina').last, findsOneWidget);
      expect(find.text('Reprezentacija'), findsNothing);
    },
  );

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
          'created_by': 'Ana Admin',
          'sent_at': '2026-04-02T12:00:00Z',
          'updated_at': '2026-04-03T09:15:00Z',
          'primka_created': true,
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

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-2048').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji narudžbe'), findsOneWidget);
    expect(find.text('Narudžba PO-2048'), findsOneWidget);
    expect(find.text('Blue Harbor Supply'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Ukupni iznosi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ukupni iznosi'), findsOneWidget);
    expect(find.textContaining('EUR 15.000,00'), findsOneWidget);
    expect(find.textContaining('EUR 18.420,50'), findsOneWidget);
    expect(find.textContaining('EUR 85,00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Povijest statusa'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Povijest statusa'), findsOneWidget);
    expect(find.text('Narudžba kreirana'), findsOneWidget);
    expect(find.text('Narudžba poslana'), findsOneWidget);
    expect(find.text('Primka kreirana'), findsOneWidget);
    expect(find.text('Trenutni status'), findsOneWidget);
    expect(find.text('Kreirao: Ana Admin'), findsOneWidget);
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

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-2048').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji nisu dostupni'), findsOneWidget);
    expect(find.text('Pokušaj ponovno'), findsOneWidget);
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

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    expect(find.text('Narudžbe nisu dostupne'), findsOneWidget);
    expect(find.text('Pokušaj ponovno'), findsOneWidget);
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

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    expect(find.text('Narudžbe nisu dostupne'), findsOneWidget);
    expect(find.text(connectivityIssueMessage), findsOneWidget);
    expect(find.text('Pokušaj ponovno'), findsOneWidget);
  });

  testWidgets(
    'recovers purchase orders after retry when connectivity returns',
    (tester) async {
      var purchaseOrdersCallCount = 0;
      final harness = await _createHarness(
        savedToken: 'saved-token',
        responses: <String, dynamic>{
          'GET /api/me/': _jsonResponse(<String, dynamic>{
            'id': 4,
            'username': 'root',
            'email': 'root@mozart.local',
          }),
          'GET /api/mailbox/messages/': _jsonListResponse(
            <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'subject': 'ok',
                'from_email': 'mail@mozart.hr',
                'to_emails': 'root@mozart.local',
                'sent_at': '2026-04-01T08:45:00Z',
                'attachments_count': 0,
              },
            ],
          ),
          'GET /api/purchase-orders/': (ApiRequest request) async {
            purchaseOrdersCallCount += 1;
            if (purchaseOrdersCallCount <= 1) {
              throw SocketException('No route to host');
            }
            return _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 2050,
                'reference': 'PO-2050',
                'supplier_name': 'Blue Harbor Supply',
                'status': 'created',
                'status_display': 'Kreirana',
                'payment_type_name': 'Virman',
                'ordered_at': '2026-04-02T11:30:00Z',
                'total_gross': '120.00',
                'items': <Map<String, dynamic>>[],
              },
            ]);
          },
          'GET /api/purchase-orders/?status=confirmed': _jsonListResponse(
            <Map<String, dynamic>>[],
          ),
          'GET /api/purchase-orders/?status=created&status=sent':
              _jsonListResponse(<Map<String, dynamic>>[]),
        },
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(_navigationDestinationFinder('Narudžbe'));
      await tester.pumpAndSettle();

      expect(find.text('Narudžbe nisu dostupne'), findsOneWidget);
      expect(find.text(connectivityIssueMessage), findsOneWidget);

      await tester.tap(find.text('Pokušaj ponovno'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.textContaining('PO-2050'), findsWidgets);
      expect(find.text(connectivityIssueMessage), findsNothing);
    },
  );

  testWidgets(
    'returns to login and clears token when restored session is invalid',
    (tester) async {
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

      expect(find.text('Prijava'), findsOneWidget);
      expect(await harness.storage.readToken(), isNull);
    },
  );

  testWidgets(
    'applies and resets purchase order filters on mobile with datepicker fields',
    (tester) async {
      final harness = await _createHarness(
        savedToken: 'saved-token',
        responses: <String, dynamic>{
          'GET /api/me/': _jsonResponse(<String, dynamic>{
            'id': 4,
            'username': 'root',
            'email': 'root@mozart.local',
          }),
          'GET /api/mailbox/messages/': _jsonListResponse(
            <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'subject': 'ok',
                'from_email': 'mail@mozart.hr',
                'to_emails': 'root@mozart.local',
                'sent_at': '2026-04-01T08:45:00Z',
                'attachments_count': 0,
              },
            ],
          ),
          'GET /api/purchase-orders/': (ApiRequest request) {
            final statuses =
                request.uri.queryParametersAll['status'] ?? const <String>[];
            final supplier = request.uri.queryParameters['supplier'];
            final orderedFrom = request.uri.queryParameters['ordered_from'];
            final orderedTo = request.uri.queryParameters['ordered_to'];
            if (statuses.length == 1 &&
                statuses.single == 'sent' &&
                supplier == '2' &&
                orderedFrom == '2026-04-02' &&
                orderedTo == '2026-04-03') {
              return _jsonListResponse(<Map<String, dynamic>>[
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
              ]);
            }
            return _jsonListResponse(<Map<String, dynamic>>[
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
            ]);
          },
          'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
            <String, dynamic>{'id': 2, 'name': 'Blue Harbor Supply'},
            <String, dynamic>{'id': 3, 'name': 'Coffee Logistics'},
          ]),
        },
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(_navigationDestinationFinder('Narudžbe'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filteri'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('po-filter-status-sent')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('po-filter-supplier')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue Harbor Supply').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('po-filter-ordered-from')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('po-filter-ordered-from')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('po-filter-ordered-to')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('po-filter-ordered-to')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();

      expect(find.text('02.04.2026.'), findsOneWidget);
      expect(find.text('03.04.2026.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Primijeni'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Primijeni'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('PO-FILTERED'), findsOneWidget);
      expect(find.text('Status: Poslana'), findsOneWidget);
      expect(find.text('Dobavljač: Blue Harbor Supply'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('PO-BASE'), findsOneWidget);
      expect(find.text('Status: Poslana'), findsNothing);
    },
  );

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
        'GET /api/purchase-orders/?status=confirmed': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
        'GET /api/purchase-orders/?status=created&status=sent':
            _jsonListResponse(<Map<String, dynamic>>[
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
        ]),
        'GET /api/purchase-orders/?status=sent': _jsonPaginatedResponse(
          count: 0,
          results: <Map<String, dynamic>>[],
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filteri'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-filter-status-sent')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Primijeni'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Primijeni'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Nema aktivnih narudžbi'), findsOneWidget);
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
        'GET /api/purchase-orders/?status=confirmed': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
        'GET /api/purchase-orders/?status=created&status=sent':
            _jsonListResponse(<Map<String, dynamic>>[
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

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filteri'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-filter-status-sent')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Primijeni'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Primijeni'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-FILTERED'), findsOneWidget);
    expect(find.text('Status: Poslana'), findsOneWidget);

    await tester.tap(find.text('Nova'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('po-form-supplier')),
      'Blue Harbor',
    );
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

  testWidgets('auto-loads additional purchase order pages near list end', (
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
        'GET /api/purchase-orders/': _jsonPaginatedResponse(
          count: 3,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'reference': 'PO-001',
              'supplier_name': 'Blue Harbor Supply',
              'status': 'created',
              'status_display': 'Kreirana',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '99.99',
              'items': <Map<String, dynamic>>[],
            },
            <String, dynamic>{
              'id': 2,
              'reference': 'PO-002',
              'supplier_name': 'Coffee Logistics',
              'status': 'sent',
              'status_display': 'Poslana',
              'payment_type_name': 'Karticno',
              'ordered_at': '2026-04-02T09:30:00Z',
              'total_gross': '149.99',
              'items': <Map<String, dynamic>>[],
            },
          ],
        ),
        'GET /api/purchase-orders/?page=2': _jsonPaginatedResponse(
          count: 3,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 3,
              'reference': 'PO-003',
              'supplier_name': 'Warehouse One',
              'status': 'confirmed',
              'status_display': 'Potvrdena',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-03T09:30:00Z',
              'total_gross': '199.99',
              'items': <Map<String, dynamic>>[],
            },
          ],
        ),
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-001'), findsOneWidget);
    expect(find.textContaining('PO-002'), findsOneWidget);
    expect(find.textContaining('PO-003'), findsOneWidget);
    expect(find.text('Prikazano 2 od 3 narudžbi.'), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('PO-003'), findsOneWidget);
    expect(find.text('Prikazano 3 od 3 narudžbi.'), findsNothing);
  });

  testWidgets(
    'keeps active filters applied across auto-loaded purchase order pagination',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _createHarness(
        savedToken: 'saved-token',
        responses: <String, dynamic>{
          'GET /api/me/': _jsonResponse(<String, dynamic>{
            'id': 4,
            'username': 'root',
            'email': 'root@mozart.local',
          }),
          'GET /api/mailbox/messages/': _jsonListResponse(
            <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'subject': 'ok',
                'from_email': 'mail@mozart.hr',
                'to_emails': 'root@mozart.local',
                'sent_at': '2026-04-01T08:45:00Z',
                'attachments_count': 0,
              },
            ],
          ),
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
          ]),
          'GET /api/purchase-orders/?status=sent': _jsonPaginatedResponse(
            count: 3,
            results: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 101,
                'reference': 'PO-SENT-1',
                'supplier_name': 'Blue Harbor Supply',
                'status': 'sent',
                'status_display': 'Poslana',
                'payment_type_name': 'Karticno',
                'ordered_at': '2026-04-02T11:30:00Z',
                'total_gross': '18420.50',
                'items': <Map<String, dynamic>>[],
              },
              <String, dynamic>{
                'id': 102,
                'reference': 'PO-SENT-2',
                'supplier_name': 'Blue Harbor Supply',
                'status': 'sent',
                'status_display': 'Poslana',
                'payment_type_name': 'Karticno',
                'ordered_at': '2026-04-03T11:30:00Z',
                'total_gross': '28420.50',
                'items': <Map<String, dynamic>>[],
              },
            ],
          ),
          'GET /api/purchase-orders/?status=sent&page=2':
              _jsonPaginatedResponse(
                count: 3,
                results: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 103,
                    'reference': 'PO-SENT-3',
                    'supplier_name': 'Blue Harbor Supply',
                    'status': 'sent',
                    'status_display': 'Poslana',
                    'payment_type_name': 'Karticno',
                    'ordered_at': '2026-04-04T11:30:00Z',
                    'total_gross': '38420.50',
                    'items': <Map<String, dynamic>>[],
                  },
                ],
              ),
        },
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(_navigationDestinationFinder('Narudžbe'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filteri'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('po-filter-status-sent')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Primijeni'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Primijeni'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('PO-SENT-1'), findsOneWidget);
      expect(find.textContaining('PO-SENT-2'), findsOneWidget);
      expect(find.textContaining('PO-SENT-3'), findsOneWidget);
      expect(find.text('Status: Poslana'), findsOneWidget);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('PO-SENT-3'), findsOneWidget);
      expect(find.text('Status: Poslana'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores stale purchase order load-more results after filter changes',
    (tester) async {
      final stalePageCompleter = Completer<_FakeResponse>();
      var stalePageRequested = 0;

      final harness = await _createHarness(
        savedToken: 'saved-token',
        responses: <String, dynamic>{
          'GET /api/me/': _jsonResponse(<String, dynamic>{
            'id': 4,
            'username': 'root',
            'email': 'root@mozart.local',
          }),
          'GET /api/mailbox/messages/': _jsonListResponse(
            <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'subject': 'ok',
                'from_email': 'mail@mozart.hr',
                'to_emails': 'root@mozart.local',
                'sent_at': '2026-04-01T08:45:00Z',
                'attachments_count': 0,
              },
            ],
          ),
          'GET /api/purchase-orders/': _jsonPaginatedResponse(
            count: 4,
            results: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 120,
                'reference': 'PO-UNFILTERED-120',
                'supplier_name': 'Fructus d.o.o.',
                'status': 'received_all',
                'status_display': 'Sve stavke s narudžbe su zaprimljene',
                'payment_type_name': 'Gotovina',
                'ordered_at': '2026-03-19T09:30:00Z',
                'total_gross': '41.77',
                'items': <Map<String, dynamic>>[],
              },
              <String, dynamic>{
                'id': 121,
                'reference': 'PO-UNFILTERED-121',
                'supplier_name': 'Koktel Ugostiteljstvo d.o.o.',
                'status': 'received_all',
                'status_display': 'Sve stavke s narudžbe su zaprimljene',
                'payment_type_name': 'Gotovina',
                'ordered_at': '2026-03-18T09:30:00Z',
                'total_gross': '13.80',
                'items': <Map<String, dynamic>>[],
              },
            ],
          ),
          'GET /api/purchase-orders/?page=2': (ApiRequest request) async {
            stalePageRequested += 1;
            return stalePageCompleter.future;
          },
          'GET /api/purchase-orders/?status=confirmed': _jsonPaginatedResponse(
            count: 0,
            results: <Map<String, dynamic>>[],
          ),
          'GET /api/purchase-orders/?status=created&status=sent':
              _jsonPaginatedResponse(
                count: 1,
                results: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 143,
                    'reference': 'PO-FRESH-143',
                    'supplier_name': 'Koktel Ugostiteljstvo d.o.o.',
                    'status': 'created',
                    'status_display': 'Kreirana',
                    'payment_type_name': 'Virman',
                    'ordered_at': '2026-04-01T09:30:00Z',
                    'total_gross': '2.86',
                    'items': <Map<String, dynamic>>[],
                  },
                ],
              ),
        },
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(_navigationDestinationFinder('Narudžbe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(stalePageRequested, 1);

      await tester.tap(_navigationDestinationFinder('Početna'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kreirane i poslane').first);
      await tester.pumpAndSettle();

      expect(find.text('Status: Kreirana'), findsOneWidget);
      expect(find.text('Status: Poslana'), findsOneWidget);
      expect(find.textContaining('PO-FRESH-143'), findsOneWidget);
      expect(find.textContaining('PO-UNFILTERED-120'), findsNothing);
      expect(find.textContaining('PO-UNFILTERED-121'), findsNothing);

      stalePageCompleter.complete(
        _jsonPaginatedResponse(
          count: 4,
          results: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 11,
              'reference': 'PO-STALE-11',
              'supplier_name': 'Koktel Ugostiteljstvo d.o.o.',
              'status': 'received_all',
              'status_display': 'Sve stavke s narudžbe su zaprimljene',
              'payment_type_name': 'Gotovina',
              'ordered_at': '2026-01-03T09:30:00Z',
              'total_gross': '237.27',
              'items': <Map<String, dynamic>>[],
            },
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('PO-FRESH-143'), findsOneWidget);
      expect(find.textContaining('PO-STALE-11'), findsNothing);
    },
  );

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

    await tester.tap(find.byKey(const Key('home-avatar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odjava'));
    await tester.pumpAndSettle();

    expect(find.text('Prijava'), findsOneWidget);
    expect(await harness.storage.readToken(), isNull);
  });

  testWidgets('warns before discarding unsaved purchase order form changes', (
    tester,
  ) async {
    const session = UserSession(
      token: 'saved-token',
      username: 'root',
      fullName: 'Mozart Operator',
      email: 'root@mozart.local',
    );
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
        }),
      ),
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
          articleName: 'Coffee beans',
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
      _testMaterialApp(
        home: PurchaseOrderFormScreen(
          session: session,
          repository: repository,
          initialOrder: initialOrder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('po-line-0-quantity')), '5');
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    expect(find.text('Odbaciti promjene?'), findsOneWidget);

    await tester.tap(find.text('Nastavi uredjivati'));
    await tester.pumpAndSettle();
    expect(find.text('Uredi narudžbu'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odbaci promjene'));
    await tester.pumpAndSettle();

    expect(find.text('Uredi narudžbu'), findsNothing);
  });

  testWidgets('warns before discarding unsaved warehouse receipt changes', (
    tester,
  ) async {
    const session = UserSession(
      token: 'saved-token',
      username: 'root',
      fullName: 'Mozart Operator',
      email: 'root@mozart.local',
    );
    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'GET /api/warehouses/': _jsonListResponse(<Map<String, dynamic>>[
            <String, dynamic>{'id': 9, 'name': 'Central Warehouse'},
          ]),
        }),
      ),
    );
    const order = PurchaseOrder(
      id: 88,
      reference: 'PO-88',
      supplierId: 2,
      status: 'sent',
      statusLabel: 'Poslana',
      supplierName: 'Blue Harbor Supply',
      paymentTypeId: 5,
      paymentTypeName: 'Virman',
      totalAmount: 120,
      currency: 'EUR',
      orderedAt: null,
      lines: <PurchaseOrderLine>[
        PurchaseOrderLine(
          id: 11,
          articleId: 77,
          articleName: 'Coffee beans',
          unitOfMeasureId: 1,
          unitName: 'kg',
          baseGroup: '',
          quantity: 10,
          receivedQuantity: 0,
          remainingQuantity: 10,
          unitPrice: 12,
        ),
      ],
    );

    await tester.pumpWidget(
      _testMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PurchaseOrderReceiptScreen(
                        order: order,
                        session: session,
                        repository: repository,
                      ),
                    ),
                  );
                },
                child: const Text('Otvori zaprimanje'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Otvori zaprimanje'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('po-receipt-invoice-code')),
      'INV-2026-001',
    );
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    expect(find.text('Odbaciti promjene?'), findsOneWidget);

    await tester.tap(find.text('Nastavi uredjivati'));
    await tester.pumpAndSettle();
    expect(find.text('Zaprimanje robe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odbaci promjene'));
    await tester.pumpAndSettle();

    expect(find.text('Zaprimanje robe'), findsNothing);
    expect(find.text('Otvori zaprimanje'), findsOneWidget);
  });

  testWidgets('warns before discarding unsaved price audit changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'GET /api/purchase-orders/2049/': _jsonResponse(<String, dynamic>{
            'id': 2049,
            'reference': 'PO-2049',
            'supplier_name': 'Blue Harbor Supply',
            'status': 'sent',
            'status_display': 'Poslana',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-02T11:30:00Z',
            'currency': 'EUR',
            'total_net': '96.00',
            'total_gross': '120.00',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 8,
                'artikl': 77,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'received_quantity': '0.0000',
                'remaining_quantity': '10.0000',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '12.00',
                'base_group': '',
              },
            ],
          }),
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
      _testMaterialApp(
        home: PurchaseOrderDetailScreen(
          orderId: 2049,
          session: session,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Korigiraj cijenu'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Korigiraj cijenu'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('po-price-audit-price')),
      '13,50',
    );
    await tester.tap(find.text('Odustani'));
    await tester.pumpAndSettle();

    expect(find.text('Odbaciti promjene?'), findsOneWidget);

    await tester.tap(find.text('Nastavi uredjivati'));
    await tester.pumpAndSettle();
    expect(find.text('Korekcija cijene'), findsOneWidget);

    await tester.tap(find.text('Odustani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odbaci promjene'));
    await tester.pumpAndSettle();

    expect(find.text('Korekcija cijene'), findsNothing);
  });

  test(
    'uses backend logout invalidation when a logout endpoint is configured',
    () async {
      ApiRequest? capturedRequest;
      final storage = InMemoryAuthStorage();
      await storage.saveToken('saved-token');
      final repository = AuthRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'POST /api/logout/': (ApiRequest request) {
              capturedRequest = request;
              return const _FakeResponse(statusCode: 204, body: '');
            },
          }),
        ),
        storage: storage,
        logoutPath: '/api/logout/',
      );

      await repository.logout(authToken: 'saved-token');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.headers['Authorization'], 'Token saved-token');
      expect(await storage.readToken(), isNull);
    },
  );

  test(
    'keeps local sign-out predictable when backend logout invalidation fails',
    () async {
      final storage = InMemoryAuthStorage();
      await storage.saveToken('saved-token');
      final repository = AuthRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'POST /api/logout/': const _FakeResponse(
              statusCode: 503,
              body: '{"detail":"Service unavailable"}',
            ),
          }),
        ),
        storage: storage,
        logoutPath: '/api/logout/',
      );

      await repository.logout(authToken: 'saved-token');

      expect(await storage.readToken(), isNull);
    },
  );

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

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-SEND').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Detalji narudžbe'), findsOneWidget);
    expect(find.text('Pošalji narudžbu'), findsOneWidget);

    await tester.tap(find.text('Pošalji narudžbu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Narudžba je uspješno poslana.'), findsOneWidget);
    expect(find.text('Pošalji narudžbu'), findsNothing);
    expect(find.text('Poslana'), findsWidgets);
  });

  testWidgets('changes created purchase order to confirmed from detail modal', (
    tester,
  ) async {
    ApiRequest? capturedStatusRequest;
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
              'id': 35,
              'reference': 'PO-CONFIRM',
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
              'id': 35,
              'reference': 'PO-CONFIRM',
              'supplier_name': 'Adriatic Trade',
              'status': 'confirmed',
              'status_display': 'Potvrđena',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ]),
        ],
        'GET /api/purchase-orders/35/': _jsonResponse(<String, dynamic>{
          'id': 35,
          'reference': 'PO-CONFIRM',
          'supplier': 2,
          'supplier_name': 'Adriatic Trade',
          'status': 'created',
          'status_display': 'Kreirana',
          'payment_type': 5,
          'payment_type_name': 'Virman',
          'ordered_at': '2026-04-01T09:30:00Z',
          'currency': 'EUR',
          'total_net': '120.00',
          'total_gross': '145.50',
          'items': <Map<String, dynamic>>[],
        }),
        'POST /api/purchase-orders/35/status/': (ApiRequest request) {
          capturedStatusRequest = request;
          return _jsonResponse(<String, dynamic>{
            'id': 35,
            'reference': 'PO-CONFIRM',
            'supplier': 2,
            'supplier_name': 'Adriatic Trade',
            'status': 'confirmed',
            'status_display': 'Potvrđena',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'currency': 'EUR',
            'total_net': '120.00',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[],
          });
        },
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(_navigationDestinationFinder('Narudžbe'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('PO-CONFIRM').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('po-detail-change-status')), findsOneWidget);
    expect(find.text('Zaprimanje robe'), findsNothing);

    await tester.tap(find.byKey(const Key('po-detail-change-status')));
    await tester.pumpAndSettle();

    expect(find.text('Promijeni status u Potvrđena'), findsOneWidget);
    expect(find.textContaining('potvrđeni status'), findsOneWidget);

    await tester.tap(find.byKey(const Key('po-status-change-confirm')));
    await tester.pump();
    await tester.pumpAndSettle();

    final body =
        jsonDecode(capturedStatusRequest!.body!) as Map<String, dynamic>;
    expect(body['status'], 'confirmed');
    expect(find.text('Narudžba je uspješno potvrđena.'), findsOneWidget);
    expect(find.text('Potvrđena'), findsWidgets);
    expect(find.byKey(const Key('po-detail-change-status')), findsNothing);
  });

  testWidgets('shows confirm target for sent purchase order', (tester) async {
    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'GET /api/purchase-orders/36/': _jsonResponse(<String, dynamic>{
            'id': 36,
            'reference': 'PO-SENT',
            'supplier': 2,
            'supplier_name': 'Adriatic Trade',
            'status': 'sent',
            'status_display': 'Poslana',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'currency': 'EUR',
            'total_net': '120.00',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[],
          }),
        }),
      ),
    );

    await tester.pumpWidget(
      _testMaterialApp(
        home: PurchaseOrderDetailPane(
          orderId: 36,
          session: const UserSession(
            token: 'saved-token',
            username: 'root',
            fullName: 'Mozart Operator',
            email: 'root@mozart.local',
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('po-detail-change-status')), findsOneWidget);

    await tester.tap(find.byKey(const Key('po-detail-change-status')));
    await tester.pumpAndSettle();

    expect(find.text('Promijeni status u Potvrđena'), findsOneWidget);
    expect(find.byKey(const Key('po-status-change-confirm')), findsOneWidget);
  });

  testWidgets(
    'changes received purchase order to received_all from detail modal',
    (tester) async {
      ApiRequest? capturedStatusRequest;
      final repository = PurchaseOrderRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'GET /api/purchase-orders/37/': _jsonResponse(<String, dynamic>{
              'id': 37,
              'reference': 'PO-RECEIVED',
              'supplier': 2,
              'supplier_name': 'Adriatic Trade',
              'status': 'received',
              'status_display': 'Djelomično zaprimljena',
              'payment_type': 5,
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'currency': 'EUR',
              'total_net': '120.00',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 8,
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
            'POST /api/purchase-orders/37/status/': (ApiRequest request) {
              capturedStatusRequest = request;
              return _jsonResponse(<String, dynamic>{
                'id': 37,
                'reference': 'PO-RECEIVED',
                'supplier': 2,
                'supplier_name': 'Adriatic Trade',
                'status': 'received_all',
                'status_display': 'Sve stavke s narudžbe su zaprimljene',
                'payment_type': 5,
                'payment_type_name': 'Virman',
                'ordered_at': '2026-04-01T09:30:00Z',
                'currency': 'EUR',
                'total_net': '120.00',
                'total_gross': '145.50',
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 8,
                    'artikl': 77,
                    'artikl_name': 'Coffee beans',
                    'quantity': '10.0000',
                    'unit_of_measure': 1,
                    'unit_name': 'kg',
                    'price': '12.00',
                    'received_quantity': '10.0000',
                    'remaining_quantity': '0.0000',
                    'base_group': '',
                  },
                ],
              });
            },
          }),
        ),
      );

      await tester.pumpWidget(
        _testMaterialApp(
          home: PurchaseOrderDetailPane(
            orderId: 37,
            session: const UserSession(
              token: 'saved-token',
              username: 'root',
              fullName: 'Mozart Operator',
              email: 'root@mozart.local',
            ),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('po-detail-change-status')));
      await tester.pumpAndSettle();

      expect(find.text('Označi kao sve zaprimljeno'), findsOneWidget);
      expect(
        find.textContaining('Sve stavke s narudžbe su zaprimljene'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('po-status-change-confirm')));
      await tester.pump();
      await tester.pumpAndSettle();

      final body =
          jsonDecode(capturedStatusRequest!.body!) as Map<String, dynamic>;
      expect(body['status'], 'received_all');
      expect(
        find.text('Narudžba je označena kao sve zaprimljeno.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('po-detail-change-status')), findsNothing);
    },
  );

  testWidgets('shows backend error when status change fails', (tester) async {
    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'GET /api/purchase-orders/38/': _jsonResponse(<String, dynamic>{
            'id': 38,
            'reference': 'PO-ERROR',
            'supplier': 2,
            'supplier_name': 'Adriatic Trade',
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'currency': 'EUR',
            'total_net': '120.00',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[],
          }),
          'POST /api/purchase-orders/38/status/': _FakeResponse(
            statusCode: 400,
            body: jsonEncode(<String, dynamic>{
              'detail': 'Status transition is not allowed.',
            }),
          ),
        }),
      ),
    );

    await tester.pumpWidget(
      _testMaterialApp(
        home: PurchaseOrderDetailPane(
          orderId: 38,
          session: const UserSession(
            token: 'saved-token',
            username: 'root',
            fullName: 'Mozart Operator',
            email: 'root@mozart.local',
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-detail-change-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('po-status-change-confirm')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Status transition is not allowed.'), findsOneWidget);
    expect(find.byKey(const Key('po-detail-change-status')), findsOneWidget);
  });

  testWidgets('creates warehouse receipt and refreshes purchase order detail', (
    tester,
  ) async {
    ApiRequest? capturedReceiptRequest;
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
              'id': 34,
              'reference': 'PO-RECEIPT',
              'supplier_name': 'Adriatic Trade',
              'status': 'confirmed',
              'status_display': 'Potvrdena',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ]),
          _jsonListResponse(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 34,
              'reference': 'PO-RECEIPT',
              'supplier_name': 'Adriatic Trade',
              'status': 'received_all',
              'status_display': 'Sve stavke s narudzbe su zaprimljene',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ]),
        ],
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[],
        ),
        'GET /api/purchase-orders/34/': <_FakeResponse>[
          _jsonResponse(<String, dynamic>{
            'id': 34,
            'reference': 'PO-RECEIPT',
            'supplier': 2,
            'supplier_name': 'Adriatic Trade',
            'status': 'confirmed',
            'status_display': 'Potvrdena',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'currency': 'EUR',
            'total_net': '120.00',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 8,
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
          _jsonResponse(<String, dynamic>{
            'id': 34,
            'reference': 'PO-RECEIPT',
            'supplier': 2,
            'supplier_name': 'Adriatic Trade',
            'status': 'received_all',
            'status_display': 'Sve stavke s narudzbe su zaprimljene',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'currency': 'EUR',
            'total_net': '120.00',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 8,
                'artikl': 77,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '12.00',
                'received_quantity': '10.0000',
                'remaining_quantity': '0.0000',
                'base_group': '',
              },
            ],
          }),
        ],
        'GET /api/warehouses/': _jsonListResponse(<Map<String, dynamic>>[
          <String, dynamic>{'id': 3, 'name': 'Glavno skladiste'},
        ]),
        'POST /api/purchase-orders/34/warehouse-inputs/': (ApiRequest request) {
          capturedReceiptRequest = request;
          return _jsonResponse(<String, dynamic>{
            'warehouse_input': <String, dynamic>{'id': 55},
            'purchase_order': <String, dynamic>{'id': 34},
          });
        },
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Narudžbe').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-RECEIPT').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Zaprimanje robe'), findsOneWidget);

    await tester.tap(find.text('Zaprimanje robe'));
    await tester.pumpAndSettle();

    expect(find.text('Zaprimanje za PO-RECEIPT'), findsOneWidget);
    expect(find.text('Glavno skladiste'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('po-receipt-line-0-quantity')),
      '6',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('po-receipt-submit')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('po-receipt-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final body =
        jsonDecode(capturedReceiptRequest!.body!) as Map<String, dynamic>;
    expect(body['warehouse_id'], 3);
    expect((body['items'] as List).single['purchase_order_item_id'], 8);
    expect((body['items'] as List).single['received_quantity'], '6.0');

    expect(
      find.text('Zaprimanje robe je uspješno spremljeno.'),
      findsOneWidget,
    );
    expect(find.text('Sve stavke s narudzbe su zaprimljene'), findsWidgets);
    expect(find.text('Zaprimanje robe'), findsNothing);
  });

  testWidgets(
    'hides edit and price audit actions for fully received orders with receipt',
    (tester) async {
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
          'GET /api/mailbox/messages/': _jsonListResponse(
            <Map<String, dynamic>>[
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
          'GET /api/purchase-orders/': _jsonListResponse(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 350,
              'reference': 'PO-LOCKED',
              'supplier_name': 'Adriatic Trade',
              'status': 'received_all',
              'status_display': 'Sve stavke s narudzbe su zaprimljene',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-01T09:30:00Z',
              'total_gross': '145.50',
              'items': <Map<String, dynamic>>[],
            },
          ]),
          'GET /api/purchase-orders/?status=confirmed': _jsonListResponse(
            <Map<String, dynamic>>[],
          ),
          'GET /api/purchase-orders/?status=created&status=sent':
              _jsonListResponse(<Map<String, dynamic>>[]),
          'GET /api/purchase-orders/350/': _jsonResponse(<String, dynamic>{
            'id': 350,
            'reference': 'PO-LOCKED',
            'supplier': 2,
            'supplier_name': 'Adriatic Trade',
            'status': 'received_all',
            'status_display': 'Sve stavke s narudzbe su zaprimljene',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'currency': 'EUR',
            'total_net': '120.00',
            'total_gross': '145.50',
            'created_by': 'vbadzim',
            'primka_created': true,
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 8,
                'artikl': 77,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '12.00',
                'received_quantity': '10.0000',
                'remaining_quantity': '0.0000',
                'base_group': '',
              },
            ],
          }),
        },
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(_navigationDestinationFinder('Narudžbe'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('PO-LOCKED').first);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Coffee beans'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.widgetWithText(OutlinedButton, 'Uredi'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'Korigiraj cijenu'),
        findsNothing,
      );
      expect(find.text('Povijest statusa'), findsOneWidget);
      expect(find.text('Coffee beans'), findsOneWidget);
    },
  );

  testWidgets('updates purchase order item price and refreshes totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ApiRequest? capturedRequest;
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
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-02T11:30:00Z',
            'total_gross': '120.00',
            'total_net': '96.00',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'artikl': 77,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'received_quantity': '0.0000',
                'remaining_quantity': '10.0000',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '12.00',
              },
            ],
          },
        ]),
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 2048,
              'reference': 'PO-2048',
              'supplier_name': 'Blue Harbor Supply',
              'status': 'created',
              'status_display': 'Kreirana',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-02T11:30:00Z',
              'total_gross': '120.00',
              'items': <Map<String, dynamic>>[],
            },
          ],
        ),
        'GET /api/purchase-orders/2048/': <_FakeResponse>[
          _jsonResponse(<String, dynamic>{
            'id': 2048,
            'reference': 'PO-2048',
            'supplier': 2,
            'supplier_name': 'Blue Harbor Supply',
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-02T11:30:00Z',
            'currency': 'EUR',
            'total_net': '96.00',
            'total_gross': '120.00',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'artikl': 77,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'received_quantity': '0.0000',
                'remaining_quantity': '10.0000',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '12.00',
                'base_group': '',
              },
            ],
          }),
          _jsonResponse(<String, dynamic>{
            'id': 2048,
            'reference': 'PO-2048',
            'supplier': 2,
            'supplier_name': 'Blue Harbor Supply',
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-02T11:30:00Z',
            'currency': 'EUR',
            'total_net': '112.00',
            'total_gross': '140.00',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'artikl': 77,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'received_quantity': '0.0000',
                'remaining_quantity': '10.0000',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '14.00',
                'base_group': '',
              },
            ],
          }),
        ],
        'PATCH /api/purchase-order-items/7/price/': (ApiRequest request) {
          capturedRequest = request;
          return _jsonResponse(<String, dynamic>{
            'purchase_order_item_id': 7,
            'old_price': '12.00',
            'new_price': '14.00',
            'audit': <String, dynamic>{'reason': 'Supplier correction'},
            'po_totals': <String, dynamic>{
              'total_net': '112.00',
              'total_gross': '140.00',
            },
          });
        },
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Narudžbe').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-2048').first);
    await tester.pumpAndSettle();

    final auditButton = find.widgetWithText(OutlinedButton, 'Korigiraj cijenu');
    await tester.scrollUntilVisible(
      auditButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(auditButton);
    final auditButtonWidget = tester.widget<OutlinedButton>(auditButton);
    auditButtonWidget.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('po-price-audit-price')),
      '14,00',
    );
    await tester.enterText(
      find.byKey(const Key('po-price-audit-reason')),
      'Supplier correction',
    );
    await tester.tap(find.byKey(const Key('po-price-audit-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
    expect(body['price'], '14.00');
    expect(body['currency'], 'EUR');
    expect(body['reason'], 'Supplier correction');

    expect(find.textContaining('EUR 140,00'), findsWidgets);
    expect(find.textContaining('EUR 14,00'), findsWidgets);
  });

  testWidgets('shows backend validation error when item price audit fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            'id': 2049,
            'reference': 'PO-2049',
            'supplier_name': 'Blue Harbor Supply',
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-02T11:30:00Z',
            'total_gross': '120.00',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 8,
                'artikl': 77,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'received_quantity': '0.0000',
                'remaining_quantity': '10.0000',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '12.00',
              },
            ],
          },
        ]),
        'GET /api/purchase-orders/?status=created': _jsonListResponse(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 2049,
              'reference': 'PO-2049',
              'supplier_name': 'Blue Harbor Supply',
              'status': 'created',
              'status_display': 'Kreirana',
              'payment_type_name': 'Virman',
              'ordered_at': '2026-04-02T11:30:00Z',
              'total_gross': '120.00',
              'items': <Map<String, dynamic>>[],
            },
          ],
        ),
        'GET /api/purchase-orders/2049/': _jsonResponse(<String, dynamic>{
          'id': 2049,
          'reference': 'PO-2049',
          'supplier': 2,
          'supplier_name': 'Blue Harbor Supply',
          'status': 'created',
          'status_display': 'Kreirana',
          'payment_type': 5,
          'payment_type_name': 'Virman',
          'ordered_at': '2026-04-02T11:30:00Z',
          'currency': 'EUR',
          'total_net': '96.00',
          'total_gross': '120.00',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 8,
              'artikl': 77,
              'artikl_name': 'Coffee beans',
              'quantity': '10.0000',
              'received_quantity': '0.0000',
              'remaining_quantity': '10.0000',
              'unit_of_measure': 1,
              'unit_name': 'kg',
              'price': '12.00',
              'base_group': '',
            },
          ],
        }),
        'PATCH /api/purchase-order-items/8/price/': _FakeResponse(
          statusCode: 400,
          body: jsonEncode(<String, dynamic>{
            'reason': <String>['Reason is required for this audit action.'],
          }),
        ),
      },
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Narudžbe').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-2049').first);
    await tester.pumpAndSettle();

    final auditButton = find.widgetWithText(OutlinedButton, 'Korigiraj cijenu');
    await tester.scrollUntilVisible(
      auditButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(auditButton);
    final auditButtonWidget = tester.widget<OutlinedButton>(auditButton);
    auditButtonWidget.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('po-price-audit-price')),
      '13,50',
    );
    await tester.enterText(
      find.byKey(const Key('po-price-audit-reason')),
      'Supplier mismatch',
    );
    await tester.tap(find.byKey(const Key('po-price-audit-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('EUR 120,00'), findsWidgets);
    expect(find.textContaining('EUR 12,00'), findsWidgets);
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
          'PATCH /api/purchase-orders/44/': (ApiRequest request) {
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
        _testMaterialApp(
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

  testWidgets('shows selected supplier name in edit purchase order form', (
    tester,
  ) async {
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
            <Map<String, dynamic>>[],
          ),
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
      lines: <PurchaseOrderLine>[],
    );

    await tester.pumpWidget(
      _testMaterialApp(
        home: PurchaseOrderFormScreen(
          session: session,
          repository: repository,
          initialOrder: initialOrder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final supplierField = tester.widget<TextFormField>(
      find.byKey(const Key('po-form-supplier')),
    );
    expect(supplierField.controller!.text, 'Blue Harbor Supply');
  });

  testWidgets(
    'preserves selected supplier when editing only payment type',
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
              <String, dynamic>{'id': 6, 'name': 'Gotovina'},
            ]),
            'GET /api/suppliers/2/artikli/': _jsonListResponse(
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 77,
                  'artikl_name': 'Coffee beans',
                  'unit_of_measure': 1,
                  'unit_name': 'kg',
                  'price': '13.00',
                },
              ],
            ),
            'PATCH /api/purchase-orders/44/': (ApiRequest request) {
              capturedRequest = request;
              return _jsonResponse(<String, dynamic>{
                'id': 44,
                'reference': 'PO-EDIT',
                'supplier': 2,
                'supplier_name': 'Blue Harbor Supply',
                'status': 'created',
                'status_display': 'Kreirana',
                'payment_type': 6,
                'payment_type_name': 'Gotovina',
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
            articleName: 'Coffee beans',
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
        _testMaterialApp(
          home: PurchaseOrderFormScreen(
            session: session,
            repository: repository,
            initialOrder: initialOrder,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('po-form-payment-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gotovina').last);
      await tester.pumpAndSettle();

      final supplierField = tester.widget<TextFormField>(
        find.byKey(const Key('po-form-supplier')),
      );
      expect(supplierField.controller!.text, 'Blue Harbor Supply');

      await tester.scrollUntilVisible(
        find.byKey(const Key('po-form-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('po-form-save')));
      await tester.pumpAndSettle();

      final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
      expect(body['supplier'], 2);
      expect(body['payment_type'], 6);
      expect(find.textContaining('supplier:'), findsNothing);
    },
  );

  testWidgets(
    'preserves initial supplier outside lookup list when editing purchase order',
    (tester) async {
      ApiRequest? capturedRequest;
      final repository = PurchaseOrderRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 9, 'name': 'Coffee Logistics'},
            ]),
            'GET /api/payment-types/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 5, 'name': 'Virman'},
              <String, dynamic>{'id': 6, 'name': 'Gotovina'},
            ]),
            'GET /api/suppliers/2/artikli/': _jsonListResponse(
              <Map<String, dynamic>>[],
            ),
            'PATCH /api/purchase-orders/44/': (ApiRequest request) {
              capturedRequest = request;
              return _jsonResponse(<String, dynamic>{
                'id': 44,
                'reference': 'PO-EDIT',
                'supplier': 2,
                'supplier_name': 'Blue Harbor Supply',
                'status': 'created',
                'status_display': 'Kreirana',
                'payment_type': 6,
                'payment_type_name': 'Gotovina',
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
        _testMaterialApp(
          home: PurchaseOrderFormScreen(
            session: session,
            repository: repository,
            initialOrder: initialOrder,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final supplierField = tester.widget<TextFormField>(
        find.byKey(const Key('po-form-supplier')),
      );
      expect(supplierField.controller!.text, 'Blue Harbor Supply');

      await tester.tap(find.byKey(const Key('po-form-payment-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gotovina').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('po-form-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('po-form-save')));
      await tester.pumpAndSettle();

      final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
      expect(body['supplier'], 2);
      expect(body['payment_type'], 6);
    },
  );

  testWidgets(
    'resolves missing supplier id from supplier lookup when editing purchase order',
    (tester) async {
      ApiRequest? capturedRequest;
      final repository = PurchaseOrderRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 2, 'name': 'Koktel Ugostiteljstvo d.o.o.'},
            ]),
            'GET /api/payment-types/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 5, 'name': 'American'},
              <String, dynamic>{'id': 6, 'name': 'Gotovina'},
            ]),
            'GET /api/suppliers/2/artikli/': _jsonListResponse(
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 77,
                  'artikl_name': 'Rucnici Kuhinjski Teta Violeta 2/1',
                  'unit_of_measure': 1,
                  'unit_name': 'Paket',
                  'price': '2.29',
                },
              ],
            ),
            'PATCH /api/purchase-orders/143/': (ApiRequest request) {
              capturedRequest = request;
              return _jsonResponse(<String, dynamic>{
                'id': 143,
                'reference': '143',
                'supplier': 2,
                'supplier_name': 'Koktel Ugostiteljstvo d.o.o.',
                'status': 'created',
                'status_display': 'Kreirana',
                'payment_type': 6,
                'payment_type_name': 'Gotovina',
                'ordered_at': '2026-04-01T00:00:00Z',
                'total_gross': '2.29',
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 7,
                    'artikl': 77,
                    'artikl_name': 'Rucnici Kuhinjski Teta Violeta 2/1',
                    'quantity': '1.0000',
                    'unit_of_measure': 1,
                    'unit_name': 'Paket',
                    'price': '2.29',
                    'received_quantity': '0.0000',
                    'remaining_quantity': '1.0000',
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
        id: 143,
        reference: '143',
        supplierId: 0,
        status: 'created',
        statusLabel: 'Kreirana',
        supplierName: 'Koktel Ugostiteljstvo d.o.o.',
        paymentTypeId: 5,
        paymentTypeName: 'American',
        totalAmount: 2.29,
        currency: 'EUR',
        orderedAt: null,
        lines: <PurchaseOrderLine>[
          PurchaseOrderLine(
            id: 7,
            articleId: 77,
            articleName: 'Rucnici Kuhinjski Teta Violeta 2/1',
            unitOfMeasureId: 1,
            unitName: 'Paket',
            baseGroup: '',
            quantity: 1,
            receivedQuantity: 0,
            remainingQuantity: 1,
            unitPrice: 2.29,
          ),
        ],
      );

      await tester.pumpWidget(
        _testMaterialApp(
          home: PurchaseOrderFormScreen(
            session: session,
            repository: repository,
            initialOrder: initialOrder,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('po-form-payment-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gotovina').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('po-form-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('po-form-save')));
      await tester.pumpAndSettle();

      final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
      expect(body['supplier'], 2);
      expect(body['payment_type'], 6);
    },
  );

  testWidgets(
    'requires re-selecting supplier when autocomplete text is edited',
    (tester) async {
      final repository = PurchaseOrderRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'GET /api/suppliers/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 2, 'name': 'Blue Harbor Supply'},
              <String, dynamic>{'id': 3, 'name': 'Coffee Logistics'},
            ]),
            'GET /api/payment-types/': _jsonListResponse(<Map<String, dynamic>>[
              <String, dynamic>{'id': 5, 'name': 'Virman'},
            ]),
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
        _testMaterialApp(
          home: PurchaseOrderFormScreen(
            session: session,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('po-form-supplier')),
        'Blue Harbor',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Harbor Supply').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('po-form-supplier')),
        'Blue Harbor x',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('po-form-save')));
      await tester.pumpAndSettle();

      expect(find.text('Odaberite dobavljača iz popisa.'), findsOneWidget);
      expect(find.text('Dodaj stavku'), findsNothing);
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
            'PATCH /api/purchase-orders/44/': (ApiRequest request) {
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

  testWidgets('hides receipt action for created purchase order', (
    tester,
  ) async {
    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'GET /api/purchase-orders/361/': _jsonResponse(<String, dynamic>{
            'id': 361,
            'reference': 'PO-CREATED',
            'supplier': 2,
            'supplier_name': 'Adriatic Trade',
            'status': 'created',
            'status_display': 'Kreirana',
            'payment_type': 5,
            'payment_type_name': 'Virman',
            'ordered_at': '2026-04-01T09:30:00Z',
            'currency': 'EUR',
            'total_net': '120.00',
            'total_gross': '145.50',
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 8,
                'artikl': 77,
                'artikl_name': 'Coffee beans',
                'quantity': '10.0000',
                'unit_of_measure': 1,
                'unit_name': 'kg',
                'price': '12.00',
                'received_quantity': '0.0000',
                'remaining_quantity': '10.0000',
                'base_group': '',
              },
            ],
          }),
        }),
      ),
    );

    await tester.pumpWidget(
      _testMaterialApp(
        home: PurchaseOrderDetailPane(
          orderId: 361,
          session: const UserSession(
            token: 'saved-token',
            username: 'root',
            fullName: 'Mozart Operator',
            email: 'root@mozart.local',
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pošalji narudžbu'), findsOneWidget);
    expect(find.text('Promijeni status'), findsOneWidget);
    expect(find.text('Uredi'), findsOneWidget);
    expect(find.text('Zaprimanje robe'), findsNothing);
  });

  test('updates purchase order status with expected payload mapping', () async {
    ApiRequest? capturedRequest;
    final repository = PurchaseOrderRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test',
        transport: _FakeTransport(<String, dynamic>{
          'POST /api/purchase-orders/44/status/': (ApiRequest request) {
            capturedRequest = request;
            return _jsonResponse(<String, dynamic>{
              'id': 44,
              'reference': 'PO-EDIT',
              'supplier': 2,
              'supplier_name': 'Blue Harbor Supply',
              'status': 'confirmed',
              'status_display': 'Potvrđena',
              'payment_type': 6,
              'payment_type_name': 'Karticno',
              'ordered_at': '2026-04-05T09:30:00Z',
              'total_gross': '130.00',
              'items': <Map<String, dynamic>>[],
            });
          },
        }),
      ),
    );

    final order = await repository.updatePurchaseOrderStatus(
      orderId: 44,
      status: 'confirmed',
      authToken: 'saved-token',
    );

    final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
    expect(body['status'], 'confirmed');
    expect(order.status, 'confirmed');
    expect(order.statusLabel, 'Potvrđena');
  });

  test(
    'updates purchase order status to received_all with expected payload mapping',
    () async {
      ApiRequest? capturedRequest;
      final repository = PurchaseOrderRepository(
        apiClient: ApiClient(
          baseUrl: 'https://example.test',
          transport: _FakeTransport(<String, dynamic>{
            'POST /api/purchase-orders/45/status/': (ApiRequest request) {
              capturedRequest = request;
              return _jsonResponse(<String, dynamic>{
                'id': 45,
                'reference': 'PO-RECEIVED',
                'supplier': 2,
                'supplier_name': 'Blue Harbor Supply',
                'status': 'received_all',
                'status_display': 'Sve stavke s narudžbe su zaprimljene',
                'payment_type': 6,
                'payment_type_name': 'Karticno',
                'ordered_at': '2026-04-05T09:30:00Z',
                'total_gross': '130.00',
                'items': <Map<String, dynamic>>[],
              });
            },
          }),
        ),
      );

      final order = await repository.updatePurchaseOrderStatus(
        orderId: 45,
        status: 'received_all',
        authToken: 'saved-token',
      );

      final body = jsonDecode(capturedRequest!.body!) as Map<String, dynamic>;
      expect(body['status'], 'received_all');
      expect(order.status, 'received_all');
      expect(order.statusLabel, 'Sve stavke s narudžbe su zaprimljene');
    },
  );

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
          slowConnectionMessage,
        ),
      ),
    );
  });

  test('maps socket failures to connectivity api exception', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      transport: _SocketFailureTransport(),
    );

    await expectLater(
      () => client.getJson('/api/purchase-orders/', authToken: 'saved-token'),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.message,
              'message',
              connectivityIssueMessage,
            )
            .having(
              (error) => error.isConnectivityIssue,
              'isConnectivityIssue',
              true,
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
      _testMaterialApp(
        home: PurchaseOrderFormScreen(session: session, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('po-form-supplier')),
      'Blue Harbor',
    );
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

  final authRepository = AuthRepository(apiClient: apiClient, storage: storage);
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
      child: _testMaterialApp(home: const AppView()),
    ),
  );

  return _Harness(app: app, controller: sessionController, storage: storage);
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
    body: jsonEncode(<String, dynamic>{'count': count, 'results': results}),
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

MaterialApp _testMaterialApp({required Widget home}) {
  return MaterialApp(
    theme: buildMozartTheme(),
    locale: const Locale('hr', 'HR'),
    supportedLocales: const [Locale('hr', 'HR'), Locale('en', 'US')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: home,
  );
}

Finder _navigationDestinationFinder(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

class _FakeResponse {
  const _FakeResponse({required this.statusCode, required this.body});

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
    final candidate =
        exactCandidate ??
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

class _SocketFailureTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) {
    throw SocketException('Network is unreachable');
  }
}

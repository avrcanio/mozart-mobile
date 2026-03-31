import '../../domain/mail_message.dart';
import '../http/api_client.dart';

class MailboxRepository {
  MailboxRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Uri get mailboxEndpoint => _apiClient.endpoint('/api/mailbox/');

  Future<List<MailMessage>> fetchMessages() async {
    return <MailMessage>[
      MailMessage(
        id: 'mail-301',
        subject: 'Warehouse receipt pending confirmation',
        sender: 'Nabava',
        preview: 'Please review the Split inbound receipt before noon.',
        receivedAt: DateTime(2026, 3, 31, 9, 18),
        hasAttachments: true,
      ),
      MailMessage(
        id: 'mail-302',
        subject: 'Supplier updated delivery timeline',
        sender: 'Logistics',
        preview: 'Vendor ETA changed for PO-2048 and PO-2052.',
        receivedAt: DateTime(2026, 3, 30, 15, 42),
        hasAttachments: false,
      ),
      MailMessage(
        id: 'mail-303',
        subject: 'Price audit requires approval',
        sender: 'Finance',
        preview: 'A price delta above threshold was detected.',
        receivedAt: DateTime(2026, 3, 29, 11, 6),
        hasAttachments: true,
      ),
    ];
  }
}

import '../../domain/mail_message.dart';
import '../http/api_client.dart';
import 'models/mail_message_dto.dart';

class MailboxRepository {
  MailboxRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Uri get messagesEndpoint => _apiClient.endpoint('/api/mailbox/messages/');

  Uri detailEndpoint(int id) => _apiClient.endpoint('/api/mailbox/messages/$id/');

  Future<List<MailMessage>> fetchMessages({
    required String authToken,
  }) async {
    final jsonList = await _apiClient.getJsonList(
      '/api/mailbox/messages/',
      authToken: authToken,
    );
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(MailMessageDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();
  }
}

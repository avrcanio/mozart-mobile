import '../../domain/mail_message.dart';
import '../../domain/mail_message_detail.dart';
import '../http/api_client.dart';
import 'models/mail_message_detail_dto.dart';
import 'models/mail_message_dto.dart';

class MailboxRepository {
  MailboxRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Uri get messagesEndpoint => _apiClient.endpoint(path: '/api/mailbox/messages/');

  Uri detailEndpoint(int id) =>
      _apiClient.endpoint(path: '/api/mailbox/messages/$id/');

  Future<MailboxPage> fetchMessagesPage({
    required String authToken,
    int page = 1,
  }) async {
    final queryParameters = <String, String>{
      if (page > 1) 'page': '$page',
    };
    final json = await _apiClient.getJson(
      '/api/mailbox/messages/',
      authToken: authToken,
      queryParameters: queryParameters,
    );
    final results = (json['results'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MailMessageDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList();

    return MailboxPage(
      count: _asCount(json['count'], fallback: results.length),
      messages: results,
    );
  }

  Future<List<MailMessage>> fetchMessages({
    required String authToken,
    int page = 1,
  }) async {
    final mailboxPage = await fetchMessagesPage(
      authToken: authToken,
      page: page,
    );
    return mailboxPage.messages;
  }

  Future<MailMessageDetail> fetchMessageDetail({
    required int id,
    required String authToken,
  }) async {
    final json = await _apiClient.getJson(
      '/api/mailbox/messages/$id/',
      authToken: authToken,
    );
    return MailMessageDetailDto.fromJson(json).toDomain();
  }

  static int _asCount(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }
}

class MailboxPage {
  const MailboxPage({
    required this.count,
    required this.messages,
  });

  final int count;
  final List<MailMessage> messages;
}

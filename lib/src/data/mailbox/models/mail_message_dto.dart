import '../../../domain/mail_message.dart';

class MailMessageDto {
  const MailMessageDto({
    required this.id,
    required this.subject,
    required this.sender,
    required this.preview,
    required this.receivedAt,
    required this.attachments,
    required this.isRead,
  });

  final int id;
  final String subject;
  final String sender;
  final String preview;
  final DateTime? receivedAt;
  final List<String> attachments;
  final bool isRead;

  factory MailMessageDto.fromJson(Map<String, dynamic> json) {
    final attachmentValues = json['attachments'];
    final attachments = attachmentValues is List
        ? attachmentValues.map((item) => item.toString()).toList()
        : <String>[];

    return MailMessageDto(
      id: _asInt(json['id']),
      subject: (json['subject'] ?? '').toString(),
      sender: (json['sender_name'] ??
              json['sender'] ??
              json['from'] ??
              'Unknown sender')
          .toString(),
      preview: (json['preview'] ?? json['body_preview'] ?? '').toString(),
      receivedAt: _asDateTime(json['received_at'] ?? json['created_at']),
      attachments: attachments,
      isRead: (json['is_read'] ?? false) == true,
    );
  }

  MailMessage toDomain() {
    return MailMessage(
      id: id,
      subject: subject,
      sender: sender,
      preview: preview,
      receivedAt: receivedAt,
      attachments: attachments,
      isRead: isRead,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}

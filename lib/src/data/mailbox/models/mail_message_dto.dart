import '../../../domain/mail_message.dart';

class MailMessageDto {
  const MailMessageDto({
    required this.id,
    required this.subject,
    required this.fromEmail,
    required this.preview,
    required this.sentAt,
    required this.attachmentCount,
    required this.isRead,
  });

  final int id;
  final String subject;
  final String fromEmail;
  final String preview;
  final DateTime? sentAt;
  final int attachmentCount;
  final bool isRead;

  factory MailMessageDto.fromJson(Map<String, dynamic> json) {
    final preview = (json['preview'] ??
            json['body_preview'] ??
            json['body_text'] ??
            json['to_emails'] ??
            '')
        .toString()
        .trim();
    final subject = (json['subject'] ?? '').toString().trim();
    final fromEmail = (json['from_email'] ??
            json['sender_name'] ??
            json['sender'] ??
            json['from'] ??
            '')
        .toString()
        .trim();
    final attachmentsCount = _asAttachmentCount(
      json['attachments_count'],
      json['attachments'],
    );

    return MailMessageDto(
      id: _asInt(json['id']),
      subject: subject.isEmpty ? _fallbackSubject(preview) : subject,
      fromEmail: fromEmail.isEmpty ? 'Unknown sender' : fromEmail,
      preview: preview,
      sentAt: _asDateTime(json['sent_at'] ?? json['received_at']),
      attachmentCount: attachmentsCount,
      isRead: (json['is_read'] ?? false) == true,
    );
  }

  MailMessage toDomain() {
    return MailMessage(
      id: id,
      subject: subject,
      fromEmail: fromEmail,
      preview: preview,
      sentAt: sentAt,
      attachmentCount: attachmentCount,
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

  static int _asAttachmentCount(dynamic countValue, dynamic attachmentsValue) {
    if (countValue is int) {
      return countValue;
    }
    final parsed = int.tryParse((countValue ?? '').toString());
    if (parsed != null) {
      return parsed;
    }
    if (attachmentsValue is List) {
      return attachmentsValue.length;
    }
    return 0;
  }

  static String _fallbackSubject(String preview) {
    if (preview.isNotEmpty) {
      return preview.length > 48 ? '${preview.substring(0, 48)}...' : preview;
    }
    return 'Bez naslova';
  }
}

import '../../../domain/mail_message_detail.dart';

class MailMessageDetailDto {
  const MailMessageDetailDto({
    required this.id,
    required this.subject,
    required this.fromEmail,
    required this.toEmails,
    required this.ccEmails,
    required this.sentAt,
    required this.bodyText,
    required this.bodyHtml,
    required this.attachments,
  });

  final int id;
  final String subject;
  final String fromEmail;
  final String toEmails;
  final String ccEmails;
  final DateTime? sentAt;
  final String bodyText;
  final String bodyHtml;
  final List<MailAttachmentDto> attachments;

  factory MailMessageDetailDto.fromJson(Map<String, dynamic> json) {
    final subject = (json['subject'] ?? '').toString().trim();
    final bodyText = (json['body_text'] ?? '').toString();
    final attachmentsJson = json['attachments'];

    return MailMessageDetailDto(
      id: _asInt(json['id']),
      subject: subject.isEmpty ? _fallbackSubject(bodyText) : subject,
      fromEmail: _readString(
        json,
        const ['from_email', 'sender_name', 'sender', 'from'],
        fallback: 'Unknown sender',
      ),
      toEmails: _readString(
        json,
        const ['to_emails', 'recipients', 'to'],
      ),
      ccEmails: _readString(
        json,
        const ['cc_emails', 'cc'],
      ),
      sentAt: _asDateTime(json['sent_at'] ?? json['received_at']),
      bodyText: bodyText,
      bodyHtml: (json['body_html'] ?? '').toString(),
      attachments: attachmentsJson is List
          ? attachmentsJson
                .whereType<Map<String, dynamic>>()
                .map(MailAttachmentDto.fromJson)
                .toList()
          : const <MailAttachmentDto>[],
    );
  }

  MailMessageDetail toDomain() {
    return MailMessageDetail(
      id: id,
      subject: subject,
      fromEmail: fromEmail,
      toEmails: toEmails,
      ccEmails: ccEmails,
      sentAt: sentAt,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      attachments: attachments.map((attachment) => attachment.toDomain()).toList(),
    );
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = (json[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
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

  static String _fallbackSubject(String bodyText) {
    final normalized = bodyText.trim();
    if (normalized.isEmpty) {
      return 'Bez naslova';
    }
    return normalized.length > 48
        ? '${normalized.substring(0, 48)}...'
        : normalized;
  }
}

class MailAttachmentDto {
  const MailAttachmentDto({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.size,
    required this.fileUrl,
  });

  final int id;
  final String filename;
  final String contentType;
  final int size;
  final String fileUrl;

  factory MailAttachmentDto.fromJson(Map<String, dynamic> json) {
    return MailAttachmentDto(
      id: MailMessageDetailDto._asInt(json['id']),
      filename: (json['filename'] ?? 'attachment').toString().trim(),
      contentType: (json['content_type'] ?? '').toString().trim(),
      size: MailMessageDetailDto._asInt(json['size']),
      fileUrl: (json['file_url'] ?? json['url'] ?? '').toString().trim(),
    );
  }

  MailAttachment toDomain() {
    return MailAttachment(
      id: id,
      filename: filename.isEmpty ? 'attachment' : filename,
      contentType: contentType,
      size: size,
      fileUrl: fileUrl,
    );
  }
}

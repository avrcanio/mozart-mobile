class MailMessageDetail {
  const MailMessageDetail({
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
  final List<MailAttachment> attachments;

  bool get hasRecipients => toEmails.isNotEmpty || ccEmails.isNotEmpty;

  String get bodyContent {
    if (bodyText.trim().isNotEmpty) {
      return bodyText.trim();
    }
    if (bodyHtml.trim().isNotEmpty) {
      return bodyHtml.trim();
    }
    return 'Poruka nema dostupnog sadrzaja.';
  }
}

class MailAttachment {
  const MailAttachment({
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

  bool get hasLink => fileUrl.isNotEmpty;
}

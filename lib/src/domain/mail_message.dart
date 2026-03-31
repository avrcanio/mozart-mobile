class MailMessage {
  const MailMessage({
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

  bool get hasAttachments => attachmentCount > 0;
}

class MailMessage {
  const MailMessage({
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

  bool get hasAttachments => attachments.isNotEmpty;
}

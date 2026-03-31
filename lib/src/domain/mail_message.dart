class MailMessage {
  const MailMessage({
    required this.id,
    required this.subject,
    required this.sender,
    required this.preview,
    required this.receivedAt,
    required this.hasAttachments,
  });

  final String id;
  final String subject;
  final String sender;
  final String preview;
  final DateTime receivedAt;
  final bool hasAttachments;
}

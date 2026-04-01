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
  bool get hasBodyText => bodyText.trim().isNotEmpty;
  bool get hasBodyHtml => bodyHtml.trim().isNotEmpty;
  String get renderableHtmlContent => _prepareRenderableHtml(bodyHtml);
  bool get hasRenderableHtml => renderableHtmlContent.trim().isNotEmpty;
  bool get hasDegradedHtmlFallback =>
      hasBodyHtml && !hasRenderableHtml && !isPlainTextBodyPrimary;
  bool get isPlainTextBodyPrimary => hasBodyText;

  String get bodyContent {
    if (hasRenderableHtml) {
      return '';
    }
    if (hasBodyText) {
      return bodyText.trim();
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

String _prepareRenderableHtml(String html) {
  final trimmed = html.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  var normalized = trimmed
      .replaceAll(RegExp(r'<!--\[if[\s\S]*?<!\[endif\]-->', caseSensitive: false), '')
      .replaceAll(RegExp(r'<\?xml[\s\S]*?\?>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<o:[^>]*>[\s\S]*?<\/o:[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<w:[^>]*>[\s\S]*?<\/w:[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<m:[^>]*>[\s\S]*?<\/m:[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<v:[^>]*>[\s\S]*?<\/v:[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<meta[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<link[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<title[^>]*>[\s\S]*?<\/title>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<head[^>]*>[\s\S]*?<\/head>', caseSensitive: false), '')
      .replaceAll(RegExp(r'@font-face\s*\{[\s\S]*?\}', caseSensitive: false), '')
      .replaceAll(RegExp(r'mso-[a-z\-]+:[^;"]+;?', caseSensitive: false), '');

  final bodyMatch = RegExp(
    r'<body[^>]*>([\s\S]*?)<\/body>',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (bodyMatch != null) {
    normalized = bodyMatch.group(1)?.trim() ?? normalized;
  }

  normalized = normalized
      .replaceAll(
        RegExp(r'\s+xmlns(:\w+)?="[^"]*"', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'\s+lang="[^"]*"', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'\s+class="[^"]*"', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'\s+style="[^"]*"', caseSensitive: false),
        '',
      )
      .trim();

  final hasMeaningfulHtml = RegExp(
    r'<(p|div|span|table|tr|td|ul|ol|li|img|a|br|strong|b|em|i|h[1-6])\b',
    caseSensitive: false,
  ).hasMatch(normalized);
  if (hasMeaningfulHtml) {
    return normalized;
  }

  final plainTextContent = normalized
      .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (plainTextContent.isNotEmpty) {
    final escapedText = plainTextContent
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '<p>$escapedText</p>';
  }

  return '';
}

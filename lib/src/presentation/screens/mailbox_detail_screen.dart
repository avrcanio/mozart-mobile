import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/mailbox/mailbox_repository.dart';
import '../../domain/mail_message_detail.dart';
import '../../domain/user_session.dart';
import '../mailbox_detail_controller.dart';

class MailboxDetailScreen extends StatelessWidget {
  const MailboxDetailScreen({
    required this.messageId,
    required this.session,
    required this.repository,
    this.attachmentLauncher = _launchAttachmentUrl,
    super.key,
  });

  final int messageId;
  final UserSession session;
  final MailboxRepository repository;
  final AttachmentLauncher attachmentLauncher;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji poruke'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: MailboxDetailPane(
            messageId: messageId,
            session: session,
            repository: repository,
            attachmentLauncher: attachmentLauncher,
          ),
        ),
      ),
    );
  }
}

class MailboxDetailPane extends StatefulWidget {
  const MailboxDetailPane({
    required this.messageId,
    required this.session,
    required this.repository,
    this.attachmentLauncher = _launchAttachmentUrl,
    this.showRefreshAction = true,
    super.key,
  });

  final int messageId;
  final UserSession session;
  final MailboxRepository repository;
  final AttachmentLauncher attachmentLauncher;
  final bool showRefreshAction;

  @override
  State<MailboxDetailPane> createState() => _MailboxDetailPaneState();
}

class _MailboxDetailPaneState extends State<MailboxDetailPane> {
  late final MailboxDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MailboxDetailController(repository: widget.repository);
    _load();
  }

  @override
  void didUpdateWidget(covariant MailboxDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      _load();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    _controller.load(id: widget.messageId, authToken: widget.session.token);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MailboxDetailState>(
      valueListenable: _controller,
      builder: (context, state, _) => Column(
        children: [
          if (widget.showRefreshAction)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _load,
                tooltip: 'Osvjezi',
                icon: const Icon(Icons.refresh),
              ),
            ),
          Expanded(
            child: _MailboxDetailBody(
              state: state,
              onRetry: _load,
              attachmentLauncher: widget.attachmentLauncher,
            ),
          ),
        ],
      ),
    );
  }
}

class _MailboxDetailBody extends StatelessWidget {
  const _MailboxDetailBody({
    required this.state,
    required this.onRetry,
    required this.attachmentLauncher,
  });

  final MailboxDetailState state;
  final VoidCallback onRetry;
  final AttachmentLauncher attachmentLauncher;

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('dd.MM.yyyy. HH:mm', 'hr_HR');

    if (state.isLoading && !state.hasContent) {
      return const _DetailStateCard(
        icon: Icons.mail_outline,
        title: 'Ucitavanje poruke',
        message: 'Pripremamo detalje odabrane poruke.',
      );
    }

    if (state.errorMessage != null && !state.hasContent) {
      return _DetailStateCard(
        icon: Icons.wifi_off_rounded,
        title: 'Detalji poruke nisu dostupni',
        message: state.errorMessage!,
        actionLabel: 'Pokusaj ponovno',
        onAction: onRetry,
      );
    }

    if (!state.hasContent) {
      return _DetailStateCard(
        icon: Icons.mark_email_read_outlined,
        title: 'Nema detalja za prikaz',
        message: 'Podaci o poruci trenutno nisu dostupni.',
        actionLabel: 'Osvjezi',
        onAction: onRetry,
      );
    }

    final message = state.message!;

    return ListView(
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              state.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.subject,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pregled posiljatelja, primatelja i sadrzaja poruke.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 14),
                _DetailRow(label: 'Od', value: message.fromEmail),
                if (message.toEmails.isNotEmpty)
                  _DetailRow(label: 'Za', value: message.toEmails),
                if (message.ccEmails.isNotEmpty)
                  _DetailRow(label: 'CC', value: message.ccEmails),
                _DetailRow(
                  label: 'Datum',
                  value: _formatDate(message.sentAt, dateTimeFormat),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sadrzaj poruke',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                if (message.hasRenderableHtml)
                  _MailHtmlContent(
                    html: message.renderableHtmlContent,
                    fallbackText: message.hasBodyText ? message.bodyText.trim() : null,
                  )
                else
                  _MailBodyFallback(message: message),
              ],
            ),
          ),
        ),
        if (message.attachments.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prilozi (${message.attachments.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  ...message.attachments.map(
                    (attachment) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AttachmentCard(
                        attachment: attachment,
                        attachmentLauncher: attachmentLauncher,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MailHtmlContent extends StatelessWidget {
  const _MailHtmlContent({
    required this.html,
    this.fallbackText,
  });

  final String html;
  final String? fallbackText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Html(
      data: html,
      shrinkWrap: true,
      onLinkTap: (url, attributes, element) async {
        final uri = url == null ? null : Uri.tryParse(url);
        if (uri == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link u poruci nije valjan.')),
            );
          }
          return;
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      style: {
        'html': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(theme.textTheme.bodyLarge?.fontSize ?? 16),
          lineHeight: const LineHeight(1.5),
          color: theme.colorScheme.onSurface,
        ),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        'p': Style(margin: Margins.only(bottom: 14)),
        'div': Style(margin: Margins.only(bottom: 10)),
        'ul': Style(margin: Margins.only(bottom: 14, left: 18)),
        'ol': Style(margin: Margins.only(bottom: 14, left: 18)),
        'li': Style(margin: Margins.only(bottom: 6)),
        'table': Style(
          margin: Margins.only(bottom: 14),
          backgroundColor: Colors.white.withValues(alpha: 0.72),
        ),
        'th': Style(
          padding: HtmlPaddings.all(10),
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          fontWeight: FontWeight.w700,
        ),
        'td': Style(
          padding: HtmlPaddings.all(10),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        'a': Style(
          color: theme.colorScheme.primary,
          textDecoration: TextDecoration.underline,
        ),
        'img': Style(
          width: Width(100, Unit.percent),
          margin: Margins.only(bottom: 12, top: 8),
        ),
      },
      extensions: [
        TagExtension(
          tagsToExtend: const {'img'},
          builder: (extensionContext) {
            final attributes = extensionContext.attributes;
            final source = attributes['src']?.trim() ?? '';
            final altText = attributes['alt']?.trim() ?? 'Slika iz poruke';
            if (source.isEmpty) {
              return _InlineHtmlNotice(label: altText);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  source,
                  fit: BoxFit.contain,
                  errorBuilder: (imageContext, error, stackTrace) =>
                      _InlineHtmlNotice(label: altText),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MailBodyFallback extends StatelessWidget {
  const _MailBodyFallback({required this.message});

  final MailMessageDetail message;

  @override
  Widget build(BuildContext context) {
    if (message.hasDegradedHtmlFallback) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HTML poruka nije bila dovoljno cista za bogatiji prikaz pa prikazujemo dostupni tekst.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(message.bodyContent),
        ],
      );
    }

    return SelectableText(message.bodyContent);
  }
}

class _InlineHtmlNotice extends StatelessWidget {
  const _InlineHtmlNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.attachmentLauncher,
  });

  final MailAttachment attachment;
  final AttachmentLauncher attachmentLauncher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attachment.filename,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (attachment.contentType.isNotEmpty)
            Text('Tip: ${attachment.contentType}'),
          if (attachment.size > 0) Text('Velicina: ${_formatBytes(attachment.size)}'),
          if (attachment.hasLink) ...[
            const SizedBox(height: 8),
            SelectableText(attachment.fileUrl),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _openAttachment(context),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Otvori prilog'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyAttachmentLink(context),
                  icon: const Icon(Icons.link),
                  label: const Text('Kopiraj link'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(attachment.fileUrl);
    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Link priloga nije valjan.')),
      );
      return;
    }

    final opened = await attachmentLauncher(uri);
    if (!context.mounted) {
      return;
    }

    if (opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Prilog se otvara u vanjskoj aplikaciji.')),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Prilog nije moguce otvoriti. Kopirajte link i pokusajte ponovno.',
        ),
      ),
    );
  }

  Future<void> _copyAttachmentLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: attachment.fileUrl));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link priloga je kopiran.')),
    );
  }
}

typedef AttachmentLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchAttachmentUrl(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _DetailStateCard extends StatelessWidget {
  const _DetailStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyLarge),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value, DateFormat formatter) {
  if (value == null) {
    return 'Bez datuma';
  }
  return formatter.format(value.toLocal());
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

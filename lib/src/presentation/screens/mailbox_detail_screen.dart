import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/mailbox/mailbox_repository.dart';
import '../../domain/mail_message_detail.dart';
import '../../domain/user_session.dart';
import '../mailbox_detail_controller.dart';

class MailboxDetailScreen extends StatelessWidget {
  const MailboxDetailScreen({
    required this.messageId,
    required this.session,
    required this.repository,
    super.key,
  });

  final int messageId;
  final UserSession session;
  final MailboxRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Detail'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: MailboxDetailPane(
            messageId: messageId,
            session: session,
            repository: repository,
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
    this.showRefreshAction = true,
    super.key,
  });

  final int messageId;
  final UserSession session;
  final MailboxRepository repository;
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
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ),
          Expanded(
            child: _MailboxDetailBody(
              state: state,
              onRetry: _load,
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
  });

  final MailboxDetailState state;
  final VoidCallback onRetry;

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
                  style: Theme.of(context).textTheme.headlineMedium,
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
                SelectableText(message.bodyContent),
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
                  'Prilozi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                if (message.attachments.isEmpty)
                  const Text('Poruka nema priloga.')
                else
                  ...message.attachments.map(
                    (attachment) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AttachmentCard(attachment: attachment),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.attachment});

  final MailAttachment attachment;

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
          ),
          const SizedBox(height: 8),
          if (attachment.contentType.isNotEmpty)
            Text('Tip: ${attachment.contentType}'),
          if (attachment.size > 0) Text('Velicina: ${_formatBytes(attachment.size)}'),
          if (attachment.hasLink) ...[
            const SizedBox(height: 8),
            SelectableText(attachment.fileUrl),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: attachment.fileUrl));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link priloga je kopiran.')),
                );
              },
              icon: const Icon(Icons.link),
              label: const Text('Kopiraj link'),
            ),
          ],
        ],
      ),
    );
  }
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

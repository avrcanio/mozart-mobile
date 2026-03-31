import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/purchase_orders/purchase_order_repository.dart';
import '../../domain/purchase_order.dart';
import '../../domain/user_session.dart';
import '../purchase_order_detail_controller.dart';
import 'purchase_order_form_screen.dart';

class PurchaseOrderDetailScreen extends StatelessWidget {
  const PurchaseOrderDetailScreen({
    required this.orderId,
    required this.session,
    required this.repository,
    this.onOrderChanged,
    super.key,
  });

  final int orderId;
  final UserSession session;
  final PurchaseOrderRepository repository;
  final Future<void> Function()? onOrderChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Order Detail'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: PurchaseOrderDetailPane(
              orderId: orderId,
              session: session,
              repository: repository,
              onOrderChanged: onOrderChanged,
          ),
        ),
      ),
    );
  }
}

class PurchaseOrderDetailPane extends StatefulWidget {
  const PurchaseOrderDetailPane({
    required this.orderId,
    required this.session,
    required this.repository,
    this.showRefreshAction = true,
    this.onOrderChanged,
    super.key,
  });

  final int orderId;
  final UserSession session;
  final PurchaseOrderRepository repository;
  final bool showRefreshAction;
  final Future<void> Function()? onOrderChanged;

  @override
  State<PurchaseOrderDetailPane> createState() => _PurchaseOrderDetailPaneState();
}

class _PurchaseOrderDetailPaneState extends State<PurchaseOrderDetailPane> {
  late final PurchaseOrderDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PurchaseOrderDetailController(repository: widget.repository);
    _load();
  }

  @override
  void didUpdateWidget(covariant PurchaseOrderDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      _load();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    _controller.load(id: widget.orderId, authToken: widget.session.token);
  }

  Future<void> _send() async {
    final sent = await _controller.send(
      id: widget.orderId,
      authToken: widget.session.token,
    );
    if (sent && widget.onOrderChanged != null) {
      await widget.onOrderChanged!();
    }
  }

  Future<void> _openEdit(PurchaseOrder order) async {
    final updated = await Navigator.of(context).push<PurchaseOrder>(
      MaterialPageRoute<PurchaseOrder>(
        builder: (context) => PurchaseOrderFormScreen(
          session: widget.session,
          repository: widget.repository,
          initialOrder: order,
          onSaved: widget.onOrderChanged == null
              ? null
              : (_) => widget.onOrderChanged!(),
        ),
      ),
    );
    if (updated != null) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PurchaseOrderDetailState>(
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
            child: _PurchaseOrderDetailBody(
              state: state,
              onRetry: _load,
              onSend: _send,
              onEdit: _openEdit,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderDetailBody extends StatelessWidget {
  const _PurchaseOrderDetailBody({
    required this.state,
    required this.onRetry,
    required this.onSend,
    required this.onEdit,
  });

  final PurchaseOrderDetailState state;
  final VoidCallback onRetry;
  final Future<void> Function() onSend;
  final Future<void> Function(PurchaseOrder order) onEdit;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: '',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd.MM.yyyy.', 'hr_HR');

    if (state.isLoading && !state.hasContent) {
      return const _DetailStateCard(
        icon: Icons.receipt_long_outlined,
        title: 'Ucitavanje detalja',
        message: 'Pripremamo podatke o odabranoj narudzbi.',
      );
    }

    if (state.errorMessage != null && !state.hasContent) {
      return _DetailStateCard(
        icon: Icons.wifi_off_rounded,
        title: 'Detalji nisu dostupni',
        message: state.errorMessage!,
        actionLabel: 'Pokusaj ponovno',
        onAction: onRetry,
      );
    }

    if (!state.hasContent) {
      return _DetailStateCard(
        icon: Icons.receipt_outlined,
        title: 'Nema detalja za prikaz',
        message: 'Podaci o narudzbi trenutno nisu dostupni.',
        actionLabel: 'Osvjezi',
        onAction: onRetry,
      );
    }

    final order = state.order!;

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
        if (state.actionMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              state.actionMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (state.actionErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              state.actionErrorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (order.canSend)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: state.isSending ? null : onSend,
                  icon: state.isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(state.isSending ? 'Slanje...' : 'Posalji narudzbu'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => onEdit(order),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Uredi'),
                ),
              ],
            ),
          ),
        if (!order.canSend)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => onEdit(order),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Uredi'),
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.reference,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                _DetailRow(label: 'Supplier', value: order.supplierName),
                _DetailRow(
                  label: 'Status',
                  value: order.statusLabel,
                ),
                _DetailRow(
                  label: 'Placanje',
                  value: order.paymentTypeName,
                ),
                _DetailRow(
                  label: 'Datum',
                  value: _formatDate(order.orderedAt, dateFormat),
                ),
                _DetailRow(
                  label: 'Ukupno',
                  value:
                      '${order.currency} ${currencyFormat.format(order.totalAmount).trim()}',
                ),
                _DetailRow(
                  label: 'Zaprimljeno',
                  value: order.receivedQuantity.toString(),
                ),
                _DetailRow(
                  label: 'Preostalo',
                  value: order.remainingQuantity.toString(),
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
                  'Stavke',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                if (order.lines.isEmpty)
                  const Text('Narudzba trenutno nema stavki.')
                else
                  ...order.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LineItemCard(line: line),
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
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({required this.line});

  final PurchaseOrderLine line;

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
            line.articleName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('Kolicina: ${line.quantity}'),
          Text('Zaprimljeno: ${line.receivedQuantity}'),
          Text('Preostalo: ${line.remainingQuantity}'),
          Text('Cijena: ${line.unitPrice.toStringAsFixed(2)}'),
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

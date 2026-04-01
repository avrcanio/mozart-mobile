import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/purchase_orders/purchase_order_repository.dart';
import '../../domain/purchase_order.dart';
import '../../domain/user_session.dart';
import '../purchase_order_detail_controller.dart';
import '../unsaved_changes_guard.dart';
import 'purchase_order_form_screen.dart';
import 'purchase_order_receipt_screen.dart';

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
        title: const Text('Detalji narud\u017Ebe'),
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

  Future<void> _openReceipt(PurchaseOrder order) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => PurchaseOrderReceiptScreen(
          order: order,
          session: widget.session,
          repository: widget.repository,
        ),
      ),
    );
    if (created == true) {
      if (widget.onOrderChanged != null) {
        await widget.onOrderChanged!();
      }
      _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaprimanje robe je uspje\u0161no spremljeno.')),
      );
    }
  }

  Future<void> _openPriceAudit(PurchaseOrder order, PurchaseOrderLine line) async {
    final result = await showModalBottomSheet<_PriceAuditSubmission>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PriceAuditSheet(
        line: line,
        currency: order.currency,
      ),
    );
    if (result == null) {
      return;
    }

    final changed = await _controller.adjustItemPrice(
      orderId: order.id,
      itemId: line.id,
      price: result.price,
      currency: order.currency,
      reason: result.reason,
      authToken: widget.session.token,
    );
    if (changed && widget.onOrderChanged != null) {
      await widget.onOrderChanged!();
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
              onReceive: _openReceipt,
              onPriceAudit: _openPriceAudit,
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
    required this.onReceive,
    required this.onPriceAudit,
  });

  final PurchaseOrderDetailState state;
  final VoidCallback onRetry;
  final Future<void> Function() onSend;
  final Future<void> Function(PurchaseOrder order) onEdit;
  final Future<void> Function(PurchaseOrder order) onReceive;
  final Future<void> Function(PurchaseOrder order, PurchaseOrderLine line)
      onPriceAudit;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: '',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd.MM.yyyy.', 'hr_HR');
    final numberFormat = NumberFormat.decimalPattern('hr_HR');

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
        actionLabel: 'Pokušaj ponovno',
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
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
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
                  label: Text(state.isSending ? 'Slanje...' : 'Pošalji narudžbu'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => onEdit(order),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Uredi'),
                ),
                if (order.remainingQuantity > 0)
                  OutlinedButton.icon(
                    onPressed: () => onReceive(order),
                    icon: const Icon(Icons.warehouse_outlined),
                    label: const Text('Zaprimanje robe'),
                  ),
              ],
            ),
          ),
        if (!order.canSend)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onEdit(order),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Uredi'),
                ),
                if (order.remainingQuantity > 0)
                  OutlinedButton.icon(
                    onPressed: () => onReceive(order),
                    icon: const Icon(Icons.warehouse_outlined),
                    label: const Text('Zaprimanje robe'),
                  ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Narud\u017Eba ${order.reference}',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Pregled osnovnih podataka i statusa narud\u017Ebe.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _DetailRow(label: '\u0160ifra', value: '#${order.id}'),
                _DetailRow(label: 'Referenca', value: order.reference),
                _DetailRow(label: 'Dobavlja\u010D', value: order.supplierName),
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
                if (order.createdBy.isNotEmpty)
                  _DetailRow(
                    label: 'Kreirao',
                    value: order.createdBy,
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
                  'Povijest statusa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kratki pregled kako je narud\u017Eba do\u0161la do trenutnog stanja.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                if (order.history.length <= 1)
                  const Text(
                    'Dodatna povijest ce se prikazati cim backend posalje vise audit podataka za ovu narudzbu.',
                  )
                else
                  ...order.history.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HistoryEntryTile(
                        entry: entry,
                        dateFormat: dateFormat,
                      ),
                    ),
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
                  'Ukupni iznosi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Neto',
                  value: _formatMoney(order.totalNetAmount, order.currency, currencyFormat),
                ),
                _DetailRow(
                  label: 'Bruto',
                  value: _formatMoney(
                    order.totalGrossAmount == 0
                        ? order.totalAmount
                        : order.totalGrossAmount,
                    order.currency,
                    currencyFormat,
                  ),
                ),
                if (order.totalDepositAmount > 0)
                  _DetailRow(
                    label: 'Povratna',
                    value: _formatMoney(
                      order.totalDepositAmount,
                      order.currency,
                      currencyFormat,
                    ),
                  ),
                _DetailRow(
                  label: 'Zaprimljeno',
                  value: _formatQuantity(order.receivedQuantity, numberFormat),
                ),
                _DetailRow(
                  label: 'Preostalo',
                  value: _formatQuantity(order.remainingQuantity, numberFormat),
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
                  const Text('Narud\u017Eba trenutno nema stavki.')
                else
                  ...order.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LineItemCard(
                        line: line,
                        isUpdatingPrice:
                            state.isUpdatingPrice &&
                            state.activePriceItemId == line.id,
                        currency: order.currency,
                        numberFormat: numberFormat,
                        currencyFormat: currencyFormat,
                        onPriceAudit: () => onPriceAudit(order, line),
                      ),
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
  const _LineItemCard({
    required this.line,
    required this.isUpdatingPrice,
    required this.currency,
    required this.numberFormat,
    required this.currencyFormat,
    required this.onPriceAudit,
  });

  final PurchaseOrderLine line;
  final bool isUpdatingPrice;
  final String currency;
  final NumberFormat numberFormat;
  final NumberFormat currencyFormat;
  final VoidCallback onPriceAudit;

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
          Text(
            'Kolicina: ${_formatQuantity(line.quantity, numberFormat)} ${line.unitName}'.trim(),
          ),
          Text('Zaprimljeno: ${_formatQuantity(line.receivedQuantity, numberFormat)}'),
          Text('Preostalo: ${_formatQuantity(line.remainingQuantity, numberFormat)}'),
          Text(
            'Cijena: ${_formatMoney(line.unitPrice, currency, currencyFormat)}',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: isUpdatingPrice ? null : onPriceAudit,
              icon: isUpdatingPrice
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.price_change_outlined),
              label: Text(
                isUpdatingPrice ? 'Azuriranje...' : 'Korigiraj cijenu',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({
    required this.entry,
    required this.dateFormat,
  });

  final PurchaseOrderHistoryEntry entry;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(entry.description),
              const SizedBox(height: 4),
              Text(
                entry.occurredAt == null
                    ? 'Vrijeme nije dostupno'
                    : _formatDateTime(entry.occurredAt!, dateFormat),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceAuditSheet extends StatefulWidget {
  const _PriceAuditSheet({
    required this.line,
    required this.currency,
  });

  final PurchaseOrderLine line;
  final String currency;

  @override
  State<_PriceAuditSheet> createState() => _PriceAuditSheetState();
}

class _PriceAuditSheetState extends State<_PriceAuditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  final TextEditingController _reasonController = TextEditingController();
  late _PriceAuditDraftSnapshot _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.line.unitPrice.toStringAsFixed(2).replaceAll('.', ','),
    );
    _initialSnapshot = _buildSnapshot();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final normalizedPrice = _normalizeDecimalString(_priceController.text);
    Navigator.of(context).pop(
      _PriceAuditSubmission(
        price: normalizedPrice,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  _PriceAuditDraftSnapshot _buildSnapshot() {
    return _PriceAuditDraftSnapshot(
      price: _normalizeDecimalString(_priceController.text),
      reason: _reasonController.text.trim(),
    );
  }

  bool get _hasUnsavedChanges => _buildSnapshot() != _initialSnapshot;

  Future<void> _handlePopAttempt() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final shouldDiscard = await showDiscardChangesDialog(
      context,
      message:
          'Imate nespremljenu korekciju cijene. Ako zatvorite ovaj prozor, uneseni podaci ce biti izgubljeni.',
    );
    if (!mounted || !shouldDiscard) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final currentPrice = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: '',
      decimalDigits: 2,
    ).format(widget.line.unitPrice).trim();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handlePopAttempt();
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(
                  'Korekcija cijene',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.line.articleName} | Trenutno ${widget.currency} $currentPrice',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('po-price-audit-price'),
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Nova cijena (${widget.currency})',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final parsed = _parseLocalizedDecimal(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Unesite ispravnu cijenu.';
                    }
                    if (parsed == widget.line.unitPrice) {
                      return 'Unesite novu cijenu razlicitu od postojece.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('po-price-audit-reason'),
                  controller: _reasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Razlog promjene',
                    hintText: 'Navedite zasto mijenjate cijenu stavke.',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Unesite razlog promjene.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _handlePopAttempt,
                        child: const Text('Odustani'),
                      ),
                      const Spacer(),
                      FilledButton(
                        key: const Key('po-price-audit-submit'),
                        onPressed: _submit,
                        child: const Text('Spremi korekciju'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceAuditDraftSnapshot {
  const _PriceAuditDraftSnapshot({
    required this.price,
    required this.reason,
  });

  final String price;
  final String reason;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _PriceAuditDraftSnapshot &&
        other.price == price &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(price, reason);
}

class _PriceAuditSubmission {
  const _PriceAuditSubmission({
    required this.price,
    required this.reason,
  });

  final String price;
  final String reason;
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

String _formatDateTime(DateTime value, DateFormat formatter) {
  final time = DateFormat('HH:mm', 'hr_HR');
  return '${formatter.format(value.toLocal())} ${time.format(value.toLocal())}';
}

String _formatMoney(double value, String currency, NumberFormat formatter) {
  return '$currency ${formatter.format(value).trim()}';
}

String _formatQuantity(double value, NumberFormat formatter) {
  if (value == value.roundToDouble()) {
    return formatter.format(value.toInt());
  }
  return formatter.format(value);
}

double? _parseLocalizedDecimal(String value) {
  final normalized = _normalizeDecimalString(value);
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String _normalizeDecimalString(String value) {
  return value.trim().replaceAll(',', '.');
}

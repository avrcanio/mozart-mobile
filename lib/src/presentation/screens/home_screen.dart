import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/dashboard/dashboard_repository.dart';
import '../../data/mailbox/mailbox_repository.dart';
import '../../data/purchase_orders/purchase_order_repository.dart';
import '../../domain/mail_message.dart';
import '../../domain/purchase_order.dart';
import '../../domain/user_session.dart';
import '../dashboard_controller.dart';
import '../mailbox_controller.dart';
import '../purchase_orders_controller.dart';
import '../session_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.session,
    required this.dashboardRepository,
    required this.mailboxRepository,
    required this.purchaseOrderRepository,
    super.key,
  });

  final UserSession session;
  final DashboardRepository dashboardRepository;
  final MailboxRepository mailboxRepository;
  final PurchaseOrderRepository purchaseOrderRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DashboardController _dashboardController;
  late final MailboxController _mailboxController;
  late final PurchaseOrdersController _purchaseOrdersController;
  int _index = 0;
  int? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    _dashboardController = DashboardController(
      repository: widget.dashboardRepository,
    );
    _mailboxController = MailboxController(
      repository: widget.mailboxRepository,
    );
    _purchaseOrdersController = PurchaseOrdersController(
      repository: widget.purchaseOrderRepository,
    );
    _loadAll();
    _purchaseOrdersController.addListener(_syncSelectedOrder);
  }

  @override
  void dispose() {
    _purchaseOrdersController.removeListener(_syncSelectedOrder);
    _dashboardController.dispose();
    _mailboxController.dispose();
    _purchaseOrdersController.dispose();
    super.dispose();
  }

  void _loadAll() {
    final token = widget.session.token;
    _dashboardController.load(token);
    _mailboxController.load(token);
    _purchaseOrdersController.load(token);
  }

  void _syncSelectedOrder() {
    final orders = _purchaseOrdersController.value.orders;
    if (orders.isEmpty) {
      setState(() {
        _selectedOrderId = null;
      });
      return;
    }

    final hasSelected = _selectedOrderId != null &&
        orders.any((order) => order.id == _selectedOrderId);
    if (!hasSelected) {
      setState(() {
        _selectedOrderId = orders.first.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionController = SessionScope.of(context);
    final tabs = <Widget>[
      ValueListenableBuilder<DashboardState>(
        valueListenable: _dashboardController,
        builder: (context, state, _) => _DashboardTab(state: state),
      ),
      ValueListenableBuilder<MailboxState>(
        valueListenable: _mailboxController,
        builder: (context, state, _) => _MailboxTab(state: state),
      ),
      ValueListenableBuilder<PurchaseOrdersState>(
        valueListenable: _purchaseOrdersController,
        builder: (context, state, _) => _PurchaseOrdersTab(
          state: state,
          selectedOrderId: _selectedOrderId,
          onSelect: (orderId) {
            setState(() {
              _selectedOrderId = orderId;
            });
          },
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mozart Mobile'),
                  Text(
                    widget.session.displayName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _SessionIdentityBadge(session: widget.session),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAll,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: sessionController.logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: tabs[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'Mailbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Purchase Orders',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _index = index;
          });
        },
      ),
    );
  }
}

class _SessionIdentityBadge extends StatelessWidget {
  const _SessionIdentityBadge({required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            session.displayName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            session.secondaryIdentity,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: child,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = state.summary;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 900
        ? 4
        : screenWidth >= 640
            ? 3
            : 2;
    final tiles = [
      (
        'Open POs',
        '${summary?.openPurchaseOrders ?? 0}',
        Icons.inventory_2,
        const Color(0xFFF3E2D4),
      ),
      (
        'Approvals',
        '${summary?.pendingApprovals ?? 0}',
        Icons.gpp_good,
        const Color(0xFFE2ECE0),
      ),
      (
        'Unread Mail',
        '${summary?.unreadMessages ?? 0}',
        Icons.mark_email_unread,
        const Color(0xFFF6E8D8),
      ),
      (
        'Warehouses',
        '${summary?.activeWarehouses ?? 0}',
        Icons.warehouse,
        const Color(0xFFE7E0D6),
      ),
    ];

    return _PageFrame(
      child: ListView(
        children: [
          Text('Dashboard', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Pregled najvaznijih obaveza i stanja za danasnji rad.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          if (state.errorMessage != null) _ErrorBanner(message: state.errorMessage!),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.insights,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brzi pregled',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Najbitnije stavke su odmah dostupne bez dodatnog skrolanja.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: screenWidth < 420 ? 1.18 : 1.32,
            ),
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return _DashboardMetricCard(
                label: tile.$1,
                value: tile.$2,
                icon: tile.$3,
                tone: tile.$4,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 26,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailboxTab extends StatelessWidget {
  const _MailboxTab({required this.state});

  final MailboxState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateTimeFormat = DateFormat('dd.MM.yyyy. HH:mm', 'hr_HR');

    return _PageFrame(
      child: ListView.separated(
        itemCount: state.messages.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mailbox', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Pregledajte nove poruke i priloge na jednom mjestu.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (state.errorMessage != null)
                  _ErrorBanner(message: state.errorMessage!),
                if (state.isLoading) const LinearProgressIndicator(),
                if (state.isLoading) const SizedBox(height: 16),
              ],
            );
          }

          final message = state.messages[index - 1];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              title: Text(message.subject),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _buildMailboxSubtitle(message, dateTimeFormat: dateTimeFormat),
                ),
              ),
              trailing: message.hasAttachments
                  ? _MailboxAttachmentCount(count: message.attachmentCount)
                  : const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

String _buildMailboxSubtitle(
  MailMessage message, {
  required DateFormat dateTimeFormat,
}) {
  final parts = <String>[
    message.fromEmail,
  ];

  if (message.preview.isNotEmpty) {
    parts.add(message.preview);
  }

  if (message.sentAt != null) {
    parts.add(dateTimeFormat.format(message.sentAt!.toLocal()));
  }

  return parts.join(' | ');
}

class _MailboxAttachmentCount extends StatelessWidget {
  const _MailboxAttachmentCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.attach_file),
        Text('$count'),
      ],
    );
  }
}

class _PurchaseOrdersTab extends StatelessWidget {
  const _PurchaseOrdersTab({
    required this.state,
    required this.selectedOrderId,
    required this.onSelect,
  });

  final PurchaseOrdersState state;
  final int? selectedOrderId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;
    final currencyFormat = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: '',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd.MM.yyyy.', 'hr_HR');
    PurchaseOrder? selectedOrder;
    if (selectedOrderId != null) {
      for (final order in state.orders) {
        if (order.id == selectedOrderId) {
          selectedOrder = order;
          break;
        }
      }
    }

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Purchase Orders', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Pratite narudzbe, statuse i osnovne detalje isporuke.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null) _ErrorBanner(message: state.errorMessage!),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
        ...state.orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                title: Text('${order.reference} | ${order.supplierName}'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_buildOrderListSubtitle(
                    order,
                    currencyFormat: currencyFormat,
                    dateFormat: dateFormat,
                  )),
                ),
                selected: selectedOrderId == order.id,
                onTap: () => onSelect(order.id),
              ),
            ),
          ),
        ),
      ],
    );

    final detail = Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: selectedOrder == null
            ? const Text('Select a purchase order to inspect its details.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedOrder.reference,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Supplier: ${selectedOrder.supplierName}'),
                  const SizedBox(height: 8),
                  Text('Datum: ${_formatDate(selectedOrder.orderedAt, dateFormat)}'),
                  const SizedBox(height: 8),
                  Text('Placanje: ${selectedOrder.paymentTypeName}'),
                  const SizedBox(height: 8),
                  Text('Status: ${selectedOrder.statusLabel}'),
                  const SizedBox(height: 8),
                  Text(
                    'Ukupno: ${selectedOrder.currency} ${currencyFormat.format(selectedOrder.totalAmount).trim()}',
                  ),
                  const SizedBox(height: 8),
                  Text('Received qty: ${selectedOrder.receivedQuantity}'),
                  const SizedBox(height: 8),
                  Text('Remaining qty: ${selectedOrder.remainingQuantity}'),
                  const SizedBox(height: 24),
                  Text('Lines', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...selectedOrder.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${line.articleName}: qty ${line.quantity}, received ${line.receivedQuantity}, remaining ${line.remainingQuantity}, price ${line.unitPrice.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    return _PageFrame(
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: list)),
                const SizedBox(width: 16),
                Expanded(child: detail),
              ],
            )
          : ListView(
              children: [
                list,
                const SizedBox(height: 16),
                detail,
              ],
            ),
    );
  }
}

String _buildOrderListSubtitle(
  PurchaseOrder order, {
  required NumberFormat currencyFormat,
  required DateFormat dateFormat,
}) {
  final parts = <String>[
    order.statusLabel,
    order.paymentTypeName,
    '${order.currency} ${currencyFormat.format(order.totalAmount).trim()}',
  ];

  if (order.orderedAt != null) {
    parts.add(_formatDate(order.orderedAt, dateFormat));
  }

  return parts.join(' | ');
}

String _formatDate(DateTime? value, DateFormat formatter) {
  if (value == null) {
    return 'Bez datuma';
  }
  return formatter.format(value.toLocal());
}

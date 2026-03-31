import 'package:flutter/material.dart';

import '../../data/dashboard/dashboard_repository.dart';
import '../../data/mailbox/mailbox_repository.dart';
import '../../data/purchase_orders/purchase_order_repository.dart';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mozart Mobile'),
            Text(
              widget.session.fullName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
    final tiles = [
      ('Open POs', '${summary?.openPurchaseOrders ?? 0}', Icons.inventory_2),
      ('Approvals', '${summary?.pendingApprovals ?? 0}', Icons.gpp_good),
      ('Unread Mail', '${summary?.unreadMessages ?? 0}', Icons.mark_email_unread),
      ('Warehouses', '${summary?.activeWarehouses ?? 0}', Icons.warehouse),
    ];

    return _PageFrame(
      child: ListView(
        children: [
          Text('Dashboard', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Composed from mailbox and purchase order endpoints instead of a dedicated dashboard API.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          if (state.errorMessage != null) _ErrorBanner(message: state.errorMessage!),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(),
            ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: tiles
                .map(
                  (tile) => SizedBox(
                    width: 220,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(tile.$3, size: 28),
                            const SizedBox(height: 14),
                            Text(tile.$1, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(tile.$2, style: theme.textTheme.displaySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
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
                  'Backed by GET /api/mailbox/messages/ and detail endpoints.',
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
                child: Text('${message.sender} | ${message.preview}'),
              ),
              trailing: message.hasAttachments
                  ? const Icon(Icons.attach_file)
                  : const SizedBox.shrink(),
            ),
          );
        },
      ),
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
          'List and detail views now target the existing purchase order contract.',
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
                  child: Text(
                    '${order.status} | ${order.paymentTypeName} | ${order.currency} ${order.totalAmount.toStringAsFixed(2)}',
                  ),
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
                  Text('Payment type: ${selectedOrder.paymentTypeName}'),
                  const SizedBox(height: 8),
                  Text('Status: ${selectedOrder.status}'),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${selectedOrder.currency} ${selectedOrder.totalAmount.toStringAsFixed(2)}',
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

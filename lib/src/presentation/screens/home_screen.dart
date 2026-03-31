import 'package:flutter/material.dart';

import '../../domain/dashboard_summary.dart';
import '../../domain/mail_message.dart';
import '../../domain/purchase_order.dart';
import '../session_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.state, super.key});

  final SessionState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  PurchaseOrder? _selectedOrder;

  @override
  void initState() {
    super.initState();
    _selectedOrder = widget.state.purchaseOrders.isEmpty
        ? null
        : widget.state.purchaseOrders.first;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.purchaseOrders.isNotEmpty &&
        !_containsOrder(widget.state.purchaseOrders, _selectedOrder)) {
      _selectedOrder = widget.state.purchaseOrders.first;
    }
  }

  bool _containsOrder(List<PurchaseOrder> orders, PurchaseOrder? target) {
    if (target == null) {
      return false;
    }
    return orders.any((order) => order.id == target.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = SessionScope.of(context);
    final state = widget.state;
    final tabs = <Widget>[
      _DashboardTab(summary: state.dashboardSummary),
      _MailboxTab(messages: state.messages),
      _PurchaseOrdersTab(
        orders: state.purchaseOrders,
        selectedOrder: _selectedOrder,
        onSelect: (order) {
          setState(() {
            _selectedOrder = order;
          });
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mozart Mobile'),
            Text(
              state.session?.fullName ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: state.isLoading ? null : controller.refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: controller.logout,
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

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.summary});

  final DashboardSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            'Mobile-first summary cards over the existing Django API.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
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
  const _MailboxTab({required this.messages});

  final List<MailMessage> messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _PageFrame(
      child: ListView.separated(
        itemCount: messages.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mailbox', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Master-detail ready list view for mobile triage.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],
            );
          }

          final message = messages[index - 1];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              title: Text(message.subject),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${message.sender} • ${message.preview}'),
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
    required this.orders,
    required this.selectedOrder,
    required this.onSelect,
  });

  final List<PurchaseOrder> orders;
  final PurchaseOrder? selectedOrder;
  final ValueChanged<PurchaseOrder> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Purchase Orders', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'List, detail, and create/edit actions are staged for the MVP.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                title: Text('${order.id} • ${order.vendor}'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${order.status} • ${order.currency} ${order.total.toStringAsFixed(2)}',
                  ),
                ),
                selected: selectedOrder?.id == order.id,
                onTap: () => onSelect(order),
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
                  Text(selectedOrder!.id, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text('Vendor: ${selectedOrder!.vendor}'),
                  const SizedBox(height: 8),
                  Text('Buyer: ${selectedOrder!.buyer}'),
                  const SizedBox(height: 8),
                  Text('Status: ${selectedOrder!.status}'),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${selectedOrder!.currency} ${selectedOrder!.total.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Create'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Edit'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Price Audit'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Warehouse Receipt'),
                      ),
                    ],
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

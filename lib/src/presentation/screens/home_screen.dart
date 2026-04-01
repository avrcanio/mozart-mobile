import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/dashboard/dashboard_repository.dart';
import '../../data/mailbox/mailbox_repository.dart';
import '../../data/purchase_orders/purchase_order_repository.dart';
import '../../domain/mail_message.dart';
import '../../domain/purchase_order.dart';
import '../../domain/purchase_order_filters.dart';
import '../../domain/user_session.dart';
import '../../data/purchase_orders/models/supplier_dto.dart';
import '../dashboard_controller.dart';
import '../mailbox_controller.dart';
import '../purchase_orders_controller.dart';
import '../session_scope.dart';
import 'mailbox_detail_screen.dart';
import 'purchase_order_detail_screen.dart';
import 'purchase_order_form_screen.dart';

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
  PurchaseOrder? _selectedOrderDetail;

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

  void _refreshCurrentTab() {
    switch (_index) {
      case 0:
        _dashboardController.load(widget.session.token);
        return;
      case 1:
        _mailboxController.load(widget.session.token);
        return;
      case 2:
        _purchaseOrdersController.load(widget.session.token);
        return;
    }
  }

  Future<void> _showPurchaseOrderFilters(PurchaseOrdersState state) async {
    await _purchaseOrdersController.ensureSuppliersLoaded(widget.session.token);
    if (!mounted) {
      return;
    }

    final filters = await showModalBottomSheet<PurchaseOrderFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PurchaseOrderFilterSheet(
        initialFilters: state.filters,
        suppliers: _purchaseOrdersController.value.suppliers,
      ),
    );

    if (filters == null) {
      return;
    }

    await _purchaseOrdersController.applyFilters(widget.session.token, filters);
  }

  Future<void> _resetPurchaseOrderFilters() async {
    await _purchaseOrdersController.resetFilters(widget.session.token);
  }

  Future<void> _refreshPurchaseOrders() async {
    await _purchaseOrdersController.load(widget.session.token);
  }

  void _syncSelectedOrder() {
    final orders = _purchaseOrdersController.value.orders;
    if (orders.isEmpty) {
      setState(() {
        _selectedOrderId = null;
        _selectedOrderDetail = null;
      });
      return;
    }

    PurchaseOrder? selectedOrder;
    if (_selectedOrderId != null) {
      for (final order in orders) {
        if (order.id == _selectedOrderId) {
          selectedOrder = order;
          break;
        }
      }
    }

    if (selectedOrder == null) {
      selectedOrder = orders.first;
      setState(() {
        _selectedOrderId = selectedOrder!.id;
        _selectedOrderDetail = selectedOrder;
      });
      return;
    }

    if (_selectedOrderDetail?.id != selectedOrder.id) {
      setState(() {
        _selectedOrderDetail = selectedOrder;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionController = SessionScope.of(context);
    final tabs = <Widget>[
      ValueListenableBuilder<DashboardState>(
        valueListenable: _dashboardController,
        builder: (context, state, _) => _DashboardTab(
          state: state,
          onRetry: _loadAll,
        ),
      ),
      ValueListenableBuilder<MailboxState>(
        valueListenable: _mailboxController,
        builder: (context, state, _) => _MailboxTab(
          state: state,
          onRetry: _loadAll,
          repository: widget.mailboxRepository,
          session: widget.session,
        ),
      ),
      ValueListenableBuilder<PurchaseOrdersState>(
        valueListenable: _purchaseOrdersController,
        builder: (context, state, _) => _PurchaseOrdersTab(
          state: state,
          onRetry: _loadAll,
          onLoadMore: () => _purchaseOrdersController.loadMore(widget.session.token),
          onOpenFilters: () => _showPurchaseOrderFilters(state),
          onResetFilters: _resetPurchaseOrderFilters,
          onOrderChanged: _refreshPurchaseOrders,
          repository: widget.purchaseOrderRepository,
          session: widget.session,
          selectedOrderId: _selectedOrderId,
          selectedOrderDetail: _selectedOrderDetail,
          onSelect: (orderId) {
            PurchaseOrder? selectedOrder;
            for (final order in state.orders) {
              if (order.id == orderId) {
                selectedOrder = order;
                break;
              }
            }
            setState(() {
              _selectedOrderId = orderId;
              _selectedOrderDetail = selectedOrder;
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
              child: Text(
                'Mozart Mobile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 12),
            _SessionIdentityBadge(session: widget.session),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshCurrentTab,
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
  const _DashboardTab({
    required this.state,
    required this.onRetry,
  });

  final DashboardState state;
  final VoidCallback onRetry;

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
        'Purchase Orders',
        '${summary?.openPurchaseOrders ?? 0}',
        Icons.inventory_2,
        const Color(0xFFF3E2D4),
      ),
      (
        'Created POs',
        '${summary?.pendingApprovals ?? 0}',
        Icons.gpp_good,
        const Color(0xFFE2ECE0),
      ),
      (
        'Messages',
        '${summary?.totalMessages ?? 0}',
        Icons.mail_outline,
        const Color(0xFFF6E8D8),
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
          if (state.isLoading && !state.hasContent)
            const _TabStateCard(
              icon: Icons.hourglass_top_rounded,
              title: 'Ucitavanje dashboarda',
              message: 'Pripremamo najvaznije podatke za danasnji rad.',
            )
          else if (state.errorMessage != null && !state.hasContent)
            _TabStateCard(
              icon: Icons.wifi_off_rounded,
              title: 'Dashboard nije dostupan',
              message: state.errorMessage!,
              actionLabel: 'Pokusaj ponovno',
              onAction: onRetry,
            )
          else if (!state.hasContent)
            _TabStateCard(
              icon: Icons.dashboard_customize_outlined,
              title: 'Nema podataka za prikaz',
              message: 'Dashboard ce se pojaviti cim stignu novi podaci.',
              actionLabel: 'Osvjezi',
              onAction: onRetry,
            )
          else ...[
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
  const _MailboxTab({
    required this.state,
    required this.onRetry,
    required this.repository,
    required this.session,
  });

  final MailboxState state;
  final VoidCallback onRetry;
  final MailboxRepository repository;
  final UserSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateTimeFormat = DateFormat('dd.MM.yyyy. HH:mm', 'hr_HR');

    return _PageFrame(
      child: ListView.separated(
        itemCount: state.messages.isEmpty ? 2 : state.messages.length + 1,
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
                if (state.errorMessage != null && state.hasContent)
                  _ErrorBanner(message: state.errorMessage!),
                if (state.isLoading && state.hasContent)
                  const LinearProgressIndicator(),
                if (state.isLoading && state.hasContent) const SizedBox(height: 16),
              ],
            );
          }

          if (index == 1 && state.isLoading && !state.hasContent) {
            return const _TabStateCard(
              icon: Icons.mail_outline,
              title: 'Ucitavanje poruka',
              message: 'Dohvacamo najnovije poruke i priloge.',
            );
          }

          if (index == 1 && state.errorMessage != null && !state.hasContent) {
            return _TabStateCard(
              icon: Icons.mark_email_unread_outlined,
              title: 'Poruke nisu dostupne',
              message: state.errorMessage!,
              actionLabel: 'Pokusaj ponovno',
              onAction: onRetry,
            );
          }

          if (index == 1 && !state.hasContent) {
            return _TabStateCard(
              icon: Icons.inbox_outlined,
              title: 'Nema poruka',
              message: 'Trenutno nema novih poruka u sanducicu.',
              actionLabel: 'Osvjezi',
              onAction: onRetry,
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
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => MailboxDetailScreen(
                      messageId: message.id,
                      session: session,
                      repository: repository,
                    ),
                  ),
                );
              },
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
    required this.onRetry,
    required this.onLoadMore,
    required this.onOpenFilters,
    required this.onResetFilters,
    required this.onOrderChanged,
    required this.repository,
    required this.session,
    required this.selectedOrderId,
    required this.selectedOrderDetail,
    required this.onSelect,
  });

  final PurchaseOrdersState state;
  final VoidCallback onRetry;
  final Future<void> Function() onLoadMore;
  final VoidCallback onOpenFilters;
  final VoidCallback onResetFilters;
  final Future<void> Function() onOrderChanged;
  final PurchaseOrderRepository repository;
  final UserSession session;
  final int? selectedOrderId;
  final PurchaseOrder? selectedOrderDetail;
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
    final selectedOrder = selectedOrderDetail;

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
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onOpenFilters,
              icon: const Icon(Icons.tune),
              label: Text(
                state.hasActiveFilters ? 'Filteri aktivni' : 'Filteri',
              ),
            ),
            if (state.hasActiveFilters) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onResetFilters,
                child: const Text('Reset'),
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              onPressed: () async {
                final created = await Navigator.of(context).push<PurchaseOrder>(
                  MaterialPageRoute<PurchaseOrder>(
                    builder: (context) => PurchaseOrderFormScreen(
                      session: session,
                      repository: repository,
                      onSaved: (_) => onOrderChanged(),
                    ),
                  ),
                );
                if (created != null) {
                  onSelect(created.id);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Nova'),
            ),
          ],
        ),
        if (state.hasActiveFilters) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildFilterChips(state.filters, state.suppliers),
          ),
          const SizedBox(height: 16),
        ],
        if (state.errorMessage != null && state.hasContent)
          _ErrorBanner(message: state.errorMessage!),
        if (state.isLoading && state.hasContent)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
        if (state.isLoading && !state.hasContent)
          const _TabStateCard(
            icon: Icons.receipt_long_outlined,
            title: 'Ucitavanje narudzbi',
            message: 'Pripremamo pregled aktivnih narudzbi.',
          )
        else if (state.errorMessage != null && !state.hasContent)
          _TabStateCard(
            icon: Icons.receipt_long_outlined,
            title: 'Narudzbe nisu dostupne',
            message: state.errorMessage!,
            actionLabel: 'Pokusaj ponovno',
            onAction: onRetry,
          )
        else if (!state.hasContent)
          _TabStateCard(
            icon: Icons.playlist_add_check_circle_outlined,
            title: 'Nema aktivnih narudzbi',
            message: 'Kad stignu nove narudzbe, ovdje ce biti prikazane.',
            actionLabel: 'Osvjezi',
            onAction: onRetry,
          )
        else
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
                onTap: () {
                  onSelect(order.id);
                  if (!isWide) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => PurchaseOrderDetailScreen(
                          orderId: order.id,
                          session: session,
                          repository: repository,
                          onOrderChanged: onOrderChanged,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),
        if (state.loadMoreErrorMessage != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(message: state.loadMoreErrorMessage!),
        ],
        if (state.hasContent && state.hasMorePages) ...[
          const SizedBox(height: 4),
          Center(
            child: FilledButton.tonal(
              key: const Key('po-load-more'),
              onPressed: state.isLoadingMore ? null : onLoadMore,
              child: Text(
                state.isLoadingMore ? 'Ucitavanje...' : 'Ucitaj jos',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prikazano ${state.orders.length} od ${state.totalCount} narudzbi.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );

    return _PageFrame(
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: list)),
                const SizedBox(width: 16),
                Expanded(
                  child: selectedOrder == null
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Odaberite narudzbu za pregled detalja.',
                            ),
                          ),
                        )
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: PurchaseOrderDetailPane(
                              orderId: selectedOrder.id,
                              session: session,
                              repository: repository,
                              onOrderChanged: onOrderChanged,
                            ),
                          ),
                        ),
                ),
              ],
            )
          : ListView(children: [list]),
    );
  }
}

List<Widget> _buildFilterChips(
  PurchaseOrderFilters filters,
  List<SupplierDto> suppliers,
) {
  final chips = <Widget>[];

  if ((filters.status ?? '').trim().isNotEmpty) {
    chips.add(
      Chip(
        label: Text('Status: ${_statusLabel(filters.status!)}'),
      ),
    );
  }

  if (filters.supplierId != null) {
    String? supplierName;
    for (final supplier in suppliers) {
      if (supplier.id == filters.supplierId) {
        supplierName = supplier.name;
        break;
      }
    }
    chips.add(
      Chip(
        label: Text('Dobavljac: ${supplierName ?? '#${filters.supplierId}'}'),
      ),
    );
  }

  final dateFormat = DateFormat('dd.MM.yyyy.', 'hr_HR');
  if (filters.orderedFrom != null) {
    chips.add(
      Chip(
        label: Text('Od: ${dateFormat.format(filters.orderedFrom!.toLocal())}'),
      ),
    );
  }
  if (filters.orderedTo != null) {
    chips.add(
      Chip(
        label: Text('Do: ${dateFormat.format(filters.orderedTo!.toLocal())}'),
      ),
    );
  }

  return chips;
}

const List<({String value, String label})> _purchaseOrderStatusOptions = [
  (value: 'created', label: 'Kreirana'),
  (value: 'sent', label: 'Poslana'),
  (value: 'confirmed', label: 'Potvrdena'),
  (value: 'received', label: 'Djelomicno zaprimljena'),
  (value: 'received_all', label: 'Sve zaprimljeno'),
  (value: 'canceled', label: 'Otkazana'),
];

String _statusLabel(String value) {
  for (final option in _purchaseOrderStatusOptions) {
    if (option.value == value) {
      return option.label;
    }
  }
  return value;
}

class _PurchaseOrderFilterSheet extends StatefulWidget {
  const _PurchaseOrderFilterSheet({
    required this.initialFilters,
    required this.suppliers,
  });

  final PurchaseOrderFilters initialFilters;
  final List<SupplierDto> suppliers;

  @override
  State<_PurchaseOrderFilterSheet> createState() =>
      _PurchaseOrderFilterSheetState();
}

class _PurchaseOrderFilterSheetState extends State<_PurchaseOrderFilterSheet> {
  late String? _status;
  late int? _supplierId;
  late final TextEditingController _orderedFromController;
  late final TextEditingController _orderedToController;

  @override
  void initState() {
    super.initState();
    _status = widget.initialFilters.status;
    _supplierId = widget.initialFilters.supplierId;
    _orderedFromController = TextEditingController(
      text: _formatInputDate(widget.initialFilters.orderedFrom),
    );
    _orderedToController = TextEditingController(
      text: _formatInputDate(widget.initialFilters.orderedTo),
    );
  }

  @override
  void dispose() {
    _orderedFromController.dispose();
    _orderedToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filteri narudzbi',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: const Key('po-filter-status'),
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Svi statusi'),
                  ),
                  ..._purchaseOrderStatusOptions.map(
                    (option) => DropdownMenuItem<String?>(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _status = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                key: const Key('po-filter-supplier'),
                initialValue: _supplierId,
                decoration: const InputDecoration(
                  labelText: 'Dobavljac',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Svi dobavljaci'),
                  ),
                  ...widget.suppliers.map(
                    (supplier) => DropdownMenuItem<int?>(
                      value: supplier.id,
                      child: Text(supplier.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _supplierId = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('po-filter-ordered-from'),
                controller: _orderedFromController,
                decoration: const InputDecoration(
                  labelText: 'Naruceno od',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('po-filter-ordered-to'),
                controller: _orderedToController,
                decoration: const InputDecoration(
                  labelText: 'Naruceno do',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(const PurchaseOrderFilters());
                    },
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        PurchaseOrderFilters(
                          status: _emptyToNull(_status),
                          supplierId: _supplierId,
                          orderedFrom: _parseInputDate(_orderedFromController.text),
                          orderedTo: _parseInputDate(_orderedToController.text),
                        ),
                      );
                    },
                    child: const Text('Primijeni'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _emptyToNull(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseInputDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}

String _formatInputDate(DateTime? value) {
  if (value == null) {
    return '';
  }
  final normalized = value.toLocal();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

class _TabStateCard extends StatelessWidget {
  const _TabStateCard({
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

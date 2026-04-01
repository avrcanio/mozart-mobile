import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/dashboard/dashboard_repository.dart';
import '../../data/mailbox/mailbox_repository.dart';
import '../../data/purchase_orders/models/supplier_dto.dart';
import '../../data/purchase_orders/purchase_order_repository.dart';
import '../../domain/mail_message.dart';
import '../../domain/purchase_order.dart';
import '../../domain/purchase_order_filters.dart';
import '../../domain/user_session.dart';
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

  String get _currentTitle {
    switch (_index) {
      case 1:
        return 'Poruke';
      case 2:
        return 'Narud\u017Ebe';
      case 0:
      default:
        return 'Početna';
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

  Future<void> _refreshDashboard() async {
    await _dashboardController.load(widget.session.token);
  }

  Future<void> _refreshMailbox() async {
    await _mailboxController.load(widget.session.token);
  }

  void _setTabIndex(int index) {
    if (_index == index) {
      return;
    }
    setState(() {
      _index = index;
    });
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
          onRetry: _refreshDashboard,
          onOpenPurchaseOrders: () => _setTabIndex(2),
          onOpenMailbox: () => _setTabIndex(1),
        ),
      ),
      ValueListenableBuilder<MailboxState>(
        valueListenable: _mailboxController,
        builder: (context, state, _) => _MailboxTab(
          state: state,
          onRetry: _refreshMailbox,
          onLoadMore: () => _mailboxController.loadMore(widget.session.token),
          repository: widget.mailboxRepository,
          session: widget.session,
        ),
      ),
      ValueListenableBuilder<PurchaseOrdersState>(
        valueListenable: _purchaseOrdersController,
        builder: (context, state, _) => _PurchaseOrdersTab(
          state: state,
          onRetry: _refreshPurchaseOrders,
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
        title: Text(_currentTitle),
        actions: [
          PopupMenuButton<_HomeMenuAction>(
            key: const Key('home-avatar-menu'),
            tooltip: 'Korisnik',
            onSelected: (action) {
              if (action == _HomeMenuAction.logout) {
                sessionController.logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.logout,
                child: Text('Odjava'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.14),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                child: Text(
                  widget.session.initials,
                  key: const Key('home-avatar-initials'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
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
            label: 'Početna',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'Poruke',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Narud\u017Ebe',
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

enum _HomeMenuAction { logout }

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
    required this.onOpenPurchaseOrders,
    required this.onOpenMailbox,
  });

  final DashboardState state;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenPurchaseOrders;
  final VoidCallback onOpenMailbox;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 900
        ? 4
        : screenWidth >= 640
            ? 3
            : 2;
    final tiles = [
      (
        'Narud\u017Ebe',
        '${summary?.openPurchaseOrders ?? 0}',
        Icons.inventory_2,
        const Color(0xFFF3E2D4),
        onOpenPurchaseOrders,
      ),
      (
        'Kreirane',
        '${summary?.pendingApprovals ?? 0}',
        Icons.gpp_good,
        const Color(0xFFE2ECE0),
        onOpenPurchaseOrders,
      ),
      (
        'Poruke',
        '${summary?.totalMessages ?? 0}',
        Icons.mail_outline,
        const Color(0xFFF6E8D8),
        onOpenMailbox,
      ),
    ];

    return _PageFrame(
      child: RefreshIndicator(
        onRefresh: onRetry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.errorMessage != null) _ErrorBanner(message: state.errorMessage!),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            if (state.isLoading && !state.hasContent)
              const _TabStateCard(
                icon: Icons.hourglass_top_rounded,
                title: 'U\u010Ditavanje dashboarda',
                message: 'Pripremamo najva\u017Enije podatke za dana\u0161nji rad.',
              )
            else if (state.errorMessage != null && !state.hasContent)
              _TabStateCard(
                icon: Icons.wifi_off_rounded,
                title: 'Po\u010Detna nije dostupna',
                message: state.errorMessage!,
                actionLabel: 'Poku\u0161aj ponovno',
                onAction: () => onRetry(),
              )
            else if (!state.hasContent)
              _TabStateCard(
                icon: Icons.dashboard_customize_outlined,
                title: 'Nema podataka za prikaz',
                message: 'Po\u010Detna \u0107e se pojaviti \u010Dim stignu novi podaci.',
                actionLabel: 'Osvje\u017Ei',
                onAction: () => onRetry(),
              )
            else
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
                    onTap: tile.$5,
                  );
                },
              ),
          ],
        ),
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
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
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
      ),
    );
  }
}

class _MailboxTab extends StatelessWidget {
  const _MailboxTab({
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    required this.repository,
    required this.session,
  });

  final MailboxState state;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLoadMore;
  final MailboxRepository repository;
  final UserSession session;

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('dd.MM.yyyy. HH:mm', 'hr_HR');
    final sections = _buildMailboxSections(state.messages);
    final children = <Widget>[
      if (state.errorMessage != null && state.hasContent)
        _ErrorBanner(message: state.errorMessage!),
      if (state.isLoading && state.hasContent)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: LinearProgressIndicator(),
        ),
    ];

    if (state.isLoading && !state.hasContent) {
      children.add(
        const _TabStateCard(
          icon: Icons.mail_outline,
          title: 'U\u010Ditavanje poruka',
          message: 'Dohva\u0107amo najnovije poruke i priloge.',
        ),
      );
    } else if (state.errorMessage != null && !state.hasContent) {
      children.add(
        _TabStateCard(
          icon: Icons.mark_email_unread_outlined,
          title: 'Poruke nisu dostupne',
          message: state.errorMessage!,
          actionLabel: 'Poku\u0161aj ponovno',
          onAction: () => onRetry(),
        ),
      );
    } else if (!state.hasContent) {
      children.add(
        _TabStateCard(
          icon: Icons.inbox_outlined,
          title: 'Nema poruka',
          message: 'Trenutno nema novih poruka u sandu\u010Di\u0107u.',
          actionLabel: 'Osvje\u017Ei',
          onAction: () => onRetry(),
        ),
      );
    } else {
      for (final section in sections) {
        children.add(_SectionHeader(label: section.label));
        for (final message in section.messages) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
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
              ),
            ),
          );
        }
      }

      if (state.loadMoreErrorMessage != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ErrorBanner(message: state.loadMoreErrorMessage!),
          ),
        );
      }
      if (state.hasMorePages) {
        children.add(
          Center(
            child: FilledButton.tonal(
              key: const Key('mailbox-load-more'),
              onPressed: state.isLoadingMore ? null : onLoadMore,
              child: Text(
                state.isLoadingMore ? 'U\u010Ditavanje...' : 'U\u010Ditaj jo\u0161',
              ),
            ),
          ),
        );
        children.add(const SizedBox(height: 8));
        children.add(
          Text(
            'Prikazano ${state.messages.length} od ${state.totalCount} poruka.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      }
    }

    return _PageFrame(
      child: RefreshIndicator(
        onRefresh: onRetry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: children,
        ),
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
  final Future<void> Function() onRetry;
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
    final isWide = MediaQuery.of(context).size.width >= 900;
    final currencyFormat = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: '',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd.MM.yyyy.', 'hr_HR');
    final selectedOrder = selectedOrderDetail;
    final sections = _buildPurchaseOrderSections(state.orders);

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            title: 'U\u010Ditavanje narud\u017Ebi',
            message: 'Pripremamo pregled aktivnih narud\u017Ebi.',
          )
        else if (state.errorMessage != null && !state.hasContent)
          _TabStateCard(
            icon: Icons.receipt_long_outlined,
            title: 'Narud\u017Ebe nisu dostupne',
            message: state.errorMessage!,
            actionLabel: 'Poku\u0161aj ponovno',
            onAction: () => onRetry(),
          )
        else if (!state.hasContent)
          _TabStateCard(
            icon: Icons.playlist_add_check_circle_outlined,
            title: 'Nema aktivnih narud\u017Ebi',
            message: 'Kad stignu nove narud\u017Ebe, ovdje \u0107e biti prikazane.',
            actionLabel: 'Osvje\u017Ei',
            onAction: () => onRetry(),
          )
        else
          ...sections.expand(
            (section) => <Widget>[
              _SectionHeader(label: section.label),
              ...section.orders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(18),
                      title: Text('${order.reference} | ${order.supplierName}'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _buildOrderListSubtitle(
                            order,
                            currencyFormat: currencyFormat,
                            dateFormat: dateFormat,
                          ),
                        ),
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
            ],
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
                state.isLoadingMore ? 'U\u010Ditavanje...' : 'U\u010Ditaj jo\u0161',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prikazano ${state.orders.length} od ${state.totalCount} narud\u017Ebi.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );

    return _PageFrame(
      child: isWide
          ? RefreshIndicator(
              onRefresh: onRetry,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
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
                                    'Odaberite narud\u017Ebu za pregled detalja.',
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
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: onRetry,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [list],
              ),
            ),
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
        label: Text('Dobavlja\u010D: ${supplierName ?? '#${filters.supplierId}'}'),
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
  (value: 'confirmed', label: 'Potvr\u0111ena'),
  (value: 'received', label: 'Djelomi\u010Dno zaprimljena'),
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
  late DateTime? _orderedFrom;
  late DateTime? _orderedTo;
  late final TextEditingController _orderedFromController;
  late final TextEditingController _orderedToController;

  @override
  void initState() {
    super.initState();
    _status = widget.initialFilters.status;
    _supplierId = widget.initialFilters.supplierId;
    _orderedFrom = widget.initialFilters.orderedFrom;
    _orderedTo = widget.initialFilters.orderedTo;
    _orderedFromController = TextEditingController(
      text: _formatDisplayDate(_orderedFrom),
    );
    _orderedToController = TextEditingController(
      text: _formatDisplayDate(_orderedTo),
    );
  }

  @override
  void dispose() {
    _orderedFromController.dispose();
    _orderedToController.dispose();
    super.dispose();
  }

  Future<void> _pickOrderedFrom() async {
    final picked = await _pickDate(initialDate: _orderedFrom ?? _orderedTo);
    if (picked == null) {
      return;
    }
    setState(() {
      _orderedFrom = picked;
      _orderedFromController.text = _formatDisplayDate(picked);
    });
  }

  Future<void> _pickOrderedTo() async {
    final picked = await _pickDate(initialDate: _orderedTo ?? _orderedFrom);
    if (picked == null) {
      return;
    }
    setState(() {
      _orderedTo = picked;
      _orderedToController.text = _formatDisplayDate(picked);
    });
  }

  Future<DateTime?> _pickDate({DateTime? initialDate}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      locale: const Locale('hr', 'HR'),
      initialDate: initialDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
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
                'Filteri narud\u017Ebi',
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
                  labelText: 'Dobavlja\u010D',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Svi dobavlja\u010Di'),
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
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Naru\u010Deno od',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickOrderedFrom,
              ),
              if (_orderedFrom != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _orderedFrom = null;
                        _orderedFromController.clear();
                      });
                    },
                    child: const Text('O\u010Disti datum od'),
                  ),
                ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('po-filter-ordered-to'),
                controller: _orderedToController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Naru\u010Deno do',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickOrderedTo,
              ),
              if (_orderedTo != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _orderedTo = null;
                        _orderedToController.clear();
                      });
                    },
                    child: const Text('O\u010Disti datum do'),
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
                          orderedFrom: _orderedFrom,
                          orderedTo: _orderedTo,
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

String _formatDisplayDate(DateTime? value) {
  if (value == null) {
    return '';
  }
  return DateFormat('dd.MM.yyyy.', 'hr_HR').format(value.toLocal());
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
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

class _MailboxSection {
  const _MailboxSection({
    required this.label,
    required this.messages,
  });

  final String label;
  final List<MailMessage> messages;
}

class _PurchaseOrderSection {
  const _PurchaseOrderSection({
    required this.label,
    required this.orders,
  });

  final String label;
  final List<PurchaseOrder> orders;
}

List<_MailboxSection> _buildMailboxSections(List<MailMessage> messages) {
  final sorted = [...messages]
    ..sort((a, b) {
      final aSentAt = a.sentAt;
      final bSentAt = b.sentAt;
      if (aSentAt == null && bSentAt == null) {
        return a.subject.compareTo(b.subject);
      }
      if (aSentAt == null) {
        return 1;
      }
      if (bSentAt == null) {
        return -1;
      }
      return bSentAt.compareTo(aSentAt);
    });

  final formatter = DateFormat('dd.MM.yyyy.', 'hr_HR');
  final sections = <_MailboxSection>[];
  DateTime? currentDay;
  List<MailMessage> currentMessages = <MailMessage>[];
  String? currentLabel;

  void flush() {
    if (currentLabel == null || currentMessages.isEmpty) {
      return;
    }
    sections.add(_MailboxSection(label: currentLabel, messages: currentMessages));
    currentMessages = <MailMessage>[];
  }

  for (final message in sorted) {
    final sentAt = message.sentAt?.toLocal();
    final day = sentAt == null ? null : DateTime(sentAt.year, sentAt.month, sentAt.day);
    final label = day == null ? 'Bez datuma' : formatter.format(day);
    final sameGroup = currentLabel == label &&
        ((day == null && currentDay == null) || day == currentDay);
    if (!sameGroup) {
      flush();
      currentDay = day;
      currentLabel = label;
    }
    currentMessages.add(message);
  }
  flush();
  return sections;
}

List<_PurchaseOrderSection> _buildPurchaseOrderSections(List<PurchaseOrder> orders) {
  final sorted = [...orders]
    ..sort((a, b) {
      final aOrderedAt = a.orderedAt?.toLocal();
      final bOrderedAt = b.orderedAt?.toLocal();
      if (aOrderedAt == null && bOrderedAt == null) {
        final supplierCompare = a.supplierName.compareTo(b.supplierName);
        if (supplierCompare != 0) {
          return supplierCompare;
        }
        final referenceCompare = a.reference.compareTo(b.reference);
        if (referenceCompare != 0) {
          return referenceCompare;
        }
        return a.id.compareTo(b.id);
      }
      if (aOrderedAt == null) {
        return 1;
      }
      if (bOrderedAt == null) {
        return -1;
      }

      final aDay = DateTime(aOrderedAt.year, aOrderedAt.month, aOrderedAt.day);
      final bDay = DateTime(bOrderedAt.year, bOrderedAt.month, bOrderedAt.day);
      final dayCompare = bDay.compareTo(aDay);
      if (dayCompare != 0) {
        return dayCompare;
      }

      final supplierCompare = a.supplierName.compareTo(b.supplierName);
      if (supplierCompare != 0) {
        return supplierCompare;
      }

      final timeCompare = bOrderedAt.compareTo(aOrderedAt);
      if (timeCompare != 0) {
        return timeCompare;
      }

      final referenceCompare = a.reference.compareTo(b.reference);
      if (referenceCompare != 0) {
        return referenceCompare;
      }
      return a.id.compareTo(b.id);
    });

  final formatter = DateFormat('dd.MM.yyyy.', 'hr_HR');
  final sections = <_PurchaseOrderSection>[];
  DateTime? currentDay;
  List<PurchaseOrder> currentOrders = <PurchaseOrder>[];
  String? currentLabel;

  void flush() {
    if (currentLabel == null || currentOrders.isEmpty) {
      return;
    }
    sections.add(_PurchaseOrderSection(label: currentLabel, orders: currentOrders));
    currentOrders = <PurchaseOrder>[];
  }

  for (final order in sorted) {
    final orderedAt = order.orderedAt?.toLocal();
    final day = orderedAt == null
        ? null
        : DateTime(orderedAt.year, orderedAt.month, orderedAt.day);
    final label = day == null ? 'Bez datuma' : formatter.format(day);
    final sameGroup = currentLabel == label &&
        ((day == null && currentDay == null) || day == currentDay);
    if (!sameGroup) {
      flush();
      currentDay = day;
      currentLabel = label;
    }
    currentOrders.add(order);
  }
  flush();
  return sections;
}

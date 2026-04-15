import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../data/http/api_client.dart';
import '../../data/purchase_orders/models/payment_type_dto.dart';
import '../../data/purchase_orders/models/supplier_article_dto.dart';
import '../../data/purchase_orders/models/supplier_dto.dart';
import '../../data/purchase_orders/purchase_order_repository.dart';
import '../../domain/purchase_order.dart';
import '../../domain/user_session.dart';
import '../unsaved_changes_guard.dart';

class PurchaseOrderFormScreen extends StatefulWidget {
  const PurchaseOrderFormScreen({
    required this.session,
    required this.repository,
    this.initialOrder,
    this.onSaved,
    super.key,
  });

  final UserSession session;
  final PurchaseOrderRepository repository;
  final PurchaseOrder? initialOrder;
  final Future<void> Function(PurchaseOrder order)? onSaved;

  bool get isEditing => initialOrder != null;

  @override
  State<PurchaseOrderFormScreen> createState() =>
      _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _supplierController = TextEditingController();
  final _supplierFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<SupplierDto> _suppliers = const <SupplierDto>[];
  List<PaymentTypeDto> _paymentTypes = const <PaymentTypeDto>[];
  List<SupplierArticleDto> _articles = const <SupplierArticleDto>[];

  int? _selectedSupplierId;
  String? _selectedSupplierName;
  int? _selectedPaymentTypeId;
  DateTime? _orderedAt;
  late List<_EditableOrderLine> _lines;
  late _PurchaseOrderDraftSnapshot _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _lines =
        widget.initialOrder?.lines
            .map(_EditableOrderLine.fromPurchaseOrderLine)
            .toList() ??
        <_EditableOrderLine>[];
    _selectedSupplierId = widget.initialOrder?.supplierId;
    _selectedSupplierName = widget.initialOrder?.supplierName;
    _selectedPaymentTypeId = widget.initialOrder?.paymentTypeId;
    _orderedAt = widget.initialOrder?.orderedAt ?? DateTime.now();
    _dateController.text = _formatDateInput(_orderedAt);
    _initialSnapshot = _buildSnapshot();
    _loadLookups();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _supplierController.dispose();
    _supplierFocusNode.dispose();
    super.dispose();
  }

  SupplierDto? get _selectedSupplier {
    if (!_hasValidSupplierSelection) {
      return null;
    }
    for (final supplier in _suppliers) {
      if (supplier.id == _selectedSupplierId) {
        return supplier;
      }
    }
    return null;
  }

  List<PaymentTypeDto> get _visiblePaymentTypes {
    final filtered = _paymentTypes
        .where((paymentType) => !_isRepresentationPaymentType(paymentType.name))
        .toList(growable: true);
    final selectedPaymentTypeId = _selectedPaymentTypeId;
    if (selectedPaymentTypeId == null) {
      return filtered;
    }

    final alreadyVisible = filtered.any(
      (paymentType) => paymentType.id == selectedPaymentTypeId,
    );
    if (alreadyVisible) {
      return filtered;
    }

    for (final paymentType in _paymentTypes) {
      if (paymentType.id == selectedPaymentTypeId) {
        filtered.add(paymentType);
        break;
      }
    }

    return filtered;
  }

  bool get _hasValidSupplierSelection =>
      _selectedSupplierId != null && _selectedSupplierId! > 0;

  bool get _canOpenCatalog =>
      _hasValidSupplierSelection &&
      _selectedPaymentTypeId != null &&
      _orderedAt != null &&
      !_isSubmitting;

  Future<void> _loadLookups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responses = await Future.wait<dynamic>([
        widget.repository.fetchSuppliers(authToken: widget.session.token),
        widget.repository.fetchPaymentTypes(authToken: widget.session.token),
      ]);

      final suppliers = responses[0] as List<SupplierDto>;
      final paymentTypes = responses[1] as List<PaymentTypeDto>;

      if (!_hasValidSupplierSelection) {
        final fallbackName =
            _selectedSupplierName ?? widget.initialOrder?.supplierName ?? '';
        final resolved = _findSupplierByName(suppliers, fallbackName);
        if (resolved != null) {
          _selectedSupplierId = resolved.id;
          _selectedSupplierName = resolved.name;
        }
      }

      var articles = const <SupplierArticleDto>[];
      if (_hasValidSupplierSelection) {
        articles = await widget.repository.fetchSupplierArticles(
          supplierId: _selectedSupplierId!,
          authToken: widget.session.token,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _suppliers = suppliers;
        _paymentTypes = paymentTypes;
        _articles = articles;
        _lines = _mergeLineMetadataFromArticles(_lines, articles);
        final supplierName =
            _selectedSupplier?.name ??
            _selectedSupplierName ??
            widget.initialOrder?.supplierName ??
            '';
        _selectedSupplierName = supplierName.isEmpty ? null : supplierName;
        _supplierController.text = supplierName;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Podaci za narud\u017ebu trenutno nisu dostupni. Poku\u0161ajte ponovno.';
      });
    }
  }

  Future<void> _loadArticlesForSupplier(int supplierId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final articles = await widget.repository.fetchSupplierArticles(
        supplierId: supplierId,
        authToken: widget.session.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _articles = articles;
        _lines = <_EditableOrderLine>[];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Artikli za odabranog dobavlja\u010da trenutno nisu dostupni.';
      });
    }
  }

  Iterable<SupplierDto> _filterSuppliers(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _suppliers;
    }
    return _suppliers.where(
      (supplier) => supplier.name.toLowerCase().contains(normalizedQuery),
    );
  }

  SupplierDto? _findSupplierByName(List<SupplierDto> suppliers, String name) {
    final normalizedName = _normalizeSupplierName(name);
    if (normalizedName.isEmpty) {
      return null;
    }
    for (final supplier in suppliers) {
      if (_normalizeSupplierName(supplier.name) == normalizedName) {
        return supplier;
      }
    }
    return null;
  }

  void _restoreSupplierSelectionFromField() {
    final resolvedSupplier = _findSupplierByName(
      _suppliers,
      _supplierController.text,
    );
    if (resolvedSupplier == null) {
      return;
    }
    _selectedSupplierId = resolvedSupplier.id;
    _selectedSupplierName = resolvedSupplier.name;
  }

  void _handleSupplierTextChanged(FormFieldState<int> field, String value) {
    final resolvedSupplier = _findSupplierByName(_suppliers, value);
    if (resolvedSupplier != null) {
      final hasSameSelection =
          _selectedSupplierId == resolvedSupplier.id &&
          _selectedSupplierName == resolvedSupplier.name;
      if (!hasSameSelection) {
        setState(() {
          _selectedSupplierId = resolvedSupplier.id;
          _selectedSupplierName = resolvedSupplier.name;
        });
      }
      field.didChange(resolvedSupplier.id);
      return;
    }

    if (_hasValidSupplierSelection) {
      setState(() {
        _selectedSupplierId = null;
        _selectedSupplierName = null;
      });
    }
    field.didChange(null);
  }

  Future<void> _handleSupplierSelected(
    FormFieldState<int> field,
    SupplierDto supplier,
  ) async {
    final previousSupplierId = _selectedSupplierId;
    setState(() {
      _selectedSupplierId = supplier.id;
      _selectedSupplierName = supplier.name;
      if (_selectedPaymentTypeId == null &&
          supplier.defaultPaymentTypeId != null) {
        _selectedPaymentTypeId = supplier.defaultPaymentTypeId;
      }
      _supplierController.value = TextEditingValue(
        text: supplier.name,
        selection: TextSelection.collapsed(offset: supplier.name.length),
      );
    });
    field.didChange(supplier.id);
    _supplierFocusNode.unfocus();
    if (previousSupplierId == supplier.id) {
      return;
    }
    await _loadArticlesForSupplier(supplier.id);
  }

  Future<void> _openAddLineCatalog() async {
    _restoreSupplierSelectionFromField();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_canOpenCatalog) {
      setState(() {
        _errorMessage =
            'Odaberite dobavlja\u010da, tip pla\u0107anja i datum narud\u017ebe.';
      });
      return;
    }

    final lines = await Navigator.of(context).push<List<_EditableOrderLine>>(
      MaterialPageRoute<List<_EditableOrderLine>>(
        builder: (context) => _PurchaseOrderArticleCatalogScreen(
          session: widget.session,
          repository: widget.repository,
          supplierId: _selectedSupplierId!,
          supplierName: _selectedSupplierName ?? '',
          orderedAt: _orderedAt!,
          initialLines: _lines,
        ),
      ),
    );

    if (!mounted || lines == null) {
      return;
    }

    setState(() {
      _lines = lines;
      _errorMessage = null;
    });
  }

  Future<void> _pickDate() async {
    if (_lines.isNotEmpty) {
      setState(() {
        _errorMessage =
            'Datum narud\u017ebe je zaklju\u010dan dok narud\u017eba sadr\u017ei stavke.';
      });
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _orderedAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _orderedAt = picked;
      _dateController.text = _formatDateInput(picked);
    });
  }

  Future<void> _submit() async {
    _restoreSupplierSelectionFromField();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_hasValidSupplierSelection || _selectedPaymentTypeId == null) {
      setState(() {
        _errorMessage = 'Odaberite dobavlja\u010da i tip pla\u0107anja.';
      });
      return;
    }
    if (_orderedAt == null) {
      setState(() {
        _errorMessage = 'Odaberite datum narud\u017ebe.';
      });
      return;
    }
    if (_lines.isEmpty) {
      setState(() {
        _errorMessage = 'Dodajte barem jednu stavku narud\u017ebe.';
      });
      return;
    }
    for (final line in _lines) {
      if (!line.isComplete) {
        setState(() {
          _errorMessage =
              'Svaka stavka mora imati artikl, koli\u010dinu i jedinicu mjere.';
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final payload = <String, dynamic>{
      'supplier': _selectedSupplierId,
      'payment_type': _selectedPaymentTypeId,
      'ordered_at': _orderedAt!.toIso8601String(),
      'status': widget.initialOrder?.status ?? 'created',
      'items': _lines.map((line) => line.toPayload()).toList(),
    };

    try {
      final order = widget.isEditing
          ? await widget.repository.updatePurchaseOrder(
              orderId: widget.initialOrder!.id,
              payload: payload,
              authToken: widget.session.token,
            )
          : await widget.repository.createPurchaseOrder(
              payload: payload,
              authToken: widget.session.token,
            );
      if (widget.onSaved != null) {
        await widget.onSaved!(order);
      }
      if (!mounted) {
        return;
      }
      _initialSnapshot = _buildSnapshot();
      Navigator.of(context).pop(order);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.message;
      });
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'Spremanje narud\u017ebe nije uspjelo. Poku\u0161ajte ponovno.';
      });
    }
  }

  _PurchaseOrderDraftSnapshot _buildSnapshot() {
    return _PurchaseOrderDraftSnapshot(
      supplierId: _selectedSupplierId,
      paymentTypeId: _selectedPaymentTypeId,
      orderedAt: _formatDateInput(_orderedAt),
      lines: _lines.map(_EditableOrderLineSnapshot.fromLine).toList(),
    );
  }

  bool get _hasUnsavedChanges => _buildSnapshot() != _initialSnapshot;

  _DraftOrderTotals get _draftTotals => _DraftOrderTotals.fromLines(_lines);

  Future<void> _handlePopAttempt() async {
    if (_isSubmitting || !_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final shouldDiscard = await showDiscardChangesDialog(context);
    if (!mounted || !shouldDiscard) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing
        ? 'Uredi narud\u017ebu'
        : 'Nova narud\u017eba';

    return _PurchaseOrderAndroidTheme(
      child: PopScope(
        canPop: _isSubmitting || !_hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            return;
          }
          await _handlePopAttempt();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: BackButton(onPressed: _handlePopAttempt),
          ),
          floatingActionButton: !_hasValidSupplierSelection
              ? null
              : FloatingActionButton.extended(
                  key: const Key('po-form-add-line'),
                  onPressed: _isLoading ? null : _openAddLineCatalog,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj stavku'),
                ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _SupplierField(
                            supplierController: _supplierController,
                            supplierFocusNode: _supplierFocusNode,
                            suppliers: _suppliers,
                            selectedSupplierId: _selectedSupplierId,
                            selectedSupplierName: _selectedSupplierName,
                            isSubmitting: _isSubmitting,
                            filterSuppliers: _filterSuppliers,
                            onTextChanged: _handleSupplierTextChanged,
                            onSupplierSelected: _handleSupplierSelected,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            key: const Key('po-form-payment-type'),
                            initialValue: _selectedPaymentTypeId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tip pla\u0107anja',
                            ),
                            items: _visiblePaymentTypes
                                .map(
                                  (paymentType) => DropdownMenuItem<int>(
                                    value: paymentType.id,
                                    child: Text(
                                      paymentType.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSubmitting
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedPaymentTypeId = value;
                                    });
                                  },
                            validator: (value) => value == null
                                ? 'Odaberite tip pla\u0107anja.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('po-form-ordered-at'),
                            controller: _dateController,
                            readOnly: true,
                            enabled: !_isSubmitting && _lines.isEmpty,
                            decoration: InputDecoration(
                              labelText: 'Datum narud\u017ebe',
                              suffixIcon: Icon(
                                _lines.isEmpty
                                    ? Icons.calendar_today
                                    : Icons.lock_outline,
                              ),
                              helperText: _lines.isEmpty
                                  ? null
                                  : 'Datum je zaklju\u010dan dok narud\u017eba sadr\u017ei stavke.',
                            ),
                            onTap: _isSubmitting ? null : _pickDate,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? 'Odaberite datum.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Stavke',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (_lines.isEmpty)
                            const Text(
                              'Dodajte stavke nakon odabira dobavlja\u010da, tipa pla\u0107anja i datuma.',
                            )
                          else
                            ..._lines.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _EditableOrderLineCard(
                                  key: Key('po-line-${entry.key}'),
                                  lineIndex: entry.key,
                                  line: entry.value,
                                  articles: _articles,
                                  onChanged: (line) {
                                    setState(() {
                                      _lines[entry.key] = line;
                                    });
                                  },
                                  onRemove: () {
                                    setState(() {
                                      _lines.removeAt(entry.key);
                                    });
                                  },
                                ),
                              ),
                            ),
                          if (_lines.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _DraftTotalsCard(totals: _draftTotals),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            key: const Key('po-form-save'),
                            onPressed: _isSubmitting ? null : _submit,
                            child: Text(
                              _isSubmitting
                                  ? 'Spremanje...'
                                  : 'Spremi narud\u017ebu',
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierField extends StatelessWidget {
  const _SupplierField({
    required this.supplierController,
    required this.supplierFocusNode,
    required this.suppliers,
    required this.selectedSupplierId,
    required this.selectedSupplierName,
    required this.isSubmitting,
    required this.filterSuppliers,
    required this.onTextChanged,
    required this.onSupplierSelected,
  });

  final TextEditingController supplierController;
  final FocusNode supplierFocusNode;
  final List<SupplierDto> suppliers;
  final int? selectedSupplierId;
  final String? selectedSupplierName;
  final bool isSubmitting;
  final Iterable<SupplierDto> Function(String query) filterSuppliers;
  final void Function(FormFieldState<int> field, String value) onTextChanged;
  final Future<void> Function(FormFieldState<int> field, SupplierDto supplier)
  onSupplierSelected;

  @override
  Widget build(BuildContext context) {
    return FormField<int>(
      initialValue: selectedSupplierId,
      validator: (_) {
        final supplierName = supplierController.text.trim();
        if (supplierName.isEmpty) {
          return 'Odaberite dobavlja\u010da.';
        }
        if (selectedSupplierId == null || selectedSupplierId! <= 0) {
          return 'Odaberite dobavlja\u010da iz popisa.';
        }
        if ((selectedSupplierName?.trim() ?? '') != supplierName) {
          return 'Odaberite dobavlja\u010da iz popisa.';
        }
        return null;
      },
      builder: (field) {
        return RawAutocomplete<SupplierDto>(
          textEditingController: supplierController,
          focusNode: supplierFocusNode,
          displayStringForOption: (supplier) => supplier.name,
          optionsBuilder: (textEditingValue) =>
              filterSuppliers(textEditingValue.text),
          onSelected: (supplier) => onSupplierSelected(field, supplier),
          optionsViewBuilder: (context, onSelected, options) {
            final optionsList = options.toList(growable: false);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    minWidth: 280,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: optionsList.length,
                    itemBuilder: (context, index) {
                      final supplier = optionsList[index];
                      return ListTile(
                        key: Key('po-form-supplier-option-${supplier.id}'),
                        title: Text(
                          supplier.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: isSubmitting ? null : () => onSelected(supplier),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              key: const Key('po-form-supplier'),
              controller: controller,
              focusNode: focusNode,
              enabled: !isSubmitting,
              decoration: InputDecoration(
                labelText: 'Dobavlja\u010d',
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => onTextChanged(field, value),
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
        );
      },
    );
  }
}

class _PurchaseOrderArticleCatalogScreen extends StatefulWidget {
  const _PurchaseOrderArticleCatalogScreen({
    required this.session,
    required this.repository,
    required this.supplierId,
    required this.supplierName,
    required this.orderedAt,
    required this.initialLines,
  });

  final UserSession session;
  final PurchaseOrderRepository repository;
  final int supplierId;
  final String supplierName;
  final DateTime orderedAt;
  final List<_EditableOrderLine> initialLines;

  @override
  State<_PurchaseOrderArticleCatalogScreen> createState() =>
      _PurchaseOrderArticleCatalogScreenState();
}

class _PurchaseOrderArticleCatalogScreenState
    extends State<_PurchaseOrderArticleCatalogScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  String? _errorMessage;
  List<_ArticleCatalogGroup> _groups = const <_ArticleCatalogGroup>[];
  int _activeGroupIndex = 0;
  late List<_EditableOrderLine> _draftLines;

  @override
  void initState() {
    super.initState();
    _draftLines = List<_EditableOrderLine>.from(widget.initialLines);
    _scrollController.addListener(_handleScroll);
    _loadArticles();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final articles = await widget.repository.fetchSupplierArticles(
        supplierId: widget.supplierId,
        authToken: widget.session.token,
        orderedAt: widget.orderedAt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = _buildArticleCatalogGroups(articles);
        _activeGroupIndex = 0;
        _isLoading = false;
      });
      debugPrint(
        '[po-catalog] loaded ${_groups.length} groups for supplier ${widget.supplierId}: '
        '${_groups.asMap().entries.map((entry) => "#${entry.key} ${entry.value.title} (sort=${entry.value.sortOrder?.toString() ?? "null"})").join(", ")}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _captureGroupOffsets();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Katalog artikala trenutno nije dostupan.';
      });
    }
  }

  Future<void> _selectArticle(SupplierArticleDto article) async {
    final line = await Navigator.of(context).push<_EditableOrderLine>(
      MaterialPageRoute<_EditableOrderLine>(
        builder: (context) => _PurchaseOrderArticleQuantityScreen(
          article: article,
          repository: widget.repository,
          authToken: widget.session.token,
        ),
      ),
    );
    if (!mounted || line == null) {
      return;
    }
    setState(() {
      _draftLines = _mergeDraftCatalogLine(_draftLines, line);
    });
  }

  void _closeCatalog() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).pop(List<_EditableOrderLine>.from(_draftLines));
  }

  double _orderedQuantityFor(SupplierArticleDto article) {
    var total = 0.0;
    for (final line in _draftLines) {
      if (line.articleId != article.id ||
          line.unitOfMeasureId != article.unitOfMeasureId) {
        continue;
      }
      total += line.parsedQuantity ?? 0;
    }
    return total;
  }

  List<String> _orderedSummaryLinesFor(SupplierArticleDto article) {
    for (final line in _draftLines) {
      if (line.articleId != article.id ||
          line.unitOfMeasureId != article.unitOfMeasureId) {
        continue;
      }
      final summaryLines = <String>[];
      final packagingEntries = line.packagingQuantities.entries.toList(
        growable: false,
      )..sort((left, right) => left.key.compareTo(right.key));
      for (final entry in packagingEntries) {
        final parsed = _parseLocalizedDecimal(entry.value);
        if (parsed == null || parsed <= 0) {
          continue;
        }
        final label =
            line.packagingLabels[entry.key]?.trim().toLowerCase() ?? '';
        if (label.isEmpty) {
          continue;
        }
        summaryLines.add('${_formatQuantityValue(parsed)} $label');
      }
      if (summaryLines.isEmpty) {
        return const <String>[];
      }
      final baseQuantity = line.parsedQuantity;
      if (baseQuantity != null && baseQuantity > 0) {
        summaryLines.add(
          '${_formatQuantityValue(baseQuantity)} ${_formatOrderedBaseUnitLabel(line.unitName, baseQuantity)}',
        );
      }
      return summaryLines;
    }
    return const <String>[];
  }

  void _handleScroll() {
    if (_groups.length <= 1 || !_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.offset;
    var resolvedIndex = 0;
    for (var index = 0; index < _groups.length; index += 1) {
      final currentOffset = _groups[index].scrollOffset;
      if (currentOffset == null) {
        continue;
      }
      if (offset + 12 >= currentOffset) {
        resolvedIndex = index;
      } else {
        break;
      }
    }

    if (resolvedIndex != _activeGroupIndex && mounted) {
      debugPrint(
        '[po-catalog] scroll active group change: $_activeGroupIndex -> $resolvedIndex '
        '(offset=${_scrollController.offset.toStringAsFixed(1)}) '
        'title=${_groups[resolvedIndex].title}',
      );
      setState(() {
        _activeGroupIndex = resolvedIndex;
      });
    }
  }

  Future<void> _jumpToGroup(int index) async {
    if (index < 0 || index >= _groups.length) {
      return;
    }
    if (!_scrollController.hasClients) {
      debugPrint(
        '[po-catalog] jump failed: index=$index hasClients=${_scrollController.hasClients}',
      );
      return;
    }

    await _ensureGroupMaterialized(index);

    final targetOffset = _groups[index].scrollOffset;
    if (targetOffset == null) {
      debugPrint(
        '[po-catalog] jump failed: index=$index title=${_groups[index].title} targetOffset=null after materialization',
      );
      return;
    }

    final currentOffset = _scrollController.offset;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    debugPrint(
      '[po-catalog] jump request: currentIndex=$_activeGroupIndex targetIndex=$index '
      'title=${_groups[index].title} targetOffset=${targetOffset.toStringAsFixed(1)} '
      'currentOffset=${currentOffset.toStringAsFixed(1)} '
      'maxScroll=${maxScrollExtent.toStringAsFixed(1)}',
    );

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );

    if (!mounted) {
      return;
    }
    debugPrint(
      '[po-catalog] jump complete: targetIndex=$index '
      'title=${_groups[index].title} finalOffset=${_scrollController.offset.toStringAsFixed(1)}',
    );
    setState(() {
      _activeGroupIndex = index;
    });
  }

  Future<void> _ensureGroupMaterialized(int targetIndex) async {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_groups[targetIndex].key.currentContext != null &&
        _groups[targetIndex].scrollOffset != null) {
      return;
    }

    debugPrint(
      '[po-catalog] capture start: targetIndex=$targetIndex title=${_groups[targetIndex].title}',
    );
    _captureGroupOffsets();
    if (_groups[targetIndex].key.currentContext != null &&
        _groups[targetIndex].scrollOffset != null) {
      debugPrint(
        '[po-catalog] jump target materialized immediately: index=$targetIndex '
        'offset=${_groups[targetIndex].scrollOffset?.toStringAsFixed(1)}',
      );
      return;
    }

    final direction = targetIndex > _activeGroupIndex ? 1 : -1;
    const maxAttempts = 24;
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      if (!_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final step = (position.viewportDimension * 0.8).clamp(240.0, 640.0);
      final nextOffset = direction > 0
          ? (position.pixels + step).clamp(0.0, position.maxScrollExtent)
          : (position.pixels - step).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            );

      debugPrint(
        '[po-catalog] jump fallback step: targetIndex=$targetIndex activeIndex=$_activeGroupIndex '
        'currentOffset=${position.pixels.toStringAsFixed(1)} '
        'nextOffset=${nextOffset.toStringAsFixed(1)} '
        'maxScrollExtent=${position.maxScrollExtent.toStringAsFixed(1)}',
      );

      if ((nextOffset - position.pixels).abs() < 1) {
        break;
      }

      await _scrollController.animateTo(
        nextOffset,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) {
        return;
      }
      await Future<void>.delayed(Duration.zero);
      _captureGroupOffsets();

      if (_groups[targetIndex].key.currentContext != null &&
          _groups[targetIndex].scrollOffset != null) {
        debugPrint(
          '[po-catalog] jump target materialized after fallback: index=$targetIndex '
          'title=${_groups[targetIndex].title} '
          'offset=${_groups[targetIndex].scrollOffset?.toStringAsFixed(1)}',
        );
        return;
      }
    }
  }

  void _captureGroupOffsets() {
    debugPrint('[po-catalog] capture start: groups=${_groups.length}');
    for (var index = 0; index < _groups.length; index += 1) {
      final group = _groups[index];
      final context = group.key.currentContext;
      if (context == null) {
        debugPrint(
          '[po-catalog] group unavailable: index=$index title=${group.title} contextMissing=true capturedOffset=${group.scrollOffset?.toStringAsFixed(1) ?? "null"}',
        );
        continue;
      }
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) {
        debugPrint(
          '[po-catalog] group unavailable: index=$index title=${group.title} contextMissing=false renderObjectMissing=true capturedOffset=${group.scrollOffset?.toStringAsFixed(1) ?? "null"}',
        );
        continue;
      }
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null) {
        debugPrint(
          '[po-catalog] group unavailable: index=$index title=${group.title} contextMissing=false renderObjectMissing=false viewportMissing=true capturedOffset=${group.scrollOffset?.toStringAsFixed(1) ?? "null"}',
        );
        continue;
      }
      group.scrollOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
      debugPrint(
        '[po-catalog] group offset captured: index=$index title=${group.title} '
        'sort=${group.sortOrder?.toString() ?? "null"} '
        'offset=${group.scrollOffset?.toStringAsFixed(1) ?? "null"}',
      );
    }
    _handleScroll();
  }

  @override
  Widget build(BuildContext context) {
    final showCategoryJumps = _groups.length > 1;

    // ignore: deprecated_member_use
    return _PurchaseOrderAndroidTheme(
      child: WillPopScope(
        onWillPop: () async {
          _closeCatalog();
          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Dodaj stavku'),
            leading: BackButton(
              key: const Key('po-catalog-back'),
              onPressed: _closeCatalog,
            ),
          ),
          floatingActionButton: showCategoryJumps
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      key: const Key('po-catalog-prev-group'),
                      heroTag: 'po-catalog-prev-group',
                      onPressed: _activeGroupIndex <= 0
                          ? null
                          : () => _jumpToGroup(_activeGroupIndex - 1),
                      child: const Icon(Icons.keyboard_arrow_up),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      key: const Key('po-catalog-next-group'),
                      heroTag: 'po-catalog-next-group',
                      onPressed: _activeGroupIndex >= _groups.length - 1
                          ? null
                          : () => _jumpToGroup(_activeGroupIndex + 1),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_errorMessage!, textAlign: TextAlign.center),
                    ),
                  )
                : _groups.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Za odabrani datum nema artikala u katalogu dobavlja\u010da.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    key: const Key('po-catalog-list'),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${widget.supplierName} | ${_formatDateInput(widget.orderedAt)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      ..._groups.asMap().entries.map((entry) {
                        final index = entry.key;
                        final group = entry.value;
                        return Padding(
                          key: group.key,
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.title,
                                key: Key('po-catalog-group-$index'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ...group.articles.map(
                                (article) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ArticleCatalogCard(
                                    article: article,
                                    repository: widget.repository,
                                    orderedQuantity: _orderedQuantityFor(
                                      article,
                                    ),
                                    orderedSummaryLines:
                                        _orderedSummaryLinesFor(article),
                                    onTap: () => _selectArticle(article),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.75,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrderArticleQuantityScreen extends StatefulWidget {
  const _PurchaseOrderArticleQuantityScreen({
    required this.article,
    required this.repository,
    required this.authToken,
  });

  final SupplierArticleDto article;
  final PurchaseOrderRepository repository;
  final String authToken;

  @override
  State<_PurchaseOrderArticleQuantityScreen> createState() =>
      _PurchaseOrderArticleQuantityScreenState();
}

class _PurchaseOrderArticleQuantityScreenState
    extends State<_PurchaseOrderArticleQuantityScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  final Map<int, TextEditingController> _packagingControllers =
      <int, TextEditingController>{};
  late final NumberFormat _currencyFormat;
  late SupplierArticleDto _article;
  bool _isLoadingArticleDetail = false;

  List<SupplierArticlePackagingLevelDto> get _packagingLevels =>
      _article.packagingLevels
          .where((level) => level.baseQuantityTotal > 0)
          .toList(growable: true)
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

  List<SupplierArticlePackagingLevelDto> get _additionalPackagingLevels =>
      _packagingLevels.where((level) => !level.isBase).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    debugPrint(
      '[po-quantity] init article=${_article.id} '
      'referenceId=${_article.referenceId} '
      'name="${_article.name}" '
      'unit=${_article.unitOfMeasureId}/${_article.unitName} '
      'catalogPackagingPath=${_article.packagingPath ?? ""} '
      'catalogPackagingLevels=${_article.packagingLevels.length}',
    );
    _quantityController = TextEditingController();
    _syncPackagingControllers();
    _currencyFormat = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: 'EUR ',
      decimalDigits: 2,
    );
    _loadArticleDetailIfNeeded();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    for (final controller in _packagingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncPackagingControllers() {
    debugPrint(
      '[po-quantity] sync packaging controllers: '
      'article=${_article.id} '
      'referenceId=${_article.referenceId} '
      'levels=${_additionalPackagingLevels.map((level) => "${level.storageKey}:${level.displayName}:${level.baseQuantityTotal}").join(", ")}',
    );
    final activeIds = _additionalPackagingLevels
        .map((level) => level.storageKey)
        .toSet();
    final staleIds = _packagingControllers.keys
        .where((unitId) => !activeIds.contains(unitId))
        .toList(growable: false);
    for (final unitId in staleIds) {
      _packagingControllers.remove(unitId)?.dispose();
    }
    for (final level in _additionalPackagingLevels) {
      _packagingControllers.putIfAbsent(
        level.storageKey,
        () => TextEditingController(),
      );
    }
  }

  Future<void> _loadArticleDetailIfNeeded() async {
    if (_article.packagingLevels.isNotEmpty ||
        ((_article.packagingPath ?? '').trim().isNotEmpty)) {
      debugPrint(
        '[po-quantity] skip detail enrichment: article=${_article.id} '
        'referenceId=${_article.referenceId} '
        'packagingPathPresent=${((_article.packagingPath ?? "").trim().isNotEmpty)} '
        'packagingLevels=${_article.packagingLevels.length}',
      );
      return;
    }
    debugPrint(
      '[po-quantity] fetch detail enrichment: article=${_article.id} '
      'referenceId=${_article.referenceId}',
    );
    setState(() {
      _isLoadingArticleDetail = true;
    });
    try {
      final detail = await widget.repository.fetchArticleDetail(
        articleId: _article.referenceId,
        authToken: widget.authToken,
      );
      if (!mounted) {
        return;
      }
      debugPrint(
        '[po-quantity] detail loaded: article=${detail.id} '
        'referenceId=${detail.referenceId} '
        'name="${detail.name}" '
        'detailPackagingPath=${detail.packagingPath ?? ""} '
        'detailPackagingLevels=${detail.packagingLevels.length} '
        'detailLevels=${detail.packagingLevels.map((level) => "${level.sortOrder}:${level.storageKey}:${level.displayName}:base=${level.isBase}:qty=${level.baseQuantityTotal}").join(", ")}',
      );
      setState(() {
        _article = _article.copyWith(
          name: detail.name.isEmpty ? _article.name : detail.name,
          unitOfMeasureId: detail.unitOfMeasureId == 0
              ? _article.unitOfMeasureId
              : detail.unitOfMeasureId,
          unitName: detail.unitName.isEmpty
              ? _article.unitName
              : detail.unitName,
          thumbnailUrl: detail.thumbnailUrl ?? _article.thumbnailUrl,
          categoryId: detail.categoryId ?? _article.categoryId,
          categoryName: detail.categoryName ?? _article.categoryName,
          categorySortOrder:
              detail.categorySortOrder ?? _article.categorySortOrder,
          categoryPath: detail.categoryPath.isEmpty
              ? _article.categoryPath
              : detail.categoryPath,
          packagingPath: detail.packagingPath ?? _article.packagingPath,
          packagingLevels: detail.packagingLevels.isEmpty
              ? _article.packagingLevels
              : detail.packagingLevels,
        );
        _syncPackagingControllers();
        _isLoadingArticleDetail = false;
      });
      debugPrint(
        '[po-quantity] detail merged: article=${_article.id} '
        'referenceId=${_article.referenceId} '
        'mergedPackagingPath=${_article.packagingPath ?? ""} '
        'mergedPackagingLevels=${_article.packagingLevels.length} '
        'renderedAdditionalLevels=${_additionalPackagingLevels.length}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      debugPrint(
        '[po-quantity] detail enrichment failed: article=${_article.id} '
        'referenceId=${_article.referenceId} '
        'error=$error',
      );
      setState(() {
        _isLoadingArticleDetail = false;
      });
    }
  }

  void _recalculateBaseQuantityFromPackaging() {
    var total = 0.0;
    for (final level in _additionalPackagingLevels) {
      final controller = _packagingControllers[level.storageKey];
      final parsed = _parseLocalizedDecimal(controller?.text ?? '');
      if (parsed == null || parsed <= 0) {
        continue;
      }
      total += parsed * level.baseQuantityTotal;
    }
    _quantityController.value = TextEditingValue(
      text: total <= 0 ? '' : _formatQuantityValue(total),
      selection: TextSelection.collapsed(
        offset: total <= 0 ? 0 : _formatQuantityValue(total).length,
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _EditableOrderLine.fromSupplierArticle(
        _article,
        quantityText: _quantityController.text,
        packagingQuantities: {
          for (final level in _additionalPackagingLevels)
            if ((_packagingControllers[level.storageKey]?.text.trim() ?? '')
                .isNotEmpty)
              level.storageKey: _packagingControllers[level.storageKey]!.text
                  .trim(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    debugPrint(
      '[po-quantity] build: article=${article.id} '
      'referenceId=${article.referenceId} '
      'packagingPath=${article.packagingPath ?? ""} '
      'allPackagingLevels=${_packagingLevels.length} '
      'additionalPackagingLevels=${_additionalPackagingLevels.length}',
    );

    return _PurchaseOrderAndroidTheme(
      child: Scaffold(
        appBar: AppBar(title: const Text('Kolicina')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                _ArticleCatalogCard(
                  article: article,
                  repository: widget.repository,
                ),
                const SizedBox(height: 18),
                Text(
                  article.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if ((article.packagingPath ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    article.packagingPath!.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(article.defaultPrice),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_isLoadingArticleDetail) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('po-catalog-quantity'),
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: article.unitName.isEmpty
                        ? 'Kolicina'
                        : 'Kolicina (${article.unitName})',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final parsed = _parseLocalizedDecimal(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Unesite kolicinu.';
                    }
                    return null;
                  },
                ),
                if (_additionalPackagingLevels.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._additionalPackagingLevels.map(
                    (level) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: Key('po-catalog-packaging-${level.storageKey}'),
                        controller: _packagingControllers[level.storageKey],
                        decoration: InputDecoration(
                          labelText: 'Broj pakiranja (${level.displayName})',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) =>
                            _recalculateBaseQuantityFromPackaging(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  key: const Key('po-catalog-submit'),
                  onPressed: _submit,
                  child: const Text('Dodaj stavku'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleCatalogCard extends StatelessWidget {
  const _ArticleCatalogCard({
    required this.article,
    required this.repository,
    this.orderedQuantity = 0,
    this.orderedSummaryLines = const <String>[],
    this.onTap,
  });

  final SupplierArticleDto article;
  final PurchaseOrderRepository repository;
  final double orderedQuantity;
  final List<String> orderedSummaryLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: 'EUR ',
      decimalDigits: 2,
    );
    final highlightOrdered = orderedQuantity > 0;
    final orderedBackgroundColor = highlightOrdered
        ? const Color(0xFFE4F5D8)
        : null;

    return Card(
      color: orderedBackgroundColor,
      child: InkWell(
        key: Key('po-catalog-article-${article.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyedSubtree(
                key: Key('po-catalog-thumbnail-${article.id}'),
                child: _ArticleThumbnail(
                  thumbnailUrl: article.thumbnailUrl,
                  repository: repository,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(currencyFormat.format(article.defaultPrice)),
                    const SizedBox(height: 4),
                    Text(
                      article.unitName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (orderedQuantity > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        orderedSummaryLines.isEmpty
                            ? 'Naruceno: ${_formatQuantityValue(orderedQuantity)} ${article.unitName}'
                                  .trim()
                            : 'Naruceno:\n${orderedSummaryLines.join('\n')}',
                        key: Key('po-catalog-ordered-${article.id}'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleThumbnail extends StatelessWidget {
  const _ArticleThumbnail({
    required this.thumbnailUrl,
    required this.repository,
  });

  final String? thumbnailUrl;
  final PurchaseOrderRepository repository;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 50,
      height: 75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined),
    );
    final url = thumbnailUrl;
    if (url == null || url.isEmpty) {
      return placeholder;
    }
    final resolvedUrl = repository.resolveMediaUri(url).toString();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 50,
        height: 75,
        child: Image.network(
          resolvedUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}

class _DraftTotalsCard extends StatelessWidget {
  const _DraftTotalsCard({required this.totals});

  final _DraftOrderTotals totals;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: 'EUR ',
      decimalDigits: 2,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ukupni iznosi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _DraftTotalRow(
              label: 'Bez PDV',
              value: currencyFormat.format(totals.netTotal),
            ),
            const SizedBox(height: 6),
            _DraftTotalRow(
              label: 'PDV',
              value: currencyFormat.format(totals.vatTotal),
            ),
            const SizedBox(height: 6),
            _DraftTotalRow(
              label: 'Povratna naknada',
              value: currencyFormat.format(totals.depositTotal),
            ),
            const Divider(height: 20),
            _DraftTotalRow(
              label: 'Total sa PDV',
              value: currencyFormat.format(totals.grossTotal),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftTotalRow extends StatelessWidget {
  const _DraftTotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textStyle = emphasize
        ? Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: textStyle)),
        Text(value, style: textStyle),
      ],
    );
  }
}

class _EditableOrderLineCard extends StatefulWidget {
  const _EditableOrderLineCard({
    required this.lineIndex,
    required this.line,
    required this.articles,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int lineIndex;
  final _EditableOrderLine line;
  final List<SupplierArticleDto> articles;
  final ValueChanged<_EditableOrderLine> onChanged;
  final VoidCallback onRemove;

  @override
  State<_EditableOrderLineCard> createState() => _EditableOrderLineCardState();
}

class _EditableOrderLineCardState extends State<_EditableOrderLineCard> {
  late final TextEditingController _quantityController;

  List<SupplierArticleDto> get _selectableArticles {
    final hasCurrentArticle = widget.articles.any(
      (article) => article.id == widget.line.articleId,
    );
    if (widget.line.articleId <= 0 || hasCurrentArticle) {
      return widget.articles;
    }
    return <SupplierArticleDto>[
      SupplierArticleDto(
        id: widget.line.articleId,
        referenceId: widget.line.articleId,
        name: widget.line.articleName.isEmpty
            ? 'Nepoznati artikl'
            : '${widget.line.articleName} (vise nije u katalogu)',
        unitOfMeasureId: widget.line.unitOfMeasureId,
        unitName: widget.line.unitName,
        defaultPrice: widget.line.parsedPrice ?? 0,
        vatRate: widget.line.vatRate,
        depositAmount: widget.line.depositAmount,
      ),
      ...widget.articles,
    ];
  }

  bool get _isHistoricalArticleMissing =>
      widget.line.articleId > 0 &&
      !widget.articles.any((article) => article.id == widget.line.articleId);

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.line.quantityText);
  }

  @override
  void didUpdateWidget(covariant _EditableOrderLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.quantityText != widget.line.quantityText) {
      _quantityController.text = widget.line.quantityText;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'hr_HR',
      symbol: 'EUR ',
      decimalDigits: 2,
    );
    final selectableArticles = _selectableArticles;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isHistoricalArticleMissing)
              DropdownButtonFormField<int>(
                key: Key('po-line-${widget.lineIndex}-article'),
                initialValue: widget.line.articleId > 0
                    ? widget.line.articleId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Artikl'),
                items: selectableArticles
                    .map(
                      (article) => DropdownMenuItem<int>(
                        value: article.id,
                        child: Text(
                          article.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  final article = selectableArticles.firstWhere(
                    (candidate) => candidate.id == value,
                  );
                  widget.onChanged(
                    widget.line.copyWith(
                      articleId: article.id,
                      articleName: article.name,
                      unitOfMeasureId: article.unitOfMeasureId,
                      unitName: article.unitName,
                      vatRate: article.vatRate,
                      depositAmount: article.depositAmount,
                      priceText: article.defaultPrice == 0
                          ? widget.line.priceText
                          : article.defaultPrice.toStringAsFixed(2),
                    ),
                  );
                },
              )
            else
              Text(
                widget.line.articleName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (_isHistoricalArticleMissing) ...[
              const SizedBox(height: 8),
              Text(
                'Ovaj artikl vise nije u aktivnom katalogu dobavljaca. Mozete ga zadrzati ili odabrati zamjenu.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: Key('po-line-${widget.lineIndex}-quantity'),
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: widget.line.unitName.isEmpty
                          ? 'Kolicina'
                          : 'Kolicina (${widget.line.unitName})',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      widget.onChanged(
                        widget.line.copyWith(quantityText: value),
                      );
                    },
                    validator: (value) {
                      final parsed = _parseLocalizedDecimal(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Unesite kolicinu.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Cijena'),
                    child: Text(
                      currencyFormat.format(widget.line.parsedPrice ?? 0),
                      key: Key('po-line-${widget.lineIndex}-price-label'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Ukloni'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableOrderLine {
  const _EditableOrderLine({
    required this.id,
    required this.articleId,
    required this.articleName,
    required this.unitOfMeasureId,
    required this.unitName,
    required this.quantityText,
    required this.priceText,
    required this.vatRate,
    required this.depositAmount,
    this.packagingQuantities = const <int, String>{},
    this.packagingLabels = const <int, String>{},
  });

  final int? id;
  final int articleId;
  final String articleName;
  final int unitOfMeasureId;
  final String unitName;
  final String quantityText;
  final String priceText;
  final double vatRate;
  final double depositAmount;
  final Map<int, String> packagingQuantities;
  final Map<int, String> packagingLabels;

  double? get parsedQuantity => _parseLocalizedDecimal(quantityText);

  double? get parsedPrice => _parseLocalizedDecimal(priceText);

  double get lineNetTotal => (parsedPrice ?? 0) * (parsedQuantity ?? 0);

  double get lineVatTotal => lineNetTotal * vatRate;

  double get lineDepositTotal => depositAmount * (parsedQuantity ?? 0);

  double get lineGrossTotal => lineNetTotal + lineVatTotal + lineDepositTotal;

  bool get isComplete =>
      articleId > 0 &&
      unitOfMeasureId > 0 &&
      parsedQuantity != null &&
      parsedQuantity! > 0;

  _EditableOrderLine copyWith({
    int? id,
    int? articleId,
    String? articleName,
    int? unitOfMeasureId,
    String? unitName,
    String? quantityText,
    String? priceText,
    double? vatRate,
    double? depositAmount,
    Map<int, String>? packagingQuantities,
    Map<int, String>? packagingLabels,
  }) {
    return _EditableOrderLine(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      articleName: articleName ?? this.articleName,
      unitOfMeasureId: unitOfMeasureId ?? this.unitOfMeasureId,
      unitName: unitName ?? this.unitName,
      quantityText: quantityText ?? this.quantityText,
      priceText: priceText ?? this.priceText,
      vatRate: vatRate ?? this.vatRate,
      depositAmount: depositAmount ?? this.depositAmount,
      packagingQuantities: packagingQuantities ?? this.packagingQuantities,
      packagingLabels: packagingLabels ?? this.packagingLabels,
    );
  }

  Map<String, dynamic> toPayload() {
    final normalizedQuantity = _normalizeDecimalString(quantityText);
    final normalizedPrice = _normalizeDecimalString(priceText);

    return <String, dynamic>{
      if (id != null && id! > 0) 'id': id,
      'artikl': articleId,
      'quantity': normalizedQuantity,
      'unit_of_measure': unitOfMeasureId,
      if (normalizedPrice.isNotEmpty) 'price': normalizedPrice,
    };
  }

  factory _EditableOrderLine.fromPurchaseOrderLine(PurchaseOrderLine line) {
    return _EditableOrderLine(
      id: line.id,
      articleId: line.articleId,
      articleName: line.articleName,
      unitOfMeasureId: line.unitOfMeasureId,
      unitName: line.unitName,
      quantityText: line.quantity.toString(),
      priceText: line.unitPrice == 0 ? '' : line.unitPrice.toStringAsFixed(2),
      vatRate: 0,
      depositAmount: 0,
      packagingQuantities: const <int, String>{},
      packagingLabels: const <int, String>{},
    );
  }

  factory _EditableOrderLine.fromSupplierArticle(
    SupplierArticleDto article, {
    required String quantityText,
    Map<int, String> packagingQuantities = const <int, String>{},
  }) {
    return _EditableOrderLine(
      id: null,
      articleId: article.id,
      articleName: article.name,
      unitOfMeasureId: article.unitOfMeasureId,
      unitName: article.unitName,
      quantityText: quantityText,
      priceText: article.defaultPrice == 0
          ? ''
          : article.defaultPrice.toStringAsFixed(2),
      vatRate: article.vatRate,
      depositAmount: article.depositAmount,
      packagingQuantities: Map<int, String>.from(packagingQuantities),
      packagingLabels: {
        for (final level in article.packagingLevels)
          if (!level.isBase) level.storageKey: level.displayName,
      },
    );
  }
}

class _PurchaseOrderDraftSnapshot {
  const _PurchaseOrderDraftSnapshot({
    required this.supplierId,
    required this.paymentTypeId,
    required this.orderedAt,
    required this.lines,
  });

  final int? supplierId;
  final int? paymentTypeId;
  final String orderedAt;
  final List<_EditableOrderLineSnapshot> lines;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _PurchaseOrderDraftSnapshot &&
        other.supplierId == supplierId &&
        other.paymentTypeId == paymentTypeId &&
        other.orderedAt == orderedAt &&
        _listEquals(other.lines, lines);
  }

  @override
  int get hashCode =>
      Object.hash(supplierId, paymentTypeId, orderedAt, Object.hashAll(lines));
}

class _EditableOrderLineSnapshot {
  const _EditableOrderLineSnapshot({
    required this.id,
    required this.articleId,
    required this.unitOfMeasureId,
    required this.quantity,
    required this.price,
    required this.vatRate,
    required this.depositAmount,
    required this.packagingQuantities,
  });

  final int? id;
  final int articleId;
  final int unitOfMeasureId;
  final String quantity;
  final String price;
  final double vatRate;
  final double depositAmount;
  final Map<int, String> packagingQuantities;

  factory _EditableOrderLineSnapshot.fromLine(_EditableOrderLine line) {
    return _EditableOrderLineSnapshot(
      id: line.id,
      articleId: line.articleId,
      unitOfMeasureId: line.unitOfMeasureId,
      quantity: _normalizeDecimalString(line.quantityText),
      price: _normalizeDecimalString(line.priceText),
      vatRate: line.vatRate,
      depositAmount: line.depositAmount,
      packagingQuantities: _normalizePackagingQuantities(
        line.packagingQuantities,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _EditableOrderLineSnapshot &&
        other.id == id &&
        other.articleId == articleId &&
        other.unitOfMeasureId == unitOfMeasureId &&
        other.quantity == quantity &&
        other.price == price &&
        other.vatRate == vatRate &&
        other.depositAmount == depositAmount &&
        _mapEquals(other.packagingQuantities, packagingQuantities);
  }

  @override
  int get hashCode => Object.hash(
    id,
    articleId,
    unitOfMeasureId,
    quantity,
    price,
    vatRate,
    depositAmount,
    _mapHash(packagingQuantities),
  );
}

class _DraftOrderTotals {
  const _DraftOrderTotals({
    required this.netTotal,
    required this.vatTotal,
    required this.depositTotal,
    required this.grossTotal,
  });

  final double netTotal;
  final double vatTotal;
  final double depositTotal;
  final double grossTotal;

  factory _DraftOrderTotals.fromLines(List<_EditableOrderLine> lines) {
    var netTotal = 0.0;
    var vatTotal = 0.0;
    var depositTotal = 0.0;
    for (final line in lines) {
      netTotal += line.lineNetTotal;
      vatTotal += line.lineVatTotal;
      depositTotal += line.lineDepositTotal;
    }
    return _DraftOrderTotals(
      netTotal: netTotal,
      vatTotal: vatTotal,
      depositTotal: depositTotal,
      grossTotal: netTotal + vatTotal + depositTotal,
    );
  }
}

class _ArticleCatalogGroup {
  _ArticleCatalogGroup({
    required this.title,
    required this.articles,
    required this.sortKey,
    required this.key,
    required this.isUncategorized,
    required this.sortOrder,
  });

  final String title;
  final List<SupplierArticleDto> articles;
  final String sortKey;
  final GlobalKey key;
  final bool isUncategorized;
  final int? sortOrder;
  double? scrollOffset;
}

List<_ArticleCatalogGroup> _buildArticleCatalogGroups(
  List<SupplierArticleDto> articles,
) {
  final grouped = <String, List<SupplierArticleDto>>{};
  final uncategorizedKey = _uncategorizedArticleGroupTitle;
  for (final article in articles) {
    final title = _resolveArticleGroupTitle(article);
    grouped.putIfAbsent(title, () => <SupplierArticleDto>[]).add(article);
  }

  final groups = grouped.entries
      .map(
        (entry) => _ArticleCatalogGroup(
          title: entry.key,
          sortKey: _normalizeSortText(entry.key),
          key: GlobalKey(),
          isUncategorized: entry.key == uncategorizedKey,
          sortOrder: _resolveGroupSortOrder(entry.value),
          articles: entry.value
            ..sort(
              (left, right) => _normalizeSortText(
                left.name,
              ).compareTo(_normalizeSortText(right.name)),
            ),
        ),
      )
      .toList(growable: true);
  groups.sort((left, right) {
    if (left.isUncategorized != right.isUncategorized) {
      return left.isUncategorized ? 1 : -1;
    }
    final leftSortOrder = left.sortOrder;
    final rightSortOrder = right.sortOrder;
    if (leftSortOrder != null && rightSortOrder != null) {
      final bySortOrder = leftSortOrder.compareTo(rightSortOrder);
      if (bySortOrder != 0) {
        return bySortOrder;
      }
    } else if (leftSortOrder != rightSortOrder) {
      return leftSortOrder == null ? 1 : -1;
    }
    return left.sortKey.compareTo(right.sortKey);
  });
  return groups;
}

int? _resolveGroupSortOrder(List<SupplierArticleDto> articles) {
  for (final article in articles) {
    final sortOrder = article.categorySortOrder;
    if (sortOrder != null) {
      return sortOrder;
    }
  }
  return null;
}

List<_EditableOrderLine> _mergeLineMetadataFromArticles(
  List<_EditableOrderLine> lines,
  List<SupplierArticleDto> articles,
) {
  if (lines.isEmpty || articles.isEmpty) {
    return lines;
  }

  return lines
      .map((line) {
        for (final article in articles) {
          if (article.id == line.articleId &&
              article.unitOfMeasureId == line.unitOfMeasureId) {
            return line.copyWith(
              vatRate: article.vatRate,
              depositAmount: article.depositAmount,
            );
          }
        }
        return line;
      })
      .toList(growable: false);
}

List<_EditableOrderLine> _mergeDraftCatalogLine(
  List<_EditableOrderLine> lines,
  _EditableOrderLine incoming,
) {
  final merged = List<_EditableOrderLine>.from(lines);
  for (var index = 0; index < merged.length; index += 1) {
    final existing = merged[index];
    if (existing.articleId != incoming.articleId ||
        existing.unitOfMeasureId != incoming.unitOfMeasureId) {
      continue;
    }

    final quantity =
        (existing.parsedQuantity ?? 0) + (incoming.parsedQuantity ?? 0);
    merged[index] = existing.copyWith(
      quantityText: _formatQuantityValue(quantity),
      articleName: incoming.articleName,
      unitName: incoming.unitName,
      priceText: incoming.priceText,
      vatRate: incoming.vatRate,
      depositAmount: incoming.depositAmount,
      packagingQuantities: _mergePackagingQuantities(
        existing.packagingQuantities,
        incoming.packagingQuantities,
      ),
      packagingLabels: {
        ...existing.packagingLabels,
        ...incoming.packagingLabels,
      },
    );
    return merged;
  }

  merged.add(incoming);
  return merged;
}

bool _isRepresentationPaymentType(String value) {
  final normalized = _normalizeSortText(value);
  return normalized.contains('reprezent');
}

String _formatDateInput(DateTime? value) {
  if (value == null) {
    return '';
  }
  return DateFormat('yyyy-MM-dd').format(value.toLocal());
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

String _formatQuantityValue(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _formatOrderedBaseUnitLabel(String label, double quantity) {
  final normalized = label.trim().toLowerCase();
  if (normalized == 'komad' && quantity != 1) {
    return 'komada';
  }
  return normalized;
}

Map<int, String> _normalizePackagingQuantities(Map<int, String> values) {
  final normalizedEntries =
      values.entries
          .where((entry) => _normalizeDecimalString(entry.value).isNotEmpty)
          .map(
            (entry) =>
                MapEntry(entry.key, _normalizeDecimalString(entry.value)),
          )
          .toList(growable: true)
        ..sort((left, right) => left.key.compareTo(right.key));
  return Map<int, String>.fromEntries(normalizedEntries);
}

Map<int, String> _mergePackagingQuantities(
  Map<int, String> left,
  Map<int, String> right,
) {
  if (left.isEmpty) {
    return _normalizePackagingQuantities(right);
  }
  if (right.isEmpty) {
    return _normalizePackagingQuantities(left);
  }
  final merged = <int, double>{};
  for (final entry in left.entries) {
    final parsed = _parseLocalizedDecimal(entry.value);
    if (parsed == null || parsed <= 0) {
      continue;
    }
    merged[entry.key] = parsed;
  }
  for (final entry in right.entries) {
    final parsed = _parseLocalizedDecimal(entry.value);
    if (parsed == null || parsed <= 0) {
      continue;
    }
    merged.update(
      entry.key,
      (current) => current + parsed,
      ifAbsent: () => parsed,
    );
  }
  final normalizedEntries =
      merged.entries
          .map(
            (entry) => MapEntry(entry.key, _formatQuantityValue(entry.value)),
          )
          .toList(growable: true)
        ..sort(
          (leftEntry, rightEntry) => leftEntry.key.compareTo(rightEntry.key),
        );
  return Map<int, String>.fromEntries(normalizedEntries);
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> left, Map<K, V> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int _mapHash<K, V>(Map<K, V> map) {
  final entries = map.entries.toList(growable: false)
    ..sort((left, right) => left.key.hashCode.compareTo(right.key.hashCode));
  return Object.hashAll(
    entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

String _normalizeSupplierName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _PurchaseOrderAndroidTheme extends StatelessWidget {
  const _PurchaseOrderAndroidTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(platform: TargetPlatform.android),
      child: child,
    );
  }
}

String _resolveArticleGroupTitle(SupplierArticleDto article) {
  final categoryName = article.categoryName?.trim();
  if (categoryName != null && categoryName.isNotEmpty) {
    return categoryName;
  }
  return _uncategorizedArticleGroupTitle;
}

String _normalizeSortText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('\u010d', 'c')
      .replaceAll('\u0107', 'c')
      .replaceAll('\u017e', 'z')
      .replaceAll('\u0161', 's')
      .replaceAll('\u0111', 'd');
}

const String _uncategorizedArticleGroupTitle = 'No category';

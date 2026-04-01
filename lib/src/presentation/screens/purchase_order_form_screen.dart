import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/http/api_client.dart';
import '../../data/purchase_orders/models/payment_type_dto.dart';
import '../../data/purchase_orders/models/supplier_article_dto.dart';
import '../../data/purchase_orders/models/supplier_dto.dart';
import '../../data/purchase_orders/purchase_order_repository.dart';
import '../../domain/purchase_order.dart';
import '../../domain/user_session.dart';

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
  State<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<SupplierDto> _suppliers = const <SupplierDto>[];
  List<PaymentTypeDto> _paymentTypes = const <PaymentTypeDto>[];
  List<SupplierArticleDto> _articles = const <SupplierArticleDto>[];

  int? _selectedSupplierId;
  int? _selectedPaymentTypeId;
  DateTime? _orderedAt;
  late List<_EditableOrderLine> _lines;

  @override
  void initState() {
    super.initState();
    _lines = widget.initialOrder?.lines
            .map(_EditableOrderLine.fromPurchaseOrderLine)
            .toList() ??
        <_EditableOrderLine>[];
    _selectedSupplierId = widget.initialOrder?.supplierId;
    _selectedPaymentTypeId = widget.initialOrder?.paymentTypeId;
    _orderedAt = widget.initialOrder?.orderedAt ?? DateTime.now();
    _dateController.text = _formatDateInput(_orderedAt);
    _loadLookups();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final futures = await Future.wait<dynamic>([
        widget.repository.fetchSuppliers(authToken: widget.session.token),
        widget.repository.fetchPaymentTypes(authToken: widget.session.token),
      ]);

      final suppliers = futures[0] as List<SupplierDto>;
      final paymentTypes = futures[1] as List<PaymentTypeDto>;

      List<SupplierArticleDto> articles = const <SupplierArticleDto>[];
      if (_selectedSupplierId != null) {
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
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Podaci za narudzbu trenutno nisu dostupni. Pokusajte ponovno.';
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
            'Artikli za odabranog dobavljaca trenutno nisu dostupni.';
      });
    }
  }

  void _addLine() {
    setState(() {
      _lines = [
        ..._lines,
        _EditableOrderLine.empty(_articles),
      ];
    });
  }

  Future<void> _pickDate() async {
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSupplierId == null || _selectedPaymentTypeId == null) {
      setState(() {
        _errorMessage = 'Odaberite dobavljaca i tip placanja.';
      });
      return;
    }
    if (_orderedAt == null) {
      setState(() {
        _errorMessage = 'Odaberite datum narudzbe.';
      });
      return;
    }
    if (_lines.isEmpty) {
      setState(() {
        _errorMessage = 'Dodajte barem jednu stavku narudzbe.';
      });
      return;
    }
    for (final line in _lines) {
      if (!line.isComplete) {
        setState(() {
          _errorMessage =
              'Svaka stavka mora imati artikl, kolicinu i jedinicu mjere.';
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
        _errorMessage = 'Spremanje narudzbe nije uspjelo. Pokusajte ponovno.';
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Uredi narudzbu' : 'Nova narudzba';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: _selectedSupplierId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _articles.isEmpty ? null : _addLine,
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
                      DropdownButtonFormField<int>(
                        key: const Key('po-form-supplier'),
                        initialValue: _selectedSupplierId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Dobavljac',
                        ),
                        items: _suppliers
                            .map(
                              (supplier) => DropdownMenuItem<int>(
                                value: supplier.id,
                                child: Text(
                                  supplier.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) async {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedSupplierId = value;
                                });
                                await _loadArticlesForSupplier(value);
                              },
                        validator: (value) =>
                            value == null ? 'Odaberite dobavljaca.' : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        key: const Key('po-form-payment-type'),
                        initialValue: _selectedPaymentTypeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tip placanja',
                        ),
                        items: _paymentTypes
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
                        validator: (value) =>
                            value == null ? 'Odaberite tip placanja.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('po-form-ordered-at'),
                        controller: _dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Datum narudzbe',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: _isSubmitting ? null : _pickDate,
                        validator: (value) =>
                            (value == null || value.isEmpty) ? 'Odaberite datum.' : null,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Stavke',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_lines.isEmpty)
                        const Text('Dodajte stavke nakon odabira dobavljaca.')
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
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const Key('po-form-save'),
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(
                          _isSubmitting ? 'Spremanje...' : 'Spremi narudzbu',
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
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
  late TextEditingController _quantityController;
  late TextEditingController _priceController;

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
        name: widget.line.articleName.isEmpty
            ? 'Nepoznati artikl'
            : '${widget.line.articleName} (vise nije u katalogu)',
        unitOfMeasureId: widget.line.unitOfMeasureId,
        unitName: widget.line.unitName,
        defaultPrice: widget.line.parsedPrice ?? 0,
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
    _priceController = TextEditingController(text: widget.line.priceText);
  }

  @override
  void didUpdateWidget(covariant _EditableOrderLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.quantityText != widget.line.quantityText) {
      _quantityController.text = widget.line.quantityText;
    }
    if (oldWidget.line.priceText != widget.line.priceText) {
      _priceController.text = widget.line.priceText;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectableArticles = _selectableArticles;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              initialValue: widget.line.articleId > 0 ? widget.line.articleId : null,
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
                    priceText: article.defaultPrice == 0
                        ? widget.line.priceText
                        : article.defaultPrice.toStringAsFixed(2),
                  ),
                );
              },
              validator: (value) => value == null ? 'Odaberite artikl.' : null,
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
            TextFormField(
              key: Key('po-line-${widget.lineIndex}-quantity'),
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: widget.line.unitName.isEmpty
                    ? 'Kolicina'
                    : 'Kolicina (${widget.line.unitName})',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                widget.onChanged(widget.line.copyWith(quantityText: value));
              },
              validator: (value) {
                final parsed = _parseLocalizedDecimal(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Unesite kolicinu.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: Key('po-line-${widget.lineIndex}-price'),
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Cijena'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                widget.onChanged(widget.line.copyWith(priceText: value));
              },
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
  });

  final int? id;
  final int articleId;
  final String articleName;
  final int unitOfMeasureId;
  final String unitName;
  final String quantityText;
  final String priceText;

  double? get parsedQuantity => _parseLocalizedDecimal(quantityText);

  double? get parsedPrice => _parseLocalizedDecimal(priceText);

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
  }) {
    return _EditableOrderLine(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      articleName: articleName ?? this.articleName,
      unitOfMeasureId: unitOfMeasureId ?? this.unitOfMeasureId,
      unitName: unitName ?? this.unitName,
      quantityText: quantityText ?? this.quantityText,
      priceText: priceText ?? this.priceText,
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
    );
  }

  factory _EditableOrderLine.empty(List<SupplierArticleDto> articles) {
    if (articles.isEmpty) {
      return const _EditableOrderLine(
        id: null,
        articleId: 0,
        articleName: '',
        unitOfMeasureId: 0,
        unitName: '',
        quantityText: '',
        priceText: '',
      );
    }
    final article = articles.first;
    return _EditableOrderLine(
      id: null,
      articleId: article.id,
      articleName: article.name,
      unitOfMeasureId: article.unitOfMeasureId,
      unitName: article.unitName,
      quantityText: '',
      priceText: article.defaultPrice == 0
          ? ''
          : article.defaultPrice.toStringAsFixed(2),
    );
  }
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

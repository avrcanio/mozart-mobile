import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/http/api_client.dart';
import '../../data/purchase_orders/purchase_order_repository.dart';
import '../../domain/purchase_order.dart';
import '../../domain/user_session.dart';
import '../../domain/warehouse_option.dart';

class PurchaseOrderReceiptScreen extends StatefulWidget {
  const PurchaseOrderReceiptScreen({
    required this.order,
    required this.session,
    required this.repository,
    super.key,
  });

  final PurchaseOrder order;
  final UserSession session;
  final PurchaseOrderRepository repository;

  @override
  State<PurchaseOrderReceiptScreen> createState() =>
      _PurchaseOrderReceiptScreenState();
}

class _PurchaseOrderReceiptScreenState extends State<PurchaseOrderReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentDateController = TextEditingController();
  final _invoiceCodeController = TextEditingController();
  final _deliveryNoteController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  DateTime _documentDate = DateTime.now();
  int? _selectedWarehouseId;
  List<WarehouseOption> _warehouses = const <WarehouseOption>[];
  late final List<_ReceiptLine> _lines;

  @override
  void initState() {
    super.initState();
    _documentDateController.text = _formatDate(_documentDate);
    _lines = widget.order.lines
        .where((line) => line.id > 0 && line.remainingQuantity > 0)
        .map(_ReceiptLine.fromOrderLine)
        .toList();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _documentDateController.dispose();
    _invoiceCodeController.dispose();
    _deliveryNoteController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final warehouses = await widget.repository.fetchWarehouses(
        authToken: widget.session.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _warehouses = warehouses;
        _selectedWarehouseId = warehouses.isNotEmpty ? warehouses.first.id : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Skladista trenutno nisu dostupna. Pokusajte ponovno.';
      });
    }
  }

  Future<void> _pickDocumentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _documentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _documentDate = picked;
      _documentDateController.text = _formatDate(picked);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedWarehouseId == null) {
      setState(() {
        _errorMessage = 'Odaberite skladiste.';
      });
      return;
    }

    final receiptItems = _lines
        .map((line) => line.toPayload())
        .where((payload) => payload != null)
        .cast<Map<String, dynamic>>()
        .toList();

    if (receiptItems.isEmpty) {
      setState(() {
        _errorMessage = 'Unesite barem jednu zaprimljenu kolicinu.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final payload = <String, dynamic>{
      'document_date': _formatDate(_documentDate),
      'warehouse_id': _selectedWarehouseId,
      'invoice_code': _invoiceCodeController.text.trim(),
      'delivery_note': _deliveryNoteController.text.trim(),
      'currency': widget.order.currency,
      if (widget.order.totalNetAmount > 0)
        'expected_total_net': widget.order.totalNetAmount.toStringAsFixed(2),
      'items': receiptItems,
    };

    try {
      await widget.repository.createWarehouseInput(
        orderId: widget.order.id,
        payload: payload,
        authToken: widget.session.token,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Zaprimanje robe nije uspjelo. Pokusajte ponovno.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zaprimanje robe')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Text(
                        'Zaprimanje za ${widget.order.reference}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Potvrdite skladiste i unesite zaprimljene kolicine po stavkama.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
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
                        key: const Key('po-receipt-warehouse'),
                        initialValue: _selectedWarehouseId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Skladiste',
                        ),
                        items: _warehouses
                            .map(
                              (warehouse) => DropdownMenuItem<int>(
                                value: warehouse.id,
                                child: Text(
                                  warehouse.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedWarehouseId = value;
                                });
                              },
                        validator: (value) =>
                            value == null ? 'Odaberite skladiste.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('po-receipt-document-date'),
                        controller: _documentDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Datum dokumenta',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: _isSubmitting ? null : _pickDocumentDate,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('po-receipt-invoice-code'),
                        controller: _invoiceCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Broj racuna',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('po-receipt-delivery-note'),
                        controller: _deliveryNoteController,
                        decoration: const InputDecoration(
                          labelText: 'Otpremnica',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Stavke za zaprimanje',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_lines.isEmpty)
                        const Text('Narudzba nema stavki za zaprimanje.')
                      else
                        ..._lines.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ReceiptLineCard(
                                  index: entry.key,
                                  line: entry.value,
                                ),
                              ),
                            ),
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const Key('po-receipt-submit'),
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(
                          _isSubmitting ? 'Spremanje...' : 'Potvrdi zaprimanje',
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

class _ReceiptLineCard extends StatelessWidget {
  const _ReceiptLineCard({
    required this.index,
    required this.line,
  });

  final int index;
  final _ReceiptLine line;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.articleName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Preostalo: ${_formatQuantity(line.remainingQuantity)} ${line.unitName}'),
            Text('Cijena: ${line.unitPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextFormField(
              key: Key('po-receipt-line-$index-quantity'),
              controller: line.quantityController,
              decoration: InputDecoration(
                labelText: 'Zaprimljeno (${line.unitName})',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = _parseDecimal(value ?? '');
                if (parsed == null) {
                  return 'Unesite kolicinu ili 0.';
                }
                if (parsed < 0) {
                  return 'Kolicina ne moze biti negativna.';
                }
                if (parsed > line.remainingQuantity) {
                  return 'Kolicina ne moze biti veca od preostale.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine {
  _ReceiptLine({
    required this.itemId,
    required this.articleName,
    required this.unitName,
    required this.remainingQuantity,
    required this.unitPrice,
    required String initialQuantityText,
  }) : quantityController = TextEditingController(text: initialQuantityText);

  final int itemId;
  final String articleName;
  final String unitName;
  final double remainingQuantity;
  final double unitPrice;
  final TextEditingController quantityController;

  factory _ReceiptLine.fromOrderLine(PurchaseOrderLine line) {
    return _ReceiptLine(
      itemId: line.id,
      articleName: line.articleName,
      unitName: line.unitName,
      remainingQuantity: line.remainingQuantity,
      unitPrice: line.unitPrice,
      initialQuantityText: _formatQuantity(line.remainingQuantity),
    );
  }

  Map<String, dynamic>? toPayload() {
    final parsed = _parseDecimal(quantityController.text);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return <String, dynamic>{
      'purchase_order_item_id': itemId,
      'received_quantity': parsed.toString(),
      'expected_unit_price': unitPrice.toStringAsFixed(2),
      'confirmed': true,
    };
  }

  void dispose() {
    quantityController.dispose();
  }
}

double? _parseDecimal(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String _formatDate(DateTime value) {
  return DateFormat('yyyy-MM-dd').format(value.toLocal());
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

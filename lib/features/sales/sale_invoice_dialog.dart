import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/db.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

enum SaleInvoiceDialogMode { view, edit, payment, returnGoods, newSale }

class SaleInvoiceDialog extends StatefulWidget {
  final Map<String, dynamic>? sale;
  final SaleInvoiceDialogMode mode;
  final int? branchId;
  const SaleInvoiceDialog({Key? key, this.sale, required this.mode, this.branchId}) : super(key: key);

  @override
  State<SaleInvoiceDialog> createState() => _SaleInvoiceDialogState();
}

class _SaleInvoiceDialogState extends State<SaleInvoiceDialog> {
  late SaleInvoiceDialogMode mode;
  late Map<String, dynamic> sale;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> inventory = [];
  bool loading = true;
  int total = 0;
  int paid = 0;
  int balance = 0;
  String customerName = '';
  String customerContact = '';
  String notes = '';
  DateTime? date;
  bool isCredit = false;
  DateTime? dueDate;

  late TextEditingController customerNameController;
  late TextEditingController customerContactController;
  late TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    mode = widget.mode;
    if (widget.sale != null) {
      sale = Map<String, dynamic>.from(widget.sale!);
      customerName = sale['customer_name'] ?? '';
      customerContact = sale['customer_contact'] ?? '';
      notes = sale['notes'] ?? '';
      date = sale['date'] != null ? DateTime.tryParse(sale['date']) : DateTime.now();
    } else {
      sale = {};
      date = DateTime.now();
    }
    customerNameController = TextEditingController(text: customerName);
    customerContactController = TextEditingController(text: customerContact);
    notesController = TextEditingController(text: notes);
    _loadInventoryAndItems();
  }

  @override
  void dispose() {
    customerNameController.dispose();
    customerContactController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryAndItems() async {
    setState(() { loading = true; });
    final db = await AppDatabase.database;
    inventory = (await db.query('inventory')).map((row) => Map<String, dynamic>.from(row)).toList();
    if (widget.sale != null && sale['id'] != null) {
      items = (await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sale['id']])).map((row) => Map<String, dynamic>.from(row)).toList();
      total = sale['amount'] ?? 0;
      paid = sale['paid'] ?? 0;
      balance = total - paid;
    } else {
      items = [];
      total = 0;
      paid = 0;
      balance = 0;
    }
    setState(() { loading = false; });
  }

  void _recalcTotal() {
    total = items.fold<int>(0, (sum, item) => sum + ((item['total'] ?? 0) as int));
    balance = total - paid;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    return AlertDialog(
      title: Row(
        children: [
          Icon(MdiIcons.fileDocumentOutline, color: Colors.blue, size: 28),
          SizedBox(width: 8),
          Text(mode == SaleInvoiceDialogMode.newSale ? 'New Sale' : 'Invoice #${sale['id'] ?? ''}'),
        ],
      ),
      content: SizedBox(
        width: 800,
        child: loading
            ? SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.blueGrey[50],
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(MdiIcons.account, color: Colors.blueGrey, size: 20),
                                SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: customerNameController,
                                    decoration: InputDecoration(labelText: 'Customer Name'),
                                    enabled: mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale,
                                    onChanged: (v) => customerName = v,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(MdiIcons.phone, color: Colors.blueGrey, size: 18),
                                SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: customerContactController,
                                    decoration: InputDecoration(labelText: 'Contact'),
                                    enabled: mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale,
                                    onChanged: (v) => customerContact = v,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(MdiIcons.calendar, color: Colors.blueGrey, size: 18),
                                SizedBox(width: 6),
                                Text('Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(DateFormat('yyyy-MM-dd').format(date!)),
                                if (mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale)
                                  IconButton(
                                    icon: Icon(MdiIcons.calendarEdit),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: date!,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) setState(() => date = picked);
                                    },
                                  ),
                              ],
                            ),
                            if (mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale)
                              Row(
                                children: [
                                  Checkbox(
                                    value: isCredit,
                                    onChanged: (v) {
                                      setState(() {
                                        isCredit = v ?? false;
                                        if (!isCredit) dueDate = null;
                                      });
                                    },
                                  ),
                                  Text('Credit Sale'),
                                  if (isCredit)
                                    Row(
                                      children: [
                                        SizedBox(width: 12),
                                        Text('Due Date: '),
                                        Text(dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : 'Select'),
                                        IconButton(
                                          icon: Icon(MdiIcons.calendar),
                                          onPressed: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: dueDate ?? DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) setState(() => dueDate = picked);
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                    elevation: 1,
                    margin: EdgeInsets.only(bottom: 12),
                    child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // (Global search bar removed, revert to per-row search only)
                    Row(
                    children: [
                    SizedBox(width: 200, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(width: 8),
                    SizedBox(width: 60, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(width: 8),
                    SizedBox(width: 80, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(width: 8),
                    SizedBox(width: 100, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    ),
                    Divider(),
                    if (mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale)
                    ...items.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                item['qtyController'] ??= TextEditingController(text: item['qty']?.toString() ?? '');
                                item['priceController'] ??= TextEditingController(text: item['price']?.toString() ?? '');
                                final inv = inventory.firstWhere(
                                (inv) => inv['name'].toString().toLowerCase() == (item['stock_name'] ?? '').toString().toLowerCase(),
                                orElse: () => {},
                                );
                                final isRealInventoryItem = inv.isNotEmpty && (item['stock_name'] ?? '').toString().trim().isNotEmpty;
                                final inStock = isRealInventoryItem
                                ? ((inv['qty'] is int) ? inv['qty'] : int.tryParse(inv['qty']?.toString() ?? '') ?? 0)
                                : 0;
                                final isRowOutOfStock = isRealInventoryItem && inStock == 0;
                                return Container(
                                  decoration: isRowOutOfStock ? BoxDecoration(color: Colors.grey.shade200) : null,
                                  child: Opacity(
                                    opacity: isRowOutOfStock ? 0.6 : 1.0,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 200,
                                          child: IgnorePointer(
                                          ignoring: isRowOutOfStock,
                                          child: TypeAheadField<Map<String, dynamic>>(
                                          suggestionsCallback: (pattern) async {
                                          final p = pattern.trim().toLowerCase();
                                          try {
                                          final db = await AppDatabase.database;
                                          final results = await db.query(
                                          'inventory',
                                          where: 'LOWER(name) LIKE ?',
                                          whereArgs: ['%$p%'],
                                          limit: 20,
                                          );
                                          final alreadyInInvoice = items.map((it) => (it['stock_name'] ?? '').toString().toLowerCase()).toSet();
                                          final filtered = results.where((inv) => !alreadyInInvoice.contains(inv['name'].toString().toLowerCase())).toList();
                                          // Sort by best match (startsWith > contains)
                                          filtered.sort((a, b) {
                                          final aName = a['name'].toString().toLowerCase();
                                          final bName = b['name'].toString().toLowerCase();
                                          if (aName.startsWith(p) && !bName.startsWith(p)) return -1;
                                          if (!aName.startsWith(p) && bName.startsWith(p)) return 1;
                                          return aName.compareTo(bName);
                                          });
                                          return filtered;
                                          } catch (e) {
                                          return [];
                                          }
                                          },
                                          itemBuilder: (context, suggestion) {
                                          final price = (suggestion['sale'] is int)
                                          ? suggestion['sale']
                                          : int.tryParse(suggestion['sale']?.toString() ?? '') ?? 0;
                                          final name = suggestion['name'].toString().toLowerCase();
                                          int vStock = (suggestion['qty'] is int)
                                          ? suggestion['qty']
                                          : int.tryParse(suggestion['qty']?.toString() ?? '') ?? 0;
                                          for (final it in items) {
                                          if (it['stock_name']?.toString().toLowerCase() == name) {
                                          int qty = (it['qty'] is int)
                                          ? it['qty']
                                          : int.tryParse(it['qty']?.toString() ?? '') ?? 0;
                                          vStock -= qty;
                                          }
                                          }
                                          final isOutOfStock = vStock <= 0;
                                          return ListTile(
                                          title: Text(
                                          suggestion['name'],
                                          style: isOutOfStock ? TextStyle(color: Colors.grey) : null,
                                          ),
                                          subtitle: Text('UGX $price | In stock: $vStock'),
                                          enabled: !isOutOfStock,
                                          );
                                          },
                                          onSelected: (suggestion) {
                                          final name = suggestion['name'].toString().toLowerCase();
                                          // Prevent duplicate
                                          if (items.any((it) => it != item && (it['stock_name'] ?? '').toString().toLowerCase() == name)) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Item already added to sale.')),
                                          );
                                          return;
                                          }
                                          int vStock = (suggestion['qty'] is int)
                                          ? suggestion['qty']
                                          : int.tryParse(suggestion['qty']?.toString() ?? '') ?? 0;
                                          for (final it in items) {
                                          if (it['stock_name']?.toString().toLowerCase() == name) {
                                          int qty = (it['qty'] is int)
                                          ? it['qty']
                                          : int.tryParse(it['qty']?.toString() ?? '') ?? 0;
                                          vStock -= qty;
                                          }
                                          }
                                          if (vStock <= 0) {
                                          showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                          title: Text('Out of Stock'),
                                          content: Text('This item is out of stock and cannot be added.'),
                                          actions: [
                                          TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text('OK'),
                                          ),
                                          ],
                                          ),
                                          );
                                          return;
                                          }
                                          setState(() {
                                          final price = (suggestion['sale'] is int)
                                          ? suggestion['sale']
                                          : int.tryParse(suggestion['sale']?.toString() ?? '') ?? 0;
                                          item['stock_name'] = suggestion['name'];
                                          item['price'] = price;
                                          item['qty'] = 1;
                                          item['total'] = price;
                                          if (item['qtyController'] == null) {
                                          item['qtyController'] = TextEditingController(text: '1');
                                          } else {
                                          item['qtyController'].text = '1';
                                          }
                                          if (item['priceController'] == null) {
                                          item['priceController'] = TextEditingController(text: price.toString());
                                          } else {
                                          item['priceController'].text = price.toString();
                                          }
                                          // Focus the quantity field after selection
                                          Future.delayed(Duration(milliseconds: 100), () {
                                          if (item['qtyController'] != null) {
                                          FocusScope.of(context).requestFocus(FocusNode());
                                          }
                                          });
                                          _recalcTotal();
                                          });
                                          },
                                          emptyBuilder: (context) => Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text('No item found'),
                                          ),
                                          builder: (context, controller, focusNode) {
                                          controller.text = item['stock_name'] ?? '';
                                          controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                                          return TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                          labelText: 'Search Item',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                          ),
                                          onChanged: (v) {
                                          final vLower = v.trim().toLowerCase();
                                          final inv = inventory.firstWhere(
                                          (inv) => inv['name'].toString().toLowerCase() == vLower,
                                          orElse: () => {},
                                          );
                                          if (v.isEmpty) {
                                          setState(() {
                                          item['stock_name'] = null;
                                          item['price'] = 0;
                                          item['qty'] = 0;
                                          item['total'] = 0;
                                          if (item['priceController'] != null) item['priceController'].text = '0';
                                          if (item['qtyController'] != null) item['qtyController'].text = '0';
                                          });
                                          return;
                                          }
                                          // Prevent duplicate
                                          if (items.any((it) => it != item && (it['stock_name'] ?? '').toString().toLowerCase() == vLower)) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Item already added to sale.')),
                                          );
                                          setState(() {
                                          item['stock_name'] = null;
                                          item['price'] = 0;
                                          item['qty'] = 0;
                                          item['total'] = 0;
                                          if (item['priceController'] != null) item['priceController'].text = '0';
                                          if (item['qtyController'] != null) item['qtyController'].text = '0';
                                          });
                                          return;
                                          }
                                          if (inv.isNotEmpty) {
                                          final inStock = (inv['qty'] is int)
                                          ? inv['qty']
                                          : int.tryParse(inv['qty']?.toString() ?? '') ?? 0;
                                          if (inStock == 0) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                          showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                          title: Text('Out of Stock'),
                                          content: Text('This item is out of stock and cannot be added.'),
                                          actions: [
                                          TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text('OK'),
                                          ),
                                          ],
                                          ),
                                          );
                                          });
                                          setState(() {
                                          item['stock_name'] = null;
                                          item['price'] = 0;
                                          item['qty'] = 0;
                                          item['total'] = 0;
                                          if (item['priceController'] != null) item['priceController'].text = '0';
                                          if (item['qtyController'] != null) item['qtyController'].text = '0';
                                          });
                                          return;
                                          } else {
                                          final price = (inv['sale'] is int)
                                          ? inv['sale']
                                          : int.tryParse(inv['sale']?.toString() ?? '') ?? 0;
                                          setState(() {
                                          item['stock_name'] = inv['name'];
                                          item['price'] = price;
                                          item['qty'] = 1;
                                          item['total'] = price;
                                          if (item['priceController'] == null) {
                                          item['priceController'] = TextEditingController(text: price.toString());
                                          } else {
                                          item['priceController'].text = price.toString();
                                          }
                                          if (item['qtyController'] == null) {
                                          item['qtyController'] = TextEditingController(text: '1');
                                          } else {
                                          item['qtyController'].text = '1';
                                          }
                                          });
                                          }
                                          } else {
                                          setState(() {
                                          item['stock_name'] = v;
                                          item['price'] = 0;
                                          item['qty'] = 0;
                                          item['total'] = 0;
                                          if (item['priceController'] != null) item['priceController'].text = '0';
                                          if (item['qtyController'] != null) item['qtyController'].text = '0';
                                          });
                                          }
                                          },
                                          );
                                          },
                                          ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 60,
                                          child: TextField(
                                            controller: item['qtyController'],
                                            keyboardType: TextInputType.number,
                                            enabled: !isRowOutOfStock,
                                            decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6)),
                                            onChanged: (v) {
                                              setState(() {
                                                int enteredQty = int.tryParse(v) ?? 0;
                                                int inStock = 0;
                                                final inv = inventory.firstWhere(
                                                  (inv) => inv['name'].toString().toLowerCase() == (item['stock_name'] ?? '').toString().toLowerCase(),
                                                  orElse: () => {},
                                                );
                                                if (inv.isNotEmpty) {
                                                  inStock = (inv['qty'] is int)
                                                    ? inv['qty']
                                                    : int.tryParse(inv['qty']?.toString() ?? '') ?? 0;
                                                }
                                                if (enteredQty > inStock && inStock > 0) {
                                                  items[i]['qty'] = inStock;
                                                  item['qtyController'].text = inStock.toString();
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: Text('Stock Limit'),
                                                      content: Text('Cannot sell more than in stock ($inStock).'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: Text('OK'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else {
                                                  items[i]['qty'] = enteredQty;
                                                }
                                                items[i]['total'] = (items[i]['qty'] ?? 0) * (items[i]['price'] ?? 0);
                                                _recalcTotal();
                                              });
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            controller: item['priceController'],
                                            keyboardType: TextInputType.number,
                                            enabled: !isRowOutOfStock,
                                            decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6)),
                                            onChanged: (v) {
                                              setState(() {
                                                items[i]['price'] = int.tryParse(v) ?? 0;
                                                items[i]['total'] = (items[i]['qty'] ?? 0) * (items[i]['price'] ?? 0);
                                                _recalcTotal();
                                              });
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 100,
                                          child: Text('UGX ${item['total'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(MdiIcons.trashCanOutline, color: Colors.red),
                                          tooltip: 'Remove Item',
                                          onPressed: () => setState(() {
                                            items.removeAt(i);
                                            _recalcTotal();
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            if (mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Center(
                                  child: ElevatedButton.icon(
                                    icon: Icon(MdiIcons.plusBox),
                                    label: Text('Add Item'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: items.any((item) {
                                      if (item['stock_name'] != null && (item['qty'] == 0 || item['price'] == 0)) return true;
                                      final inv = inventory.firstWhere(
                                        (inv) => inv['name']?.toString().toLowerCase() == (item['stock_name'] ?? '').toString().toLowerCase(),
                                        orElse: () => {},
                                      );
                                      final inStock = inv.isNotEmpty
                                        ? ((inv['qty'] is int) ? inv['qty'] : int.tryParse(inv['qty']?.toString() ?? '') ?? 0)
                                        : 0;
                                      return (item['stock_name'] != null && inStock == 0);
                                    })
                                        ? null
                                        : () {
                                            setState(() {
                                              items.add({
                                                'stock_name': null,
                                                'qty': 1,
                                                'price': 0,
                                                'total': 0,
                                                'qtyController': TextEditingController(text: '1'),
                                                'priceController': TextEditingController(text: '0'),
                                              });
                                              _recalcTotal();
                                            });
                                          },
                                  ),
                                ),
                              ),
                            if (!(mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale))
                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 200,
                                        child: Text(item['stock_name'] ?? ''),
                                      ),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 60,
                                        child: Text('${item['qty']}', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                                      ),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 80,
                                        child: Text('UGX ${item['price']}', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                                      ),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 100,
                                        child: Text('UGX ${item['total']}', style: TextStyle(fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      color: Colors.amber[50],
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          children: [
                            Icon(MdiIcons.clipboardTextOutline, color: Colors.amber[800], size: 20),
                            SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: notesController,
                                decoration: InputDecoration(
                                  labelText: 'Notes (optional)',
                                  border: InputBorder.none,
                                ),
                                maxLines: 2,
                                enabled: mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale,
                                onChanged: (v) => notes = v,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total: UGX $total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('Paid: UGX $paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('Balance: UGX $balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: balance > 0 ? Colors.red : Colors.green)),
                            ],
                          ),
                          SizedBox(width: 32),
                          SizedBox(
                            width: 180,
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Amount Paid',
                                prefixText: 'UGX ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                setState(() {
                                  paid = int.tryParse(v) ?? 0;
                                  balance = total - paid;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (mode == SaleInvoiceDialogMode.view)
                            Tooltip(
                              message: 'Edit Invoice',
                              child: ElevatedButton.icon(
                                icon: Icon(MdiIcons.pencil),
                                label: Text('Edit'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                onPressed: () => setState(() => mode = SaleInvoiceDialogMode.edit),
                              ),
                            ),
                          if (mode == SaleInvoiceDialogMode.view && balance > 0)
                            Tooltip(
                              message: 'Make Payment',
                              child: ElevatedButton.icon(
                                icon: Icon(MdiIcons.cashPlus),
                                label: Text('Pay'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: () => setState(() => mode = SaleInvoiceDialogMode.payment),
                              ),
                            ),
                          if (mode == SaleInvoiceDialogMode.view)
                            Tooltip(
                              message: 'Return Goods',
                              child: ElevatedButton.icon(
                                icon: Icon(MdiIcons.undoVariant),
                                label: Text('Return'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                                onPressed: () => setState(() => mode = SaleInvoiceDialogMode.returnGoods),
                              ),
                            ),
                          if (mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale)
                            ElevatedButton.icon(
                              icon: Icon(MdiIcons.contentSave),
                              label: Text('Save'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              onPressed: () async {
                                customerName = customerNameController.text.trim();
                                customerContact = customerContactController.text.trim();
                                notes = notesController.text.trim();
                                if (items.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Add at least one item.')),
                                  );
                                  return;
                                }
                                if (paid < total && (customerNameController.text.trim().isEmpty && customerContactController.text.trim().isEmpty)) {
                                  final shouldContinue = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Customer Info Recommended'),
                                      content: Text('This is a credit sale. Enter customer name and contact to follow up on the loan. Proceed without customer info?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: Text('Proceed'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (shouldContinue != true) return;
                                }
                                for (final item in items) {
                                  if (item['stock_name'] == null || item['qty'] == null || item['qty'] <= 0 || item['price'] == null || item['price'] < 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Check all item fields.')),
                                    );
                                    return;
                                  }
                                }
                                final db = await AppDatabase.database;
                                if (mode == SaleInvoiceDialogMode.newSale) {
                                  for (final item in items) {
                                    final inv = await db.query('inventory', where: 'name = ?', whereArgs: [item['stock_name']]);
                                    int inStock = 0;
                                    if (inv.isNotEmpty) {
                                      final row = inv.first;
                                      if (row['qty'] is int) {
                                        inStock = row['qty'] as int;
                                      } else if (row['qty'] != null) {
                                        inStock = int.tryParse(row['qty'].toString()) ?? 0;
                                      }
                                    }
                                    if (item['qty'] > inStock) {
                                      await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Stock Error'),
                                          content: Text('Cannot sell more ${item['stock_name']} than in stock ($inStock).'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                  }
                                  String paymentStatus;
                                  if (paid >= total) {
                                    paymentStatus = 'Fully Paid';
                                  } else if (paid > 0) {
                                    paymentStatus = 'Partially Paid';
                                  } else {
                                    paymentStatus = 'Unpaid';
                                  }
                                  final saleId = await AppDatabase.addSale({
                                    'date': DateFormat('yyyy-MM-dd').format(date!),
                                    'amount': total,
                                    'payment_status': paymentStatus,
                                    'branch_id': widget.branchId,
                                    'customer_name': customerName,
                                    'customer_contact': customerContact,
                                    'notes': notes,
                                    'paid': paid,
                                    'return_status': '',
                                    'is_credit': (paid < total) ? 1 : 0,
                                    'due_date': (paid < total) && dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : null,
                                  });
                                  for (final item in items) {
                                    final inv = inventory.firstWhere(
                                      (inv) => inv['name'] == item['stock_name'] && (widget.branchId == null || inv['branch_id'] == widget.branchId),
                                      orElse: () => <String, dynamic>{},
                                    );
                                    if (inv.isEmpty || inv['id'] == null) {
                                      await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Inventory Error'),
                                          content: Text('Inventory record not found for ${item['stock_name']}. Cannot complete sale.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                    final currentQty = (inv['qty'] ?? 0) is int
                                        ? inv['qty']
                                        : int.tryParse(inv['qty']?.toString() ?? '') ?? 0;
                                    final soldQty = (item['qty'] ?? 0) is int
                                        ? item['qty']
                                        : int.tryParse(item['qty']?.toString() ?? '') ?? 0;
                                    if (soldQty > currentQty) {
                                      await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Stock Error'),
                                          content: Text('Cannot sell more ${item['stock_name']} than in stock ($currentQty).'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                    final newQty = currentQty - soldQty;
                                    await AppDatabase.addSaleItem({
                                      'sale_id': saleId,
                                      'stock_name': item['stock_name'],
                                      'qty': item['qty'],
                                      'price': item['price'],
                                      'total': item['total'],
                                    });
                                    await AppDatabase.updateInventory(inv['id'], {...inv, 'qty': newQty});
                                  }
                                  await _loadInventoryAndItems();
                                } else if (mode == SaleInvoiceDialogMode.edit && sale['id'] != null) {
                                  await db.update('sales', {
                                    'date': DateFormat('yyyy-MM-dd').format(date!),
                                    'amount': total,
                                    'customer_name': customerName,
                                    'customer_contact': customerContact,
                                    'notes': notes,
                                  }, where: 'id = ?', whereArgs: [sale['id']]);
                                  final oldItems = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sale['id']]);
                                  for (final old in oldItems) {
                                    final inv = inventory.firstWhere((inv) => inv['name'] == old['stock_name'], orElse: () => <String, dynamic>{});
                                    if (inv != null) {
                                      final newQty = (inv['qty'] ?? 0) + (old['qty'] ?? 0);
                                      await AppDatabase.updateInventory(inv['id'], {...inv, 'qty': newQty});
                                    }
                                    await AppDatabase.deleteSaleItem(old['id'] as int);
                                  }
                                  for (final item in items) {
                                    await AppDatabase.addSaleItem({
                                      'sale_id': sale['id'],
                                      'stock_name': item['stock_name'],
                                      'qty': item['qty'],
                                      'price': item['price'],
                                      'total': item['total'],
                                    });
                                    final inv = inventory.firstWhere((inv) => inv['name'] == item['stock_name'], orElse: () => <String, dynamic>{});
                                    if (inv != null) {
                                      final newQty = (inv['qty'] ?? 0) - (item['qty'] ?? 0);
                                      await AppDatabase.updateInventory(inv['id'], {...inv, 'qty': newQty});
                                    }
                                  }
                                }
                                Navigator.of(context).pop();
                              },
                            ),
                          ElevatedButton.icon(
                            icon: Icon(MdiIcons.close),
                            label: Text('Close'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

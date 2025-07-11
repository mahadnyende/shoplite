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

  // Persistent controllers for text fields
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

  Future<void> _loadItems() async {
    setState(() { loading = true; });
    if (widget.sale != null && sale['id'] != null) {
      final db = await AppDatabase.database;
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
          Text(mode == SaleInvoiceDialogMode.newSale
              ? 'New Sale'
              : 'Invoice #${sale['id'] ?? ''}'),
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
                    // Customer, Date, Credit
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
                    // Items Table
                    Card(
                      elevation: 1,
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 200,
                                  child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 100,
                                  child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            Divider(),
                            if (mode == SaleInvoiceDialogMode.edit || mode == SaleInvoiceDialogMode.newSale)
                              ...items.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                item['qtyController'] ??= TextEditingController(text: item['qty']?.toString() ?? '');
                                item['priceController'] ??= TextEditingController(text: item['price']?.toString() ?? '');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 200,
                                        child: TypeAheadField<Map<String, dynamic>>(
                                          suggestionsCallback: (pattern) {
                                            // Exclude items already added with full stock
                                            return inventory.where((inv) {
                                              final name = inv['name'].toString().toLowerCase();
                                              final inStock = (inv['qty'] is int)
                                                  ? inv['qty']
                                                  : int.tryParse(inv['qty']?.toString() ?? '') ?? 0;
                                              // If already added with full stock, exclude
                                              final alreadyAdded = items.any((it) =>
                                                it['stock_name']?.toString().toLowerCase() == name && (it['qty'] ?? 0) >= inStock && inStock > 0
                                              );
                                              return name.contains(pattern.toLowerCase()) && !alreadyAdded;
                                            }).toList();
                                          },
                                          itemBuilder: (context, suggestion) {
                                            final price = (suggestion['sale'] is int)
                                                ? suggestion['sale']
                                                : int.tryParse(suggestion['sale']?.toString() ?? '') ?? 0;
                                            final inStock = (suggestion['qty'] is int)
                                                ? suggestion['qty']
                                                : int.tryParse(suggestion['qty']?.toString() ?? '') ?? 0;
                                            final isOutOfStock = inStock == 0;
                                            return ListTile(
                                              title: Text(
                                                suggestion['name'],
                                                style: isOutOfStock
                                                    ? TextStyle(color: Colors.grey)
                                                    : null,
                                              ),
                                              subtitle: Text('UGX $price | In stock: $inStock'),
                                              enabled: !isOutOfStock,
                                            );
                                          },
                                          onSelected: (suggestion) {
                                            final inStock = (suggestion['qty'] is int)
                                                ? suggestion['qty']
                                                : int.tryParse(suggestion['qty']?.toString() ?? '') ?? 0;
                                            if (inStock == 0) {
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
                                              items[i]['stock_name'] = suggestion['name'];
                                              items[i]['price'] = price;
                                              items[i]['qty'] = 1;
                                              items[i]['total'] = price;
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
                                                setState(() {
                                                  items[i]['stock_name'] = v;
                                                  // Auto-fill price if item matches inventory
                                                  final inv = inventory.firstWhere(
                                                    (inv) => inv['name'].toString().toLowerCase() == v.toLowerCase(),
                                                    orElse: () => {},
                                                  );
                                                  if (inv.isNotEmpty) {
                                                    final price = (inv['sale'] is int)
                                                        ? inv['sale']
                                                        : int.tryParse(inv['sale']?.toString() ?? '') ?? 0;
                                                    items[i]['price'] = price;
                                                    items[i]['total'] = (items[i]['qty'] ?? 0) * price;
                                                    if (item['priceController'] == null) {
                                                      item['priceController'] = TextEditingController(text: price.toString());
                                                    } else {
                                                      item['priceController'].text = price.toString();
                                                    }
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          controller: item['qtyController'],
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6)),
                                          onChanged: (v) {
                                            setState(() {
                                              int enteredQty = int.tryParse(v) ?? 0;
                                              // Find available stock for this item
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
                                    onPressed: () {
                                      setState(() {
                                        if (inventory.isNotEmpty) {
                                          final first = inventory[0];
                                          final price = (first['sale'] is int)
                                              ? first['sale']
                                              : int.tryParse(first['sale']?.toString() ?? '') ?? 0;
                                          items.add({
                                            'stock_name': first['name'],
                                            'qty': 1,
                                            'price': price,
                                            'total': price,
                                            'qtyController': TextEditingController(text: '1'),
                                            'priceController': TextEditingController(text: price.toString()),
                                          });
                                        } else {
                                          items.add({
                                            'stock_name': null,
                                            'qty': 1,
                                            'price': 0,
                                            'total': 0,
                                            'qtyController': TextEditingController(text: '1'),
                                            'priceController': TextEditingController(text: '0'),
                                          });
                                        }
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
                                      Expanded(child: Text(item['stock_name'] ?? '')),
                                      SizedBox(width: 8),
                                      Text('${item['qty']}', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                                      SizedBox(width: 8),
                                      Text('UGX ${item['price']}', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                                      SizedBox(width: 8),
                                      Text('UGX ${item['total']}', style: TextStyle(fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Notes
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
                    // Totals and Amount Paid
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
                    // Action Buttons
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
                                // If not fully paid and no customer info, prompt for follow-up
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
                                  // Determine payment status
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
                                  // Insert items
                                  for (final item in items) {
                                    await AppDatabase.addSaleItem({
                                      'sale_id': saleId,
                                      'stock_name': item['stock_name'],
                                      'qty': item['qty'],
                                      'price': item['price'],
                                      'total': item['total'],
                                    });
                                    // Update inventory
                                    final inv = inventory.firstWhere((inv) => inv['name'] == item['stock_name'], orElse: () => <String, dynamic>{});
                                    if (inv != null) {
                                      final newQty = (inv['qty'] ?? 0) - (item['qty'] ?? 0);
                                      await AppDatabase.updateInventory(inv['id'], {...inv, 'qty': newQty});
                                    }
                                  }
                                } else if (mode == SaleInvoiceDialogMode.edit && sale['id'] != null) {
                                  // Update sale
                                  await db.update('sales', {
                                    'date': DateFormat('yyyy-MM-dd').format(date!),
                                    'amount': total,
                                    'customer_name': customerName,
                                    'customer_contact': customerContact,
                                    'notes': notes,
                                  }, where: 'id = ?', whereArgs: [sale['id']]);
                                  // Remove old items and restore inventory
                                  final oldItems = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sale['id']]);
                                  for (final old in oldItems) {
                                    // Restore inventory
                                    final inv = inventory.firstWhere((inv) => inv['name'] == old['stock_name'], orElse: () => <String, dynamic>{});
                                    if (inv != null) {
                                      final newQty = (inv['qty'] ?? 0) + (old['qty'] ?? 0);
                                      await AppDatabase.updateInventory(inv['id'], {...inv, 'qty': newQty});
                                    }
                                    await AppDatabase.deleteSaleItem(old['id'] as int);
                                  }
                                  // Add new items and update inventory
                                  for (final item in items) {
                                    await AppDatabase.addSaleItem({
                                      'sale_id': sale['id'],
                                      'stock_name': item['stock_name'],
                                      'qty': item['qty'],
                                      'price': item['price'],
                                      'total': item['total'],
                                    });
                                    // Update inventory
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
                          if (mode == SaleInvoiceDialogMode.payment)
                            Builder(
                              builder: (context) {
                                final controller = TextEditingController();
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: TextField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Amount to receive',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      icon: Icon(MdiIcons.cashPlus),
                                      label: Text('Receive Payment'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () async {
                                        int pay = int.tryParse(controller.text.trim()) ?? 0;
                                        if (pay <= 0 || pay > balance) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Enter a valid payment amount.')),
                                          );
                                          return;
                                        }
                                        final db = await AppDatabase.database;
                                        final newPaid = paid + pay;
                                        final newStatus = (newPaid >= total) ? 'Fully Paid' : 'Partially Paid';
                                        await db.update('sales', {
                                          'paid': newPaid,
                                          'payment_status': newStatus,
                                        }, where: 'id = ?', whereArgs: [sale['id']]);
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          if (mode == SaleInvoiceDialogMode.returnGoods)
                            Builder(
                              builder: (context) {
                                // Track return quantities for each item
                                final List<TextEditingController> returnControllers = [
                                  for (final item in items)
                                    TextEditingController(text: '0')
                                ];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text('Enter quantity to return for each item:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    ...items.asMap().entries.map((entry) {
                                      final i = entry.key;
                                      final item = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(item['stock_name'] ?? '')),
                                            SizedBox(width: 8),
                                            Text('Sold: ${item['qty']}'),
                                            SizedBox(width: 8),
                                            SizedBox(
                                              width: 80,
                                              child: TextField(
                                                controller: returnControllers[i],
                                                keyboardType: TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: 'Return',
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      icon: Icon(MdiIcons.undoVariant),
                                      label: Text('Process Return'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                                      onPressed: () async {
                                        final db = await AppDatabase.database;
                                        bool anyReturn = false;
                                        for (int i = 0; i < items.length; i++) {
                                          final item = items[i];
                                          int retQty = int.tryParse(returnControllers[i].text.trim()) ?? 0;
                                          if (retQty > 0 && retQty <= (item['qty'] ?? 0)) {
                                            anyReturn = true;
                                            // Update sale item
                                            final newQty = (item['qty'] ?? 0) - retQty;
                                            final newTotal = newQty * (item['price'] ?? 0);
                                            await db.update('sale_items', {
                                              'qty': newQty,
                                              'total': newTotal,
                                            }, where: 'id = ?', whereArgs: [item['id']]);
                                            // Update inventory
                                            final inv = inventory.firstWhere((inv) => inv['name'] == item['stock_name'], orElse: () => <String, dynamic>{});
                                            if (inv != null) {
                                              final invQty = (inv['qty'] ?? 0) + retQty;
                                              await AppDatabase.updateInventory(inv['id'], {...inv, 'qty': invQty});
                                            }
                                          }
                                        }
                                        if (anyReturn) {
                                          await db.update('sales', {
                                            'return_status': 'Returned',
                                          }, where: 'id = ?', whereArgs: [sale['id']]);
                                        }
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
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

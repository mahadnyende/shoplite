import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/db.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class PurchaseFormDialog extends StatefulWidget {
  @override
  _PurchaseFormDialogState createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController amountPaidController = TextEditingController(text: '0');
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> inventory = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final inv = await AppDatabase.getInventory();
    setState(() {
      inventory = inv;
      items = [
        {
          'name': '',
          'qty': 1,
          'price': 0,
          'nameController': TextEditingController(),
          'qtyController': TextEditingController(text: '1'),
          'priceController': TextEditingController(text: '0'),
        },
      ];
      loading = false;
    });
  }

  @override
  void dispose() {
    supplierController.dispose();
    amountPaidController.dispose();
    for (var item in items) {
      item['nameController'].dispose();
      item['qtyController'].dispose();
      item['priceController'].dispose();
    }
    super.dispose();
  }

  void _addItemRow() {
    setState(() {
      items.add({
        'name': '',
        'qty': 1,
        'price': 0,
        'nameController': TextEditingController(),
        'qtyController': TextEditingController(text: '1'),
        'priceController': TextEditingController(text: '0'),
      });
    });
  }

  void _removeItemRow(int i) {
    setState(() {
      items[i]['nameController'].dispose();
      items[i]['qtyController'].dispose();
      items[i]['priceController'].dispose();
      items.removeAt(i);
    });
  }

  int _itemTotal(Map<String, dynamic> item) {
    final qty = int.tryParse(item['qtyController'].text.trim()) ?? 0;
    final price = int.tryParse(item['priceController'].text.trim()) ?? 0;
    return qty * price;
  }

  int get _purchaseTotal => items.fold(0, (sum, item) => sum + _itemTotal(item));

  void _savePurchase() {
    if (!_formKey.currentState!.validate()) return;
    final amountPaid = int.tryParse(amountPaidController.text.trim()) ?? 0;
    Navigator.of(context).pop({
      'supplier': supplierController.text.trim(),
      'date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'amount_paid': amountPaid,
      'items': items.map((item) => {
        'name': item['nameController'].text.trim(),
        'qty': int.tryParse(item['qtyController'].text.trim()) ?? 0,
        'purchase_price': int.tryParse(item['priceController'].text.trim()) ?? 0,
        'total': _itemTotal(item),
      }).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AlertDialog(
        title: Text('New Purchase'),
        content: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      );
    }
    return AlertDialog(
      title: Text('New Purchase'),
      content: SizedBox(
        width: 600, // Increased width
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: supplierController,
                  decoration: InputDecoration(labelText: 'Supplier'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter supplier' : null,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Text('Date: '),
                    Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => selectedDate = picked);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TypeAheadField<Map<String, dynamic>>(
                          suggestionsCallback: (pattern) async {
                            final p = pattern.trim().toLowerCase();
                            return inventory.where((inv) => inv['name'].toString().toLowerCase().contains(p)).toList();
                          },
                          itemBuilder: (context, suggestion) {
                            return ListTile(
                            title: Text(suggestion['name']),
                            subtitle: Text('Last Price: UGX ${suggestion['purchase'] ?? 0} | Qty: ${suggestion['qty'] ?? suggestion['quantity'] ?? 0}'),
                            );
                          },
                          onSelected: (suggestion) {
                            setState(() {
                              item['nameController'].text = suggestion['name'];
                              item['priceController'].text = (suggestion['purchase'] ?? 0).toString();
                            });
                          },
                          builder: (context, controller, focusNode) {
                            controller.text = item['nameController'].text;
                            controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(labelText: 'Item Name'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Enter item' : null,
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: item['qtyController'],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Qty'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Qty';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: item['priceController'],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Purchase Price'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 0) return 'Price';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('UGX ${_itemTotal(item)}', style: TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: items.length > 1 ? () => _removeItemRow(i) : null,
                      ),
                    ],
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Item'),
                    onPressed: _addItemRow,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('UGX $_purchaseTotal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: amountPaidController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Amount Paid to Supplier'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 0) return 'Enter amount';
                    if (n > _purchaseTotal) return 'Cannot pay more than total';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _savePurchase,
          child: Text('Save'),
        ),
      ],
    );
  }
}

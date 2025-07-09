import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';
// import '../../widgets/footer.dart';
import '../../core/db.dart';

class InventoryScreen extends StatefulWidget {
  final int? branchId;
  InventoryScreen({this.branchId});

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String? _sortColumn;
  bool _sortAsc = true;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();

    // Make a mutable copy for sorting
    List<Map<String, dynamic>> sortedInventory = List<Map<String, dynamic>>.from(inventory);
    if (_sortColumn != null) {
      sortedInventory.sort((a, b) {
        dynamic va;
        dynamic vb;
        switch (_sortColumn) {
          case 'no':
            va = sortedInventory.indexOf(a);
            vb = sortedInventory.indexOf(b);
            break;
          case 'name':
            va = (a['name'] ?? '').toString().toLowerCase();
            vb = (b['name'] ?? '').toString().toLowerCase();
            break;
          case 'qty':
            va = (a['qty'] is int) ? a['qty'] as int : int.tryParse(a['qty']?.toString() ?? '') ?? 0;
            vb = (b['qty'] is int) ? b['qty'] as int : int.tryParse(b['qty']?.toString() ?? '') ?? 0;
            break;
          case 'purchase':
            va = (a['purchase'] is int) ? a['purchase'] as int : int.tryParse(a['purchase']?.toString() ?? '') ?? 0;
            vb = (b['purchase'] is int) ? b['purchase'] as int : int.tryParse(b['purchase']?.toString() ?? '') ?? 0;
            break;
          case 'sale':
            va = (a['sale'] is int) ? a['sale'] as int : int.tryParse(a['sale']?.toString() ?? '') ?? 0;
            vb = (b['sale'] is int) ? b['sale'] as int : int.tryParse(b['sale']?.toString() ?? '') ?? 0;
            break;
          case 'unit_profit':
            va = ((a['sale'] ?? 0) - (a['purchase'] ?? 0));
            vb = ((b['sale'] ?? 0) - (b['purchase'] ?? 0));
            break;
          case 'total_profit':
            va = ((a['sale'] ?? 0) - (a['purchase'] ?? 0)) * (a['qty'] ?? 0);
            vb = ((b['sale'] ?? 0) - (b['purchase'] ?? 0)) * (b['qty'] ?? 0);
            break;
          case 'expiry':
            va = a['expiry_date'] ?? '';
            vb = b['expiry_date'] ?? '';
            break;
          default:
            va = '';
            vb = '';
        }
        int cmp;
        if (va is num && vb is num) {
          cmp = va.compareTo(vb);
        } else {
          cmp = va.toString().compareTo(vb.toString());
        }
        return _sortAsc ? cmp : -cmp;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Inventory',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[100]
                    : Colors.grey[850],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (Theme.of(context).brightness == Brightness.light)
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Total items in inventory',
                    child: Row(
                      children: [
                        Icon(MdiIcons.cube, color: Colors.blue[700], size: 22),
                        SizedBox(width: 4),
                        Text(
                          formatter.format(totalQty),
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Tooltip(
                    message: 'Total profit from all inventory items',
                    child: Row(
                      children: [
                        Icon(MdiIcons.cashMultiple, color: Colors.green[700], size: 22),
                        SizedBox(width: 4),
                        Text(
                          'UGX ${formatter.format(totalProfit)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: loading
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header and filters
                  Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Search by name',
                                      prefixIcon: Icon(MdiIcons.magnify),
                                      suffixIcon: search.isNotEmpty
                                          ? (loading
                                              ? Padding(
                                                  padding: const EdgeInsets.all(12.0),
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                )
                                              : IconButton(
                                                  icon: Icon(
                                                    MdiIcons.closeCircleOutline,
                                                    color: Colors.grey[500],
                                                    size: 22,
                                                  ),
                                                  splashRadius: 20,
                                                  tooltip: 'Clear',
                                                  onPressed: () {
                                                    setState(() {
                                                      search = '';
                                                      _nameController.clear();
                                                    });
                                                    _loadInventory();
                                                  },
                                                ))
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                    ),
                                    onChanged: (v) {
                                      if (_searchDebounce?.isActive ?? false)
                                        _searchDebounce!.cancel();
                                      _searchDebounce = Timer(
                                        const Duration(milliseconds: 350),
                                        () async {
                                          setState(() {
                                            search = v;
                                          });
                                          await _loadInventory();
                                        },
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Min Qty',
                                    ),
                                    keyboardType: TextInputType.number,
                                    controller: _minQtyController,
                                    onChanged: (v) {
                                      if (_minQtyDebounce?.isActive ?? false) _minQtyDebounce!.cancel();
                                      _minQtyDebounce = Timer(
                                        const Duration(milliseconds: 350),
                                        () async {
                                          setState(() {
                                            filterMinQty = int.tryParse(v);
                                          });
                                          await _loadInventory();
                                        },
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 6),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Max Qty',
                                    ),
                                    keyboardType: TextInputType.number,
                                    controller: _maxQtyController,
                                    onChanged: (v) {
                                      if (_maxQtyDebounce?.isActive ?? false) _maxQtyDebounce!.cancel();
                                      _maxQtyDebounce = Timer(
                                        const Duration(milliseconds: 350),
                                        () async {
                                          setState(() {
                                            filterMaxQty = int.tryParse(v);
                                          });
                                          await _loadInventory();
                                        },
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 6),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Min Price',
                                    ),
                                    keyboardType: TextInputType.number,
                                    controller: _minPriceController,
                                    onChanged: (v) {
                                      if (_minPriceDebounce?.isActive ?? false) _minPriceDebounce!.cancel();
                                      _minPriceDebounce = Timer(
                                        const Duration(milliseconds: 350),
                                        () async {
                                          setState(() {
                                            filterMinPrice = int.tryParse(v);
                                          });
                                          await _loadInventory();
                                        },
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 6),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Max Price',
                                    ),
                                    keyboardType: TextInputType.number,
                                    controller: _maxPriceController,
                                    onChanged: (v) {
                                      if (_maxPriceDebounce?.isActive ?? false) _maxPriceDebounce!.cancel();
                                      _maxPriceDebounce = Timer(
                                        const Duration(milliseconds: 350),
                                        () async {
                                          setState(() {
                                            filterMaxPrice = int.tryParse(v);
                                          });
                                          await _loadInventory();
                                        },
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.clear),
                                  label: Text('Clear Filters'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    foregroundColor: Colors.black87,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      search = '';
                                      _nameController.clear();
                                      filterMinQty = null;
                                      filterMaxQty = null;
                                      filterMinPrice = null;
                                      filterMaxPrice = null;
                                      // Only clear controllers here
                                      _minQtyController.clear();
                                      _maxQtyController.clear();
                                      _minPriceController.clear();
                                      _maxPriceController.clear();
                                    });
                                    _loadInventory();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    if (errorMsg != null) ...[
                      Text(errorMsg!, style: TextStyle(color: Colors.red)),
                      SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Tooltip(
                          message: 'Add a new inventory item',
                          child: ElevatedButton.icon(
                            icon: Icon(MdiIcons.plus),
                            label: Text('Add New'),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                enableDrag: false,
                                backgroundColor: Colors.transparent,
                                builder: (context) {
                                  final _formKey = GlobalKey<FormState>();
                                  final nameController = TextEditingController();
                                  final qtyController = TextEditingController();
                                  final purchaseController = TextEditingController();
                                  final saleController = TextEditingController();
                                  FocusNode nameFocus = FocusNode();
                                  FocusNode qtyFocus = FocusNode();
                                  FocusNode purchaseFocus = FocusNode();
                                  FocusNode saleFocus = FocusNode();
                                  bool isSubmitting = false;
                                  return StatefulBuilder(
                                    builder: (context, setModalState) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(context).viewInsets.bottom,
                                          left: 0,
                                          right: 0,
                                          top: 0,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).dialogBackgroundColor,
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                          ),
                                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          child: Form(
                                            key: _formKey,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Add Inventory Item',
                                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(MdiIcons.close),
                                                      tooltip: 'Close',
                                                      onPressed: () => Navigator.of(context).pop(),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Divider(),
                                                SizedBox(height: 12),
                                                TextFormField(
                                                  controller: nameController,
                                                  focusNode: nameFocus,
                                                  autofocus: true,
                                                  textInputAction: TextInputAction.next,
                                                  decoration: InputDecoration(
                                                    labelText: 'Stock Name',
                                                    hintText: 'e.g. Sugar',
                                                    prefixIcon: Icon(MdiIcons.cubeOutline),
                                                    border: OutlineInputBorder(),
                                                    helperText: 'Enter the product name',
                                                  ),
                                                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter stock name' : null,
                                                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(qtyFocus),
                                                ),
                                                SizedBox(height: 16),
                                                TextFormField(
                                                  controller: qtyController,
                                                  focusNode: qtyFocus,
                                                  keyboardType: TextInputType.number,
                                                  textInputAction: TextInputAction.next,
                                                  decoration: InputDecoration(
                                                    labelText: 'Quantity',
                                                    hintText: 'e.g. 100',
                                                    prefixIcon: Icon(MdiIcons.counter),
                                                    border: OutlineInputBorder(),
                                                    helperText: 'Enter the quantity in stock',
                                                  ),
                                                  validator: (value) {
                                                    if (value == null || value.trim().isEmpty) return 'Enter quantity';
                                                    final n = int.tryParse(value.trim());
                                                    if (n == null || n < 0) return 'Enter valid quantity';
                                                    return null;
                                                  },
                                                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(purchaseFocus),
                                                ),
                                                SizedBox(height: 16),
                                                // Expiry Date Picker
                                                Builder(
                                                  builder: (context) {
                                                    DateTime? selectedExpiryDate;
                                                    return StatefulBuilder(
                                                      builder: (context, setExpiryState) {
                                                        return Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            TextFormField(
                                                              controller: purchaseController,
                                                              focusNode: purchaseFocus,
                                                              keyboardType: TextInputType.number,
                                                              textInputAction: TextInputAction.next,
                                                              decoration: InputDecoration(
                                                                labelText: 'Purchase Price',
                                                                hintText: 'e.g. 2000',
                                                                prefixIcon: Icon(MdiIcons.cashPlus),
                                                                border: OutlineInputBorder(),
                                                                helperText: 'Enter the purchase price per unit',
                                                              ),
                                                              validator: (value) {
                                                                if (value == null || value.trim().isEmpty) return 'Enter purchase price';
                                                                final n = int.tryParse(value.trim());
                                                                if (n == null || n < 0) return 'Enter valid price';
                                                                return null;
                                                              },
                                                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(saleFocus),
                                                            ),
                                                            SizedBox(height: 16),
                                                            OutlinedButton.icon(
                                                              icon: Icon(MdiIcons.calendarClock, size: 18),
                                                              label: Text(selectedExpiryDate == null ? 'Expiry Date (optional)' : DateFormat('yyyy-MM-dd').format(selectedExpiryDate!)),
                                                              onPressed: () async {
                                                                final picked = await showDatePicker(
                                                                  context: context,
                                                                  initialDate: DateTime.now(),
                                                                  firstDate: DateTime.now().subtract(Duration(days: 1)),
                                                                  lastDate: DateTime.now().add(Duration(days: 3650)),
                                                                );
                                                                if (picked != null) {
                                                                  setExpiryState(() {
                                                                    selectedExpiryDate = picked;
                                                                  });
                                                                }
                                                              },
                                                            ),
                                                            SizedBox(height: 16),
                                                            TextFormField(
                                                              controller: saleController,
                                                              focusNode: saleFocus,
                                                              keyboardType: TextInputType.number,
                                                              textInputAction: TextInputAction.done,
                                                              decoration: InputDecoration(
                                                                labelText: 'Sale Price',
                                                                hintText: 'e.g. 2500',
                                                                prefixIcon: Icon(MdiIcons.cashMultiple),
                                                                border: OutlineInputBorder(),
                                                                helperText: 'Enter the sale price per unit',
                                                              ),
                                                              validator: (value) {
                                                                if (value == null || value.trim().isEmpty) return 'Enter sale price';
                                                                final n = int.tryParse(value.trim());
                                                                if (n == null || n < 0) return 'Enter valid price';
                                                                return null;
                                                              },
                                                              onFieldSubmitted: (_) async {
                                                                if (_formKey.currentState?.validate() ?? false) {
                                                                  setModalState(() => isSubmitting = true);
                                                                  final db = await AppDatabase.database;
                                                                  final name = nameController.text.trim();
                                                                  final qty = int.parse(qtyController.text.trim());
                                                                  final purchase = int.parse(purchaseController.text.trim());
                                                                  final sale = int.parse(saleController.text.trim());
                                                                  final expiry = selectedExpiryDate != null ? DateFormat('yyyy-MM-dd').format(selectedExpiryDate!) : null;
                                                                  final branchId = widget.branchId;
                                                                  final existing = await db.query(
                                                                  'inventory',
                                                                  where: 'LOWER(name) = ? AND branch_id = ? AND expiry_date IS ? OR expiry_date = ?',
                                                                  whereArgs: [name.toLowerCase(), branchId, expiry, expiry],
                                                                  );
                                                                  if (existing.isNotEmpty) {
                                                                  // Update quantity for existing batch
                                                                  final existingItem = existing.first;
                                                                  final newQty = (existingItem['qty'] as int? ?? 0) + qty;
                                                                  await db.update(
                                                                  'inventory',
                                                                  {
                                                                  'qty': newQty,
                                                                  'purchase': purchase, // Optionally update price info
                                                                  'sale': sale,
                                                                  },
                                                                  where: 'id = ?',
                                                                  whereArgs: [existingItem['id']],
                                                                  );
                                                                  Navigator.of(context).pop();
                                                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                                                  SnackBar(content: Text('Inventory batch updated.')),
                                                                  );
                                                                  } else {
                                                                  await db.insert('inventory', {
                                                                  'name': name,
                                                                  'qty': qty,
                                                                  'purchase': purchase,
                                                                  'sale': sale,
                                                                  'branch_id': branchId,
                                                                  'expiry_date': expiry,
                                                                  });
                                                                  Navigator.of(context).pop();
                                                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                                                  SnackBar(content: Text('Inventory item added.')),
                                                                  );
                                                                  }
                                                                  _loadInventory();
                                                                }
                                                              },
                                                            ),
                                                            SizedBox(height: 24),
                                                            SizedBox(
                                                              width: double.infinity,
                                                              child: ElevatedButton.icon(
                                                                icon: isSubmitting
                                                                    ? SizedBox(
                                                                        width: 18,
                                                                        height: 18,
                                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                                      )
                                                                    : Icon(MdiIcons.plus),
                                                                label: Text('Add Item'),
                                                                style: ElevatedButton.styleFrom(
                                                                  padding: EdgeInsets.symmetric(vertical: 14),
                                                                  textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                ),
                                                                onPressed: isSubmitting
                                                                    ? null
                                                                    : () async {
                                                                        if (_formKey.currentState?.validate() ?? false) {
                                                                          setModalState(() => isSubmitting = true);
                                                                          final db = await AppDatabase.database;
                                                                          await db.insert('inventory', {
                                                                            'name': nameController.text.trim(),
                                                                            'qty': int.parse(qtyController.text.trim()),
                                                                            'purchase': int.parse(purchaseController.text.trim()),
                                                                            'sale': int.parse(saleController.text.trim()),
                                                                            'branch_id': widget.branchId,
                                                                            'expiry_date': selectedExpiryDate != null ? DateFormat('yyyy-MM-dd').format(selectedExpiryDate!) : null,
                                                                          });
                                                                          Navigator.of(context).pop();
                                                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                                                            SnackBar(content: Text('Inventory item added.')),
                                                                          );
                                                                          _loadInventory();
                                                                        }
                                                                      },
                                                              ),
                                                            ),
                                                            SizedBox(height: 8),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    // Custom table with expanding width and horizontal scroll
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final tableWidth = constraints.maxWidth;
                          // Proportional widths (sum = 1.0)
                          final colNo = tableWidth * 0.05;
                          final colStockName = tableWidth * 0.16;
                          final colQty = tableWidth * 0.07;
                          final colPurchase = tableWidth * 0.12;
                          final colSale = tableWidth * 0.12;
                          final colUnitProfit = tableWidth * 0.10;
                          final colTotalProfit = tableWidth * 0.12;
                          final colExpiry = tableWidth * 0.12;
                          final colEdit = tableWidth * 0.08;
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            width: double.infinity,
                            child: Column(
                              children: [
                                _buildTableHeader(
                                  colNo,
                                  colStockName,
                                  colQty,
                                  colPurchase,
                                  colSale,
                                  colUnitProfit,
                                  colTotalProfit,
                                  colExpiry,
                                  colEdit,
                                ),
                                Divider(height: 1, thickness: 1),
                                Expanded(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics: ClampingScrollPhysics(),
                                    scrollDirection: Axis.vertical,
                                    itemCount: (addingNew ? 1 : 0) + sortedInventory.length,
                                    itemBuilder: (context, idx) {
                                      if (addingNew && idx == 0) {
                                        return _buildTableRow(
                                          index: -1,
                                          isNew: true,
                                          formatter: formatter,
                                          colNo: colNo,
                                          colStockName: colStockName,
                                          colQty: colQty,
                                          colPurchase: colPurchase,
                                          colSale: colSale,
                                          colUnitProfit: colUnitProfit,
                                          colTotalProfit: colTotalProfit,
                                          colExpiry: colExpiry,
                                          colEdit: colEdit,
                                        );
                                      } else {
                                        final item = sortedInventory[addingNew ? idx - 1 : idx];
                                        return _buildTableRow(
                                          index: addingNew ? idx - 1 : idx,
                                          item: item,
                                          formatter: formatter,
                                          colNo: colNo,
                                          colStockName: colStockName,
                                          colQty: colQty,
                                          colPurchase: colPurchase,
                                          colSale: colSale,
                                          colUnitProfit: colUnitProfit,
                                          colTotalProfit: colTotalProfit,
                                          colExpiry: colExpiry,
                                          colEdit: colEdit,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Footer removed
                  ],
                ),
      ),
    );
  }
  // Table headings as constants
  static const String headingNo = 'No.';
  static const String headingStockName = 'Stock Name';
  static const String headingQuantity = 'Quantity';
  static const String headingPurchasePrice = 'Purchase Price';
  static const String headingSalePrice = 'Sale Price';
  static const String headingUnitProfit = 'Unit Profit';
  static const String headingTotalProfit = 'Total Profit';
  static const String headingExpiry = 'Expiry Date';
  static const String headingEdit = 'Edit';

  List<Map<String, dynamic>> inventory = [];
  String search = '';
  int? filterMinQty;
  int? filterMaxQty;
  int? filterMinPrice;
  int? filterMaxPrice;
  int? editingId;
  bool addingNew = false;
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _saleController = TextEditingController();
  final _minQtyController = TextEditingController();
  final _maxQtyController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  String? errorMsg;
  bool loading = true;
  bool saveEnabled = false;
  Timer? _searchDebounce;
  Timer? _minQtyDebounce;
  Timer? _maxQtyDebounce;
  Timer? _minPriceDebounce;
  Timer? _maxPriceDebounce;

  // Track edited expiry dates for items being edited
  final Map<int, String?> _editedExpiryDates = {};

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void didUpdateWidget(covariant InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _loadInventory();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _minQtyDebounce?.cancel();
    _maxQtyDebounce?.cancel();
    _minPriceDebounce?.cancel();
    _maxPriceDebounce?.cancel();
    _minQtyController.dispose();
    _maxQtyController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
  setState(() {
  loading = true;
  });
  final db = await AppDatabase.database;
  // Auto-move expired items to written_off
  final expired = await db.query(
  'inventory',
  where: 'expiry_date IS NOT NULL AND expiry_date < ?',
  whereArgs: [DateTime.now().toIso8601String().substring(0, 10)],
  );
  for (final item in expired) {
  await db.insert('written_off', {
  'name': item['name'],
  'qty': item['qty'],
  'purchase': item['purchase'],
  'sale': item['sale'],
  'branch_id': item['branch_id'],
  'expiry_date': item['expiry_date'],
  'reason': 'Expired',
  'written_off_at': DateTime.now().toIso8601String(),
  });
  await db.delete('inventory', where: 'id = ?', whereArgs: [item['id']]);
  }
  // Build SQL WHERE clause for filters
  String where = '';
  List<dynamic> whereArgs = [];
  if (widget.branchId != null) {
  where = 'branch_id = ?';
  whereArgs.add(widget.branchId);
  }
  if (search.isNotEmpty) {
  final s = search.toLowerCase();
  if (where.isNotEmpty) where += ' AND ';
  where +=
  '('
  'LOWER(name) LIKE ? OR '
  'CAST(qty AS TEXT) LIKE ? OR '
  'CAST(purchase AS TEXT) LIKE ? OR '
  'CAST(sale AS TEXT) LIKE ?'
  ')';
  whereArgs.addAll(['%$s%', '%$s%', '%$s%', '%$s%']);
  }
  if (filterMinQty != null) {
  if (where.isNotEmpty) where += ' AND ';
  where += 'qty >= ?';
  whereArgs.add(filterMinQty);
  }
  if (filterMaxQty != null) {
  if (where.isNotEmpty) where += ' AND ';
  where += 'qty <= ?';
  whereArgs.add(filterMaxQty);
  }
  if (filterMinPrice != null) {
  if (where.isNotEmpty) where += ' AND ';
  where += 'sale >= ?';
  whereArgs.add(filterMinPrice);
  }
  if (filterMaxPrice != null) {
  if (where.isNotEmpty) where += ' AND ';
  where += 'sale <= ?';
  whereArgs.add(filterMaxPrice);
  }
  final data = await db.query(
  'inventory',
  where: where.isNotEmpty ? where : null,
  whereArgs: where.isNotEmpty ? whereArgs : null,
  orderBy: 'name ASC',
  );
  setState(() {
  inventory = data;
  loading = false;
  });
  }

  int get totalQty => inventory.fold<int>(
    0,
    (sum, item) =>
        sum +
        (item['qty'] is int
            ? item['qty'] as int
            : int.tryParse(item['qty'].toString()) ?? 0),
  );
  int get totalProfit => inventory.fold<int>(
    0,
    (sum, item) =>
        sum +
        (((item['sale'] is int
                    ? item['sale'] as int
                    : int.tryParse(item['sale'].toString()) ?? 0) -
                (item['purchase'] is int
                    ? item['purchase'] as int
                    : int.tryParse(item['purchase'].toString()) ?? 0)) *
            (item['qty'] is int
                ? item['qty'] as int
                : int.tryParse(item['qty'].toString()) ?? 0)),
  );

  void _startEdit(Map<String, dynamic> item) {
    setState(() {
      editingId = item['id'] as int?;
      _nameController.text = item['name'] ?? '';
      _qtyController.text = (item['qty'] ?? '').toString();
      _purchaseController.text = (item['purchase'] ?? '').toString();
      _saleController.text = (item['sale'] ?? '').toString();
      errorMsg = null;
      saveEnabled = false;
    });
  }

  Future<void> _saveEdit(int? id) async {
    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final purchase = int.tryParse(_purchaseController.text.trim()) ?? 0;
    final sale = int.tryParse(_saleController.text.trim()) ?? 0;
    if (name.isEmpty || qty < 0 || purchase < 0 || sale < 0) {
      setState(() {
        errorMsg = 'Invalid input.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid input.')));
      return;
    }
    // Prevent duplicate names (except for the current editing row)
    final db = await AppDatabase.database;
    final dupes = await db.query(
      'inventory',
      where: 'LOWER(name) = ? AND branch_id = ? AND id != ?',
      whereArgs: [name.toLowerCase(), widget.branchId, id ?? -1],
    );
    if (dupes.isNotEmpty) {
      setState(() {
        errorMsg = 'Duplicate stock name.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Duplicate stock name.')));
      return;
    }
    final item = {
      'name': name,
      'qty': qty,
      'purchase': purchase,
      'sale': sale,
      'branch_id': widget.branchId,
      'expiry_date': (id != null && _editedExpiryDates.containsKey(id))
        ? _editedExpiryDates[id]
        : (editingId != null && inventory.any((e) => e['id'] == id))
          ? inventory.firstWhere((e) => e['id'] == id)['expiry_date']
          : null,
    };
    if (id == null) {
      await AppDatabase.addInventory(item);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Stock added.')));
    } else {
      await AppDatabase.updateInventory(id, item);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Stock updated.')));
      // Remove the edited value after saving
      _editedExpiryDates.remove(id);
    }
    setState(() {
      editingId = null;
      errorMsg = null;
      saveEnabled = false;
      addingNew = false;
    });
    await _loadInventory();
  }

  bool _isInputValid() {
    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim()) ?? -1;
    final purchase = int.tryParse(_purchaseController.text.trim()) ?? -1;
    final sale = int.tryParse(_saleController.text.trim()) ?? -1;
    return name.isNotEmpty && qty >= 0 && purchase >= 0 && sale >= 0;
  }

  Widget _buildTableHeader(
    double colNo,
    double colStockName,
    double colQty,
    double colPurchase,
    double colSale,
    double colUnitProfit,
    double colTotalProfit,
    double colExpiry,
    double colEdit,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          _headerCell(_InventoryScreenState.headingNo, colNo, sortKey: 'no'),
          _headerCell(_InventoryScreenState.headingStockName, colStockName, sortKey: 'name'),
          _headerCell(_InventoryScreenState.headingQuantity, colQty, sortKey: 'qty'),
          _headerCell(_InventoryScreenState.headingPurchasePrice, colPurchase, sortKey: 'purchase'),
          _headerCell(_InventoryScreenState.headingSalePrice, colSale, sortKey: 'sale'),
          _headerCell(_InventoryScreenState.headingUnitProfit, colUnitProfit, sortKey: 'unit_profit'),
          _headerCell(_InventoryScreenState.headingTotalProfit, colTotalProfit, sortKey: 'total_profit'),
          _headerCell(_InventoryScreenState.headingExpiry, colExpiry, sortKey: 'expiry'),
          _headerCell(_InventoryScreenState.headingEdit, colEdit),
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width, {String? sortKey}) {
    final isSorted = _sortColumn == sortKey;
    return InkWell(
      onTap: sortKey == null
          ? null
          : () {
              setState(() {
                if (_sortColumn == sortKey) {
                  _sortAsc = !_sortAsc;
                } else {
                  _sortColumn = sortKey;
                  _sortAsc = true;
                }
              });
            },
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Text(
              text,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isSorted)
              Icon(
                _sortAsc ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 18,
                color: Colors.blueGrey,
              ),
          ],
        ),
      ),
    );
  }

  // --- HOVER ROW HIGHLIGHT STATE ---

  int? hoveredRowIndex;

  Widget _buildTableRow({
    required int index,
    Map<String, dynamic>? item,
    bool isNew = false,
    NumberFormat? formatter,
    required double colNo,
    required double colStockName,
    required double colQty,
    required double colPurchase,
    required double colSale,
    required double colUnitProfit,
    required double colTotalProfit,
    required double colExpiry,
    required double colEdit,
  }) {
    final isEditing = item != null && editingId == item['id'];
    final expiryOriginal = item?['expiry_date'] as String? ?? '';
    final expiryEdited = (item?['id'] != null && _editedExpiryDates.containsKey(item?['id']))
        ? _editedExpiryDates[item?['id']] ?? ''
        : expiryOriginal;
    final expiryChanged = expiryEdited != expiryOriginal;
    final isChanged =
        isEditing &&
        (_nameController.text.trim() != (item!['name'] ?? '') ||
            _qtyController.text.trim() != (item['qty'] ?? '').toString() ||
            _purchaseController.text.trim() !=
                (item['purchase'] ?? '').toString() ||
            _saleController.text.trim() != (item['sale'] ?? '').toString() ||
            expiryChanged);
    final canSave = isEditing && _isInputValid() && isChanged;
    final unitProfit = item != null
        ? (item['sale'] ?? 0) - (item['purchase'] ?? 0)
        : 0;
    final totalProfit = item != null ? unitProfit * (item['qty'] ?? 0) : 0;
    final highlight = hoveredRowIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredRowIndex = index),
      onExit: (_) => setState(() => hoveredRowIndex = null),
      child: Container(
        color: highlight ? Colors.blue.withOpacity(0.08) : null,
        child: Row(
          children: [
            _dataCell(isNew ? '' : (index + 1).toString(), colNo),
            _dataCell(
              isEditing || isNew
                  ? SizedBox(
                      width: colStockName - 20,
                      child: TextField(
                        controller: isNew ? _nameController : _nameController,
                        decoration: InputDecoration(hintText: 'Stock Name'),
                        onChanged: (_) => setState(() {
                          saveEnabled = _isInputValid() && (isNew || isChanged);
                        }),
                      ),
                    )
                  : Text(item?['name'] ?? ''),
              colStockName,
            ),
            _dataCell(
              isEditing || isNew
                  ? SizedBox(
                      width: colQty - 20,
                      child: TextField(
                        controller: isNew ? _qtyController : _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(hintText: 'Qty'),
                        onChanged: (_) => setState(() {
                          saveEnabled = _isInputValid() && (isNew || isChanged);
                        }),
                      ),
                    )
                  : Text((item?['qty'] ?? '').toString()),
              colQty,
            ),
            _dataCell(
              isEditing || isNew
                  ? SizedBox(
                      width: colPurchase - 30,
                      child: TextField(
                        controller: isNew
                            ? _purchaseController
                            : _purchaseController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(hintText: 'Purchase'),
                        onChanged: (_) => setState(() {
                          saveEnabled = _isInputValid() && (isNew || isChanged);
                        }),
                      ),
                    )
                  : Text(
                      'UGX ${formatter?.format(item?['purchase'] ?? 0) ?? ''}',
                    ),
              colPurchase,
            ),
            _dataCell(
              isEditing || isNew
                  ? SizedBox(
                      width: colSale - 30,
                      child: TextField(
                        controller: isNew ? _saleController : _saleController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(hintText: 'Sale'),
                        onChanged: (_) => setState(() {
                          saveEnabled = _isInputValid() && (isNew || isChanged);
                        }),
                      ),
                    )
                  : Text('UGX ${formatter?.format(item?['sale'] ?? 0) ?? ''}'),
              colSale,
            ),
            _dataCell(
              isNew
                  ? Text('')
                  : Text('UGX ${formatter?.format(unitProfit) ?? ''}'),
              colUnitProfit,
            ),
            _dataCell(
              isNew
                  ? Text('')
                  : Text('UGX ${formatter?.format(totalProfit) ?? ''}'),
              colTotalProfit,
            ),
            _dataCell(
              isEditing || isNew
                  ? Builder(
                      builder: (context) {
                        DateTime? selectedExpiryDate;
                        if (isEditing) {
                          // Use the locally edited value if present, else the DB value
                          final id = item?['id'] as int?;
                          if (id != null && _editedExpiryDates.containsKey(id)) {
                            final str = _editedExpiryDates[id];
                            if (str != null && str.isNotEmpty) {
                              selectedExpiryDate = DateTime.tryParse(str);
                            }
                          } else if (item?['expiry_date'] != null && (item?['expiry_date'] as String).isNotEmpty) {
                            selectedExpiryDate = DateTime.tryParse(item?['expiry_date']);
                          }
                        }
                        return StatefulBuilder(
                          builder: (context, setExpiryState) {
                            return OutlinedButton.icon(
                              icon: Icon(MdiIcons.calendarClock, size: 18),
                              label: Text(selectedExpiryDate == null ? 'Expiry Date (optional)' : DateFormat('yyyy-MM-dd').format(selectedExpiryDate!)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedExpiryDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(Duration(days: 1)),
                                  lastDate: DateTime.now().add(Duration(days: 3650)),
                                );
                                if (picked != null) {
                                setExpiryState(() {
                                selectedExpiryDate = picked;
                                });
                                // Store the edited value in the local map
                                if (isEditing) {
                                final id = item?['id'] as int?;
                                if (id != null) {
                                _editedExpiryDates[id] = DateFormat('yyyy-MM-dd').format(picked);
                                // Also update parent state to enable save button
                                if (mounted) setState(() {
                                saveEnabled = _isInputValid() && (isNew || (_nameController.text.trim() != (item['name'] ?? '') ||
                                _qtyController.text.trim() != (item['qty'] ?? '').toString() ||
                                _purchaseController.text.trim() != (item['purchase'] ?? '').toString() ||
                                _saleController.text.trim() != (item['sale'] ?? '').toString() ||
                                true)); // expiryChanged is now always true here
                                });
                                }
                                }
                                }
                              },
                            );
                          },
                        );
                      },
                    )
                  : Builder(
                      builder: (context) {
                        String? expiryStr = (item != null && item['expiry_date'] != null && (item['expiry_date'] as String).isNotEmpty)
                            ? item['expiry_date'] as String
                            : null;
                        if (expiryStr == null) return Text('-');
                        DateTime? expiryDate = DateTime.tryParse(expiryStr);
                        final now = DateTime.now();
                        final isClose = expiryDate != null && expiryDate.difference(now).inDays >= 0 && expiryDate.difference(now).inDays <= 30;
                        if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
                        return Text(
                        '$expiryStr (Expired)',
                        style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.bold,
                        ),
                        );
                        }
                        return Text(
                        expiryStr,
                        style: TextStyle(
                        color: isClose ? Colors.orange[800] : null,
                        fontWeight: isClose ? FontWeight.bold : null,
                        ),
                        );
                      },
                    ),
              colExpiry,
            ),
            _dataCell(
              isEditing || isNew
                  ? Row(
                      children: [
                        Tooltip(
                          message: 'Save changes',
                          child: IconButton(
                            icon: Icon(
                              MdiIcons.contentSave,
                              color: saveEnabled ? Colors.green : Colors.grey,
                            ),
                            onPressed: saveEnabled
                                ? () async {
                                    if (isNew) {
                                      await _saveEdit(null);
                                      setState(() {
                                        addingNew = false;
                                      });
                                    } else {
                                      await _saveEdit(item!['id']);
                                    }
                                  }
                                : null,
                          ),
                        ),
                        Tooltip(
                          message: 'Cancel editing',
                          child: IconButton(
                            icon: Icon(MdiIcons.closeCircle, color: Colors.red),
                            onPressed: () => setState(() {
                              if (isNew) {
                                addingNew = false;
                                _nameController.clear();
                                _qtyController.clear();
                                _purchaseController.clear();
                                _saleController.clear();
                                saveEnabled = false;
                              } else {
                                editingId = null;
                              }
                            }),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Tooltip(
                          message: 'Edit this item',
                          child: IconButton(
                            icon: Icon(MdiIcons.pencil),
                            onPressed: () => _startEdit(item!),
                          ),
                        ),
                        Tooltip(
                          message: 'Delete this item',
                          child: IconButton(
                            icon: Icon(MdiIcons.delete, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete Item'),
                                  content: Text(
                                    'Are you sure you want to delete this item?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final db = await AppDatabase.database;
                                await db.delete(
                                  'inventory',
                                  where: 'id = ?',
                                  whereArgs: [item!['id']],
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Item deleted.')),
                                );
                                await _loadInventory();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
              colEdit,
            ),
          ],
        ),
      ),
    );
  }
  }

  Widget _dataCell(dynamic child, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: child is Widget ? child : Text(child.toString()),
    );
  }

  // (build method moved below all variable and method declarations)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:async';
import '../../core/db.dart';
import '../../widgets/app_drawer.dart';

class WrittenOffScreen extends StatefulWidget {
  final int? branchId;
  final Function(int)? onTap;
  final VoidCallback? onLogout;
  const WrittenOffScreen({Key? key, this.branchId, this.onTap, this.onLogout}) : super(key: key);

  @override
  _WrittenOffScreenState createState() => _WrittenOffScreenState();
}

class _WrittenOffScreenState extends State<WrittenOffScreen> {
  List<Map<String, dynamic>> writtenOff = [];
  bool loading = true;
  String search = '';
  DateTime? _startDate;
  DateTime? _endDate;

  String? _sortColumn;
  bool _sortAsc = true;
  int? hoveredRowIndex;

  @override
  void initState() {
    super.initState();
    _loadWrittenOff();
  }

  Future<void> _loadWrittenOff({DateTime? startDate, DateTime? endDate}) async {
    setState(() { loading = true; });
    final db = await AppDatabase.database;
    // Ensure accounting table exists (auto-fix for old DBs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        description TEXT,
        amount INTEGER,
        type TEXT,
        reference_id INTEGER,
        branch_id INTEGER
      )
    ''');
    String where = 'branch_id = ?';
    List whereArgs = [widget.branchId];
    if (startDate != null && endDate != null) {
      where += ' AND written_off_at >= ? AND written_off_at <= ?';
      whereArgs.addAll([
        startDate.toIso8601String(),
        endDate.add(Duration(days: 1)).toIso8601String(), // inclusive
      ]);
    } else if (startDate != null) {
      where += ' AND written_off_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    } else if (endDate != null) {
      where += ' AND written_off_at <= ?';
      whereArgs.add(endDate.add(Duration(days: 1)).toIso8601String());
    }
    final data = await db.query(
      'written_off',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    setState(() {
      writtenOff = data;
      loading = false;
    });
  }

  Future<void> _writeOffFromInventory() async {
    final db = await AppDatabase.database;
    final inventory = await db.query('inventory', where: 'branch_id = ?', whereArgs: [widget.branchId]);
    await showDialog(
      context: context,
      builder: (context) {
        String itemSearch = '';
        List<Map<String, dynamic>> filteredInventory = List.from(inventory);
        final searchController = TextEditingController();
        // Debounce timer
        Timer? debounce;
        // Multi-select state
        Map<int, bool> selected = {};
        Map<int, int> qtys = {};
        Map<int, String> reasons = {};
        Map<int, String?> errors = {};
        return StatefulBuilder(
          builder: (context, setState) {
            void onSearchChanged(String v) {
              if (debounce?.isActive ?? false) debounce!.cancel();
              debounce = Timer(const Duration(milliseconds: 250), () {
                setState(() { itemSearch = v; });
              });
            }
            filteredInventory = itemSearch.isEmpty
                ? List.from(inventory)
                : inventory.where((item) =>
                    (item['name'] ?? '').toString().toLowerCase().contains(itemSearch.toLowerCase())
                  ).toList();
            bool canWriteOff = selected.keys.any((id) {
              final item = inventory.firstWhere((e) => e['id'] == id);
              final int stock = (item['qty'] is int) ? item['qty'] as int : int.tryParse(item['qty'].toString()) ?? 0;
              final int qty = qtys[id] ?? 0;
              final String reason = reasons[id]?.trim() ?? '';
              return qty > 0 && qty <= stock && reason.isNotEmpty;
            });
            return AlertDialog(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              title: Row(
                children: [
                  Icon(MdiIcons.trashCanOutline, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Write Off Items'),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 480,
                child: Column(
                  children: [
                    // Sticky search and controls
                    Material(
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Search item',
                                    prefixIcon: Icon(MdiIcons.magnify),
                                    suffixIcon: itemSearch.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(MdiIcons.closeCircleOutline, color: Colors.grey),
                                            onPressed: () {
                                              searchController.clear();
                                              setState(() { itemSearch = ''; });
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                  ),
                                  onChanged: onSearchChanged,
                                ),
                              ),
                              SizedBox(width: 8),
                              Checkbox(
                                value: filteredInventory.isNotEmpty && filteredInventory.every((item) => selected[item['id'] as int] ?? false),
                                tristate: false,
                                onChanged: (v) {
                                  setState(() {
                                    final check = v ?? false;
                                    for (final item in filteredInventory) {
                                      selected[item['id'] as int] = check;
                                      if (!check) {
                                        qtys.remove(item['id'] as int);
                                        reasons.remove(item['id'] as int);
                                        errors.remove(item['id'] as int);
                                      }
                                    }
                                  });
                                },
                              ),
                              Text('Select All'),
                              SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    for (final item in filteredInventory) {
                                      selected[item['id'] as int] = false;
                                      qtys.remove(item['id'] as int);
                                      reasons.remove(item['id'] as int);
                                      errors.remove(item['id'] as int);
                                    }
                                  });
                                },
                                child: Text('Deselect All'),
                              ),
                            ],
                          ),
                          Divider(height: 1),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: filteredInventory.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(MdiIcons.magnifyClose, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('No items found', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredInventory.length,
                              itemBuilder: (context, i) {
                                final item = filteredInventory[i];
                                final int id = item['id'] as int;
                                final int stock = (item['qty'] is int) ? item['qty'] as int : int.tryParse(item['qty'].toString()) ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        value: selected[id] ?? false,
                                        onChanged: (v) {
                                          setState(() {
                                            selected[id] = v ?? false;
                                            if (!(v ?? false)) {
                                              qtys.remove(id);
                                              reasons.remove(id);
                                              errors.remove(id);
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text('${item['name']}', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Stock: $stock'),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          enabled: selected[id] ?? false,
                                          decoration: InputDecoration(
                                            labelText: 'Qty',
                                            errorText: errors[id],
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                          ),
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(fontSize: 13),
                                          onChanged: (v) {
                                            setState(() {
                                              final qty = int.tryParse(v) ?? 0;
                                              qtys[id] = qty;
                                              if (qty > stock) {
                                                errors[id] = 'Max $stock';
                                              } else if (qty < 0) {
                                                errors[id] = 'Min 0';
                                              } else {
                                                errors.remove(id);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 120,
                                        child: TextField(
                                          enabled: selected[id] ?? false,
                                          decoration: InputDecoration(
                                            labelText: 'Reason',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                          ),
                                          style: TextStyle(fontSize: 13),
                                          onChanged: (v) {
                                            setState(() {
                                              reasons[id] = v;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, right: 8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Selected: ${selected.values.where((v) => v).length}',
                          style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: Icon(MdiIcons.closeCircleOutline, color: Colors.red),
                  onPressed: () => Navigator.of(context).pop(),
                  label: Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: Icon(MdiIcons.trashCan, color: Colors.white),
                  onPressed: canWriteOff
                      ? () async {
                          for (final id in selected.keys.where((k) => selected[k] == true)) {
                            final item = inventory.firstWhere((e) => e['id'] == id);
                            final int stock = (item['qty'] is int) ? item['qty'] as int : int.tryParse(item['qty'].toString()) ?? 0;
                            final int qty = qtys[id] ?? 0;
                            final String reason = reasons[id] ?? '';
                            if (qty <= 0 || qty > stock || reason.trim().isEmpty) continue;
                            final writtenOffId = await db.insert('written_off', {
                              'name': item['name'],
                              'qty': qty,
                              'purchase': item['purchase'],
                              'sale': item['sale'],
                              'branch_id': widget.branchId,
                              'expiry_date': item['expiry_date'],
                              'reason': reason,
                              'written_off_at': DateTime.now().toIso8601String(),
                            });
                            // Insert into accounting
                            final int purchase = (item['purchase'] is int)
                                ? item['purchase'] as int
                                : int.tryParse(item['purchase']?.toString() ?? '') ?? 0;
                            final int totalCost = purchase * qty;
                            await db.insert('accounting', {
                              'date': DateTime.now().toIso8601String(),
                              'description': 'Write Off: ${item['name']} (${reason})',
                              'amount': -totalCost, // negative for loss
                              'type': 'write_off',
                              'reference_id': writtenOffId,
                              'branch_id': widget.branchId,
                            });
                            if (qty == stock) {
                              await db.update('inventory', {'qty': 0}, where: 'id = ?', whereArgs: [item['id']]);
                            } else {
                              await db.update('inventory', {'qty': stock - qty}, where: 'id = ?', whereArgs: [item['id']]);
                            }
                          }
                          _loadWrittenOff();
                          Navigator.of(context).pop();
                        }
                      : null,
                  label: Text('Write Off'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    int _rowTotal(Map<String, dynamic> item) {
      final int qty = (item['qty'] is int) ? item['qty'] as int : int.tryParse(item['qty']?.toString() ?? '') ?? 0;
      final int purchase = (item['purchase'] is int) ? item['purchase'] as int : int.tryParse(item['purchase']?.toString() ?? '') ?? 0;
      return qty * purchase;
    }

    List<Map<String, dynamic>> filtered = search.isEmpty
        ? List<Map<String, dynamic>>.from(writtenOff)
        : writtenOff.where((item) =>
            (item['name'] ?? '').toString().toLowerCase().contains(search.toLowerCase()) ||
            (item['reason'] ?? '').toString().toLowerCase().contains(search.toLowerCase())
          ).toList();

    // Sorting logic
    if (_sortColumn != null) {
      filtered.sort((a, b) {
        dynamic va;
        dynamic vb;
        switch (_sortColumn) {
          case 'no':
            va = filtered.indexOf(a);
            vb = filtered.indexOf(b);
            break;
          case 'name':
            va = (a['name'] ?? '').toString().toLowerCase();
            vb = (b['name'] ?? '').toString().toLowerCase();
            break;
          case 'qty':
            va = (a['qty'] is int) ? a['qty'] as int : int.tryParse(a['qty']?.toString() ?? '') ?? 0;
            vb = (b['qty'] is int) ? b['qty'] as int : int.tryParse(b['qty']?.toString() ?? '') ?? 0;
            break;
          case 'value':
            va = _rowTotal(a);
            vb = _rowTotal(b);
            break;
          case 'reason':
            va = (a['reason'] ?? '').toString().toLowerCase();
            vb = (b['reason'] ?? '').toString().toLowerCase();
            break;
          case 'expiry':
            va = a['expiry_date'] ?? '';
            vb = b['expiry_date'] ?? '';
            break;
          case 'written_off':
            va = a['written_off_at'] ?? '';
            vb = b['written_off_at'] ?? '';
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

    final int grandTotal = filtered.fold(0, (sum, item) => sum + _rowTotal(item));
    final formatter = NumberFormat('#,##0', 'en_US');
    // --- HOVER ROW HIGHLIGHT STATE ---
    // int? hoveredRowIndex; // Now a class field

    return Scaffold(
      drawer: AppDrawer(
        isAdmin: true,
        onTap: (i) {
          Navigator.of(context).pop();
          if (i != 9) {
            Navigator.of(context).pop(i); // Pop WrittenOffScreen and return selected index
          }
        },
        onLogout: widget.onLogout ?? () {},
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(MdiIcons.menuOpen, color: Colors.blueGrey, size: 28),
            tooltip: 'Open navigation menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Icon(MdiIcons.closeOctagonOutline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Written Off Items'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadWrittenOff,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(MdiIcons.plus, color: Colors.white),
        label: Text('Write Off'),
        backgroundColor: Colors.red,
        onPressed: _writeOffFromInventory,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Search written off items',
                                prefixIcon: Icon(MdiIcons.magnify),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (v) => setState(() => search = v),
                            ),
                          ),
                          SizedBox(width: 8),
                          Tooltip(
                            message: 'Total value of written off items',
                            child: Text(
                              'Total: UGX ${formatter.format(grandTotal)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _startDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: Icon(MdiIcons.calendarStart),
                                ),
                                child: Text(_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : 'Select start date'),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _endDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: Icon(MdiIcons.calendarEnd),
                                ),
                                child: Text(_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : 'Select end date'),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: Icon(MdiIcons.filter),
                            label: Text('Filter'),
                            onPressed: () {
                              _loadWrittenOff(startDate: _startDate, endDate: _endDate);
                            },
                          ),
                          if (_startDate != null || _endDate != null)
                            IconButton(
                              icon: Icon(MdiIcons.closeCircleOutline, color: Colors.grey),
                              tooltip: 'Clear Dates',
                              onPressed: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                                _loadWrittenOff();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(MdiIcons.closeOctagonOutline, color: Colors.red, size: 60),
                          SizedBox(height: 12),
                          Text('No written off items found.', style: theme.textTheme.titleMedium),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tableWidth = constraints.maxWidth;
                        final colNo = tableWidth * 0.06;
                        final colName = tableWidth * 0.16;
                        final colQty = tableWidth * 0.08;
                        final colValue = tableWidth * 0.12;
                        final colReason = tableWidth * 0.18;
                        final colExpiry = tableWidth * 0.16;
                        final colWrittenOff = tableWidth * 0.18;
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          width: double.infinity,
                          child: Column(
                            children: [
                              // Table header
                              Container(
                                color: theme.colorScheme.surface,
                                child: Row(
                                  children: [
                                    _headerCell('No.', colNo, MdiIcons.numeric, sortKey: 'no'),
                                    _headerCell('Item', colName, MdiIcons.cubeOutline, sortKey: 'name'),
                                    _headerCell('Qty', colQty, MdiIcons.counter, sortKey: 'qty'),
                                    _headerCell('Value', colValue, MdiIcons.cash, sortKey: 'value'),
                                    _headerCell('Reason', colReason, MdiIcons.textBoxOutline, sortKey: 'reason'),
                                    _headerCell('Expiry', colExpiry, MdiIcons.calendarClock, sortKey: 'expiry'),
                                    _headerCell('Written Off', colWrittenOff, MdiIcons.clockOutline, sortKey: 'written_off'),
                                  ],
                                ),
                              ),
                              Divider(height: 1, thickness: 1),
                              // Table body
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, i) {
                                    final item = filtered[i];
                                    final isExpired = (item['reason'] ?? '').toString().toLowerCase().contains('expired');
                                    final rowColor = i % 2 == 0 ? Colors.grey[50] : Colors.white;
                                    final highlight = hoveredRowIndex == i;
                                    return MouseRegion(
                                      onEnter: (_) => setState(() => hoveredRowIndex = i),
                                      onExit: (_) => setState(() => hoveredRowIndex = null),
                                      child: Container(
                                        color: highlight ? Colors.blue.withOpacity(0.08) : rowColor,
                                        child: Row(
                                          children: [
                                            _dataCell((filtered.length - i).toString(), colNo, fontWeight: FontWeight.bold),
                                            _dataCell(item['name'] ?? '', colName, icon: MdiIcons.cubeOutline),
                                            _dataCell(item['qty'].toString(), colQty),
                                            _dataCell('UGX ${formatter.format(_rowTotal(item))}', colValue),
                                            _dataCell(item['reason'] ?? '', colReason, icon: isExpired ? MdiIcons.clockAlertOutline : MdiIcons.alert, iconColor: isExpired ? Colors.red : Colors.orange),
                                            _dataCell(item['expiry_date'] ?? '-', colExpiry),
                                            _dataCell(item['written_off_at']?.toString().substring(0, 19) ?? '', colWrittenOff),
                                            SizedBox(
                                              width: 40,
                                              child: Tooltip(
                                                message: 'Revert this item to inventory',
                                                child: IconButton(
                                                  icon: Icon(MdiIcons.undo, color: Colors.blueGrey, size: 20),
                                                  tooltip: 'Revert to Inventory',
                                                  onPressed: () async {
                                                    if ((item['reason'] ?? '').toString().toLowerCase().contains('expired')) {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: Text('Cannot Revert'),
                                                          content: Text('Expired items cannot be returned to inventory.'),
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
                                                    final int qty = (item['qty'] is int) ? item['qty'] as int : int.tryParse(item['qty'].toString()) ?? 0;
                                                    final int price = (item['purchase'] is int) ? item['purchase'] as int : int.tryParse(item['purchase']?.toString() ?? '') ?? 0;
                                                    final int total = qty * price;
                                                    final formatter = NumberFormat('#,##0', 'en_US');
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: Text('Revert Write Off'),
                                                        content: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text('Are you sure you want to return this item to inventory?'),
                                                            SizedBox(height: 12),
                                                            Text('Item: ${item['name']}', style: TextStyle(fontWeight: FontWeight.bold)),
                                                            Text('Quantity: $qty'),
                                                            Text('Unit Price: UGX ${formatter.format(price)}'),
                                                            Text('Total Value: UGX ${formatter.format(total)}', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.of(context).pop(false),
                                                            child: Text('Cancel'),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () => Navigator.of(context).pop(true),
                                                            child: Text('Revert'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      final db = await AppDatabase.database;
                                                      // Check if item exists in inventory
                                                      final inv = await db.query('inventory', where: 'name = ? AND branch_id = ?', whereArgs: [item['name'], item['branch_id']]);
                                                      if (inv.isNotEmpty) {
                                                        final invItem = inv.first;
                                                        final int currentQty = (invItem['qty'] is int) ? invItem['qty'] as int : int.tryParse(invItem['qty'].toString()) ?? 0;
                                                        final int addQty = (item['qty'] is int) ? item['qty'] as int : int.tryParse(item['qty'].toString()) ?? 0;
                                                        await db.update('inventory', {'qty': currentQty + addQty}, where: 'id = ?', whereArgs: [invItem['id']]);
                                                      } else {
                                                        // Recreate inventory item if missing
                                                        await db.insert('inventory', {
                                                          'name': item['name'],
                                                          'qty': item['qty'],
                                                          'purchase': item['purchase'],
                                                          'sale': item['sale'],
                                                          'expiry_date': item['expiry_date'],
                                                          'branch_id': item['branch_id'],
                                                        });
                                                      }
                                                      // Remove from written_off
                                                      await db.delete('written_off', where: 'id = ?', whereArgs: [item['id']]);
                                                      _loadWrittenOff();
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _headerCell(String text, double width, IconData icon, {String? sortKey}) {
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
            Icon(icon, size: 18, color: Colors.blueGrey),
            SizedBox(width: 4),
            Flexible(
              child: Row(
                children: [
                  Text(
                    text,
                    style: TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String text, double width, {IconData? icon, Color? iconColor, FontWeight? fontWeight}) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor ?? Colors.blueGrey),
            SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontWeight: fontWeight ?? FontWeight.normal),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

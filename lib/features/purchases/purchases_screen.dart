import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shoplite/core/db.dart';
import 'package:shoplite/features/purchases/purchase_form_dialog.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'dart:typed_data';

class PurchasesScreen extends StatefulWidget {
  final int branchId;
  final int? highlightInvoiceId;
  const PurchasesScreen({Key? key, required this.branchId, this.highlightInvoiceId}) : super(key: key);

  @override
  _PurchasesScreenState createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final ScrollController _scrollController = ScrollController();
  int? highlightedInvoiceId;
  Future<pw.Document> _generateInvoicePdf(
    Map<String, dynamic> purchase,
    List<Map<String, dynamic>> items,
    String businessName,
    String businessAddress,
    String businessContact,
  ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      businessName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(businessAddress),
                    pw.Text(businessContact),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue, width: 2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.blue,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Invoice #: ${purchase['id']}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Date: ${purchase['date']}'),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Supplier: ${purchase['supplier']}'),
            pw.Text('Payment Status: ${purchase['payment_status']}'),
            pw.Text('Delivery Status: ${purchase['delivery_status'] == 'Not Received' ? 'Not Received' : purchase['delivery_status']}'),
            if ((purchase['notes'] ?? '').toString().isNotEmpty)
              pw.Text('Notes: ${purchase['notes']}'),
            pw.SizedBox(height: 12),
            pw.Text(
              'Items',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.Table.fromTextArray(
              headers: ['Stock', 'Qty', 'Price', 'Total'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              data: items
                  .map(
                    (item) => [
                      item['stock_name']?.toString() ?? '',
                      item['qty']?.toString() ?? '',
                      item['purchase_price']?.toString() ?? '',
                      item['total']?.toString() ?? '',
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Total: UGX ${purchase['total'] ?? 0}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Paid: UGX ${purchase['amount_paid'] ?? 0}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Balance: UGX ${(purchase['total'] ?? 0) - (purchase['amount_paid'] ?? 0)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
                ),
                pw.Text('Page 1 of 1'),
              ],
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  Future<void> _showPaymentDialog(Map<String, dynamic> purchase) async {
    final db = await AppDatabase.database;
    final total = purchase['total'] ?? 0;
    final amountPaid = purchase['amount_paid'] ?? 0;
    final balance = total - amountPaid;
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? payWarning;
            void updatePay(String value) {
              int v = int.tryParse(value) ?? 0;
              if (v > balance) {
                v = balance;
                payWarning = 'You cannot pay more than the remaining balance.';
              } else {
                payWarning = null;
              }
              if (v < 0) v = 0;
              controller.text = v.toString();
              controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
              setState(() {});
            }
            return AlertDialog(
              title: Text('Pay Invoice #${purchase['id']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: UGX $total'),
                  Text('Already Paid: UGX $amountPaid'),
                  Text('Balance: UGX $balance'),
                  SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount to Pay',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: updatePay,
                  ),
                  if (payWarning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        payWarning!,
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    int payAmount = int.tryParse(controller.text.trim()) ?? 0;
                    if (payAmount > balance) payAmount = balance;
                    if (payAmount <= 0) return;
                    final newPaid = amountPaid + payAmount;
                    final newStatus = newPaid >= total ? 'Fully Paid' : 'Partially Paid';
                    await db.update(
                      'purchases',
                      {
                        'amount_paid': newPaid,
                        'payment_status': newStatus,
                      },
                      where: 'id = ?',
                      whereArgs: [purchase['id']],
                    );
                    // Insert payment record
                    await db.insert('payments', {
                      'invoice_id': purchase['id'],
                      'amount': payAmount,
                      'date': DateTime.now().toIso8601String(),
                    });
                    Navigator.of(context).pop();
                    await _loadPurchases();
                  },
                  child: Text('Pay'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showReceiveGoodsDialog(Map<String, dynamic> purchase) async {
    final db = await AppDatabase.database;
    final List<Map<String, dynamic>> rawItems = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchase['id']],
    );
    // Make items mutable and add a received_qty field if not present
    final List<Map<String, dynamic>> items = rawItems.map((item) {
      final mutable = Map<String, dynamic>.from(item);
      if (!mutable.containsKey('received_qty')) {
        mutable['received_qty'] = mutable['qty'] ?? 0;
      }
      return mutable;
    }).toList();
    // Helper to auto-select delivery status
    String calcStatus() {
      final total = items.length;
      final fully = items.where((item) => (item['received_qty'] ?? 0) >= (item['qty'] ?? 0)).length;
      final none = items.where((item) => (item['received_qty'] ?? 0) == 0).length;
      if (fully == total) return 'Fully Received';
      if (none == total) return 'Not Received';
      return 'Partially Received';
    }
    String selectedStatus = calcStatus();
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateReceived(int i, String value) {
              int v = int.tryParse(value) ?? 0;
              final maxQty = items[i]['qty'] ?? 0;
              if (v > maxQty) v = maxQty;
              if (v < 0) v = 0;
              items[i]['received_qty'] = v;
              // Update the controller to reflect the capped value
              items[i]['_controller']?.text = v.toString();
              setState(() {
                selectedStatus = calcStatus();
              });
            }
            return AlertDialog(
              title: Text('Receive Items for Invoice #${purchase['id']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      // Use a controller for each item to allow programmatic updates
                      item['_controller'] ??= TextEditingController(text: item['received_qty'].toString());
                      item['_controller'].text = item['received_qty'].toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(child: Text(item['stock_name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                            SizedBox(width: 8),
                            Text('Ordered: ${item['qty']}', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: item['_controller'],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Received',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) => updateReceived(i, v),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Delivery Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Chip(
                          label: Text(selectedStatus),
                          backgroundColor: selectedStatus == 'Fully Received'
                              ? Colors.green.shade100
                              : selectedStatus == 'Partially Received'
                                  ? Colors.orange.shade100
                                  : Colors.red.shade100,
                          labelStyle: TextStyle(
                            color: selectedStatus == 'Fully Received'
                                ? Colors.green.shade900
                                : selectedStatus == 'Partially Received'
                                    ? Colors.orange.shade900
                                    : Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Save received_qty for each item and update inventory
                    for (final item in items) {
                      await db.update(
                        'purchase_items',
                        {'received_qty': item['received_qty']},
                        where: 'id = ?',
                        whereArgs: [item['id']],
                      );
                      // Update inventory: add received_qty to inventory.qty
                      final stockName = item['stock_name'];
                      final receivedQty = item['received_qty'] ?? 0;
                      if (receivedQty > 0) {
                        // Find inventory record for this stock and branch
                        final inv = await db.query(
                          'inventory',
                          where: 'name = ? AND branch_id = ?',
                          whereArgs: [stockName, purchase['branch_id']],
                        );
                        if (inv.isNotEmpty) {
                          final invId = inv.first['id'] as int;
                          final currentQty = inv.first['qty'] as int? ?? 0;
                          await db.update(
                            'inventory',
                            {'qty': currentQty + receivedQty},
                            where: 'id = ?',
                            whereArgs: [invId],
                          );
                        }
                      }
                    }
                    // Save delivery_status
                    await db.update(
                      'purchases',
                      {'delivery_status': selectedStatus},
                      where: 'id = ?',
                      whereArgs: [purchase['id']],
                    );
                    Navigator.of(context).pop();
                    await _loadPurchases();
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  int? hoveredRowIndex;
  List<Map<String, dynamic>> purchases = [];
  String businessName = 'Your Business Name';
  String businessAddress = '123 Business St, City, Country';
  String businessContact = 'Contact: +123456789 | info@business.com';
  String _supplierSearch = '';
  String _deliveryFilter = '';
  String _paymentFilter = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    highlightedInvoiceId = widget.highlightInvoiceId;
    _loadPurchases();
    _loadBusinessDetails();
  }

  @override
  void didUpdateWidget(covariant PurchasesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _loadPurchases();
      _loadBusinessDetails();
    }
  }

  Future<void> _loadBusinessDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      businessName = prefs.getString('business_name') ?? businessName;
      businessAddress = prefs.getString('business_address') ?? businessAddress;
      businessContact = prefs.getString('business_contact') ?? businessContact;
    });
  }

  Future<void> _loadPurchases() async {
    final data = await AppDatabase.getPurchases(branchId: widget.branchId);
    setState(() {
      purchases = data;
    });
  }

  List<Map<String, dynamic>> _filteredSortedPurchases() {
    List<Map<String, dynamic>> filtered = purchases.where((p) {
      final supplierMatch =
          _supplierSearch.isEmpty ||
          (p['supplier']?.toString().toLowerCase().contains(
                _supplierSearch.toLowerCase(),
              ) ??
              false);
      final deliveryMatch =
          _deliveryFilter.isEmpty || (p['delivery_status']?.toString().toLowerCase() == _deliveryFilter.toLowerCase());
      final paymentMatch =
          _paymentFilter.isEmpty || (p['payment_status'] == _paymentFilter);
      final date = p['date'] != null ? DateTime.tryParse(p['date']) : null;
      final fromOk = fromDate == null || (date != null && !date.isBefore(fromDate!));
      final toOk = toDate == null || (date != null && !date.isAfter(toDate!));
      return supplierMatch && deliveryMatch && paymentMatch && fromOk && toOk;
    }).toList();
    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        dynamic aVal;
        dynamic bVal;
        switch (_sortColumnIndex) {
          case 0:
            aVal = a['id'];
            bVal = b['id'];
            break;
          case 1:
            aVal = a['supplier'] ?? '';
            bVal = b['supplier'] ?? '';
            break;
          case 2:
            aVal = a['date'] ?? '';
            bVal = b['date'] ?? '';
            break;
          case 3:
            aVal = a['delivery_status'] ?? '';
            bVal = b['delivery_status'] ?? '';
            break;
          case 4:
            aVal = a['payment_status'] ?? '';
            bVal = b['payment_status'] ?? '';
            break;
          case 5:
            aVal = a['total'] ?? 0;
            bVal = b['total'] ?? 0;
            break;
          case 6:
            aVal = a['amount_paid'] ?? 0;
            bVal = b['amount_paid'] ?? 0;
            break;
          case 7:
            aVal = (a['total'] ?? 0) - (a['amount_paid'] ?? 0);
            bVal = (b['total'] ?? 0) - (b['amount_paid'] ?? 0);
            break;
          default:
            aVal = a['id'];
            bVal = b['id'];
        }
        if (aVal is num && bVal is num) {
          return _sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
        } else if (aVal is String && bVal is String) {
          return _sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
        } else {
          return 0;
        }
      });
    } else {
      // Default: sort by date descending, fallback to id descending
      filtered.sort((a, b) {
        final aDate = a['date'] != null ? DateTime.tryParse(a['date']) : null;
        final bDate = b['date'] != null ? DateTime.tryParse(b['date']) : null;
        if (aDate != null && bDate != null) {
          return bDate.compareTo(aDate); // latest first
        } else {
          // fallback to id descending
          final aId = a['id'] ?? 0;
          final bId = b['id'] ?? 0;
          return bId.compareTo(aId);
        }
      });
    }
    // Move highlighted invoice to top if needed
    if (widget.highlightInvoiceId != null) {
      final idx = filtered.indexWhere((p) => p['id'] == widget.highlightInvoiceId);
      if (idx > 0) {
        final highlighted = filtered.removeAt(idx);
        filtered.insert(0, highlighted);
      }
    }
    return filtered;
  }

  void _sortPurchases(String key, bool ascending, int columnIndex) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Widget _dataCell(dynamic child, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: child is Widget ? child : Text(child.toString()),
    );
  }

  Widget _buildTableHeader(
    double colNo,
    double colSupplier,
    double colDate,
    double colDelivery,
    double colPayment,
    double colTotal,
    double colPaid,
    double colBalance,
    double colActions,
  ) {
    // Column keys and display names
    final columns = [
      {'label': 'No.', 'width': colNo, 'index': 0},
      {'label': 'Supplier', 'width': colSupplier, 'index': 1},
      {'label': 'Date', 'width': colDate, 'index': 2},
      {'label': 'Delivery', 'width': colDelivery, 'index': 3},
      {'label': 'Payment', 'width': colPayment, 'index': 4},
      {'label': 'Total', 'width': colTotal, 'index': 5},
      {'label': 'Paid', 'width': colPaid, 'index': 6},
      {'label': 'Balance', 'width': colBalance, 'index': 7},
      {'label': 'Actions', 'width': colActions, 'index': null},
    ];
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: columns.map((col) {
          if (col['index'] == null) {
            return _dataCell(col['label'], col['width'] as double);
          }
          final idx = col['index'] as int;
          final isSorted = _sortColumnIndex == idx;
          final icon = isSorted
              ? (_sortAscending
                  ? Icons.arrow_drop_up
                  : Icons.arrow_drop_down)
              : null;
          return GestureDetector(
            onTap: () {
              final ascending = _sortColumnIndex == idx ? !_sortAscending : true;
              _sortPurchases(col['label'].toString(), ascending, idx);
            },
            child: Container(
              width: col['width'] as double,
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(col['label'].toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                  if (icon != null) Icon(icon, size: 18),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final filteredPurchases = _filteredSortedPurchases();
    return Scaffold(
      appBar: AppBar(
        title: Text('Purchases'),
        actions: [
          Tooltip(
            message: 'Export Purchases List to PDF',
            child: IconButton(
              icon: Icon(MdiIcons.filePdfBox),
              onPressed: _exportPurchasesListToPdf,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Search by supplier',
                            prefixIcon: Icon(MdiIcons.magnify),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          ),
                          onChanged: (v) {
                            setState(() {
                              _supplierSearch = v;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _deliveryFilter.isEmpty ? null : _deliveryFilter,
                          decoration: InputDecoration(
                            labelText: 'Delivery',
                            isDense: true,
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade100 : Colors.grey.shade800,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          style: TextStyle(fontSize: 13),
                          items: [
                            DropdownMenuItem(
                              value: '',
                              child: Builder(
                                builder: (context) => Text('All', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Fully Received',
                              child: Builder(
                                builder: (context) => Text('Fully Received', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Partially Received',
                              child: Builder(
                                builder: (context) => Text('Partially Received', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Not Received',
                              child: Builder(
                                builder: (context) => Text('Not Received', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _deliveryFilter = v ?? '';
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _paymentFilter.isEmpty ? null : _paymentFilter,
                          decoration: InputDecoration(
                            labelText: 'Payment',
                            isDense: true,
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade100 : Colors.grey.shade800,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          style: TextStyle(fontSize: 13),
                          items: [
                            DropdownMenuItem(
                              value: '',
                              child: Builder(
                                builder: (context) => Text('All', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Fully Paid',
                              child: Builder(
                                builder: (context) => Text('Fully Paid', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Partially Paid',
                              child: Builder(
                                builder: (context) => Text('Partially Paid', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Unpaid',
                              child: Builder(
                                builder: (context) => Text('Unpaid', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _paymentFilter = v ?? '';
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Tooltip(
                        message: 'Add New Purchase',
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.plus),
                          label: Text('Add New'),
                          onPressed: _showNewPurchaseDialog,
                        ),
                      ),
                      SizedBox(width: 8),
                      Tooltip(
                        message: 'Reset Filters',
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text('Reset'),
                          onPressed: () {
                            setState(() {
                              _supplierSearch = '';
                              _deliveryFilter = '';
                              _paymentFilter = '';
                              fromDate = null;
                              toDate = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = constraints.maxWidth;
                  final colNo = tableWidth * 0.07;
                  final colSupplier = tableWidth * 0.13; // reduced from 0.18
                  final colDate = tableWidth * 0.09;     // reduced from 0.13
                  final colDelivery = tableWidth * 0.10; // reduced from 0.15
                  final colPayment = tableWidth * 0.09;  // reduced from 0.13
                  final colTotal = tableWidth * 0.14;
                  final colPaid = tableWidth * 0.14;
                  final colBalance = tableWidth * 0.10;
                  final colActions = tableWidth * 0.11;
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
                          colSupplier,
                          colDate,
                          colDelivery,
                          colPayment,
                          colTotal,
                          colPaid,
                          colBalance,
                          colActions,
                        ),
                        Divider(height: 1, thickness: 1),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            physics: ClampingScrollPhysics(),
                            scrollDirection: Axis.vertical,
                            itemCount: filteredPurchases.length,
                            itemBuilder: (context, idx) {
                              final purchase = filteredPurchases[idx];
                              final highlight = hoveredRowIndex == idx || (highlightedInvoiceId != null && purchase['id'] == highlightedInvoiceId);
                              final balance = (purchase['total'] ?? 0) - (purchase['amount_paid'] ?? 0);
                              // Scroll to highlighted invoice after build
                              if (highlightedInvoiceId != null && purchase['id'] == highlightedInvoiceId) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _scrollController.animateTo(
                                    idx * 56.0, // Approximate row height
                                    duration: Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                  );
                                  setState(() {
                                    highlightedInvoiceId = null;
                                  });
                                });
                              }
                              return MouseRegion(
                                onEnter: (_) => setState(() => hoveredRowIndex = idx),
                                onExit: (_) => setState(() => hoveredRowIndex = null),
                                child: Container(
                                  decoration: highlight
                                      ? BoxDecoration(
                                          color: Colors.orange.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(6),
                                        )
                                      : null,
                                  width: double.infinity,
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _dataCell((purchase['id'] ?? '').toString(), colNo),
                                        _dataCell(
                                          Text(
                                            purchase['supplier'] ?? '',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          colSupplier,
                                        ),
                                        _dataCell(
                                          Text(
                                            purchase['date'] ?? '',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          colDate,
                                        ),
                                        _dataCell(
                                          Chip(
                                            label: Text(
                                              purchase['delivery_status'] ?? '',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            backgroundColor: purchase['delivery_status'] == 'Fully Received'
                                                ? Colors.green.shade100
                                                : purchase['delivery_status'] == 'Partially Received'
                                                    ? Colors.orange.shade100
                                                    : Colors.red.shade100,
                                            labelStyle: TextStyle(
                                              color: purchase['delivery_status'] == 'Fully Received'
                                                  ? Colors.green.shade900
                                                  : purchase['delivery_status'] == 'Partially Received'
                                                      ? Colors.orange.shade900
                                                      : Colors.red.shade900,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          colDelivery,
                                        ),
                                        _dataCell(
                                          Chip(
                                            label: Text(
                                              purchase['payment_status'] ?? '',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            backgroundColor: purchase['payment_status'] == 'Fully Paid'
                                                ? Colors.green.shade100
                                                : purchase['payment_status'] == 'Partially Paid'
                                                    ? Colors.orange.shade100
                                                    : Colors.red.shade100,
                                            labelStyle: TextStyle(
                                              color: purchase['payment_status'] == 'Fully Paid'
                                                  ? Colors.green.shade900
                                                  : purchase['payment_status'] == 'Partially Paid'
                                                      ? Colors.orange.shade900
                                                      : Colors.red.shade900,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          colPayment,
                                        ),
                                        _dataCell('UGX ${formatter.format(purchase['total'] ?? 0)}', colTotal),
                                        _dataCell('UGX ${formatter.format(purchase['amount_paid'] ?? 0)}', colPaid),
                                        _dataCell(
                                          Text(
                                            'UGX ${formatter.format(balance)}',
                                            style: TextStyle(
                                              color: balance > 0 ? Colors.red : Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          colBalance,
                                        ),
                                        _dataCell(
                                          Row(
                                            children: [
                                              Tooltip(
                                                message: 'View Invoice',
                                                child: IconButton(
                                                  icon: Icon(MdiIcons.eye),
                                                  color: Colors.blue,
                                                  onPressed: () => _showViewInvoiceDialog(purchase),
                                                ),
                                              ),
                                              Tooltip(
                                                message: 'Edit Invoice',
                                                child: IconButton(
                                                  icon: Icon(MdiIcons.pencil),
                                                  color: Colors.orange,
                                                  onPressed: () => _showEditPurchaseDialog(purchase),
                                                ),
                                              ),
                                            ],
                                          ),
                                          colActions,
                                        ),
                                      ],
                                    ),
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
      ),
    );
  }

  // --- Restore missing methods for functionality ---

  Future<void> _exportPurchasesListToPdf() async {
    await _loadBusinessDetails();
    final pdf = pw.Document();
    final now = DateTime.now();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              businessName,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(businessAddress),
            pw.Text(businessContact),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Purchases List',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: [
                'Invoice No.',
                'Supplier',
                'Date',
                'Delivery',
                'Payment',
                'Total',
                'Paid',
                'Balance',
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              data: purchases
                  .map(
                    (purchase) => [
                      purchase['id']?.toString() ?? '',
                      purchase['supplier']?.toString() ?? '',
                      purchase['date']?.toString() ?? '',
                      purchase['delivery_status'] == 'Not Received' ? 'Not Received' : purchase['delivery_status']?.toString() ?? '',
                      purchase['payment_status']?.toString() ?? '',
                      purchase['total']?.toString() ?? '',
                      purchase['amount_paid']?.toString() ?? '',
                      ((purchase['total'] ?? 0) - (purchase['amount_paid'] ?? 0)).toString(),
                    ],
                  )
                  .toList(),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
                ),
                pw.Text('Page 1 of 1'),
              ],
            ),
          ],
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'purchases_list.pdf',
    );
  }

  Future<void> _showNewPurchaseDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PurchaseFormDialog(),
    );
    if (result == null) return;
    final db = await AppDatabase.database;
    final supplier = result['supplier'] ?? '';
    final date = result['date'] ?? DateTime.now().toString();
    final items = List<Map<String, dynamic>>.from(result['items'] ?? []);
    final total = items.fold<int>(0, (sum, item) => sum + ((item['total'] ?? 0) as int));
    // Insert purchase
    final purchaseId = await db.insert('purchases', {
      'supplier': supplier,
      'date': date,
      'total': total,
      'amount_paid': 0,
      'payment_status': 'Unpaid',
      'delivery_status': 'Not Received',
      'branch_id': widget.branchId,
    });
    // Insert items
    for (final item in items) {
      await db.insert('purchase_items', {
        'purchase_id': purchaseId,
        'stock_name': item['name'],
        'qty': item['qty'],
        'purchase_price': item['purchase_price'],
        'total': item['total'],
        'received_qty': 0,
      });
    }
    await _loadPurchases();
  }

  Future<void> _showViewInvoiceDialog(Map<String, dynamic> purchase) async {
    await _loadBusinessDetails();
    final db = await AppDatabase.database;
    final List<Map<String, dynamic>> items = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchase['id']],
    );
    final balance = (purchase['total'] ?? 0) - (purchase['amount_paid'] ?? 0);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(MdiIcons.eye, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('Invoice #${purchase['id']}'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business and Invoice Info
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(businessName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(businessAddress, style: TextStyle(color: Colors.blueGrey[700], fontSize: 13)),
                      Text(businessContact, style: TextStyle(color: Colors.blueGrey[700], fontSize: 13)),
                      Divider(height: 18),
                      Row(
                        children: [
                          Icon(MdiIcons.account, size: 18, color: Colors.blueGrey),
                          SizedBox(width: 4),
                          Text('Supplier: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${purchase['supplier']}'),
                          Spacer(),
                          Icon(MdiIcons.calendar, size: 18, color: Colors.blueGrey),
                          SizedBox(width: 4),
                          Text('Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${purchase['date']}'),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(MdiIcons.cashMultiple, size: 18, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Payment: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Chip(
                            label: Text(purchase['payment_status'] ?? ''),
                            backgroundColor: purchase['payment_status'] == 'Fully Paid'
                                ? Colors.green.shade100
                                : purchase['payment_status'] == 'Partially Paid'
                                    ? Colors.orange.shade100
                                    : Colors.red.shade100,
                            labelStyle: TextStyle(
                              color: purchase['payment_status'] == 'Fully Paid'
                                  ? Colors.green.shade900
                                  : purchase['payment_status'] == 'Partially Paid'
                                      ? Colors.orange.shade900
                                      : Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          Icon(MdiIcons.truckDelivery, size: 18, color: Colors.blue),
                          SizedBox(width: 4),
                          Text('Delivery: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Chip(
                            label: Text(
                              purchase['delivery_status'] == 'Not Received'
                                  ? 'Not Received'
                                  : purchase['delivery_status'] ?? ''),
                            backgroundColor: purchase['delivery_status'] == 'Fully Received'
                                ? Colors.green.shade100
                                : purchase['delivery_status'] == 'Partially Received'
                                    ? Colors.orange.shade100
                                    : Colors.red.shade100,
                            labelStyle: TextStyle(
                              color: purchase['delivery_status'] == 'Fully Received'
                                  ? Colors.green.shade900
                                  : purchase['delivery_status'] == 'Partially Received'
                                      ? Colors.orange.shade900
                                      : Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if ((purchase['notes'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            children: [
                              Icon(MdiIcons.noteTextOutline, size: 18, color: Colors.amber[800]),
                              SizedBox(width: 4),
                              Text('Notes: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text('${purchase['notes']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Action Buttons
                Center(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Tooltip(
                        message: 'Print Invoice',
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.printer),
                          label: Text('Print'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          onPressed: () async {
                            await _loadBusinessDetails();
                            final db = await AppDatabase.database;
                            final List<Map<String, dynamic>> items = await db.query(
                              'purchase_items',
                              where: 'purchase_id = ?',
                              whereArgs: [purchase['id']],
                            );
                            final pdf = await _generateInvoicePdf(
                              purchase,
                              items,
                              businessName,
                              businessAddress,
                              businessContact,
                            );
                            await Printing.layoutPdf(onLayout: (format) => pdf.save());
                          },
                        ),
                      ),
                      Tooltip(
                        message: 'Export to PDF',
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.filePdfBox),
                          label: Text('Export'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                          onPressed: () async {
                            await _loadBusinessDetails();
                            final db = await AppDatabase.database;
                            final List<Map<String, dynamic>> items = await db.query(
                              'purchase_items',
                              where: 'purchase_id = ?',
                              whereArgs: [purchase['id']],
                            );
                            final pdf = await _generateInvoicePdf(
                              purchase,
                              items,
                              businessName,
                              businessAddress,
                              businessContact,
                            );
                            await Printing.sharePdf(
                              bytes: await pdf.save(),
                              filename: 'invoice_${purchase['id']}.pdf',
                            );
                          },
                        ),
                      ),
                      Tooltip(
                        message: 'Edit Invoice',
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.pencil),
                          label: Text('Edit'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          onPressed: () => _showEditPurchaseDialog(purchase),
                        ),
                      ),
                      Tooltip(
                        message: 'Pay',
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.cash),
                          label: Text('Pay'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: (purchase['payment_status'] == 'Fully Paid')
                              ? null
                              : () => _showPaymentDialog(purchase),
                        ),
                      ),
                      Tooltip(
                        message: 'Receive Items',
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.packageVariant),
                          label: Text('Receive'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          onPressed: (purchase['delivery_status'] == 'Fully Received')
                              ? null
                              : () => _showReceiveGoodsDialog(purchase),
                        ),
                      ),
                      Tooltip(
                        message: 'Delete Invoice',
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.delete),
                          label: Text('Delete'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Confirm Delete'),
                                content: Text(
                                  'Are you sure you want to delete this invoice? This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final db = await AppDatabase.database;
                              await db.delete(
                                'purchase_items',
                                where: 'purchase_id = ?',
                                whereArgs: [purchase['id']],
                              );
                              await db.delete(
                                'purchases',
                                where: 'id = ?',
                                whereArgs: [purchase['id']],
                              );
                              await _loadPurchases();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                // Items Table
                Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                            SizedBox(width: 8),
                            Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Text('Price', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              children: [
                                Expanded(child: Text(item['stock_name'] ?? '')),
                                SizedBox(width: 8),
                                Text('${item['qty']}', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                                SizedBox(width: 8),
                                Text('UGX ${item['purchase_price']}', style: TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
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
                SizedBox(height: 18),
                // Totals
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total: UGX ${purchase['total'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Paid: UGX ${purchase['amount_paid'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Balance: UGX $balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: balance > 0 ? Colors.red : Colors.green)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditPurchaseDialog(Map<String, dynamic> purchase) async {
    final db = await AppDatabase.database;
    // Load purchase items
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
      await db.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchase['id']],
      ),
    );
    // Load inventory for stock names
    List<Map<String, dynamic>> inventory = await AppDatabase.getInventory(
      branchId: widget.branchId,
    );
    List<String> stockNames = inventory
        .map((e) => e['name'] as String)
        .toList();
    final supplierController = TextEditingController(
      text: purchase['supplier'] ?? '',
    );
    final notesController = TextEditingController(
      text: purchase['notes'] ?? '',
    );
    DateTime selectedDate = DateFormat('yyyy-MM-dd').parse(purchase['date']);
    int total = items.fold<int>(
      0,
      (sum, item) => sum + (item['total'] as int? ?? 0),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateItem(int i, String field, String value) {
              setState(() {
                if (field == 'qty') {
                  items[i]['qty'] = int.tryParse(value) ?? 0;
                  items[i]['total'] =
                      (items[i]['qty'] as int) *
                      (items[i]['purchase_price'] as int);
                } else if (field == 'purchase_price') {
                  items[i]['purchase_price'] = int.tryParse(value) ?? 0;
                  items[i]['total'] =
                      (items[i]['qty'] as int) *
                      (items[i]['purchase_price'] as int);
                }
              });
            }

            total = items.fold<int>(
              0,
              (sum, item) => sum + (item['total'] as int? ?? 0),
            );
            return AlertDialog(
              title: Row(
                children: [
                  Icon(MdiIcons.pencil, color: Colors.orange, size: 26),
                  SizedBox(width: 8),
                  Text('Edit Invoice #${purchase['id']}'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier and Date
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
                                    controller: supplierController,
                                    decoration: InputDecoration(labelText: 'Supplier'),
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
                                Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                                IconButton(
                                  icon: Icon(MdiIcons.calendarEdit),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        selectedDate = picked;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Items Table
                    if (items.isNotEmpty)
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
                                  Expanded(child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 8),
                                  Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(width: 8),
                                  Text('Price', style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(width: 8),
                                  Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(width: 8),
                                  SizedBox(width: 32), // For delete icon
                                ],
                              ),
                              Divider(),
                              ...items.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(item['stock_name'] ?? '')),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 50,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text: item['qty'].toString(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6)),
                                          onChanged: (v) => updateItem(i, 'qty', v),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      SizedBox(
                                        width: 70,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text: item['purchase_price'].toString(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6)),
                                          onChanged: (v) => updateItem(i, 'purchase_price', v),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('UGX ${item['total']}', style: TextStyle(fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(MdiIcons.trashCanOutline, color: Colors.red),
                                        tooltip: 'Remove Item',
                                        onPressed: () => setState(() {
                                          items.removeAt(i);
                                        }),
                                      ),
                                    ],
                                  ),
                                );
                              }),
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
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Total
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Total Invoice Value: UGX $total',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Confirm Delete'),
                        content: Text(
                          'Are you sure you want to delete this purchase? This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    // Delete purchase and its items
                    await db.delete(
                      'purchase_items',
                      where: 'purchase_id = ?',
                      whereArgs: [purchase['id']],
                    );
                    await db.delete(
                      'purchases',
                      where: 'id = ?',
                      whereArgs: [purchase['id']],
                    );
                    Navigator.of(context).pop();
                    await _loadPurchases();
                  },
                  child: Text('Delete'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Update purchase
                    await db.update(
                      'purchases',
                      {
                        'supplier': supplierController.text.trim(),
                        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'notes': notesController.text.trim(),
                        'total': total,
                      },
                      where: 'id = ?',
                      whereArgs: [purchase['id']],
                    );
                    // Update purchase items
                    await db.delete(
                      'purchase_items',
                      where: 'purchase_id = ?',
                      whereArgs: [purchase['id']],
                    );
                    for (final item in items) {
                      await db.insert('purchase_items', {
                        'purchase_id': purchase['id'],
                        'stock_name': item['stock_name'],
                        'qty': item['qty'],
                        'purchase_price': item['purchase_price'],
                        'total': item['total'],
                      });
                    }
                    Navigator.of(context).pop();
                    await _loadPurchases();
                  },
                  child: Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

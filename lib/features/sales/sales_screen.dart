import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/db.dart';
import '../../widgets/footer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'sale_invoice_dialog.dart';

class SalesScreen extends StatefulWidget {
  final int? branchId;
  SalesScreen({this.branchId});
  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String, dynamic>> sales = [];
  String searchInvoice = '';
  String searchDate = '';
  String searchEndDate = '';
  String searchPayment = '';
  bool loading = true;

  // --- HOVER ROW HIGHLIGHT STATE ---
  int? hoveredRowIndex;

  // Sorting state
  String? sortColumn;
  bool sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void didUpdateWidget(covariant SalesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _loadSales();
    }
  }

  Future<void> _loadSales() async {
    setState(() {
      loading = true;
    });
    final db = await AppDatabase.database;
    String where = 'branch_id = ?';
    List<dynamic> whereArgs = [widget.branchId];
    if (searchInvoice.isNotEmpty) {
      where += ' AND id LIKE ?';
      whereArgs.add('%$searchInvoice%');
    }
    if (searchDate.isNotEmpty) {
      where += ' AND date LIKE ?';
      whereArgs.add('%$searchDate%');
    }
    if (searchPayment.isNotEmpty) {
      where += ' AND LOWER(payment_status) LIKE ?';
      whereArgs.add('%${searchPayment.toLowerCase()}%');
    }
    final data = await db.query('sales', where: where, whereArgs: whereArgs);
    setState(() {
      sales = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  Widget _headerCell(String text, double width, {VoidCallback? onTap}) {
    final isSorted = sortColumn == _sortKeyForHeader(text);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 2.0),
                child: isSorted
                    ? Icon(
                        sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        size: 18,
                        color: Colors.blueGrey,
                      )
                    : SizedBox(width: 18),
              ),
          ],
        ),
      ),
    );
  }

  String? _sortKeyForHeader(String header) {
    switch (header) {
      case 'Invoice No.':
        return 'id';
      case 'Date':
        return 'date';
      case 'Payment Status':
        return 'payment_status';
      case 'Customer':
        return 'customer_name';
      case 'Amount':
        return 'amount';
      case 'Paid':
        return 'paid';
      case 'Balance':
        return 'balance';
      default:
        return null;
    }
  }

  void _onSort(String column) {
    setState(() {
      if (sortColumn == column) {
        sortAscending = !sortAscending;
      } else {
        sortColumn = column;
        sortAscending = true;
      }
      sales.sort((a, b) {
        dynamic aValue;
        dynamic bValue;
        if (column == 'balance') {
          aValue = (a['amount'] ?? 0) - (a['paid'] ?? 0);
          bValue = (b['amount'] ?? 0) - (b['paid'] ?? 0);
        } else {
          aValue = a[column];
          bValue = b[column];
        }
        if (aValue is String && bValue is String) {
          return sortAscending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        } else if (aValue is num && bValue is num) {
          return sortAscending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        } else {
          return 0;
        }
      });
    });
  }

  Widget _dataCell(dynamic child, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: child is Widget ? child : Text(child.toString()),
    );
  }

  // --- Stub implementations for missing methods ---
  Future<void> _exportSalesToPdf() async {}
  Future<void> _exportSalesToCsv() async {}
  Future<void> _showNewSaleDialog() async {
    await showDialog(
      context: context,
      builder: (context) => SaleInvoiceDialog(
        mode: SaleInvoiceDialogMode.newSale,
        branchId: widget.branchId,
      ),
    );
    _loadSales();
  }

  Future<void> _showSaleDetailsDialog(int saleId) async {
    final sale = sales.firstWhere((s) => s['id'] == saleId, orElse: () => {});
    await showDialog(
      context: context,
      builder: (context) => SaleInvoiceDialog(
        sale: sale,
        mode: SaleInvoiceDialogMode.view,
        branchId: widget.branchId,
      ),
    );
    _loadSales();
  }

  Future<void> _showPaymentDialog(Map<String, dynamic> sale) async {
    await showDialog(
      context: context,
      builder: (context) => SaleInvoiceDialog(
        sale: sale,
        mode: SaleInvoiceDialogMode.payment,
        branchId: widget.branchId,
      ),
    );
    _loadSales();
  }

  Future<void> _returnGoods(Map<String, dynamic> sale) async {
    await showDialog(
      context: context,
      builder: (context) => SaleInvoiceDialog(
        sale: sale,
        mode: SaleInvoiceDialogMode.returnGoods,
        branchId: widget.branchId,
      ),
    );
    _loadSales();
  }

  Future<void> _editInvoice(Map<String, dynamic> sale) async {
    await showDialog(
      context: context,
      builder: (context) => SaleInvoiceDialog(
        sale: sale,
        mode: SaleInvoiceDialogMode.edit,
        branchId: widget.branchId,
      ),
    );
    _loadSales();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sales', style: Theme.of(context).textTheme.headlineSmall),
              Row(
                children: [
                  Tooltip(
                    message: 'Total sales amount for the selected period',
                    child: Chip(
                      avatar: Icon(
                        MdiIcons.cashPlus,
                        color: Colors.white,
                      ),
                      label: Text(
                        'UGX ' + NumberFormat.decimalPattern().format(
                          sales.fold<int>(0, (sum, s) => sum + (((s['amount'] ?? 0) is int ? s['amount'] ?? 0 : int.tryParse(s['amount'].toString()) ?? 0) as int)),
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.filePdfBox),
                    label: Text('Export PDF'),
                    onPressed: _exportSalesToPdf,
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.fileDelimited),
                    label: Text('Export CSV'),
                    onPressed: _exportSalesToCsv,
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.plusBox),
                    label: Text('New Sale'),
                    onPressed: _showNewSaleDialog,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          // Date filter row
          Row(
            children: [
              Icon(MdiIcons.calendarStart, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('From:'),
              TextButton(
                child: Row(
                  children: [
                    Icon(MdiIcons.calendar, size: 18, color: Colors.indigo),
                    SizedBox(width: 4),
                    Text(searchDate.isEmpty ? 'Start' : searchDate),
                  ],
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      searchDate = DateFormat('yyyy-MM-dd').format(picked);
                    });
                    _loadSales();
                  }
                },
              ),
              SizedBox(width: 16),
              Text('To:'),
              TextButton(
                child: Row(
                  children: [
                    Icon(MdiIcons.calendarEnd, size: 18, color: Colors.deepPurple),
                    SizedBox(width: 4),
                    Text(searchEndDate.isEmpty ? 'End' : searchEndDate),
                  ],
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      searchEndDate = DateFormat('yyyy-MM-dd').format(picked);
                    });
                    _loadSales();
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by Invoice, Date, or Payment',
                    prefixIcon: Icon(MdiIcons.magnify),
                  ),
                  onChanged: (v) {
                    setState(() {
                      searchInvoice = v;
                    });
                    _loadSales();
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Table head and scrollable body
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = constraints.maxWidth;
                    final colNo = tableWidth * 0.08;
                    final colDate = tableWidth * 0.13;
                    final colStatus = tableWidth * 0.07;
                    final colCustomer = tableWidth * 0.15;
                    final colAmount = tableWidth * 0.12;
                    final colPaid = tableWidth * 0.12;
                    final colBalance = tableWidth * 0.12;
                    final colActions = tableWidth * 0.21;
                    final formatter = NumberFormat.decimalPattern();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            // Table header (unscrollable)
                            Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Row(
                                children: [
                                  _headerCell('Invoice No.', colNo, onTap: () => _onSort('id')),
                                  _headerCell('Date', colDate, onTap: () => _onSort('date')),
                                  _headerCell('Payment Status', colStatus, onTap: () => _onSort('payment_status')),
                                  _headerCell('Customer', colCustomer, onTap: () => _onSort('customer_name')),
                                  _headerCell('Amount', colAmount, onTap: () => _onSort('amount')),
                                  _headerCell('Paid', colPaid, onTap: () => _onSort('paid')),
                                  _headerCell('Balance', colBalance, onTap: () => _onSort('balance')),
                                  _headerCell('Actions', colActions),
                                ],
                              ),
                            ),
                            Divider(height: 1, thickness: 1),
                            // Table body (scrollable)
                            if (loading)
                              Expanded(
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (sales.isEmpty)
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(MdiIcons.fileDocumentOutline, size: 64, color: Colors.grey.shade400),
                                      SizedBox(height: 16),
                                      Text(
                                        'No sales found.',
                                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Try adjusting your filters or add a new sale.',
                                        style: TextStyle(color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: SizedBox(
                                  height: 400,
                                  child: Container(
                                    width: tableWidth,
                                    child: ListView.builder(
                                      itemCount: sales.length,
                                      itemBuilder: (context, i) {
                                        final sale = sales[i];
                                        final paid = sale['paid'] ?? 0;
                                        final amount = sale['amount'] ?? 0;
                                        final balance = amount - paid;
                                        final highlight = hoveredRowIndex == i;
                                        return MouseRegion(
                                          onEnter: (_) => setState(() => hoveredRowIndex = i),
                                          onExit: (_) => setState(() => hoveredRowIndex = null),
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () => _showSaleDetailsDialog(sale['id']),
                                            child: AnimatedContainer(
                                              duration: Duration(milliseconds: 150),
                                              color: highlight
                                                  ? Colors.blue.withOpacity(0.08)
                                                  : (i % 2 == 0
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .surfaceVariant
                                                          .withOpacity(0.5)
                                                      : Colors.transparent),
                                              child: IntrinsicWidth(
                                                child: Row(
                                                  children: [
                                                    _dataCell(sale['id'].toString(), colNo),
                                                    _dataCell(sale['date'] ?? '', colDate),
                                                    _dataCell(
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: balance == 0
                                                              ? Colors.green.withOpacity(0.15)
                                                              : Colors.orange.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          balance == 0 ? 'Fully Paid' : 'Credit/Partial',
                                                          style: TextStyle(
                                                            color: balance == 0 ? Colors.green : Colors.orange,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      colStatus,
                                                    ),
                                                    _dataCell(
                                                      (sale['customer_name'] != null && (sale['customer_name'] as String).isNotEmpty)
                                                          ? InkWell(
                                                              onTap: () {
                                                                showDialog(
                                                                  context: context,
                                                                  builder: (context) => AlertDialog(
                                                                    title: Text('Customer Details'),
                                                                    content: Column(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text('Name: ${sale['customer_name']}'),
                                                                        SizedBox(height: 8),
                                                                        Text('Contact: ${sale['customer_contact'] ?? '-'}'),
                                                                      ],
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed: () => Navigator.of(context).pop(),
                                                                        child: Text('Close'),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              },
                                                              child: Text(
                                                                (sale['customer_name'] as String).split(' ').first,
                                                                style: TextStyle(
                                                                  color: Colors.blue,
                                                                  decoration: TextDecoration.underline,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            )
                                                          : Text('-'),
                                                      colCustomer,
                                                    ),
                                                    _dataCell('UGX ${formatter.format(amount)}', colAmount),
                                                    _dataCell('UGX ${formatter.format(paid)}', colPaid),
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
                                                            message: 'View Details',
                                                            child: IconButton(
                                                              icon: Icon(MdiIcons.eye, color: Colors.blue),
                                                              onPressed: () => _showSaleDetailsDialog(sale['id']),
                                                            ),
                                                          ),
                                                          Tooltip(
                                                            message: 'Make Payment',
                                                            child: IconButton(
                                                              icon: Icon(MdiIcons.cashPlus, color: Colors.green),
                                                              onPressed: () => _showPaymentDialog(sale),
                                                            ),
                                                          ),
                                                          Tooltip(
                                                            message: 'Return Goods',
                                                            child: IconButton(
                                                              icon: Icon(MdiIcons.undoVariant, color: Colors.orange),
                                                              onPressed: () => _returnGoods(sale),
                                                            ),
                                                          ),
                                                          Tooltip(
                                                            message: 'Edit Invoice',
                                                            child: IconButton(
                                                              icon: Icon(MdiIcons.pencil, color: Colors.amber),
                                                              onPressed: () => _editInvoice(sale),
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
                                          ),
                                        );
                                      },
                                    ),
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
            ),
          ),
        ],
      ),
    );
  }
}

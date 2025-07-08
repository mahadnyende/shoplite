import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shoplite/core/db.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'dart:typed_data';

class PurchasesScreen extends StatefulWidget {
  final int branchId;
  const PurchasesScreen({Key? key, required this.branchId}) : super(key: key);

  @override
  _PurchasesScreenState createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  // Helper for fixed table header cell
  Widget _headerCell(String text, {int flex = 1, int col = 0}) {
    // Set column widths to match the table (total width: 1200)
    final colWidths = [
      100.0,
      180.0,
      100.0,
      120.0,
      120.0,
      100.0,
      100.0,
      100.0,
      180.0,
    ];
    final isSorted = _sortColumnIndex == col;
    return InkWell(
      onTap: () {
        if (col == 8) return; // Don't sort on actions column
        final ascending = _sortColumnIndex == col ? !_sortAscending : true;
        String key;
        switch (col) {
          case 0:
            key = 'id';
            break;
          case 1:
            key = 'supplier';
            break;
          case 2:
            key = 'date';
            break;
          case 3:
            key = 'delivery_status';
            break;
          case 4:
            key = 'payment_status';
            break;
          case 5:
            key = 'total';
            break;
          case 6:
            key = 'amount_paid';
            break;
          case 7:
            key = 'balance';
            break;
          default:
            key = 'id';
        }
        _sortPurchases(key, ascending, col);
      },
      child: Container(
        width: colWidths[col],
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: col >= 5 && col <= 7 ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          border: Border(
            right: BorderSide(color: Colors.blueGrey[100]!, width: 1),
            bottom: BorderSide(color: Colors.blueGrey[200]!, width: 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blueGrey[900],
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (isSorted)
              Icon(
                _sortAscending ? MdiIcons.sortAscending : MdiIcons.sortDescending,
                size: 22,
                color: Colors.blueGrey[700],
              ),
          ],
        ),
      ),
    );
  }

  // Helper for fixed table body cell
  Widget _bodyCell(dynamic child, {int flex = 1, int col = 0, bool isAlt = false}) {
    final colWidths = [
      100.0,
      180.0,
      100.0,
      120.0,
      120.0,
      100.0,
      100.0,
      100.0,
      180.0,
    ];
    return Container(
      width: colWidths[col],
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      alignment: col >= 5 && col <= 7 ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: isAlt ? Colors.blueGrey[50] : Colors.white,
        border: Border(
          right: BorderSide(color: Colors.blueGrey[50]!, width: 1),
          bottom: BorderSide(color: Colors.blueGrey[100]!, width: 1),
        ),
      ),
      child: child is Widget
          ? child
          : Text(
              child.toString(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: Colors.blueGrey[900],
              ),
            ),
    );
  }

  // Dummy purchases list for supplier dropdown (replace with your actual data loading logic)
  List<Map<String, dynamic>> purchases = [];

  String businessName = 'Your Business Name';
  String businessAddress = '123 Business St, City, Country';
  String businessContact = 'Contact: +123456789 | info@business.com';

  Future<void> _loadBusinessDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      businessName = prefs.getString('business_name') ?? businessName;
      businessAddress = prefs.getString('business_address') ?? businessAddress;
      businessContact = prefs.getString('business_contact') ?? businessContact;
    });
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
              Icon(MdiIcons.receipt, color: Colors.blue, size: 28),
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
                          onPressed: () => _showReceiveGoodsDialog(purchase),
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
            // Enterprise Header
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
            // Enterprise Header
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
                      ((purchase['total'] ?? 0) -
                              (purchase['amount_paid'] ?? 0))
                          .toString(),
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

  @override
  void initState() {
    super.initState();
    _loadPurchases();
    _loadBusinessDetails();
  }

  // For search/filter/sort
  String _supplierSearch = '';
  String _deliveryFilter = '';
  String _paymentFilter = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  DateTime? fromDate;
  DateTime? toDate;

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
    // Add balance for sorting (do not mutate read-only maps)
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
          case 3: // delivery_status
            aVal = a['delivery_status'] ?? '';
            bVal = b['delivery_status'] ?? '';
            break;
          case 4: // payment_status
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
          case 7: // balance
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
    }
    return filtered;
  }

  void _sortPurchases(String key, bool ascending, int columnIndex) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Future<void> _loadPurchases() async {
    final data = await AppDatabase.getPurchases(branchId: widget.branchId);
    setState(() {
      purchases = data;
    });
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

  // --- Apophen Standard Purchase Invoice Dialog ---
  Future<void> _showNewPurchaseDialog() async {
    // Supplier logic
    List<String> savedSuppliers = purchases
        .map((p) => p['supplier'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    String? selectedSupplier;
    final _supplierController = TextEditingController();
    final _notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    // Load inventory from database
    List<Map<String, dynamic>> inventory = await AppDatabase.getInventory(
      branchId: widget.branchId,
    );
    List<String> stockNames = inventory
        .map((e) => e['name'] as String)
        .toList();
    List<Map<String, dynamic>> items = [];
    int total = 0;
    final _qtyController = TextEditingController();
    final _priceController = TextEditingController();
    String? selectedStock;
    await showDialog(
      context: context,
      builder: (context) {
        // Helper to highlight search matches in product names
        Widget _highlightMatch(String name, String search) {
          if (search.trim().isEmpty) return Text(name);
          final lower = name.toLowerCase();
          final query = search.trim().toLowerCase();
          final start = lower.indexOf(query);
          if (start == -1) return Text(name);
          final end = start + query.length;
          return RichText(
            text: TextSpan(
              children: [
                TextSpan(text: name.substring(0, start), style: TextStyle(color: Colors.black)),
                TextSpan(text: name.substring(start, end), style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                TextSpan(text: name.substring(end), style: TextStyle(color: Colors.black)),
              ],
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        String productSearch = '';
        return StatefulBuilder(
          builder: (context, setState) {
            // productSearch is now preserved across rebuilds
            void updatePriceAndTotal() {}
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

            void onSupplierChanged(String? v) {
              setState(() {
                selectedSupplier = v;
                _supplierController.text = v ?? '';
              });
            }

            void onStockChanged(String? v) async {
              if (v == '__new__') {
                final newName = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    final _newStockController = TextEditingController();
                    return AlertDialog(
                      title: Row(
                        children: [
                          Icon(MdiIcons.plusBox, color: Colors.blue, size: 22),
                          SizedBox(width: 8),
                          Text('New Stock Name'),
                        ],
                      ),
                      content: TextField(
                        controller: _newStockController,
                        decoration: InputDecoration(labelText: 'Stock Name'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(_newStockController.text.trim()),
                          child: Text('Create'),
                        ),
                      ],
                    );
                  },
                );
                if (newName != null &&
                    newName.isNotEmpty &&
                    !stockNames.contains(newName)) {
                  // Add new product to inventory DB
                  await AppDatabase.addInventory({
                    'name': newName,
                    'qty': 0,
                    'purchase': 0,
                    'sale': 0,
                    'branch_id': widget.branchId,
                  });
                  setState(() {
                    stockNames.add(newName);
                    selectedStock = newName;
                    _priceController.text = '';
                  });
                }
              } else {
                setState(() {
                  selectedStock = v;
                  if (selectedStock != null &&
                      stockNames.contains(selectedStock)) {
                    final stock = inventory.firstWhere(
                      (e) => e['name'] == selectedStock,
                    );
                    if (_priceController.text.isEmpty) {
                      _priceController.text = stock['purchase'].toString();
                    }
                  }
                });
                updatePriceAndTotal();
              }
            }

            DateTime? selectedExpiryDate;
            Future<void> addItem() async {
            if (selectedStock == null ||
            _qtyController.text.isEmpty ||
            _priceController.text.isEmpty)
            return;
            final qty = int.tryParse(_qtyController.text) ?? 0;
            final price = int.tryParse(_priceController.text) ?? 0;
            // Prevent adding to expired batch
            if (selectedExpiryDate != null && selectedExpiryDate!.isBefore(DateTime.now())) {
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot purchase into an expired batch.')),
            );
            return;
            }
            if (!stockNames.contains(selectedStock)) {
            // Add new product inline to inventory DB
            final db = await AppDatabase.database;
            final existing = await db.query(
            'inventory',
            where: 'LOWER(name) = ? AND branch_id = ? AND (expiry_date IS ? OR expiry_date = ?)',
            whereArgs: [selectedStock!.toLowerCase(), widget.branchId, null, null],
            );
            if (existing.isNotEmpty) {
            // Update price if needed, but qty is 0 for new product
            final existingItem = existing.first;
            await db.update(
            'inventory',
            {
            'purchase': price,
            'sale': 0,
            },
            where: 'id = ?',
            whereArgs: [existingItem['id']],
            );
            } else {
            await AppDatabase.addInventory({
            'name': selectedStock,
            'qty': 0,
            'purchase': price,
            'sale': 0,
            'branch_id': widget.branchId,
            });
            }
            stockNames.add(selectedStock!);
            }
            setState(() {
            items.add({
            'stock_name': selectedStock,
            'qty': qty,
            'purchase_price': price,
            'total': qty * price,
            'expiry_date': selectedExpiryDate != null ? DateFormat('yyyy-MM-dd').format(selectedExpiryDate!) : null,
            });
            _qtyController.clear();
            _priceController.clear();
            selectedStock = null;
            selectedExpiryDate = null;
            });
            }

            total = items.fold<int>(
              0,
              (sum, item) => sum + (item['total'] as int? ?? 0),
            );
            return AlertDialog(
              title: Row(
                children: [
                  Icon(MdiIcons.cartPlus, color: Colors.deepPurple, size: 30),
                  SizedBox(width: 12),
                  Text('New Purchase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.deepPurple)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier and Date
                    Card(
                      color: Colors.indigo[50],
                      margin: EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(MdiIcons.account, color: Colors.deepPurple, size: 26),
                                SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedSupplier,
                                    hint: Text('Select Supplier'),
                                    items: [
                                      ...savedSuppliers.map(
                                        (s) => DropdownMenuItem(value: s, child: Text(s)),
                                      ),
                                      DropdownMenuItem(
                                        value: '__new__',
                                        child: Row(
                                          children: [
                                            Icon(MdiIcons.accountPlus, size: 20, color: Colors.deepPurple),
                                            SizedBox(width: 6),
                                            Text('Add new supplier...'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v == '__new__') {
                                        setState(() {
                                          selectedSupplier = null;
                                        });
                                        _supplierController.clear();
                                      } else {
                                        onSupplierChanged(v);
                                      }
                                    },
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(MdiIcons.calendar, color: Colors.deepPurple, size: 22),
                                SizedBox(width: 10),
                                Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(width: 6),
                                Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                                IconButton(
                                  icon: Icon(MdiIcons.calendarEdit, color: Colors.deepPurple),
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
                    // Product Search and Add
                    Card(
                      color: Colors.green[50],
                      margin: EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          children: [
                            // Improved product search UI/UX
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tooltip(
                                  message: 'Type to search products. Click X to clear.',
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Search products',
                                      labelStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                      prefixIcon: Icon(MdiIcons.magnify, color: Colors.deepPurple),
                                      suffixIcon: productSearch.isNotEmpty
                                          ? InkWell(
                                              borderRadius: BorderRadius.circular(20),
                                              onTap: () {
                                                setState(() {
                                                  productSearch = '';
                                                });
                                                FocusScope.of(context).unfocus();
                                              },
                                              child: Tooltip(
                                                message: 'Clear search',
                                                child: Icon(MdiIcons.closeCircle, color: Colors.redAccent, size: 26),
                                              ),
                                            )
                                          : null,
                                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    onChanged: (v) => setState(() {
                                      productSearch = v;
                                    }),
                                  ),
                                ),
                                SizedBox(height: 10),
                                // Product list search and select
                                if (selectedStock != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Chip(
                                          avatar: Icon(MdiIcons.tag, color: Colors.white, size: 22),
                                          label: Text(selectedStock!, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                          backgroundColor: Colors.deepPurple,
                                          deleteIcon: Tooltip(
                                            message: 'Clear selected product',
                                            child: Icon(MdiIcons.closeCircle, color: Colors.redAccent, size: 22),
                                          ),
                                          onDeleted: () {
                                            setState(() {
                                              selectedStock = null;
                                            });
                                          },
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (selectedStock == null)
                                  Builder(
                                    builder: (context) {
                                      final filtered = stockNames
                                          .where((name) => name.toLowerCase().contains(productSearch.trim().toLowerCase()))
                                          .toList();
                                      if (filtered.isEmpty)
                                        return SizedBox(
                                          height: 60,
                                          width: double.infinity,
                                          child: ListTile(
                                            leading: Tooltip(
                                              message: 'No products found',
                                              child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                            ),
                                            title: Text('No products found', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                            trailing: Tooltip(
                                              message: 'Create new stock',
                                              child: TextButton.icon(
                                                icon: Icon(MdiIcons.plusCircle, color: Colors.green, size: 24),
                                                label: Text('Create new stock'),
                                                style: TextButton.styleFrom(foregroundColor: Colors.green, textStyle: TextStyle(fontWeight: FontWeight.bold)),
                                                onPressed: () => onStockChanged('__new__'),
                                              ),
                                            ),
                                          ),
                                        );
                                      return SizedBox(
                                        height: 180,
                                        width: double.infinity,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            children: [
                                              for (int idx = 0; idx < filtered.length; idx++) ...[
                                                if (idx > 0) Divider(height: 1),
                                                ListTile(
                                                  leading: Tooltip(
                                                    message: 'Product',
                                                    child: Icon(MdiIcons.cubeOutline, color: Colors.deepPurple, size: 28),
                                                  ),
                                                  title: _highlightMatch(filtered[idx], productSearch),
                                                  trailing: Tooltip(
                                                    message: 'Select product',
                                                    child: Icon(MdiIcons.checkCircle, color: Colors.green, size: 28),
                                                  ),
                                                  onTap: () {
                                                    final selected = filtered[idx];
                                                    final Map<String, dynamic> inv = inventory.firstWhere(
                                                      (e) => e['name'] == selected,
                                                      orElse: () => {},
                                                    );
                                                    setState(() {
                                                      selectedStock = selected;
                                                      // Auto-fill price if available
                                                      if (inv['purchase'] != null) {
                                                        _priceController.text = inv['purchase'].toString();
                                                      }
                                                    });
                                                  },
                                                ),
                                              ]
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                SizedBox(height: 8),
                                Divider(height: 18, thickness: 1.2, color: Colors.blueGrey[100]),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blueGrey[100]!, width: 1),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: TextField(
                                          controller: _qtyController,
                                          decoration: InputDecoration(
                                            labelText: 'Qty *',
                                            labelStyle: TextStyle(fontWeight: FontWeight.bold),
                                            prefixIcon: Tooltip(
                                              message: 'Quantity',
                                              child: Icon(MdiIcons.counter, color: Colors.deepPurple, size: 24),
                                            ),
                                            isDense: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            helperText: '',
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) => updatePriceAndTotal(),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: _priceController,
                                          decoration: InputDecoration(
                                            labelText: 'Price *',
                                            labelStyle: TextStyle(fontWeight: FontWeight.bold),
                                            prefixIcon: Tooltip(
                                              message: 'Price',
                                              child: Icon(MdiIcons.currencyUsd, color: Colors.teal, size: 24),
                                            ),
                                            isDense: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            helperText: '',
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) => updatePriceAndTotal(),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      // Expiry Date Picker
                                      SizedBox(
                                        width: 140,
                                        child: OutlinedButton.icon(
                                          icon: Icon(MdiIcons.calendarClock, size: 18),
                                          label: Text(selectedExpiryDate == null ? 'Expiry (opt)' : DateFormat('yyyy-MM-dd').format(selectedExpiryDate!)),
                                          onPressed: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime.now().subtract(Duration(days: 1)),
                                              lastDate: DateTime.now().add(Duration(days: 3650)),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                selectedExpiryDate = picked;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Tooltip(
                                        message: 'Add Item',
                                        child: ElevatedButton.icon(
                                          icon: Icon(MdiIcons.plusBox, color: Colors.white, size: 28),
                                          label: Text('Add'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade700,
                                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                            elevation: 2,
                                          ),
                                          onPressed: addItem,
                                        ),
                                      ),
                                    ],
                                  ),
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
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
                                  SizedBox(width: 10),
                                  Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  SizedBox(width: 10),
                                  Text('Price', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  SizedBox(width: 10),
                                  Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  SizedBox(width: 10),
                                  SizedBox(width: 36), // For delete icon
                                ],
                              ),
                              Divider(),
                              ...items.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(item['stock_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w500))),
                                      SizedBox(width: 10),
                                      SizedBox(
                                        width: 50,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text: item['qty'].toString(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onChanged: (v) => updateItem(i, 'qty', v),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      SizedBox(
                                        width: 70,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text: item['purchase_price'].toString(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onChanged: (v) => updateItem(i, 'purchase_price', v),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text('UGX ${item['total']}', style: TextStyle(fontWeight: FontWeight.bold)),
                                      SizedBox(width: 10),
                                      IconButton(
                                        icon: Icon(MdiIcons.delete, color: Colors.redAccent, size: 26),
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
                      margin: EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(MdiIcons.noteTextOutline, color: Colors.amber[800], size: 22),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _notesController,
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
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Total Invoice Value: UGX $total',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: Icon(MdiIcons.closeCircle, color: Colors.redAccent),
                  onPressed: () => Navigator.of(context).pop(),
                  label: Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: Icon(MdiIcons.contentSave, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (_supplierController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Supplier is required.')),
                      );
                      return;
                    }
                    if (items.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Add at least one item.')),
                      );
                      return;
                    }
                    try {
                      final db = await AppDatabase.database;
                      // Insert purchase
                      final purchaseId = await db.insert('purchases', {
                        'supplier': _supplierController.text.trim(),
                        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'payment_status': 'Unpaid',
                        'delivery_status': 'Not Received',
                        'branch_id': widget.branchId,
                        'total': total,
                        'notes': _notesController.text.trim(),
                      });
                      // Insert items
                      for (final item in items) {
                        await db.insert('purchase_items', {
                          'purchase_id': purchaseId,
                          'stock_name': item['stock_name'],
                          'qty': item['qty'],
                          'purchase_price': item['purchase_price'],
                          'total': item['total'],
                          'expiry_date': item['expiry_date'],
                        });
                      }
                      Navigator.of(context).pop();
                      await _loadPurchases();
                    } catch (e) {
                      print('Error saving purchase: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving purchase: $e')),
                      );
                    }
                  },
                  label: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant PurchasesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _loadPurchases();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('Purchases'),
      Builder(
        builder: (context) {
          final totalPurchases = purchases.fold<int>(0, (sum, p) => sum + ((p['total'] ?? 0) as int));
          return Tooltip(
            message: 'Total Purchases',
            child: Chip(
              avatar: Icon(
                MdiIcons.cart,
                color: Colors.white,
              ),
              label: Text(
                'UGX ${NumberFormat('#,##0').format(totalPurchases)}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.blue,
            ),
          );
        },
      ),
    ],
  ),
),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
            child: Row(
              children: [
                
                SizedBox(width: 16),
                Icon(
                MdiIcons.calendarRange,
                color: Colors.blueGrey,
                ),
                SizedBox(width: 8),
                Tooltip(
                message: 'Select Date Range',
                child: ElevatedButton.icon(
                icon: Icon(MdiIcons.calendarRange, color: Colors.indigo, size: 28),
                label: Text('Select Date Range'),
                style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueGrey,
                elevation: 0,
                side: BorderSide(color: Colors.blueGrey.shade100),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                await showDialog(
                context: context,
                builder: (context) {
                DateTime? tempStart = fromDate;
                DateTime? tempEnd = toDate;
                return AlertDialog(
                title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Row(
                children: [
                Icon(MdiIcons.calendarRange, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Select Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
                ),
                IconButton(
                icon: Icon(MdiIcons.closeCircle, color: Colors.redAccent),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
                ),
                ],
                ),
                content: SizedBox(
                width: 350,
                child: SfDateRangePicker(
                selectionMode: DateRangePickerSelectionMode.range,
                initialSelectedRange: (fromDate != null && toDate != null)
                ? PickerDateRange(fromDate, toDate)
                : null,
                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                if (args.value is PickerDateRange) {
                tempStart = args.value.startDate;
                tempEnd = args.value.endDate;
                }
                },
                showActionButtons: false,
                headerStyle: DateRangePickerHeaderStyle(
                textAlign: TextAlign.center,
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                monthViewSettings: DateRangePickerMonthViewSettings(
                viewHeaderStyle: DateRangePickerViewHeaderStyle(
                textStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                ),
                navigationDirection: DateRangePickerNavigationDirection.horizontal,
                todayHighlightColor: Colors.indigo,
                rangeSelectionColor: Colors.indigo.withOpacity(0.2),
                startRangeSelectionColor: Colors.indigo,
                endRangeSelectionColor: Colors.indigo,
                selectionTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                rangeTextStyle: TextStyle(color: Colors.indigo),
                monthCellStyle: DateRangePickerMonthCellStyle(
                todayTextStyle: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                todayCellDecoration: BoxDecoration(
                border: Border.all(color: Colors.indigo, width: 2),
                shape: BoxShape.circle,
                ),
                ),
                showNavigationArrow: true,
                navigationMode: DateRangePickerNavigationMode.snap,
                // Custom navigation icons
                                                ),
                ),
                actions: [
                TextButton.icon(
                icon: Icon(MdiIcons.close, color: Colors.redAccent),
                label: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton.icon(
                icon: Icon(MdiIcons.check, color: Colors.white),
                label: Text('Apply'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                onPressed: () {
                setState(() {
                fromDate = tempStart;
                toDate = tempEnd;
                });
                Navigator.of(context).pop();
                },
                ),
                ],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                );
                },
                );
                },
                ),
                ),
                SizedBox(width: 8),
                if (fromDate != null && toDate != null)
                Row(
                children: [
                Text(
                '${DateFormat('yyyy-MM-dd').format(fromDate!)} - ${DateFormat('yyyy-MM-dd').format(toDate!)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                Tooltip(
                message: 'Clear date range',
                child: IconButton(
                icon: Icon(MdiIcons.closeCircle, color: Colors.redAccent, size: 28),
                onPressed: () {
                setState(() {
                fromDate = null;
                toDate = null;
                });
                },
                ),
                ),
                ],
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by Supplier',
                      prefixIcon: Icon(
                        MdiIcons.magnify,
                      ),
                    ),
                    onChanged: (v) => setState(() => _supplierSearch = v),
                  ),
                ),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: _deliveryFilter.isEmpty ? null : _deliveryFilter,
                  hint: Row(
                    children: [
                      Icon(
                        MdiIcons.truckDelivery,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(width: 4),
                      Text('All'),
                    ],
                  ),
                  items: [
                    'All',
                    'Fully Received',
                    'Partially Received',
                    'Not Delivered',
                  ]
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status == 'All' ? '' : status,
                          child: Row(
                            children: [
                              Icon(
                                MdiIcons.truckDelivery,
                                size: 18,
                                color: Colors.blueGrey,
                              ),
                              SizedBox(width: 4),
                              Text(status),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _deliveryFilter = v ?? ''),
                ),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: _paymentFilter.isEmpty ? null : _paymentFilter,
                  hint: Row(
                    children: [
                      Icon(
                        MdiIcons.cashMultiple,
                        size: 18,
                        color: Colors.green,
                      ),
                      SizedBox(width: 4),
                      Text('All'),
                    ],
                  ),
                  items: ['All', 'Fully Paid', 'Unpaid', 'Partially Paid']
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status == 'All' ? '' : status,
                          child: Row(
                            children: [
                              Icon(
                                MdiIcons.cashMultiple,
                                size: 18,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(status),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _paymentFilter = v ?? ''),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                icon: Icon(MdiIcons.filterRemove),
                label: Text('Reset Filters'),
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
                ElevatedButton.icon(
                icon: Icon(MdiIcons.export),
                label: Text('Export'),
                onPressed: _exportPurchasesListToPdf,
                ),
              ],
            ),
          ),
          // Fixed header and scrollable body in one horizontal scroll view
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: 1200, // Restored fixed width to prevent infinite constraints error
                child: Column(
                  children: [
                    // Header
                    Container(
                      color: Colors.grey[200],
                      width: double.infinity,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          _headerCell('Invoice No.', flex: 2, col: 0),
                          _headerCell('Supplier', flex: 3, col: 1),
                          _headerCell('Date', flex: 2, col: 2),
                          _headerCell('Delivery Status', flex: 2, col: 3),
                          _headerCell('Payment Status', flex: 2, col: 4),
                          _headerCell('Total', flex: 2, col: 5),
                          _headerCell('Paid', flex: 2, col: 6),
                          _headerCell('Balance', flex: 2, col: 7),
                          _headerCell('Actions', flex: 3, col: 8),
                        ],
                      ),
                    ),
                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: _filteredSortedPurchases().map<Widget>((purchase) {
                            final balance = (purchase['total'] ?? 0) - (purchase['amount_paid'] ?? 0);
                            int rowIndex = _filteredSortedPurchases().indexOf(purchase);
                            bool isAlt = rowIndex % 2 == 1;
                            return Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                _bodyCell('${purchase['id'] ?? ''}', flex: 2, col: 0, isAlt: isAlt),
                                _bodyCell('${purchase['supplier'] ?? ''}', flex: 3, col: 1, isAlt: isAlt),
                                _bodyCell('${purchase['date'] ?? ''}', flex: 2, col: 2, isAlt: isAlt),
                                _bodyCell(
                                  Chip(
                                    label: Text(
                                      purchase['delivery_status'] ?? '',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor:
                                        purchase['delivery_status'] == 'Fully Received'
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
                                  flex: 2,
                                  col: 3,
                                  isAlt: isAlt,
                                ),
                                _bodyCell(
                                  Chip(
                                    label: Text(
                                      purchase['payment_status'] ?? '',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor:
                                        purchase['payment_status'] == 'Fully Paid'
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
                                  flex: 2,
                                  col: 4,
                                  isAlt: isAlt,
                                ),
                                _bodyCell('UGX ${purchase['total'] ?? 0}', flex: 2, col: 5, isAlt: isAlt),
                                _bodyCell('UGX ${purchase['amount_paid'] ?? 0}', flex: 2, col: 6, isAlt: isAlt),
                                _bodyCell(
                                  Text(
                                    'UGX $balance',
                                    style: TextStyle(
                                      color: balance > 0 ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  flex: 2,
                                  col: 7,
                                  isAlt: isAlt,
                                ),
                                _bodyCell(
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Tooltip(
                                          message: 'View Invoice',
                                          child: IconButton(
                                            icon: Icon(MdiIcons.eyeOutline),
                                            onPressed: () => _showViewInvoiceDialog(purchase),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Print Invoice',
                                          child: IconButton(
                                            icon: Icon(MdiIcons.printer),
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
                                              await Printing.layoutPdf(
                                                onLayout: (format) => pdf.save(),
                                              );
                                            },
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Export to PDF',
                                          child: IconButton(
                                            icon: Icon(MdiIcons.filePdfBox),
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
                                          child: IconButton(
                                            icon: Icon(MdiIcons.pencil),
                                            onPressed: () => _showEditPurchaseDialog(purchase),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Delete Invoice',
                                          child: IconButton(
                                            icon: Icon(MdiIcons.delete),
                                            color: Colors.red,
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
                                  flex: 3,
                                  col: 8,
                                  isAlt: isAlt,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewPurchaseDialog,
        icon: Icon(MdiIcons.cartPlus),
        label: Text('New Purchase'),
      ),
    );
  }

  Future<void> _showPaymentDialog(Map<String, dynamic> purchase) async {
    final db = await AppDatabase.database;
    final total = purchase['total'] ?? 0;
    final paid = purchase['amount_paid'] ?? 0;
    int newPaid = paid;
    int newBalance = total - paid;
    String paymentStatus = purchase['payment_status'] ?? 'Unpaid';
    final _amountController = TextEditingController(text: '0');
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Make Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Amount Due: UGX $total'),
                  Text('Amount Paid: UGX $paid'),
                  Text(
                    'Current Balance: UGX ${total - paid}',
                    style: TextStyle(
                      color: (total - paid) > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Amount to Pay'),
                    onChanged: (v) {
                      final amt = int.tryParse(v) ?? 0;
                      setState(() {
                        newPaid = paid + amt;
                        newBalance = total - newPaid;
                        if (newPaid >= total) {
                          paymentStatus = 'Fully Paid';
                        } else if (newPaid > 0) {
                          paymentStatus = 'Partially Paid';
                        } else {
                          paymentStatus = 'Unpaid';
                        }
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentStatus,
                    items: [
                      DropdownMenuItem(
                        value: 'Fully Paid',
                        child: Text('Fully Paid'),
                      ),
                      DropdownMenuItem(
                        value: 'Partially Paid',
                        child: Text('Partially Paid'),
                      ),
                      DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => paymentStatus = v);
                    },
                    decoration: InputDecoration(labelText: 'Payment Status'),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'New Balance: UGX $newBalance',
                    style: TextStyle(
                      color: newBalance > 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
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
                    final amt = int.tryParse(_amountController.text) ?? 0;
                    final updatedPaid = paid + amt;
                    final updatedBalance = total - updatedPaid;
                    String updatedStatus;
                    if (paymentStatus == 'Fully Paid' || updatedPaid >= total) {
                      updatedStatus = 'Fully Paid';
                    } else if (paymentStatus == 'Partially Paid' ||
                        (updatedPaid > 0 && updatedPaid < total)) {
                      updatedStatus = 'Partially Paid';
                    } else {
                      updatedStatus = 'Unpaid';
                    }
                    await db.update(
                      'purchases',
                      {
                        'amount_paid': updatedPaid,
                        'payment_status': updatedStatus,
                      },
                      where: 'id = ?',
                      whereArgs: [purchase['id']],
                    );
                    // Insert payment record
                    if (amt > 0) {
                      await db.insert('payments', {
                        'invoice_id': purchase['id'],
                        'amount': amt,
                        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      });
                    }
                    Navigator.of(context).pop();
                    await _loadPurchases();
                  },
                  child: Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Payment history dialog removed

  Future<void> _showNotesDialog(Map<String, dynamic> purchase) async {
    final db = await AppDatabase.database;
    final _notesController = TextEditingController(
      text: purchase['notes'] ?? '',
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Invoice Notes'),
          content: TextField(
            controller: _notesController,
            maxLines: 5,
            decoration: InputDecoration(labelText: 'Notes'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await db.update(
                  'purchases',
                  {'notes': _notesController.text.trim()},
                  where: 'id = ?',
                  whereArgs: [purchase['id']],
                );
                Navigator.of(context).pop();
                await _loadPurchases();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPrintDialog(Map<String, dynamic> purchase) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Printable Invoice (PDF)'),
          content: SizedBox(
            width: 300,
            child: Text('PDF export/print feature coming soon.'),
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

  Future<void> _showReturnDialog(Map<String, dynamic> purchase) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Stock Return'),
          content: SizedBox(
            width: 300,
            child: Text('Stock return feature coming soon.'),
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

  Future<void> _showProfitDialog(Map<String, dynamic> purchase) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Profit Impact'),
          content: SizedBox(
            width: 300,
            child: Text('Profit impact calculation coming soon.'),
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

  Future<void> _showReceiveGoodsDialog(Map<String, dynamic> purchase) async {
    final db = await AppDatabase.database;
    // Load purchase items
    final List<Map<String, dynamic>> items = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchase['id']],
    );
    // Check if all items are fully received
    final allFullyReceived =
        items.isNotEmpty &&
        items.every(
          (item) => (item['received_qty'] ?? 0) >= (item['qty'] ?? 0),
        );
    if (allFullyReceived) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All goods already received for this invoice.')),
      );
      return;
    }
    // Load inventory for updating
    List<Map<String, dynamic>> inventory = await AppDatabase.getInventory(
      branchId: widget.branchId,
    );
    // Prepare controllers for each item
    List<TextEditingController> qtyControllers = [
      for (final item in items)
        TextEditingController(text: item['qty'].toString()),
    ];
    String deliveryStatus = 'Fully Received';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Receive Goods'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Row(
                        children: [
                          Expanded(child: Text(item['stock_name'] ?? '')),
                          SizedBox(width: 8),
                          Text('Ordered: ${item['qty']}'),
                          SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: qtyControllers[i],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Received',
                              ),
                              onChanged: (v) {
                                setState(() {
                                  final received = int.tryParse(v) ?? 0;
                                  if (received > item['qty']) {
                                    qtyControllers[i].text = item['qty']
                                        .toString();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Cannot receive more than ordered (${item['qty']})',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  // Auto-update delivery status
                                  bool allZero = true;
                                  bool allFull = true;
                                  for (int j = 0; j < items.length; j++) {
                                    final rc =
                                        int.tryParse(qtyControllers[j].text) ??
                                        0;
                                    if (rc < items[j]['qty']) allFull = false;
                                    if (rc > 0) allZero = false;
                                  }
                                  if (allFull) {
                                    deliveryStatus = 'Fully Received';
                                  } else if (allZero) {
                                    deliveryStatus = 'Not Received';
                                  } else {
                                    deliveryStatus = 'Partially Received';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    }),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: deliveryStatus,
                      items: [
                        DropdownMenuItem(
                          value: 'Fully Received',
                          child: Text('Fully Received'),
                        ),
                        DropdownMenuItem(
                          value: 'Partially Received',
                          child: Text('Partially Received'),
                        ),
                        DropdownMenuItem(
                          value: 'Not Received',
                          child: Text('Not Received'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => deliveryStatus = v);
                      },
                      decoration: InputDecoration(labelText: 'Delivery Status'),
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
                    // Update inventory and purchase status
                    for (int i = 0; i < items.length; i++) {
                      final item = items[i];
                      final received =
                          int.tryParse(qtyControllers[i].text) ?? 0;
                      // Update received_qty in purchase_items
                      await db.update(
                        'purchase_items',
                        {'received_qty': received},
                        where: 'id = ?',
                        whereArgs: [item['id']],
                      );
                      if (received > 0) {
                        // Update inventory qty
                        final stock = inventory.firstWhere(
                          (e) => e['name'] == item['stock_name'],
                          orElse: () => {},
                        );
                        if (stock.isNotEmpty) {
                          await db.update(
                            'inventory',
                            {'qty': (stock['qty'] ?? 0) + received},
                            where: 'name = ? AND branch_id = ?',
                            whereArgs: [item['stock_name'], widget.branchId],
                          );
                        }
                      }
                    }
                    // Update purchase delivery status
                    await db.update(
                      'purchases',
                      {'delivery_status': deliveryStatus},
                      where: 'id = ?',
                      whereArgs: [purchase['id']],
                    );
                    if (deliveryStatus == 'Fully Received') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ Goods received and added to inventory',
                          ),
                        ),
                      );
                    } else if (deliveryStatus == 'Partially Received') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('⚠️ You’ve received less than ordered'),
                        ),
                      );
                    }
                    Navigator.of(context).pop();
                    await _loadPurchases();
                  },
                  child: Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

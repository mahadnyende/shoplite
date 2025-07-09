import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import '../../core/db.dart';
import '../../widgets/footer.dart';

class ReportsScreen extends StatefulWidget {
  final int? branchId;
  ReportsScreen({this.branchId});
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  int? hoveredRowIndexSales;
  int? hoveredRowIndexPurchases;
  late TabController _tabController;
  final ScrollController _purchasesScrollController = ScrollController();
  final ScrollController _incomeStatementScrollController = ScrollController();
  final ScrollController _salesScrollController = ScrollController();
  bool loading = true;
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> purchases = [];
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> inventory = [];
  DateTime? fromDate;
  DateTime? toDate;
  String? productFilter;
  int? branchFilter;
  List<String> productNames = [];

  // Sorting state for sales report
  String? salesSortColumn;
  bool salesSortAscending = true;

  // Sorting state for purchases report
  String? purchasesSortColumn;
  bool purchasesSortAscending = true;

  // Purchases report header cell with sort
  Widget _purchasesHeaderCell({
    required String label,
    required int flex,
    required String sortKey,
    VoidCallback? onTap,
  }) {
    final isSorted = purchasesSortColumn == sortKey;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: isSorted
                      ? Icon(
                          purchasesSortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          size: 18,
                          color: Colors.blueGrey,
                        )
                      : SizedBox(width: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPurchasesSort(String column) {
    setState(() {
      if (purchasesSortColumn == column) {
        purchasesSortAscending = !purchasesSortAscending;
      } else {
        purchasesSortColumn = column;
        purchasesSortAscending = true;
      }
    });
  }

  // Sales report header cell with sort
  Widget _salesHeaderCell({
    required IconData icon,
    required String label,
    required int flex,
    required String sortKey,
    VoidCallback? onTap,
  }) {
    final isSorted = salesSortColumn == sortKey;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
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
                          salesSortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          size: 18,
                          color: Colors.blueGrey,
                        )
                      : SizedBox(width: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSalesSort(String column) {
    setState(() {
      if (salesSortColumn == column) {
        salesSortAscending = !salesSortAscending;
      } else {
        salesSortColumn = column;
        salesSortAscending = true;
      }
    });
  }
  // Example branch list; replace with your actual branch data source
  final List<Map<String, dynamic>> branches = [
    {'id': 1, 'name': 'Main Branch'},
    {'id': 2, 'name': 'Branch 2'},
    {'id': 3, 'name': 'Branch 3'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
    });
    // For branch filter, use widget.branchId if not set
    final branchId = branchFilter ?? widget.branchId;
    sales = await AppDatabase.getSales(branchId: branchId);
    purchases = await AppDatabase.getPurchases(branchId: branchId);
    expenses = await AppDatabase.getExpenses(branchId: branchId);
    inventory = await AppDatabase.getInventory(branchId: branchId);
    productNames = inventory.map((e) => e['name'] as String).toSet().toList();
    setState(() {
      loading = false;
    });
  }

  List<Map<String, dynamic>> _filterByDate(
    List<Map<String, dynamic>> data,
    String dateField,
  ) {
    if (fromDate == null && toDate == null) return data;
    return data.where((row) {
      final dateStr = row[dateField];
      if (dateStr == null) return false;
      final date = DateTime.tryParse(dateStr);
      if (date == null) return false;
      if (fromDate != null && date.isBefore(fromDate!)) return false;
      if (toDate != null && date.isAfter(toDate!)) return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _filterByProduct(
    List<Map<String, dynamic>> data,
    String productField,
  ) {
    if (productFilter == null || productFilter!.isEmpty) return data;
    return data.where((row) => row[productField] == productFilter).toList();
  }

  void _exportCSV(List<List<dynamic>> rows, String filename) async {
    final csv = const ListToCsvConverter().convert(rows);
    final file = File(filename);
    await file.writeAsString(csv);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exported to $filename')));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _purchasesScrollController.dispose();
    _incomeStatementScrollController.dispose();
    _salesScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Business Reports', style: theme.textTheme.headlineSmall),
          SizedBox(height: 8),
          Text(
            'Analyze your business performance with detailed sales, purchases, and financial reports. Use filters and export options for deeper insights.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Row(
                children: [
                  Icon(MdiIcons.calendarRange, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text('From:', style: theme.textTheme.bodyLarge),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fromDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null)
                        setState(() {
                          fromDate = picked;
                        });
                    },
                    child: Text(
                      fromDate == null
                          ? 'Start'
                          : DateFormat('yyyy-MM-dd').format(fromDate!),
                    ),
                  ),
                  Text('To:', style: theme.textTheme.bodyLarge),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: toDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null)
                        setState(() {
                          toDate = picked;
                        });
                    },
                    child: Text(
                      toDate == null
                          ? 'End'
                          : DateFormat('yyyy-MM-dd').format(toDate!),
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(MdiIcons.officeBuilding, color: Colors.blueGrey),
                  SizedBox(width: 4),
                  Text('Branch:', style: theme.textTheme.bodyLarge),
                  SizedBox(width: 4),
                  DropdownButton<int>(
                    value: branchFilter ?? widget.branchId,
                    hint: Text('All'),
                    items: branches
                        .map(
                          (branch) => DropdownMenuItem(
                            value: branch['id'] as int,
                            child: Text(branch['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      branchFilter = v;
                      productFilter = null;
                      productNames = [];
                      _loadData();
                    },
                  ),
                  SizedBox(width: 16),
                  Icon(MdiIcons.cubeOutline, color: Colors.blueGrey),
                  SizedBox(width: 4),
                  Text('Product:', style: theme.textTheme.bodyLarge),
                  SizedBox(width: 4),
                  DropdownButton<String>(
                    value: productFilter,
                    hint: Text('All'),
                    items: [null, ...productNames]
                        .map(
                          (name) => DropdownMenuItem(
                            value: name,
                            child: Text(name ?? 'All'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      productFilter = v;
                    }),
                  ),
                  SizedBox(width: 16),
                  Tooltip(
                    message: 'Apply Filters',
                    child: ElevatedButton.icon(
                      icon: Icon(MdiIcons.filter),
                      label: Text('Apply'),
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(child: Text('Sales', style: TextStyle(fontWeight: FontWeight.bold))),
              Tab(child: Text('Purchases', style: TextStyle(fontWeight: FontWeight.bold))),
              Tab(child: Text('Income Statement', style: TextStyle(fontWeight: FontWeight.bold))),
              Tab(child: Text('Balance Sheet', style: TextStyle(fontWeight: FontWeight.bold))),
              Tab(child: Text('Cash Flow', style: TextStyle(fontWeight: FontWeight.bold))),
              Tab(child: Text('Full Report', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSalesReport(),
                      _buildPurchaseReport(),
                      _buildIncomeStatement(),
                      _buildBalanceSheet(),
                      _buildCashFlow(),
                      _buildFullReport(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<pw.Document> _generateSalesReportPdf(
    List<Map<String, dynamic>> filtered,
  ) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final businessName =
        prefs.getString('business_name') ?? 'Your Business Name';
    final businessAddress =
        prefs.getString('business_address') ?? '123 Business St, City, Country';
    final businessContact =
        prefs.getString('business_contact') ??
        'Contact: +123456789 | info@business.com';
    final now = DateTime.now();
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              businessName,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                font: fontBold,
              ),
            ),
            pw.Text(businessAddress, style: pw.TextStyle(font: font)),
            pw.Text(businessContact, style: pw.TextStyle(font: font)),
            pw.Divider(),
            pw.Text(
              'Sales Report',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                font: fontBold,
              ),
            ),
            pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
              style: pw.TextStyle(font: font),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Invoice No.', 'Date', 'Amount', 'Payment Status'],
              data: filtered
                  .map(
                    (sale) => [
                      sale['id']?.toString() ?? '',
                      sale['date']?.toString() ?? '',
                      'UGX ${sale['amount'] ?? 0}',
                      sale['payment_status'] ?? '',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                font: fontBold,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontSize: 10, font: font),
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  Widget _buildSalesReport({bool isInFullReport = false}) {
    final filtered = _filterByDate(sales, 'date').toList(); // Ensure mutable list
    // Sort filtered list if a sort column is selected
    if (salesSortColumn != null) {
      filtered.sort((a, b) {
        final aValue = a[salesSortColumn];
        final bValue = b[salesSortColumn];
        int cmp;
        if (aValue is num && bValue is num) {
          cmp = aValue.compareTo(bValue);
        } else if (aValue is String && bValue is String) {
          cmp = aValue.compareTo(bValue);
        } else if (aValue is Comparable && bValue is Comparable) {
          cmp = aValue.compareTo(bValue);
        } else {
          cmp = aValue.toString().compareTo(bValue.toString());
        }
        return salesSortAscending ? cmp : -cmp;
      });
    }
    final totalSales = filtered.fold<int>(0, (sum, s) => sum + ((s['amount'] ?? 0) as num).toInt());
    final content = [
      Row(
        children: [
          Tooltip(
            message: 'Export sales report as CSV',
            child: ElevatedButton.icon(
              icon: Icon(MdiIcons.download),
              label: Text('Export CSV'),
              onPressed: () {
                final rows = [
                  ['Invoice No.', 'Date', 'Amount', 'Payment Status'],
                  ...filtered.map(
                    (sale) => [
                      sale['id'],
                      sale['date'],
                      sale['amount'],
                      sale['payment_status'],
                    ],
                  ),
                ];
                _exportCSV(rows, 'sales_report.csv');
              },
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'Export sales report as PDF',
            child: ElevatedButton.icon(
              icon: Icon(MdiIcons.filePdfBox),
              label: Text('Export PDF'),
              onPressed: () async {
                final pdf = await _generateSalesReportPdf(filtered);
                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'sales_report.pdf',
                );
              },
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'Print sales report',
            child: ElevatedButton.icon(
              icon: Icon(MdiIcons.printer),
              label: Text('Print'),
              onPressed: () async {
                final pdf = await _generateSalesReportPdf(filtered);
                await Printing.layoutPdf(onLayout: (format) => pdf.save());
              },
            ),
          ),
          SizedBox(width: 16),
          Tooltip(
            message: 'Total sales in this report',
            child: Chip(
              label: Text('UGX ${NumberFormat.decimalPattern().format(totalSales)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
              avatar: Icon(MdiIcons.cashPlus, color: Colors.white),
            ),
          ),
        ],
      ),
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                child: Row(
                  children: [
                    _salesHeaderCell(
                      icon: MdiIcons.fileDocumentOutline,
                      label: 'Invoice No.',
                      flex: 2,
                      sortKey: 'id',
                      onTap: () => _onSalesSort('id'),
                    ),
                    _salesHeaderCell(
                      icon: MdiIcons.calendarMonthOutline,
                      label: 'Date',
                      flex: 2,
                      sortKey: 'date',
                      onTap: () => _onSalesSort('date'),
                    ),
                    _salesHeaderCell(
                      icon: MdiIcons.cash,
                      label: 'Amount',
                      flex: 2,
                      sortKey: 'amount',
                      onTap: () => _onSalesSort('amount'),
                    ),
                    _salesHeaderCell(
                      icon: MdiIcons.checkDecagram,
                      label: 'Payment Status',
                      flex: 2,
                      sortKey: 'payment_status',
                      onTap: () => _onSalesSort('payment_status'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1),
              SizedBox(
                height: 350,
                child: Scrollbar(
                  controller: _salesScrollController,
                  child: ListView.builder(
                    controller: _salesScrollController,
                    itemCount: filtered.length,
                    padding: EdgeInsets.only(bottom: 24.0),
                    itemBuilder: (context, i) {
                      final sale = filtered[i];
                      final formatter = NumberFormat.decimalPattern();
                      final paymentStatus = sale['payment_status'] ?? '';
                      final isPaid = paymentStatus.toString().toLowerCase().contains('paid') &&
                          !paymentStatus.toString().toLowerCase().contains('not');
                      final highlight = hoveredRowIndexSales == i;
                      return MouseRegion(
                        onEnter: (_) => setState(() { hoveredRowIndexSales = i; }),
                        onExit: (_) => setState(() { hoveredRowIndexSales = null; }),
                        child: Container(
                          color: highlight
                              ? Colors.blue.withOpacity(0.08)
                              : (i % 2 == 0
                                  ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
                                  : Colors.transparent),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                  child: Text(sale['id'].toString()),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                  child: Text(sale['date'] ?? ''),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                  child: Text(
                                    'UGX ${formatter.format(sale['amount'] ?? 0)}',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? Colors.green.withOpacity(0.15)
                                          : Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      paymentStatus,
                                      style: TextStyle(
                                        color: isPaid ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
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
            ],
          ),
        ),
      ),
    ];
    if (isInFullReport) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      );
    } else {
      return SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      );
    }
  }

  Future<pw.Document> _generatePurchaseReportPdf(
    List<Map<String, dynamic>> filtered,
  ) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final businessName =
        prefs.getString('business_name') ?? 'Your Business Name';
    final businessAddress =
        prefs.getString('business_address') ?? '123 Business St, City, Country';
    final businessContact =
        prefs.getString('business_contact') ??
        'Contact: +123456789 | info@business.com';
    final now = DateTime.now();
    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(32),
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
            pw.Text(
              'Purchase Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: [
                'Supplier',
                'Date',
                'Payment Status',
                'Delivery Status',
              ],
              data: filtered
                  .map(
                    (p) => [
                      p['supplier']?.toString() ?? '',
                      p['date']?.toString() ?? '',
                      p['payment_status'] ?? '',
                      p['delivery_status'] ?? '',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  Widget _buildPurchaseReport({bool isInFullReport = false}) {
    final filtered = _filterByDate(purchases, 'date').toList(); // Ensure mutable list
    // Sort filtered list if a sort column is selected
    if (purchasesSortColumn != null) {
      filtered.sort((a, b) {
        final aValue = a[purchasesSortColumn];
        final bValue = b[purchasesSortColumn];
        int cmp;
        if (aValue is num && bValue is num) {
          cmp = aValue.compareTo(bValue);
        } else if (aValue is String && bValue is String) {
          cmp = aValue.compareTo(bValue);
        } else if (aValue is Comparable && bValue is Comparable) {
          cmp = aValue.compareTo(bValue);
        } else {
          cmp = aValue.toString().compareTo(bValue.toString());
        }
        return purchasesSortAscending ? cmp : -cmp;
      });
    }
    final totalPurchases = filtered.fold<int>(0, (sum, p) => sum + ((p['total'] ?? 0) as num).toInt());
    final content = [
      Row(
        children: [
          Tooltip(
            message: 'Export purchases report as CSV',
            child: ElevatedButton.icon(
              icon: Icon(MdiIcons.download),
              label: Text('Export CSV'),
              onPressed: () {
                final rows = [
                  ['Supplier', 'Date', 'Payment Status', 'Delivery Status'],
                  ...filtered.map(
                    (p) => [
                      p['supplier'],
                      p['date'],
                      p['payment_status'],
                      p['delivery_status'],
                    ],
                  ),
                ];
                _exportCSV(rows, 'purchase_report.csv');
              },
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'Export purchases report as PDF',
            child: ElevatedButton.icon(
              icon: Icon(MdiIcons.filePdfBox),
              label: Text('Export PDF'),
              onPressed: () async {
                final pdf = await _generatePurchaseReportPdf(filtered);
                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'purchase_report.pdf',
                );
              },
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'Print purchases report',
            child: ElevatedButton.icon(
              icon: Icon(MdiIcons.printer),
              label: Text('Print'),
              onPressed: () async {
                final pdf = await _generatePurchaseReportPdf(filtered);
                await Printing.layoutPdf(onLayout: (format) => pdf.save());
              },
            ),
          ),
          SizedBox(width: 16),
          Tooltip(
            message: 'Total purchases in this report',
            child: Chip(
              label: Text('UGX ${NumberFormat.decimalPattern().format(totalPurchases)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.blue,
              avatar: Icon(MdiIcons.cartArrowDown, color: Colors.white),
            ),
          ),
        ],
      ),
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 0),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Table header (unscrollable)
                    Container(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                      child: Row(
                        children: [
                          _purchasesHeaderCell(
                            label: 'Supplier',
                            flex: 2,
                            sortKey: 'supplier',
                            onTap: () => _onPurchasesSort('supplier'),
                          ),
                          _purchasesHeaderCell(
                            label: 'Date',
                            flex: 2,
                            sortKey: 'date',
                            onTap: () => _onPurchasesSort('date'),
                          ),
                          _purchasesHeaderCell(
                            label: 'Payment Status',
                            flex: 2,
                            sortKey: 'payment_status',
                            onTap: () => _onPurchasesSort('payment_status'),
                          ),
                          _purchasesHeaderCell(
                            label: 'Delivery Status',
                            flex: 2,
                            sortKey: 'delivery_status',
                            onTap: () => _onPurchasesSort('delivery_status'),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1),
                    // Table body (scrollable)
                    SizedBox(
                      height: 350,
                      child: Scrollbar(
                        controller: _purchasesScrollController,
                        child: ListView.builder(
                          controller: _purchasesScrollController,
                          itemCount: filtered.length,
                          padding: EdgeInsets.only(bottom: 24.0),
                          itemBuilder: (context, i) {
                            final p = filtered[i];
                            final highlight = hoveredRowIndexPurchases == i;
                            return MouseRegion(
                              onEnter: (_) => setState(() { hoveredRowIndexPurchases = i; }),
                              onExit: (_) => setState(() { hoveredRowIndexPurchases = null; }),
                              child: Container(
                                color: highlight
                                    ? Colors.blue.withOpacity(0.08)
                                    : (i % 2 == 0
                                        ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
                                        : Colors.transparent),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                        child: Text(p['supplier'] ?? ''),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                        child: Text(p['date'] ?? ''),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                        child: Text(p['payment_status'] ?? ''),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                        child: Text(p['delivery_status'] ?? ''),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
    if (isInFullReport) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      );
    } else {
      return ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: content,
      );
    }
  }

  Future<pw.Document> _generateIncomeStatementPdf(
    int totalSales,
    int totalExpenses,
    int profit,
  ) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final businessName =
        prefs.getString('business_name') ?? 'Your Business Name';
    final businessAddress =
        prefs.getString('business_address') ?? '123 Business St, City, Country';
    final businessContact =
        prefs.getString('business_contact') ??
        'Contact: +123456789 | info@business.com';
    final now = DateTime.now();
    final formatter = NumberFormat.decimalPattern();
    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(32),
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
            pw.Text(
              'Income Statement',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}'),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Revenue',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('UGX ${formatter.format(totalSales)}'),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Expenses',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('UGX ${formatter.format(totalExpenses)}'),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: profit >= 0 ? PdfColors.green100 : PdfColors.red100,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        'Net Profit',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        'UGX ${formatter.format(profit)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: profit >= 0
                              ? PdfColors.green800
                              : PdfColors.red800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  Widget _buildIncomeStatement({bool isInFullReport = false}) {
    final filteredSales = _filterByDate(sales, 'date');
    final filteredExpenses = _filterByDate(expenses, 'date');
    final totalSales = filteredSales.fold<int>(
      0,
      (sum, s) => (sum + (s['amount'] ?? 0)).toInt(),
    );
    final totalExpenses = filteredExpenses.fold<int>(
      0,
      (sum, e) => (sum + (e['amount'] ?? 0)).toInt(),
    );
    final profit = totalSales - totalExpenses;
    final formatter = NumberFormat.decimalPattern();
    final theme = Theme.of(context);
    int? hoveredRowIndex;
    final content = [
      Row(
        children: [
          Tooltip(
            message: 'Export income statement as PDF',
            child: ElevatedButton.icon(
              icon: Icon(MdiIcons.filePdfBox),
              label: Text('Export PDF'),
              onPressed: () async {
                final pdf = await _generateIncomeStatementPdf(
                  totalSales,
                  totalExpenses,
                  profit,
                );
                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'income_statement.pdf',
                );
              },
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'Print income statement',
            child: ElevatedButton.icon(
              icon: Icon(MdiIcons.printer),
              label: Text('Print'),
              onPressed: () async {
                final pdf = await _generateIncomeStatementPdf(
                  totalSales,
                  totalExpenses,
                  profit,
                );
                await Printing.layoutPdf(
                  onLayout: (format) => pdf.save(),
                );
              },
            ),
          ),
          SizedBox(width: 16),
          Tooltip(
            message: 'Total sales (revenue) in this period',
            child: Chip(
              label: Text('UGX ${formatter.format(totalSales)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
              avatar: Icon(MdiIcons.cashPlus, color: Colors.white),
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'Total expenses in this period',
            child: Chip(
              label: Text('UGX ${formatter.format(totalExpenses)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.redAccent,
              avatar: Icon(MdiIcons.cashMinus, color: Colors.white),
            ),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: 'Net profit (revenue - expenses)',
            child: Chip(
              label: Text('UGX ${formatter.format(profit)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: profit >= 0 ? Colors.green : Colors.red,
              avatar: Icon(profit >= 0 ? MdiIcons.cashCheck : MdiIcons.cashRemove, color: Colors.white),
            ),
          ),
        ],
      ),
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.chartBoxOutline, color: Colors.deepPurple, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Income Statement',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Table header (unscrollable)
                    Container(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                              child: Row(
                                children: [
                                  Icon(MdiIcons.trendingUp, color: Colors.green, size: 22),
                                  SizedBox(width: 6),
                                  Text('Revenue', style: TextStyle(fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                              child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1),
                    // Table body (scrollable)
                    SizedBox(
                      height: 250, // Increased height for more details
                      child: Scrollbar(
                        controller: _incomeStatementScrollController,
                        child: ListView(
                          controller: _incomeStatementScrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            // Summary rows
                            Container(
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Row(
                                        children: [
                                          Icon(MdiIcons.trendingUp, color: Colors.green, size: 0),
                                          SizedBox(width: 0),
                                          Text('Revenue', style: TextStyle(color: Colors.transparent)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Text('UGX ${formatter.format(totalSales)}', style: TextStyle(fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, thickness: 1),
                            Container(
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Row(
                                        children: [
                                          Icon(MdiIcons.trendingDown, color: Colors.red, size: 22),
                                          SizedBox(width: 6),
                                          Text('Expenses', style: TextStyle(fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Text('UGX ${formatter.format(totalExpenses)}', style: TextStyle(fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, thickness: 1),
                            Container(
                              color: profit >= 0 ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            profit >= 0 ? MdiIcons.cashCheck : MdiIcons.cashRemove,
                                            color: profit >= 0 ? Colors.green : Colors.red,
                                            size: 24,
                                          ),
                                          SizedBox(width: 6),
                                          Text('Net Profit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                                      child: Text(
                                        'UGX ${formatter.format(profit)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: profit >= 0 ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, thickness: 1),
                            // Expense details header
                            Container(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, thickness: 1),
                            // Expense details rows
                            ...filteredExpenses.map((e) => Container(
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Text(e['description']?.toString() ?? ''),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Text(e['date']?.toString() ?? ''),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                      child: Text('UGX ${formatter.format(e['amount'] ?? 0)}'),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
    if (isInFullReport) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      );
    } else {
      return ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: content,
      );
    }
  }

  Future<pw.Document> _generateBalanceSheetPdf(
    int inventoryValue,
    int totalPurchases,
    int totalSales,
  ) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final businessName =
        prefs.getString('business_name') ?? 'Your Business Name';
    final businessAddress =
        prefs.getString('business_address') ?? '123 Business St, City, Country';
    final businessContact =
        prefs.getString('business_contact') ??
        'Contact: +123456789 | info@business.com';
    final now = DateTime.now();
    final formatter = NumberFormat.decimalPattern();
    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(32),
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
            pw.Text(
              'Balance Sheet',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}'),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Assets (Inventory)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('UGX ${formatter.format(inventoryValue)}'),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Liabilities (Purchases)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('UGX ${formatter.format(totalPurchases)}'),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.green100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        'Equity (Sales)',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        'UGX ${formatter.format(totalSales)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: PdfColors.green800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  Widget _buildBalanceSheet({bool isInFullReport = false}) {
    final filteredInventory = productFilter == null
        ? inventory
        : inventory.where((i) => i['name'] == productFilter).toList();
    final inventoryValue = filteredInventory.fold<int>(
      0,
      (sum, item) => (sum + ((item['qty'] ?? 0) * (item['sale'] ?? 0))).toInt(),
    );
    final filteredPurchases = _filterByDate(purchases, 'date');
    final totalPurchases = filteredPurchases.fold<int>(
      0,
      (sum, p) => (sum + (p['total'] ?? 0)).toInt(),
    );
    final filteredSales = _filterByDate(sales, 'date');
    final totalSales = filteredSales.fold<int>(
      0,
      (sum, s) => (sum + (s['amount'] ?? 0)).toInt(),
    );
    final formatter = NumberFormat.decimalPattern();
    final theme = Theme.of(context);
    final content = [
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.scaleBalance, color: Colors.blue, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Balance Sheet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.filePdfBox),
                    label: Text('Export PDF'),
                    onPressed: () async {
                      final pdf = await _generateBalanceSheetPdf(
                        inventoryValue,
                        totalPurchases,
                        totalSales,
                      );
                      await Printing.sharePdf(
                        bytes: await pdf.save(),
                        filename: 'balance_sheet.pdf',
                      );
                    },
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.printer),
                    label: Text('Print'),
                    onPressed: () async {
                      final pdf = await _generateBalanceSheetPdf(
                        inventoryValue,
                        totalPurchases,
                        totalSales,
                      );
                      await Printing.layoutPdf(
                        onLayout: (format) => pdf.save(),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(
                        0.5,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(MdiIcons.packageVariantClosed, color: Colors.blue, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Assets (Inventory)',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Text(
                          'UGX ${formatter.format(inventoryValue)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    decoration: BoxDecoration(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(MdiIcons.cartArrowDown, color: Colors.red, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Liabilities (Purchases)',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Text(
                          'UGX ${formatter.format(totalPurchases)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(MdiIcons.cashMultiple, color: Colors.green, size: 24),
                            SizedBox(width: 6),
                            Text(
                              'Equity (Sales)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 4,
                        ),
                        child: Text(
                          'UGX ${formatter.format(totalSales)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
    if (isInFullReport) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      );
    } else {
      return ListView(
        padding: EdgeInsets.zero,
        children: content,
      );
    }
  }

  Future<pw.Document> _generateCashFlowPdf(
    int totalSales,
    int totalPurchases,
    int totalExpenses,
    int cashFlow,
  ) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final businessName =
        prefs.getString('business_name') ?? 'Your Business Name';
    final businessAddress =
        prefs.getString('business_address') ?? '123 Business St, City, Country';
    final businessContact =
        prefs.getString('business_contact') ??
        'Contact: +123456789 | info@business.com';
    final now = DateTime.now();
    final formatter = NumberFormat.decimalPattern();
    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(32),
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
            pw.Text(
              'Cash Flow Statement',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}'),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total Sales',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('UGX ${formatter.format(totalSales)}'),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total Purchases',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('UGX ${formatter.format(totalPurchases)}'),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total Expenses',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('UGX ${formatter.format(totalExpenses)}'),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: cashFlow >= 0
                        ? PdfColors.green100
                        : PdfColors.red100,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        'Net Cash Flow',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Text(
                        'UGX ${formatter.format(cashFlow)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: cashFlow >= 0
                              ? PdfColors.green800
                              : PdfColors.red800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  Widget _buildCashFlow({bool isInFullReport = false}) {
    final filteredSales = _filterByDate(sales, 'date');
    final filteredPurchases = _filterByDate(purchases, 'date');
    final filteredExpenses = _filterByDate(expenses, 'date');
    final totalSales = filteredSales.fold<int>(
      0,
      (sum, s) => (sum + (s['amount'] ?? 0)).toInt(),
    );
    final totalPurchases = filteredPurchases.fold<int>(
      0,
      (sum, p) => (sum + (p['total'] ?? 0)).toInt(),
    );
    final totalExpenses = filteredExpenses.fold<int>(
      0,
      (sum, e) => (sum + (e['amount'] ?? 0)).toInt(),
    );
    final cashFlow = totalSales - totalPurchases - totalExpenses;
    final formatter = NumberFormat.decimalPattern();
    final theme = Theme.of(context);
    final content = [
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.swapVertical, color: Colors.teal, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Cash Flow Statement',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.filePdfBox),
                    label: Text('Export PDF'),
                    onPressed: () async {
                      final pdf = await _generateCashFlowPdf(
                        totalSales,
                        totalPurchases,
                        totalExpenses,
                        cashFlow,
                      );
                      await Printing.sharePdf(
                        bytes: await pdf.save(),
                        filename: 'cash_flow.pdf',
                      );
                    },
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.printer),
                    label: Text('Print'),
                    onPressed: () async {
                      final pdf = await _generateCashFlowPdf(
                        totalSales,
                        totalPurchases,
                        totalExpenses,
                        cashFlow,
                      );
                      await Printing.layoutPdf(
                        onLayout: (format) => pdf.save(),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(
                        0.5,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(MdiIcons.trendingUp, color: Colors.green, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Total Sales',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Text(
                          'UGX ${formatter.format(totalSales)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    decoration: BoxDecoration(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(MdiIcons.cartArrowDown, color: Colors.red, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Total Purchases',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Text(
                          'UGX ${formatter.format(totalPurchases)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    decoration: BoxDecoration(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(MdiIcons.cashMinus, color: Colors.red, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Total Expenses',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4,
                        ),
                        child: Text(
                          'UGX ${formatter.format(totalExpenses)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    decoration: BoxDecoration(
                      color: cashFlow >= 0
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              cashFlow >= 0
                                  ? MdiIcons.cashCheck
                                  : MdiIcons.cashRemove,
                              color: cashFlow >= 0
                                  ? Colors.green
                                  : Colors.red,
                              size: 24,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Net Cash Flow',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 4,
                        ),
                        child: Text(
                          'UGX ${formatter.format(cashFlow)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: cashFlow >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
    if (isInFullReport) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      );
    } else {
      return ListView(
        padding: EdgeInsets.zero,
        children: content,
      );
    }
  }

  Future<pw.Document> _generateFullReportPdf() async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final businessName =
        prefs.getString('business_name') ?? 'Your Business Name';
    final businessAddress =
        prefs.getString('business_address') ?? '123 Business St, City, Country';
    final businessContact =
        prefs.getString('business_contact') ??
        'Contact: +123456789 | info@business.com';
    final now = DateTime.now();
    final formatter = NumberFormat.decimalPattern();
    // Prepare data
    final filteredSales = _filterByDate(sales, 'date');
    final filteredPurchases = _filterByDate(purchases, 'date');
    final filteredExpenses = _filterByDate(expenses, 'date');
    final filteredInventory = productFilter == null
        ? inventory
        : inventory.where((i) => i['name'] == productFilter).toList();
    final totalSales = filteredSales.fold<int>(
      0,
      (sum, s) => (sum + (s['amount'] ?? 0)).toInt(),
    );
    final totalPurchases = filteredPurchases.fold<int>(
      0,
      (sum, p) => (sum + (p['total'] ?? 0)).toInt(),
    );
    final totalExpenses = filteredExpenses.fold<int>(
      0,
      (sum, e) => (sum + (e['amount'] ?? 0)).toInt(),
    );
    final inventoryValue = filteredInventory.fold<int>(
      0,
      (sum, item) => (sum + ((item['qty'] ?? 0) * (item['sale'] ?? 0))).toInt(),
    );
    final profit = totalSales - totalExpenses;
    final cashFlow = totalSales - totalPurchases - totalExpenses;
    pdf.addPage(
      pw.MultiPage(
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Text(
            businessName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(businessAddress),
          pw.Text(businessContact),
          pw.Divider(),
          pw.Text(
            'Full Business Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}'),
          pw.SizedBox(height: 12),
          // Sales Report
          pw.Text(
            'Sales Report',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
          ),
          pw.Table.fromTextArray(
            headers: ['Invoice No.', 'Date', 'Amount', 'Payment Status'],
            data: filteredSales
                .map(
                  (sale) => [
                    sale['id']?.toString() ?? '',
                    sale['date']?.toString() ?? '',
                    'UGX ${sale['amount'] ?? 0}',
                    sale['payment_status'] ?? '',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          ),
          pw.SizedBox(height: 16),
          // Purchase Report
          pw.Text(
            'Purchase Report',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
          ),
          pw.Table.fromTextArray(
            headers: ['Supplier', 'Date', 'Payment Status', 'Delivery Status'],
            data: filteredPurchases
                .map(
                  (p) => [
                    p['supplier']?.toString() ?? '',
                    p['date']?.toString() ?? '',
                    p['payment_status'] ?? '',
                    p['delivery_status'] ?? '',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          ),
          pw.SizedBox(height: 16),
          // Income Statement
          pw.Text(
            'Income Statement',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Revenue',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('UGX ${formatter.format(totalSales)}'),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Expenses',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('UGX ${formatter.format(totalExpenses)}'),
                  ),
                ],
              ),
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: profit >= 0 ? PdfColors.green100 : PdfColors.red100,
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Text(
                      'Net Profit',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Text(
                      'UGX ${formatter.format(profit)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: profit >= 0
                            ? PdfColors.green800
                            : PdfColors.red800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          // Balance Sheet
          pw.Text(
            'Balance Sheet',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Assets (Inventory)',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('UGX ${formatter.format(inventoryValue)}'),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Liabilities (Purchases)',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('UGX ${formatter.format(totalPurchases)}'),
                  ),
                ],
              ),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.green100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Text(
                      'Equity (Sales)',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Text(
                      'UGX ${formatter.format(totalSales)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: PdfColors.green800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          // Cash Flow
          pw.Text(
            'Cash Flow Statement',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Total Sales',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('UGX ${formatter.format(totalSales)}'),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Total Purchases',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('UGX ${formatter.format(totalPurchases)}'),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Total Expenses',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('UGX ${formatter.format(totalExpenses)}'),
                  ),
                ],
              ),
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: cashFlow >= 0 ? PdfColors.green100 : PdfColors.red100,
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Text(
                      'Net Cash Flow',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Text(
                      'UGX ${formatter.format(cashFlow)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: cashFlow >= 0
                            ? PdfColors.green800
                            : PdfColors.red800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return pdf;
  }

  Widget _buildFullReport() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        MdiIcons.fileChart,
                        color: theme.colorScheme.primary,
                        size: 34,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Full Business Report',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(MdiIcons.filePdfBox),
                        label: Text('Export PDF'),
                        onPressed: () async {
                          final pdf = await _generateFullReportPdf();
                          await Printing.sharePdf(
                            bytes: await pdf.save(),
                            filename: 'full_report.pdf',
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(MdiIcons.printer),
                        label: Text('Print'),
                        onPressed: () async {
                          final pdf = await _generateFullReportPdf();
                          await Printing.layoutPdf(
                            onLayout: (format) => pdf.save(),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildSalesReport(isInFullReport: true),
                  SizedBox(height: 24),
                  _buildPurchaseReport(isInFullReport: true),
                  SizedBox(height: 24),
                  _buildIncomeStatement(isInFullReport: true),
                  SizedBox(height: 24),
                  _buildBalanceSheet(isInFullReport: true),
                  SizedBox(height: 24),
                  _buildCashFlow(isInFullReport: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

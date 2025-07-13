import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../core/db.dart';
import '../../widgets/footer.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/purchases/purchases_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/backup/backup_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../written_off_screen.dart';

class DashboardOverview extends StatefulWidget {
  final int? activeBranchId;
  final String businessName;
  final String userName;
  final String userRole;
  final String? userPhotoUrl;

  DashboardOverview({
    required this.activeBranchId,
    required this.businessName,
    required this.userName,
    required this.userRole,
    this.userPhotoUrl,
  });

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  bool loading = true;
  List<Map<String, dynamic>> inventory = [];
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> writtenOff = [];
  List<Map<String, dynamic>> purchases = [];
  int writtenOffValue = 0;
  String? _businessLogoPath;

  int receivables = 0;
  int payables = 0;

  // Branches for switcher
  List<Map<String, dynamic>> _branches = [];
  int? _selectedBranchId;
  bool _loadingBranches = true;

  // 0 = Month, 1 = Week, 2 = Day
  int _growthView = 0;

  @override
  void initState() {
    super.initState();
    _loadBusinessLogo();
    _loadBranches();
    _loadData();
  }

  Future<void> _loadBranches() async {
    setState(() { _loadingBranches = true; });
    final branches = await AppDatabase.getBranches();
    // Ensure 'All Branches' is always the first option and not duplicated
    final allBranchesOption = {'id': null, 'name': 'All Branches'};
    final filteredBranches = branches.where((b) => b['id'] != null).toList();
    setState(() {
      _branches = [allBranchesOption, ...filteredBranches];
      _selectedBranchId = widget.activeBranchId;
      _loadingBranches = false;
    });
  }

  Future<void> _loadBusinessLogo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _businessLogoPath = prefs.getString('business_logo');
    });
  }

  @override
  void didUpdateWidget(covariant DashboardOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeBranchId != widget.activeBranchId) {
      _selectedBranchId = widget.activeBranchId;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
    });
    final db = await AppDatabase.database;
    List<Map<String, dynamic>> inv = [];
    List<Map<String, dynamic>> salesData = [];
    List<Map<String, dynamic>> expensesData = [];
    List<Map<String, dynamic>> purchasesData = [];
    List<Map<String, dynamic>> writtenOffData = [];
    // Accept both null and 0 as "All Branches" for compatibility with AppBar switcher
    final allBranchesSelected = (widget.activeBranchId == null || widget.activeBranchId == 0);
    final branchId = allBranchesSelected ? null : widget.activeBranchId;
    if (allBranchesSelected) {
      // All branches: aggregate all data
      inv = await AppDatabase.getInventory();
      salesData = await AppDatabase.getSales();
      expensesData = await AppDatabase.getExpenses();
      purchasesData = await db.query('purchases');
      writtenOffData = await db.query('written_off');
    } else {
      inv = await AppDatabase.getInventory(branchId: branchId);
      salesData = await AppDatabase.getSales(branchId: branchId);
      expensesData = await AppDatabase.getExpenses(branchId: branchId);
      purchasesData = await db.query('purchases', where: 'branch_id = ?', whereArgs: [branchId]);
      writtenOffData = await db.query('written_off', where: 'branch_id = ?', whereArgs: [branchId]);
    }
    int wValue = 0;
    for (final item in writtenOffData) {
      final int qty = (item['qty'] is int)
          ? item['qty'] as int
          : int.tryParse(item['qty']?.toString() ?? '') ?? 0;
      final int purchase = (item['purchase'] is int)
          ? item['purchase'] as int
          : int.tryParse(item['purchase']?.toString() ?? '') ?? 0;
      wValue += qty * purchase;
    }
    // Calculate receivables (sales: amount - paid where paid < amount)
    int rec = 0;
    for (final s in salesData) {
      final int amount = (s['amount'] is int) ? s['amount'] as int : int.tryParse(s['amount']?.toString() ?? '') ?? 0;
      final int paid = (s['paid'] is int) ? s['paid'] as int : int.tryParse(s['paid']?.toString() ?? '') ?? 0;
      if (paid < amount) rec += (amount - paid);
    }
    // Calculate payables (purchases: total - amount_paid where amount_paid < total)
    int pay = 0;
    for (final p in purchasesData) {
      final int total = (p['total'] is int) ? p['total'] as int : int.tryParse(p['total']?.toString() ?? '') ?? 0;
      final int paid = (p['amount_paid'] is int) ? p['amount_paid'] as int : int.tryParse(p['amount_paid']?.toString() ?? '') ?? 0;
      if (paid < total) pay += (total - paid);
    }
    setState(() {
      inventory = List<Map<String, dynamic>>.from(inv);
      sales = List<Map<String, dynamic>>.from(salesData);
      expenses = List<Map<String, dynamic>>.from(expensesData);
      writtenOff = List<Map<String, dynamic>>.from(writtenOffData);
      purchases = List<Map<String, dynamic>>.from(purchasesData);
      writtenOffValue = wValue;
      receivables = rec;
      payables = pay;
      loading = false;
    });
  }

  Widget summaryInfoBox(String label, int value, IconData icon, Color? color) {
    final formatter = NumberFormat.decimalPattern();
    return Container(
      width: 200,
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.08) ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color?.withOpacity(0.18) ?? Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.blueGrey, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'UGX ${formatter.format(value)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(
    String label,
    int value, {
    IconData? icon,
    Color? iconColor,
    Color? bgColor,
  }) {
    final formatter = NumberFormat.decimalPattern();
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('UGX ${formatter.format(value)}', style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _valueCard({
    required String label,
    required int value,
    required IconData icon,
    required Color? iconColor,
    required Color? bgColor,
    Color? badgeColor,
  }) {
    final formatter = NumberFormat.decimalPattern();
    final bool showBadge = badgeColor != null;
    return Container(
      width: 220,
      constraints: BoxConstraints(minWidth: 160, maxWidth: 260),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.blue).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.all(10),
            child: Icon(icon, color: iconColor ?? Colors.blue, size: 28),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'UGX ${formatter.format(value)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showBadge) ...[
                      SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            value < 0 ? 'NEGATIVE' : 'POSITIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReceivablesDialog(BuildContext context) {
    DateTime? fromDate;
    DateTime? toDate;
    List<Map<String, dynamic>> filtered = sales.where((s) {
      final int amount = (s['amount'] is int) ? s['amount'] as int : int.tryParse(s['amount']?.toString() ?? '') ?? 0;
      final int paid = (s['paid'] is int) ? s['paid'] as int : int.tryParse(s['paid']?.toString() ?? '') ?? 0;
      if (paid >= amount) return false;
      final date = s['date'] != null ? DateTime.tryParse(s['date']) : null;
      final fromOk = fromDate == null || (date != null && !date.isBefore(fromDate));
      final toOk = toDate == null || (date != null && !date.isAfter(toDate));
      return fromOk && toOk;
    }).toList();
    // Persist sort state across dialog rebuilds
    int sortColumnIndex = 2; // Default to Date
    bool sortAscending = false; // LIFO
    showDialog(
      context: context,
      builder: (context) {
        DateTime? _from = fromDate;
        DateTime? _to = toDate;
        return StatefulBuilder(
          builder: (context, setState) {
            void updateSort(int i, bool asc) {
              sortColumnIndex = i;
              sortAscending = asc;
              setState(() {});
            }
            List<Map<String, dynamic>> filtered = sales.where((s) {
              final int amount = (s['amount'] is int) ? s['amount'] as int : int.tryParse(s['amount']?.toString() ?? '') ?? 0;
              final int paid = (s['paid'] is int) ? s['paid'] as int : int.tryParse(s['paid']?.toString() ?? '') ?? 0;
              if (paid >= amount) return false;
              final date = s['date'] != null ? DateTime.tryParse(s['date']) : null;
              final fromOk = _from == null || (date != null && (_from == null || !date.isBefore(_from!)));
              final toOk = _to == null || (date != null && (_to == null || !date.isAfter(_to!)));
              return fromOk && toOk;
            }).toList();
            // Ensure mutable and sort by id descending (latest first)
            filtered = List<Map<String, dynamic>>.from(filtered);
            filtered.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
            // Sorting logic (by column)
            filtered.sort((a, b) {
              int cmp = 0;
              switch (sortColumnIndex) {
                case 0:
                  cmp = (b['id'] ?? 0).compareTo(a['id'] ?? 0);
                  break;
                case 1:
                  cmp = (b['customer_name'] ?? '').toString().compareTo((a['customer_name'] ?? '').toString());
                  break;
                case 2:
                  cmp = (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString());
                  break;
                case 3:
                  cmp = ((b['amount'] ?? 0) as int).compareTo((a['amount'] ?? 0) as int);
                  break;
                case 4:
                  cmp = ((b['paid'] ?? 0) as int).compareTo((a['paid'] ?? 0) as int);
                  break;
                case 5:
                  int balA = ((a['amount'] ?? 0) as int) - ((a['paid'] ?? 0) as int);
                  int balB = ((b['amount'] ?? 0) as int) - ((b['paid'] ?? 0) as int);
                  cmp = balB.compareTo(balA);
                  break;
                default:
                  cmp = (b['id'] ?? 0).compareTo(a['id'] ?? 0);
              }
              return sortAscending ? -cmp : cmp;
            });
            return AlertDialog(
              title: Text('Receivables (Debts)'),
              content: SizedBox(
                width: 800,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Total value at the top
                    Builder(
                      builder: (context) {
                        final formatter = NumberFormat.decimalPattern();
                        int totalReceivables = 0;
                        for (final s in filtered) {
                          final int amount = (s['amount'] is int) ? s['amount'] as int : int.tryParse(s['amount']?.toString() ?? '') ?? 0;
                          final int paid = (s['paid'] is int) ? s['paid'] as int : int.tryParse(s['paid']?.toString() ?? '') ?? 0;
                          if (paid < amount) totalReceivables += (amount - paid);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Text(
                                'Total Receivables: ',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'UGX 	${formatter.format(totalReceivables)}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange[800]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        Text('From: '),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _from ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _from = picked);
                          },
                          child: Text(_from != null ? DateFormat('yyyy-MM-dd').format(_from!) : 'Any'),
                        ),
                        SizedBox(width: 16),
                        Text('To: '),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _to ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _to = picked);
                          },
                          child: Text(_to != null ? DateFormat('yyyy-MM-dd').format(_to!) : 'Any'),
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.refresh, color: Colors.blue),
                          label: Text('Reset Date Filters'),
                          onPressed: () {
                            setState(() {
                              _from = null;
                              _to = null;
                            });
                          },
                        ),
                        Spacer(),
                        ElevatedButton.icon(
                          icon: Icon(Icons.picture_as_pdf, color: Colors.red),
                          label: Text('Export All to PDF'),
                          onPressed: () async {
                            await _exportAllInvoicesToPdf(context, filtered);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setState) {
                        final verticalController = ScrollController();
                        // Move hoveredRowIndex outside the builder to persist across rebuilds
                        return _ReceivablesPayablesTable(
                          filtered: filtered,
                          sortColumnIndex: sortColumnIndex,
                          sortAscending: sortAscending,
                          verticalController: verticalController,
                          isReceivables: true,
                          updateSort: updateSort,
                        );
                      },
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
      },
    );
  }

  void _showPayablesDialog(BuildContext context) {
    DateTime? fromDate;
    DateTime? toDate;
    int sortColumnIndex = 2; // Default to Date
    bool sortAscending = false; // LIFO
    showDialog(
      context: context,
      builder: (context) {
        DateTime? _from = fromDate;
        DateTime? _to = toDate;
        return StatefulBuilder(
          builder: (context, setState) {
            void updateSort(int i, bool asc) {
              setState(() {
                sortColumnIndex = i;
                sortAscending = asc;
              });
            }
            // Filter purchases for payables (unpaid only, with optional date filter)
            List<Map<String, dynamic>> filtered = purchases.where((p) {
              final int total = (p['total'] is int) ? p['total'] as int : int.tryParse(p['total']?.toString() ?? '') ?? 0;
              final int paid = (p['amount_paid'] is int) ? p['amount_paid'] as int : int.tryParse(p['amount_paid']?.toString() ?? '') ?? 0;
              if (paid >= total) return false;
              final date = p['date'] != null ? DateTime.tryParse(p['date']) : null;
              final fromOk = _from == null || (date != null && !date!.isBefore(_from!));
              final toOk = _to == null || (date != null && !date!.isAfter(_to!));
              return fromOk && toOk;
            }).toList();
            // Ensure mutable and sort by id descending (latest first)
            filtered = List<Map<String, dynamic>>.from(filtered);
            filtered.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
            // Sorting logic (LIFO: latest invoices on top by default)
            filtered.sort((a, b) {
              int cmp = 0;
              switch (sortColumnIndex) {
                case 0:
                  cmp = (b['id'] ?? 0).compareTo(a['id'] ?? 0);
                  break;
                case 1:
                  cmp = (b['supplier'] ?? '').toString().compareTo((a['supplier'] ?? '').toString());
                  break;
                case 2:
                  // Sort by date descending (latest first)
                  DateTime? dateA = a['date'] != null ? DateTime.tryParse(a['date']) : null;
                  DateTime? dateB = b['date'] != null ? DateTime.tryParse(b['date']) : null;
                  if (dateA == null && dateB == null) cmp = 0;
                  else if (dateA == null) cmp = 1;
                  else if (dateB == null) cmp = -1;
                  else cmp = dateB.compareTo(dateA); // LIFO: latest first
                  break;
                case 3:
                  cmp = ((b['total'] ?? 0) as int).compareTo((a['total'] ?? 0) as int);
                  break;
                case 4:
                  cmp = ((b['amount_paid'] ?? 0) as int).compareTo((a['amount_paid'] ?? 0) as int);
                  break;
                case 5:
                  int balA = ((a['total'] ?? 0) as int) - ((a['amount_paid'] ?? 0) as int);
                  int balB = ((b['total'] ?? 0) as int) - ((b['amount_paid'] ?? 0) as int);
                  cmp = balB.compareTo(balA);
                  break;
                default:
                  cmp = (b['id'] ?? 0).compareTo(a['id'] ?? 0);
              }
              return sortAscending ? -cmp : cmp;
            });
            return AlertDialog(
              title: Text('Payables (Unpaid)'),
              content: SizedBox(
                width: 800,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Total value at the top
                    Builder(
                      builder: (context) {
                        final formatter = NumberFormat.decimalPattern();
                        int totalPayables = 0;
                        for (final p in filtered) {
                          final int total = (p['total'] is int) ? p['total'] as int : int.tryParse(p['total']?.toString() ?? '') ?? 0;
                          final int paid = (p['amount_paid'] is int) ? p['amount_paid'] as int : int.tryParse(p['amount_paid']?.toString() ?? '') ?? 0;
                          if (paid < total) totalPayables += (total - paid);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Text(
                                'Total Payables: ',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'UGX 	${formatter.format(totalPayables)}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple[800]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        Text('From: '),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _from ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _from = picked);
                          },
                          child: Text(_from != null ? DateFormat('yyyy-MM-dd').format(_from!) : 'Any'),
                        ),
                        SizedBox(width: 16),
                        Text('To: '),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _to ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _to = picked);
                          },
                          child: Text(_to != null ? DateFormat('yyyy-MM-dd').format(_to!) : 'Any'),
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.refresh, color: Colors.blue),
                          label: Text('Reset Date Filters'),
                          onPressed: () {
                            setState(() {
                              _from = null;
                              _to = null;
                            });
                          },
                        ),
                        Spacer(),
                        ElevatedButton.icon(
                          icon: Icon(Icons.picture_as_pdf, color: Colors.red),
                          label: Text('Export All to PDF'),
                          onPressed: () async {
                            await _exportAllInvoicesToPdf(context, filtered);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setState) {
                        final verticalController = ScrollController();
                        int? hoveredRowIndex;
                        return SizedBox(
                          height: 400,
                          child: Scrollbar(
                            controller: verticalController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: verticalController,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 8.0,
                                  sortColumnIndex: sortColumnIndex,
                                  sortAscending: sortAscending,
                                  columns: [
                                    DataColumn(
                                    label: Text('Invoice No.'),
                                    onSort: (i, asc) {
                                    updateSort(i, asc);
                                    },
                                    ),
                                    DataColumn(
                                    label: Text('Supplier'),
                                    onSort: (i, asc) {
                                    updateSort(i, asc);
                                    },
                                    ),
                                    DataColumn(
                                    label: Text('Date'),
                                    onSort: (i, asc) {
                                    updateSort(i, asc);
                                    },
                                    ),
                                    DataColumn(
                                    label: Text('Total'),
                                    numeric: true,
                                    onSort: (i, asc) {
                                    updateSort(i, asc);
                                    },
                                    ),
                                    DataColumn(
                                    label: Text('Paid'),
                                    numeric: true,
                                    onSort: (i, asc) {
                                    updateSort(i, asc);
                                    },
                                    ),
                                    DataColumn(
                                    label: Text('Balance'),
                                    numeric: true,
                                    onSort: (i, asc) {
                                    updateSort(i, asc);
                                    },
                                    ),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: List<DataRow>.generate(filtered.length, (idx) {
                                    final p = filtered[idx];
                                    final int total = (p['total'] is int) ? p['total'] as int : int.tryParse(p['total']?.toString() ?? '') ?? 0;
                                    final int paid = (p['amount_paid'] is int) ? p['amount_paid'] as int : int.tryParse(p['amount_paid']?.toString() ?? '') ?? 0;
                                    final int balance = total - paid;
                                    const cellTextStyle = TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis);
                                    return DataRow(
                                      color: MaterialStateProperty.resolveWith<Color?>((states) {
                                        if (hoveredRowIndex == idx) {
                                          return Colors.orange.withOpacity(0.18);
                                        }
                                        return null;
                                      }),
                                      cells: [
                                        DataCell(
                                          MouseRegion(
                                            onEnter: (_) => setState(() { hoveredRowIndex = idx; }),
                                            onExit: (_) => setState(() { hoveredRowIndex = null; }),
                                            child: Container(width: 60, child: Text((p['id'] ?? '').toString(), style: cellTextStyle)),
                                          ),
                                        ),
                                        DataCell(
                                          MouseRegion(
                                            onEnter: (_) => setState(() { hoveredRowIndex = idx; }),
                                            onExit: (_) => setState(() { hoveredRowIndex = null; }),
                                            child: Container(width: 90, child: Text(p['supplier']?.toString() ?? '', style: cellTextStyle, maxLines: 1)),
                                          ),
                                        ),
                                        DataCell(
                                          MouseRegion(
                                            onEnter: (_) => setState(() { hoveredRowIndex = idx; }),
                                            onExit: (_) => setState(() { hoveredRowIndex = null; }),
                                            child: Container(width: 80, child: Text(p['date']?.toString() ?? '', style: cellTextStyle, maxLines: 1)),
                                          ),
                                        ),
                                        DataCell(
                                          MouseRegion(
                                            onEnter: (_) => setState(() { hoveredRowIndex = idx; }),
                                            onExit: (_) => setState(() { hoveredRowIndex = null; }),
                                            child: Container(width: 70, alignment: Alignment.centerRight, child: Text('UGX $total', style: cellTextStyle, maxLines: 1)),
                                          ),
                                        ),
                                        DataCell(
                                          MouseRegion(
                                            onEnter: (_) => setState(() { hoveredRowIndex = idx; }),
                                            onExit: (_) => setState(() { hoveredRowIndex = null; }),
                                            child: Container(width: 70, alignment: Alignment.centerRight, child: Text('UGX $paid', style: cellTextStyle, maxLines: 1)),
                                          ),
                                        ),
                                        DataCell(
                                          MouseRegion(
                                            onEnter: (_) => setState(() { hoveredRowIndex = idx; }),
                                            onExit: (_) => setState(() { hoveredRowIndex = null; }),
                                            child: Container(width: 80, alignment: Alignment.centerRight, child: Text('UGX $balance', style: cellTextStyle.copyWith(color: balance > 0 ? Colors.red : Colors.green), maxLines: 1)),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.visibility, size: 18),
                                                tooltip: 'View Invoice',
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                  builder: (_) => PurchasesScreen(
                                                  branchId: widget.activeBranchId ?? 0,
                                                  highlightInvoiceId: p['id'],
                                                  ),
                                                  ),
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                                                tooltip: 'Export to PDF',
                                                onPressed: () async {
                                                  await _exportInvoiceToPdf(context, p);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
      },
    );
  }

  // Helper to filter purchases for payables dialog
  List<Map<String, dynamic>> purchasesFiltered(DateTime? from, DateTime? to) {
    return (widget.activeBranchId != null)
        ? (context.findAncestorStateOfType<_DashboardOverviewState>()?.mounted ?? false)
            ? (this as _DashboardOverviewState).getPayablesFiltered(from, to)
            : []
        : [];
  }

  // Actual filter logic for payables
  List<Map<String, dynamic>> getPayablesFiltered(DateTime? from, DateTime? to) {
    final db = AppDatabase.database;
    // Use purchases from _loadData
    final List<Map<String, dynamic>> purchasesData = (this as _DashboardOverviewState).getPurchasesFromState();
    return purchasesData.where((p) {
      final int total = (p['total'] is int) ? p['total'] as int : int.tryParse(p['total']?.toString() ?? '') ?? 0;
      final int paid = (p['amount_paid'] is int) ? p['amount_paid'] as int : int.tryParse(p['amount_paid']?.toString() ?? '') ?? 0;
      if (paid >= total) return false;
      final date = p['date'] != null ? DateTime.tryParse(p['date']) : null;
      final fromOk = from == null || (date != null && !date.isBefore(from));
      final toOk = to == null || (date != null && !date.isAfter(to));
      return fromOk && toOk;
    }).toList();
  }

  // Helper to get purchases from state
  List<Map<String, dynamic>> getPurchasesFromState() {
    // Return the purchases loaded in _loadData
    return purchases;
  }

  // Export invoice as PDF and save to device
  Future<void> _exportInvoiceToPdf(BuildContext context, Map<String, dynamic> invoice) async {
    final pdf = pw.Document();
    final formatter = NumberFormat.decimalPattern();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('INVOICE', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Text('Invoice No: ${invoice['id'] ?? ''}', style: pw.TextStyle(fontSize: 16)),
                pw.Text('Customer: ${invoice['customer_name'] ?? ''}', style: pw.TextStyle(fontSize: 16)),
                pw.Text('Date: ${invoice['date'] ?? ''}', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 16),
                pw.Text('Total: UGX ${formatter.format(invoice['amount'] ?? 0)}', style: pw.TextStyle(fontSize: 16)),
                pw.Text('Paid: UGX ${formatter.format(invoice['paid'] ?? 0)}', style: pw.TextStyle(fontSize: 16)),
                pw.Text('Balance: UGX ${formatter.format((invoice['amount'] ?? 0) - (invoice['paid'] ?? 0))}', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 24),
                pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 14)),
              ],
            ),
          );
        },
      ),
    );
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/invoice_${invoice['id'] ?? DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice exported to PDF: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  // Export all invoices as a single PDF
  Future<void> _exportAllInvoicesToPdf(BuildContext context, List<Map<String, dynamic>> invoices) async {
    if (invoices.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No invoices to export.')),
        );
      }
      return;
    }
    final pdf = pw.Document();
    final formatter = NumberFormat.decimalPattern();
    for (final invoice in invoices) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('INVOICE', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 16),
                  pw.Text('Invoice No: ${invoice['id'] ?? ''}', style: pw.TextStyle(fontSize: 16)),
                  pw.Text('Customer: ${invoice['customer_name'] ?? ''}', style: pw.TextStyle(fontSize: 16)),
                  pw.Text('Date: ${invoice['date'] ?? ''}', style: pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 16),
                  pw.Text('Total: UGX ${formatter.format(invoice['amount'] ?? 0)}', style: pw.TextStyle(fontSize: 16)),
                  pw.Text('Paid: UGX ${formatter.format(invoice['paid'] ?? 0)}', style: pw.TextStyle(fontSize: 16)),
                  pw.Text('Balance: UGX ${formatter.format((invoice['amount'] ?? 0) - (invoice['paid'] ?? 0))}', style: pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 24),
                  pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 14)),
                ],
              ),
            );
          },
        ),
      );
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/all_invoices_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All invoices exported to PDF: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export all invoices: $e')),
        );
      }
    }
  }

// Table widget for Receivables/Payables dialogs
Widget _ReceivablesPayablesTable({
  required List<Map<String, dynamic>> filtered,
  required int sortColumnIndex,
  required bool sortAscending,
  required ScrollController verticalController,
  required bool isReceivables,
  void Function(int, bool)? updateSort,
}) {
  final cellTextStyle = const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis);
  return SizedBox(
    height: 400,
    child: Scrollbar(
      controller: verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: verticalController,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 8.0,
            sortColumnIndex: sortColumnIndex,
            sortAscending: sortAscending,
            columns: isReceivables
                ? [
                    DataColumn(
                      label: Text('Invoice No.'),
                      onSort: updateSort != null ? (i, asc) => updateSort(i, asc) : null,
                    ),
                    DataColumn(
                      label: Text('Customer'),
                      onSort: updateSort != null ? (i, asc) => updateSort(i, asc) : null,
                    ),
                    DataColumn(
                      label: Text('Date'),
                      onSort: updateSort != null ? (i, asc) => updateSort(i, asc) : null,
                    ),
                    DataColumn(
                      label: Text('Total'),
                      numeric: true,
                      onSort: updateSort != null ? (i, asc) => updateSort(i, asc) : null,
                    ),
                    DataColumn(
                      label: Text('Paid'),
                      numeric: true,
                      onSort: updateSort != null ? (i, asc) => updateSort(i, asc) : null,
                    ),
                    DataColumn(
                      label: Text('Balance'),
                      numeric: true,
                      onSort: updateSort != null ? (i, asc) => updateSort(i, asc) : null,
                    ),
                    DataColumn(label: Text('Actions')),
                  ]
                : [
                    DataColumn(
                      label: Text('Invoice No.'),
                    ),
                    DataColumn(
                      label: Text('Supplier'),
                    ),
                    DataColumn(
                      label: Text('Date'),
                    ),
                    DataColumn(
                      label: Text('Total'),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text('Paid'),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text('Balance'),
                      numeric: true,
                    ),
                    DataColumn(label: Text('Actions')),
                  ],
            rows: List<DataRow>.generate(filtered.length, (idx) {
              final item = filtered[idx];
              final int total = isReceivables
                  ? (item['amount'] is int)
                      ? item['amount'] as int
                      : int.tryParse(item['amount']?.toString() ?? '') ?? 0
                  : (item['total'] is int)
                      ? item['total'] as int
                      : int.tryParse(item['total']?.toString() ?? '') ?? 0;
              final int paid = isReceivables
                  ? (item['paid'] is int)
                      ? item['paid'] as int
                      : int.tryParse(item['paid']?.toString() ?? '') ?? 0
                  : (item['amount_paid'] is int)
                      ? item['amount_paid'] as int
                      : int.tryParse(item['amount_paid']?.toString() ?? '') ?? 0;
              final int balance = total - paid;
              return DataRow(
                cells: [
                  DataCell(Container(width: 60, child: Text((item['id'] ?? '').toString(), style: cellTextStyle))),
                  DataCell(Container(width: 90, child: Text(isReceivables ? (item['customer_name']?.toString() ?? '') : (item['supplier']?.toString() ?? ''), style: cellTextStyle, maxLines: 1))),
                  DataCell(Container(width: 80, child: Text(item['date']?.toString() ?? '', style: cellTextStyle, maxLines: 1))),
                  DataCell(Container(width: 70, alignment: Alignment.centerRight, child: Text('UGX $total', style: cellTextStyle, maxLines: 1))),
                  DataCell(Container(width: 70, alignment: Alignment.centerRight, child: Text('UGX $paid', style: cellTextStyle, maxLines: 1))),
                  DataCell(Container(width: 80, alignment: Alignment.centerRight, child: Text('UGX $balance', style: cellTextStyle.copyWith(color: balance > 0 ? Colors.red : Colors.green), maxLines: 1))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.visibility, size: 18),
                        tooltip: isReceivables ? 'View Invoice' : 'View Purchase',
                        onPressed: () {
                          if (!isReceivables) {
                            Navigator.of(verticalController.position.context.storageContext).pop();
                            Navigator.push(
                              verticalController.position.context.storageContext,
                              MaterialPageRoute(
                                builder: (_) => PurchasesScreen(
                                  branchId: item['branch_id'] ?? 0,
                                  highlightInvoiceId: item['id'],
                                ),
                              ),
                            );
                          } else {
                            Navigator.of(verticalController.position.context.storageContext).pop();
                            Navigator.push(
                              verticalController.position.context.storageContext,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    leading: BackButton(),
                                    title: Text('Sales'),
                                  ),
                                  body: SalesScreen(
                                    branchId: item['branch_id'] ?? 0,
                                    highlightInvoiceId: item['id'],
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                        tooltip: 'Export to PDF',
                        onPressed: () {
                          // Implement export to PDF if needed
                        },
                      ),
                    ],
                  )),
                ],
              );
            }),
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    // Business value summary
    final inventoryValue = inventory.fold<int>(
      0,
      (sum, item) => (sum + ((item['qty'] ?? 0) * (item['purchase'] ?? 0))).toInt(),
    );
    final totalIncome = sales.fold<int>(
      0,
      (sum, item) => (sum + (item['amount'] ?? 0)).toInt(),
    );
    final totalExpenses = expenses.fold<int>(
      0,
      (sum, item) => (sum + (item['amount'] ?? 0)).toInt(),
    );
    final businessWorth = inventoryValue + totalIncome - totalExpenses;
    // Low stock alerts (qty <= 5)
    final lowStock = inventory
        .where((item) => (item['qty'] ?? 0) <= 5)
        .toList();

    // Close to expiry alerts (expiry_date within 30 days)
    final nowDate = DateTime.now();
    final closeToExpiry = inventory.where((item) {
      if (item['expiry_date'] == null || item['expiry_date'].toString().isEmpty)
        return false;
      final expiry = DateTime.tryParse(item['expiry_date']);
      if (expiry == null) return false;
      final diff = expiry.difference(nowDate).inDays;
      return diff >= 0 && diff <= 30;
    }).toList();

    // Prepare 7-day (weekly) income/expenses for chart
    final now = DateTime.now();
    final List<double> weeklyIncome = List.filled(4, 0);
    final List<double> weeklyExpenses = List.filled(4, 0);
    for (int week = 0; week < 4; week++) {
      final weekStart = now.subtract(Duration(days: week * 7));
      final weekEnd = now.subtract(Duration(days: week * 7 + 6));
      for (final s in sales) {
        final date = s['date'];
        if (date != null) {
          final d = DateTime.tryParse(date);
          if (d != null && !d.isBefore(weekEnd) && !d.isAfter(weekStart)) {
            weeklyIncome[3 - week] += (s['amount'] ?? 0).toDouble();
          }
        }
      }
      for (final e in expenses) {
        final date = e['date'];
        if (date != null) {
          final d = DateTime.tryParse(date);
          if (d != null && !d.isBefore(weekEnd) && !d.isAfter(weekStart)) {
            weeklyExpenses[3 - week] += (e['amount'] ?? 0).toDouble();
          }
        }
      }
    }

    // Prepare monthly sales/expenses for chart (last 12 months)
    final Map<String, int> salesByMonth = {};
    final Map<String, int> expensesByMonth = {};
    for (int i = 0; i < 12; i++) {
      final month = DateFormat(
        'yyyy-MM',
      ).format(DateTime(now.year, now.month - i));
      salesByMonth[month] = 0;
      expensesByMonth[month] = 0;
    }
    for (final s in sales) {
      final month = (s['date'] ?? '').toString().substring(0, 7);
      if (salesByMonth.containsKey(month))
        salesByMonth[month] = (salesByMonth[month]! + (s['amount'] ?? 0))
            .toInt();
    }
    for (final e in expenses) {
      final month = (e['date'] ?? '').toString().substring(0, 7);
      if (expensesByMonth.containsKey(month))
        expensesByMonth[month] = (expensesByMonth[month]! + (e['amount'] ?? 0))
            .toInt();
    }
    final sales12 = List.generate(
      12,
      (i) =>
          salesByMonth[DateFormat(
                'yyyy-MM',
              ).format(DateTime(now.year, now.month - i))]!
              .toDouble(),
    );
    final expenses12 = List.generate(
      12,
      (i) =>
          expensesByMonth[DateFormat(
                'yyyy-MM',
              ).format(DateTime(now.year, now.month - i))]!
              .toDouble(),
    );

    // Prepare daily income/expenses for last 7 days (for daily table)
    final Map<String, int> incomeByDay = {};
    final Map<String, int> expensesByDay = {};
    for (int i = 0; i < 7; i++) {
      final day = DateFormat(
        'yyyy-MM-dd',
      ).format(now.subtract(Duration(days: i)));
      incomeByDay[day] = 0;
      expensesByDay[day] = 0;
    }
    for (final s in sales) {
      final day = s['date'] ?? '';
      if (incomeByDay.containsKey(day))
        incomeByDay[day] = (incomeByDay[day]! + (s['amount'] ?? 0)).toInt();
    }
    for (final e in expenses) {
      final day = e['date'] ?? '';
      if (expensesByDay.containsKey(day))
        expensesByDay[day] = (expensesByDay[day]! + (e['amount'] ?? 0)).toInt();
    }
    // Prepare daily table (last 7 days)
    final List<Map<String, dynamic>> dailyTable = List.generate(7, (i) {
      final day = DateFormat(
        'yyyy-MM-dd',
      ).format(now.subtract(Duration(days: i)));
      final salesAmt = incomeByDay[day] ?? 0;
      final expensesAmt = expensesByDay[day] ?? 0;
      final profit = salesAmt - expensesAmt;
      return {
        'date': DateFormat(
          'dd-MM-yyyy',
        ).format(now.subtract(Duration(days: i))),
        'sales': salesAmt,
        'expenses': expensesAmt,
        'profit': profit,
        'worth': businessWorth, // For demo, use current worth
      };
    });

    return loading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.grey[200],
                            backgroundImage:
                                _businessLogoPath != null &&
                                    _businessLogoPath!.isNotEmpty
                                ? (_businessLogoPath!.startsWith('http')
                                          ? NetworkImage(_businessLogoPath!)
                                          : FileImage(File(_businessLogoPath!)))
                                      as ImageProvider
                                : (widget.userPhotoUrl != null
                                      ? NetworkImage(widget.userPhotoUrl!)
                                      : null),
                            child:
                                (_businessLogoPath == null ||
                                        _businessLogoPath!.isEmpty) &&
                                    widget.userPhotoUrl == null
                                ? Icon(
                                    MdiIcons.store,
                                    size: 36,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.businessName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      MdiIcons.account,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      widget.userName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      MdiIcons.shieldAccount,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      widget.userRole,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                                                  ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Quick Actions Bar
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      leading: BackButton(),
                                      title: Text('Sales'),
                                    ),
                                    body: SalesScreen(
                                      branchId: widget.activeBranchId,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: Icon(MdiIcons.cartPlus, color: Colors.white),
                            label: Text('New Sale'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    body: PurchasesScreen(
                                      branchId: widget.activeBranchId ?? 0,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              MdiIcons.truckDelivery,
                              color: Colors.white,
                            ),
                            label: Text('New Purchase'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      leading: BackButton(),
                                      title: Text('Business Reports'),
                                    ),
                                    body: ReportsScreen(
                                      branchId: widget.activeBranchId,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: Icon(MdiIcons.fileChart, color: Colors.white),
                            label: Text('View Full Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      leading: BackButton(),
                                      title: Text('Backup'),
                                    ),
                                    body: BackupScreen(),
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              MdiIcons.cloudUploadOutline,
                              color: Colors.white,
                            ),
                            label: Text('Backup Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Branch Switcher
                  if (_branches.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18.0),
                      child: Row(
                        children: [
                          Text('Branch: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(width: 12),
                          DropdownButton<int?>(
                            value: _selectedBranchId,
                            items: _branches.map((branch) {
                              return DropdownMenuItem<int?>(
                                value: branch['id'],
                                child: Text(branch['name'] ?? 'Unknown'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedBranchId = value;
                              });
                              // Update the dashboard to show data for the selected branch (or all)
                              Navigator.pushReplacement(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation1, animation2) => DashboardOverview(
                                    activeBranchId: value,
                                    businessName: widget.businessName,
                                    userName: widget.userName,
                                    userRole: widget.userRole,
                                    userPhotoUrl: widget.userPhotoUrl,
                                  ),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  // Inventory Value Summary Card (single row)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InventoryScreen(
                                  branchId: widget.activeBranchId,
                                ),
                              ),
                            );
                          },
                          child: this._valueCard(
                            label: 'Inventory Value',
                            value: inventoryValue,
                            icon: MdiIcons.packageVariant,
                            iconColor: Colors.blue[700],
                            bgColor: Colors.blue[50],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WrittenOffScreen(
                                  branchId: widget.activeBranchId,
                                ),
                              ),
                            );
                          },
                          child: this._valueCard(
                            label: 'Written Off Value',
                            value: writtenOffValue,
                            icon: MdiIcons.trashCanOutline,
                            iconColor: Colors.red[700],
                            bgColor: Colors.red[50],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  // Today's Summary Panel
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Summary",
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 32,
                            runSpacing: 12,
                            children: [
                              this.summaryInfoBox(
                                'Sales',
                                incomeByDay[now.toString().substring(0, 10)] ??
                                    0,
                                MdiIcons.cashPlus,
                                Colors.green[700],
                              ),
                              this.summaryInfoBox(
                                'Expenses',
                                expensesByDay[now.toString().substring(
                                      0,
                                      10,
                                    )] ??
                                    0,
                                MdiIcons.cashMinus,
                                Colors.red[700],
                              ),
                              this.summaryInfoBox(
                                'Net Profit',
                                (incomeByDay[now.toString().substring(0, 10)] ??
                                        0) -
                                    (expensesByDay[now.toString().substring(
                                          0,
                                          10,
                                        )] ??
                                        0),
                                MdiIcons.trendingUp,
                                Colors.teal[700],
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showReceivablesDialog(context),
                                child: this.summaryInfoBox(
                                  'Receivables (Debts)',
                                  receivables,
                                  MdiIcons.accountArrowRight,
                                  Colors.orange[700],
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showPayablesDialog(context),
                                child: this.summaryInfoBox(
                                  'Payables (Unpaid)',
                                  payables,
                                  MdiIcons.accountArrowLeft,
                                  Colors.purple[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),
                  // Business Growth Line Graph (Last 6 months sales vs expenses)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _growthView == 0
                            ? 'Business Growth (Last 6 Months)'
                            : _growthView == 1
                            ? 'Business Growth (Last 6 Weeks)'
                            : 'Business Growth (Last 7 Days)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      ToggleButtons(
                        isSelected: [
                          _growthView == 0,
                          _growthView == 1,
                          _growthView == 2,
                        ],
                        onPressed: (index) {
                          setState(() {
                            _growthView = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: Colors.blue[700],
                        color: Colors.blueGrey[700],
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Month'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Week'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Day'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 280,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Builder(
                        builder: (context) {
                          List<FlSpot> salesSpots = [];
                          List<FlSpot> expensesSpots = [];
                          List<String> xLabels = [];
                          if (_growthView == 0) {
                            // Month: last 6 months
                            for (int i = 0; i < 6; i++) {
                              salesSpots.add(
                                FlSpot(i.toDouble(), sales12[5 - i]),
                              );
                              expensesSpots.add(
                                FlSpot(i.toDouble(), expenses12[5 - i]),
                              );
                              xLabels.add(
                                DateFormat('MMM').format(
                                  DateTime(now.year, now.month - (5 - i), 1),
                                ),
                              );
                            }
                          } else if (_growthView == 1) {
                            // Week: last 6 weeks
                            List<double> salesByWeek = List.filled(6, 0);
                            List<double> expensesByWeek = List.filled(6, 0);
                            for (int w = 0; w < 6; w++) {
                              final weekStart = now.subtract(
                                Duration(days: w * 7),
                              );
                              final weekEnd = now.subtract(
                                Duration(days: w * 7 + 6),
                              );
                              for (final s in sales) {
                                final date = s['date'];
                                if (date != null) {
                                  final d = DateTime.tryParse(date);
                                  if (d != null &&
                                      !d.isBefore(weekEnd) &&
                                      !d.isAfter(weekStart)) {
                                    salesByWeek[5 - w] += (s['amount'] ?? 0)
                                        .toDouble();
                                  }
                                }
                              }
                              for (final e in expenses) {
                                final date = e['date'];
                                if (date != null) {
                                  final d = DateTime.tryParse(date);
                                  if (d != null &&
                                      !d.isBefore(weekEnd) &&
                                      !d.isAfter(weekStart)) {
                                    expensesByWeek[5 - w] += (e['amount'] ?? 0)
                                        .toDouble();
                                  }
                                }
                              }
                              salesSpots.add(
                                FlSpot(w.toDouble(), salesByWeek[w]),
                              );
                              expensesSpots.add(
                                FlSpot(w.toDouble(), expensesByWeek[w]),
                              );
                              xLabels.add('W${6 - w}');
                            }
                          } else {
                            // Day: last 7 days
                            List<double> salesByDay = List.filled(7, 0);
                            List<double> expensesByDay = List.filled(7, 0);
                            for (int d = 0; d < 7; d++) {
                              final day = DateFormat(
                                'yyyy-MM-dd',
                              ).format(now.subtract(Duration(days: 6 - d)));
                              for (final s in sales) {
                                if (s['date'] == day) {
                                  salesByDay[d] += (s['amount'] ?? 0)
                                      .toDouble();
                                }
                              }
                              for (final e in expenses) {
                                if (e['date'] == day) {
                                  expensesByDay[d] += (e['amount'] ?? 0)
                                      .toDouble();
                                }
                              }
                              salesSpots.add(
                                FlSpot(d.toDouble(), salesByDay[d]),
                              );
                              expensesSpots.add(
                                FlSpot(d.toDouble(), expensesByDay[d]),
                              );
                              xLabels.add(
                                DateFormat(
                                  'E',
                                ).format(now.subtract(Duration(days: 6 - d))),
                              );
                            }
                          }
                          return LineChart(
                            LineChartData(
                              lineBarsData: [
                                LineChartBarData(
                                  spots: salesSpots,
                                  isCurved: true,
                                  color: Colors.blue,
                                  barWidth: 3,
                                  dotData: FlDotData(show: true),
                                  belowBarData: BarAreaData(show: false),
                                ),
                                LineChartBarData(
                                  spots: expensesSpots,
                                  isCurved: true,
                                  color: Colors.red,
                                  barWidth: 3,
                                  dotData: FlDotData(show: true),
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 60,
                                    getTitlesWidget: (value, meta) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4.0,
                                        ),
                                        child: Text(
                                          'UGX\n${NumberFormat.compact().format(value)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blueGrey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      int idx = value.toInt();
                                      if (idx < 0 || idx >= xLabels.length)
                                        return SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6.0,
                                        ),
                                        child: Text(
                                          xLabels[idx],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey[900],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.blueGrey[200]!,
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.blueGrey[200]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: 1,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.blueGrey[100],
                                  strokeWidth: 1,
                                ),
                                getDrawingVerticalLine: (value) => FlLine(
                                  color: Colors.blueGrey[50],
                                  strokeWidth: 1,
                                ),
                              ),
                              lineTouchData: LineTouchData(
                                enabled: true,
                                touchTooltipData: LineTouchTooltipData(
                                  tooltipBgColor: Colors.black87,
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final isSales = spot.barIndex == 0;
                                      return LineTooltipItem(
                                        '${isSales ? 'Sales' : 'Expenses'}\nUGX ${NumberFormat.decimalPattern().format(spot.y.toInt())}',
                                        TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Low Stock Alerts Panel
                  if (lowStock.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Card(
                        elevation: 3,
                        color: Colors.red[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    MdiIcons.alertCircle,
                                    color: Colors.red[700],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Low Stock Alerts',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                  if (lowStock.length > 0)
                                    Container(
                                      margin: EdgeInsets.only(left: 10),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red[700],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${lowStock.length}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 10),
                              ...lowStock.map(
                                (item) => InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InventoryScreen(
                                          branchId: widget.activeBranchId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          MdiIcons.cubeOutline,
                                          color: Colors.red[400],
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${item['name']} (Qty: ${item['qty']})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red[900],
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          MdiIcons.pencil,
                                          color: Colors.red[300],
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Close to Expiry Alerts Panel
                  if (closeToExpiry.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Card(
                        elevation: 3,
                        color: Colors.orange[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    MdiIcons.alert,
                                    color: Colors.orange[700],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Close to Expiry',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                  if (closeToExpiry.length > 0)
                                    Container(
                                      margin: EdgeInsets.only(left: 10),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[700],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${closeToExpiry.length}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 10),
                              ...closeToExpiry.map(
                                (item) => InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InventoryScreen(
                                          branchId: widget.activeBranchId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          MdiIcons.clockAlert,
                                          color: Colors.orange[400],
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${item['name']} (Exp: ${item['expiry_date']})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange[900],
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          MdiIcons.pencil,
                                          color: Colors.orange[300],
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 24),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        'Powered by Apophen',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int writtenOffValue = 0;
  String? _businessLogoPath;

  // 0 = Month, 1 = Week, 2 = Day
  int _growthView = 0;

  @override
  void initState() {
    super.initState();
    _loadBusinessLogo();
    _loadData();
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
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
    });
    final inv = widget.activeBranchId != null
        ? await AppDatabase.getInventory(branchId: widget.activeBranchId)
        : [];
    final salesData = widget.activeBranchId != null
        ? await AppDatabase.getSales(branchId: widget.activeBranchId)
        : [];
    final expensesData = widget.activeBranchId != null
        ? await AppDatabase.getExpenses(branchId: widget.activeBranchId)
        : [];
    final db = await AppDatabase.database;
    final writtenOffData = widget.activeBranchId != null
        ? await db.query(
            'written_off',
            where: 'branch_id = ?',
            whereArgs: [widget.activeBranchId],
          )
        : [];
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
    setState(() {
      inventory = List<Map<String, dynamic>>.from(inv);
      sales = List<Map<String, dynamic>>.from(salesData);
      expenses = List<Map<String, dynamic>>.from(expensesData);
      writtenOff = List<Map<String, dynamic>>.from(writtenOffData);
      writtenOffValue = wValue;
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

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    // Business value summary
    final inventoryValue = inventory.fold<int>(
      0,
      (sum, item) => (sum + ((item['qty'] ?? 0) * (item['sale'] ?? 0))).toInt(),
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
                              this.summaryInfoBox(
                                'Receivables (Debts)',
                                0,
                                MdiIcons.accountArrowRight,
                                Colors.orange[700],
                              ),
                              this.summaryInfoBox(
                                'Payables (Unpaid)',
                                0,
                                MdiIcons.accountArrowLeft,
                                Colors.purple[700],
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

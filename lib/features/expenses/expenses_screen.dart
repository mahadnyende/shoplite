import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/db.dart';
import '../../widgets/footer.dart';

class ExpensesScreen extends StatefulWidget {
  final int? branchId;
  ExpensesScreen({this.branchId});
  @override
  _ExpensesScreenState createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> expenses = [];
  bool loading = true;
  bool addingNew = false;
  int? editingId;
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String? errorMsg;
  bool saveEnabled = false;
  int? hoveredRowIndex;

  // Sorting state
  String? sortColumn;
  bool sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() { loading = true; });
    final db = await AppDatabase.database;
    final data = await db.query(
      'expenses',
      where: widget.branchId != null ? 'branch_id = ?' : null,
      whereArgs: widget.branchId != null ? [widget.branchId] : null,
      orderBy: 'date DESC',
    );
    setState(() {
      expenses = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  void _startEdit(Map<String, dynamic> item) {
    setState(() {
      editingId = item['id'] as int?;
      _descController.text = item['description'] ?? '';
      _amountController.text = (item['amount'] ?? '').toString();
      errorMsg = null;
      saveEnabled = false;
    });
  }

  Future<void> _saveEdit(int? id) async {
    final desc = _descController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (desc.isEmpty || amount <= 0) {
      setState(() { errorMsg = 'Invalid input.'; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid input.')));
      return;
    }
    final db = await AppDatabase.database;
    final item = {
      'description': desc,
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'branch_id': widget.branchId
    };
    if (id == null) {
      await db.insert('expenses', item);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense added.')));
    } else {
      await db.update('expenses', item, where: 'id = ?', whereArgs: [id]);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense updated.')));
    }
    setState(() {
      editingId = null;
      errorMsg = null;
      saveEnabled = false;
      addingNew = false;
    });
    await _loadExpenses();
  }

  DateTime? fromDate;
  DateTime? toDate;

  @override
  void didUpdateWidget(covariant ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final theme = Theme.of(context);
    int totalExpenses = expenses.fold<int>(0, (sum, e) => sum + ((e['amount'] is int) ? e['amount'] as int : int.tryParse(e['amount'].toString()) ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text('Expenses')),
      body: Padding(
      padding: const EdgeInsets.all(12.0),
      child: loading
      ? Center(child: CircularProgressIndicator())
      : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Text(
      'Track and manage your business expenses. Add, edit, or delete expense records for better financial control.',
      style: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.7),
      ),
      ),
      SizedBox(height: 16),
      Row(
      children: [
      Icon(MdiIcons.calendarRange, color: Colors.blueGrey),
      SizedBox(width: 8),
      Text('From:'),
      TextButton(
      onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: fromDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Colors.deepPurple,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              iconTheme: IconThemeData(
                color: Colors.deepPurple,
                size: 28,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                ),
              ),
              datePickerTheme: DatePickerThemeData(
                // Use MdiIcons for navigation and input switch
                headerBackgroundColor: Colors.deepPurple.shade100,
                headerForegroundColor: Colors.deepPurple,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                // Custom icons
                // (Navigation and input icons not supported in your Flutter version)
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) setState(() { fromDate = picked; });
      },
      child: Text(fromDate == null ? 'Start' : DateFormat('yyyy-MM-dd').format(fromDate!)),
      ),
      Text('To:'),
      TextButton(
      onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: toDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Colors.deepPurple,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              iconTheme: IconThemeData(
                color: Colors.deepPurple,
                size: 28,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                ),
              ),
              datePickerTheme: DatePickerThemeData(
                // Use MdiIcons for navigation and input switch
                                headerBackgroundColor: Colors.deepPurple.shade100,
                headerForegroundColor: Colors.deepPurple,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                // Custom icons
                                                // Optionally, you can set other icons if needed
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) setState(() { toDate = picked; });
      },
      child: Text(toDate == null ? 'End' : DateFormat('yyyy-MM-dd').format(toDate!)),
      ),
      Spacer(),
      Tooltip(
      message: 'Total Expenses',
      child: Chip(
      label: Text('UGX ${formatter.format(totalExpenses)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.redAccent,
      avatar: Icon(MdiIcons.currencyUsd, color: Colors.white),
      ),
      ),
      ],
      ),
      SizedBox(height: 16),
      // Custom Table (like Inventory Screen)
      Expanded(
      child: LayoutBuilder(
      builder: (context, constraints) {
      final tableWidth = constraints.maxWidth;
      final colNo = tableWidth * 0.08;
      final colDesc = tableWidth * 0.38;
      final colAmount = tableWidth * 0.18;
      final colDate = tableWidth * 0.18;
      final colActions = tableWidth * 0.18;
      return Container(
      decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
      ),
      height: 400,
      width: double.infinity,
      child: Column(
      children: [
      // Header
      Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
      children: [
      Flexible(flex: 8, child: _headerCell('No.', double.infinity, onTap: () => _onSort('no'))),
      Flexible(flex: 38, child: _headerCell('Description', double.infinity, onTap: () => _onSort('description'))),
      Flexible(flex: 18, child: _headerCell('Amount', double.infinity, onTap: () => _onSort('amount'))),
      Flexible(flex: 18, child: _headerCell('Date', double.infinity, onTap: () => _onSort('date'))),
      Flexible(flex: 18, child: _headerCell('Actions', double.infinity)),
      ],
      ),
      ),
      Divider(height: 1, thickness: 1),
      // Data rows
      // --- HOVER ROW HIGHLIGHT STATE ---
      // Move this to the class field section:
      // int? hoveredRowIndex;
      Expanded(
      child: ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (context, i) {
      final item = expenses[i];
      final isEditing = editingId == item['id'];
      final isChanged = isEditing && (
      _descController.text.trim() != (item['description'] ?? '') ||
      _amountController.text.trim() != (item['amount'] ?? '').toString()
      );
      final canSave = isEditing && _descController.text.trim().isNotEmpty && int.tryParse(_amountController.text.trim()) != null && isChanged;
      final highlight = hoveredRowIndex == i;
      return MouseRegion(
        onEnter: (_) => setState(() { hoveredRowIndex = i; }),
        onExit: (_) => setState(() { hoveredRowIndex = null; }),
        child: Container(
          color: highlight ? Colors.blue.withOpacity(0.08) : null,
          child: Row(
            children: [
              Flexible(flex: 8, child: _dataCell((i + 1).toString(), double.infinity)),
              Flexible(
                flex: 38,
                child: _dataCell(
                  isEditing
                      ? TextField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            prefixIcon: Icon(MdiIcons.textBoxOutline),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        )
                      : Text(item['description'] ?? ''),
                  double.infinity,
                ),
              ),
              Flexible(
                flex: 18,
                child: _dataCell(
                  isEditing
                      ? TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixIcon: Icon(MdiIcons.currencyUsd),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        )
                      : Text('UGX ${formatter.format(item['amount'] ?? 0)}'),
                  double.infinity,
                ),
              ),
              Flexible(flex: 18, child: _dataCell(Text(item['date'] ?? ''), double.infinity)),
              Flexible(
                flex: 18,
                child: _dataCell(
                  isEditing
                      ? Row(
                          children: [
                            IconButton(
                              icon: Icon(MdiIcons.contentSave, color: canSave ? Colors.green : Colors.grey),
                              onPressed: canSave ? () => _saveEdit(item['id']) : null,
                              tooltip: 'Save',
                            ),
                            IconButton(icon: Icon(MdiIcons.closeCircle, color: Colors.red), onPressed: () => setState(() => editingId = null), tooltip: 'Cancel'),
                          ],
                        )
                      : Row(
                          children: [
                            IconButton(icon: Icon(MdiIcons.pencil), onPressed: () => _startEdit(item), tooltip: 'Edit'),
                            IconButton(
                              icon: Icon(MdiIcons.delete, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Delete Expense'),
                                    content: Text('Are you sure you want to delete this expense?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')),
                                      ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final db = await AppDatabase.database;
                                  await db.delete('expenses', where: 'id = ?', whereArgs: [item['id']]);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense deleted.')));
                                  await _loadExpenses();
                                }
                              },
                            ),
                          ],
                        ),
                  double.infinity,
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseModal(context),
        icon: Icon(MdiIcons.plus),
        label: Text('Add Expense'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAddExpenseModal(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final descController = TextEditingController();
    final amountController = TextEditingController();
    FocusNode descFocus = FocusNode();
    FocusNode amountFocus = FocusNode();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                              'Add Expense',
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
                        controller: descController,
                        focusNode: descFocus,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g. Office supplies',
                          prefixIcon: Icon(MdiIcons.textBoxOutline),
                          border: OutlineInputBorder(),
                          helperText: 'What was the expense for?',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter description' : null,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(amountFocus),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        focusNode: amountFocus,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          hintText: 'e.g. 50000',
                          prefixIcon: Icon(MdiIcons.currencyUsd),
                          border: OutlineInputBorder(),
                          helperText: 'Enter the amount spent',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Enter amount';
                          final n = int.tryParse(value.trim());
                          if (n == null || n <= 0) return 'Enter valid amount';
                          return null;
                        },
                        onFieldSubmitted: (_) async {
                          if (_formKey.currentState?.validate() ?? false) {
                            setModalState(() => isSubmitting = true);
                            final db = await AppDatabase.database;
                            await db.insert('expenses', {
                              'description': descController.text.trim(),
                              'amount': int.parse(amountController.text.trim()),
                              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              'branch_id': widget.branchId
                            });
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Expense added.')),
                            );
                            _loadExpenses();
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
                          label: Text('Add Expense'),
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
                                    await db.insert('expenses', {
                                      'description': descController.text.trim(),
                                      'amount': int.parse(amountController.text.trim()),
                                      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                      'branch_id': widget.branchId
                                    });
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(content: Text('Expense added.')),
                                    );
                                    _loadExpenses();
                                  }
                                },
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper for table header cell
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
      case 'No.':
        return 'no';
      case 'Description':
        return 'description';
      case 'Amount':
        return 'amount';
      case 'Date':
        return 'date';
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
      expenses.sort((a, b) {
        dynamic aValue;
        dynamic bValue;
        if (column == 'no') {
          aValue = expenses.indexOf(a);
          bValue = expenses.indexOf(b);
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

  // Helper for table data cell
  Widget _dataCell(dynamic child, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: child is Widget ? child : Text(child.toString()),
    );
  }
}

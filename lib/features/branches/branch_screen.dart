import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/db.dart';

class BranchManagementScreen extends StatefulWidget {
  final VoidCallback? onBranchesChanged;
  BranchManagementScreen({this.onBranchesChanged});
  @override
  _BranchManagementScreenState createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  List<Map<String, dynamic>> _branches = [];
  int? _activeBranchId;
  final _branchController = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      loading = true;
    });
    final branches = await AppDatabase.getBranches();
    final activeBranchId = await AppDatabase.getActiveBranch();
    setState(() {
      _branches = branches;
      _activeBranchId = activeBranchId;
      loading = false;
    });
  }

  Future<void> _addBranch(String name) async {
    if (name.trim().isEmpty) return;
    await AppDatabase.addBranch(name);
    await _loadBranches();
    // Set as default if first branch
    if (_branches.length == 0) {
      final branches = await AppDatabase.getBranches();
      if (branches.isNotEmpty) {
        await AppDatabase.setActiveBranch(branches.first['id'] as int);
      }
    }
    if (widget.onBranchesChanged != null) widget.onBranchesChanged!();
  }

  Future<void> _deleteBranch(int id) async {
    await AppDatabase.deleteBranch(id);
    await _loadBranches();
    // If deleted branch was active, set new active
    if (_activeBranchId == id) {
      final branches = await AppDatabase.getBranches();
      if (branches.isNotEmpty) {
        await AppDatabase.setActiveBranch(branches.first['id'] as int);
      } else {
        await AppDatabase.setActiveBranch(-1); // No active branch
      }
    }
    if (widget.onBranchesChanged != null) widget.onBranchesChanged!();
  }

  Future<void> _setActiveBranch(int id) async {
    await AppDatabase.setActiveBranch(id);
    setState(() {
      _activeBranchId = id;
    });
    if (widget.onBranchesChanged != null) widget.onBranchesChanged!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return loading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Branch Management', style: theme.textTheme.headlineSmall),
                  SizedBox(height: 8),
                  Text(
                    'Manage your business branches. Add, activate, or remove branches as needed. The active branch is used for all operations.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 24),
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
                              Icon(MdiIcons.sourceBranch, color: Colors.blueGrey),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _branchController,
                                  decoration: InputDecoration(
                                    labelText: 'New Branch Name',
                                    prefixIcon: Icon(MdiIcons.plusBox),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              ElevatedButton.icon(
                                icon: Icon(MdiIcons.plus),
                                onPressed: () async {
                                  if (_branchController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Branch name cannot be empty.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  await _addBranch(_branchController.text);
                                  _branchController.clear();
                                },
                                label: Text('Add Branch'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          Text('Branches:', style: theme.textTheme.titleMedium),
                          SizedBox(height: 8),
                          if (_branches.isEmpty) Text('No branches created.'),
                          if (_branches.isNotEmpty)
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _branches.length,
                              separatorBuilder: (_, __) => Divider(),
                              itemBuilder: (context, i) {
                                final branch = _branches[i];
                                return ListTile(
                                  leading: Radio<int>(
                                    value: branch['id'] as int,
                                    groupValue: _activeBranchId,
                                    onChanged: (val) => _setActiveBranch(val!),
                                  ),
                                  title: Text(
                                    branch['name'],
                                    style: TextStyle(
                                      fontWeight: _activeBranchId == branch['id']
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _activeBranchId == branch['id']
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                  subtitle: _activeBranchId == branch['id']
                                      ? Text(
                                          'Active Branch',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                          ),
                                        )
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(MdiIcons.pencil, color: Colors.blue),
                                        tooltip: 'Edit Branch Name',
                                        onPressed: () async {
                                          final controller = TextEditingController(text: branch['name']);
                                          final result = await showDialog<String>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('Edit Branch Name'),
                                              content: TextField(
                                                controller: controller,
                                                decoration: InputDecoration(labelText: 'Branch Name'),
                                                autofocus: true,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(),
                                                  child: Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                                                  child: Text('Save'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (result != null && result.isNotEmpty && result != branch['name']) {
                                            await AppDatabase.updateBranchName(branch['id'] as int, result);
                                            await _loadBranches();
                                            if (widget.onBranchesChanged != null) widget.onBranchesChanged!();
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          MdiIcons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('Delete Branch'),
                                              content: Text(
                                                'Are you sure you want to delete this branch?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(false),
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
                                            await _deleteBranch(branch['id'] as int);
                                          }
                                        },
                                        tooltip: 'Delete Branch',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}

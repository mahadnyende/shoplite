import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'core/db.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/branches/branch_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/purchases/purchases_screen.dart';
import 'features/sales/sales_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/backup/backup_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/written_off_screen.dart';
import 'widgets/footer.dart';
import 'widgets/app_drawer.dart';

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // assert(() {
  //   // Auto-delete DB in debug mode
  //   try {
  //     final dbDir = Directory(p.join(
  //       Directory.current.path,
  //       '.dart_tool',
  //       'sqflite_common_ffi',
  //       'databases',
  //     ));
  //     final dbFile = File(p.join(dbDir.path, 'shoplite.db'));
  //     if (dbFile.existsSync()) {
  //       dbFile.deleteSync();
  //       print('shoplite.db deleted for fresh start.');
  //     }
  //   } catch (e) {
  //     print('Warning: Could not delete shoplite.db: $e');
  //   }
  //   return true;
  // }());
  runApp(ShopLiteApp());
}

class ShopLiteApp extends StatefulWidget {
  @override
  _ShopLiteAppState createState() => _ShopLiteAppState();
}

class _ShopLiteAppState extends State<ShopLiteApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _authenticated = true; // For demo, skip login
  bool _isAdmin = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');
    setState(() {
      if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    });
  }

  void _toggleTheme() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  void _logout() {
    setState(() {
      _authenticated = false;
      _isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShopLite',
      theme: ThemeData.light(useMaterial3: false),
      darkTheme: ThemeData.dark(useMaterial3: false),
      themeMode: _themeMode,
      home: _authenticated
          ? MainScreen(
              onToggleTheme: _toggleTheme,
              themeMode: _themeMode,
              isAdmin: _isAdmin,
              onLogout: _logout,
            )
          : Center(
              child: Text('Login screen placeholder'),
            ), // Replace with real login
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final bool isAdmin;
  final VoidCallback onLogout;

  MainScreen({
    required this.onToggleTheme,
    required this.themeMode,
    required this.isAdmin,
    required this.onLogout,
  });

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _branches = [];
  int? _activeBranchId;
  bool _loadingBranches = true;
  String _businessName = 'ShopLite';

  String _branchDisplayName(dynamic name) {
    if (name == null) return 'Branch';
    final n = name.toString();
    return n.toLowerCase().endsWith('branch') ? n : '$n Branch';
  }

  @override
  void initState() {
    super.initState();
    _loadBusinessName();
    _loadBranches();
  }

  Future<void> _loadBusinessName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _businessName = prefs.getString('business_name') ?? 'ShopLite';
    });
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loadingBranches = true;
    });
    final branches = await AppDatabase.getBranches();
    final activeBranchId = await AppDatabase.getActiveBranch();
    setState(() {
      _branches = branches;
      _activeBranchId = activeBranchId;
      _loadingBranches = false;
    });
  }

  Future<void> _setActiveBranch(int branchId) async {
    await AppDatabase.setActiveBranch(branchId);
    setState(() {
      _activeBranchId = branchId;
    });
  }

  void _onDrawerItemTap(int index) async {
    if (index == 9) {
      Navigator.pop(context);
      if (_activeBranchId != null) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WrittenOffScreen(branchId: _activeBranchId!),
          ),
        );
        if (result != null && result is int) {
          setState(() {
            _selectedIndex = result;
          });
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please select a branch.')));
      }
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);
    if (index == 1) {
      await _loadBranches();
    }
    if (index == 7) {
      // Reload business name after returning from settings
      await _loadBusinessName();
    }
    // If switching to Branch Management, force rebuild to reflect active branch
    setState(() {});
  }

  void _onBranchesChanged() async {
    await _loadBranches();
  }

  @override
  Widget build(BuildContext context) {
    bool isWide = MediaQuery.of(context).size.width > 700;
    Widget body;
    if (_loadingBranches) {
      body = Center(child: CircularProgressIndicator());
    } else if (_selectedIndex == 0) {
      final activeBranch = _branches.firstWhere(
        (b) => b['id'] == _activeBranchId,
        orElse: () => {},
      );
      body = DashboardOverview(
        activeBranchId: _activeBranchId,
        businessName: _businessName,
        userName: 'Admin User',
        userRole: 'Admin',
        userPhotoUrl: null,
      );
    } else if (_selectedIndex == 1) {
      body = BranchManagementScreen(onBranchesChanged: _onBranchesChanged);
    } else if (_selectedIndex == 2) {
      body = _activeBranchId != null
          ? InventoryScreen(branchId: _activeBranchId!)
          : Center(child: Text('Please select a branch.'));
    } else if (_selectedIndex == 3) {
      body = _activeBranchId != null
          ? PurchasesScreen(branchId: _activeBranchId!)
          : Center(child: Text('Please select a branch.'));
    } else if (_selectedIndex == 4) {
      body = _activeBranchId != null
          ? SalesScreen(branchId: _activeBranchId!)
          : Center(child: Text('Please select a branch.'));
    } else if (_selectedIndex == 5) {
      body = _activeBranchId != null
          ? ReportsScreen(branchId: _activeBranchId!)
          : Center(child: Text('Please select a branch.'));
    } else if (_selectedIndex == 6) {
      body = BackupScreen();
    } else if (_selectedIndex == 7) {
      body = SettingsScreen(
        themeMode: widget.themeMode,
        onThemeChanged: (mode) {
          if (mode != widget.themeMode) widget.onToggleTheme();
        },
        systemVersion: '1.0.0',
        onSettingsSaved: () async {
          await _loadBusinessName();
          setState(() {});
        },
      );
    } else if (_selectedIndex == 8) {
      body = _activeBranchId != null
          ? ExpensesScreen(branchId: _activeBranchId!)
          : Center(child: Text('Please select a branch.'));
    } else {
      body = Center(child: Text('Page not found'));
    }
    return Scaffold(
      drawer: AppDrawer(
        isAdmin: widget.isAdmin,
        onTap: _onDrawerItemTap,
        onLogout: widget.onLogout,
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(MdiIcons.menu), // More modern menu icon
            tooltip: 'Open navigation menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Icon(
              MdiIcons.storefront,
              size: 22,
              color: Colors.blueGrey,
            ), // App icon for ShopLite
            SizedBox(width: 8),
            Text('ShopLite'),
            SizedBox(width: 16),
            if (_activeBranchId != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(MdiIcons.sourceBranch, size: 20, color: Colors.indigo),
                    SizedBox(width: 6),
                    if (_branches.length > 1)
                      DropdownButton<int>(
                        value: _activeBranchId,
                        onChanged: (int? newBranchId) async {
                          if (newBranchId != null) {
                            await _setActiveBranch(newBranchId);
                            if (_selectedIndex == 1) setState(() {});
                          }
                        },
                        items: _branches
                            .map(
                              (branch) => DropdownMenuItem<int>(
                                value: branch['id'] as int,
                                child: Text(_branchDisplayName(branch['name'])),
                              ),
                            )
                            .toList(),
                        underline: Container(),
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                        dropdownColor: Colors.white,
                        icon: Icon(MdiIcons.chevronDown, color: Colors.blue),
                      )
                    else
                      Text(
                        _branchDisplayName(
                          _branches.firstWhere(
                            (b) => b['id'] == _activeBranchId,
                            orElse: () => {'name': 'Branch'},
                          )['name'],
                        ),
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.light
                  ? MdiIcons.weatherNight
                  : MdiIcons.whiteBalanceSunny,
            ),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: Icon(MdiIcons.logout),
            tooltip: 'Logout',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: body,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AppDrawer extends StatelessWidget {
  final bool isAdmin;
  final Function(int) onTap;
  final VoidCallback onLogout;

  AppDrawer({this.isAdmin = false, required this.onTap, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Text(
              'ShopLite Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(MdiIcons.viewDashboard, size: 24),
            title: Text('Dashboard'),
            onTap: () => onTap(0),
          ),
          ListTile(
            leading: Icon(MdiIcons.officeBuilding, size: 24, color: Colors.indigo), // Better branch icon
            title: Text('Branch Management'),
            onTap: () => onTap(1),
          ),
          ListTile(
            leading: Icon(MdiIcons.cubeOutline, size: 24),
            title: Text('Inventory'),
            onTap: () => onTap(2),
          ),
          ListTile(
            leading: Icon(MdiIcons.cartOutline, size: 24),
            title: Text('Purchases'),
            onTap: () => onTap(3),
          ),
          ListTile(
            leading: Icon(MdiIcons.receiptTextOutline, size: 24),
            title: Text('Sales'),
            onTap: () => onTap(4),
          ),
          ListTile(
            leading: Icon(MdiIcons.cashMinus, size: 24),
            title: Text('Expenses'),
            onTap: () => onTap(8),
          ),
          ListTile(
            leading: Icon(MdiIcons.closeOctagonOutline, size: 24, color: Colors.red),
            title: Text('Written Off'),
            onTap: () => onTap(9),
          ),
          ListTile(
            leading: Icon(MdiIcons.chartBar, size: 24),
            title: Text('Reports'),
            onTap: () => onTap(5),
          ),
          ListTile(
            leading: Icon(MdiIcons.cloudUploadOutline, size: 24),
            title: Text('Backup'),
            onTap: () => onTap(6),
          ),
          ListTile(
            leading: Icon(MdiIcons.cogOutline, size: 24),
            title: Text('Settings'),
            onTap: () => onTap(7),
          ),
          Divider(),
          ListTile(
            leading: Icon(MdiIcons.logout, size: 24),
            title: Text('Logout'),
            onTap: onLogout,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'Powered by Apophen',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

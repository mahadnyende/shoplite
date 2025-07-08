import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LucideIconTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Icon(Icons.dashboard, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Material Icon'),
                ],
              ),
              SizedBox(width: 40),
              Column(
                children: [
                  Icon(LucideIcons.layoutDashboard, size: 48, color: Colors.blue),
                  SizedBox(height: 8),
                  Text('Lucide Icon'),
                ],
              ),
            ],
          ),
          SizedBox(height: 32),
          Text('If you see only the red icon, Lucide is not working.', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

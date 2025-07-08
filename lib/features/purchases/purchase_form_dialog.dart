import 'package:flutter/material.dart';

class PurchaseFormDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Purchase Form'),
      content: Text('Purchase Form Dialog Placeholder'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class PasswordResetScreen extends StatefulWidget {
  final VoidCallback onResetSuccess;
  const PasswordResetScreen({Key? key, required this.onResetSuccess}) : super(key: key);

  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _generatedCode;
  String? _error;
  bool _codeVerified = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _generateAndStoreResetCode();
  }

  Future<void> _generateAndStoreResetCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = (Random().nextInt(900000) + 100000).toString(); // 6-digit code
    await prefs.setString('reset_code', code);
    setState(() { _generatedCode = code; });
    // In a real app, you would send this code to the user via Apophen/admin
  }

  Future<bool> _verifyCode(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final storedCode = prefs.getString('reset_code');
    return input == storedCode;
  }

  Future<void> _resetPassword() async {
    setState(() { _loading = true; _error = null; });
    if (!_codeVerified) {
      final codeOk = await _verifyCode(_codeController.text.trim());
      if (!codeOk) {
        setState(() { _error = 'Invalid reset code.'; _loading = false; });
        return;
      }
      setState(() { _codeVerified = true; _loading = false; });
      return;
    }
    // Now, code is verified, check passwords
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() { _error = 'Please enter and confirm your new password.'; _loading = false; });
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() { _error = 'Passwords do not match.'; _loading = false; });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', newPassword);
    await prefs.remove('reset_code');
    setState(() { _loading = false; });
    widget.onResetSuccess();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successful.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reset Password', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              if (!_codeVerified) ...[
                Text('Enter the reset code provided by Apophen/admin.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Reset Code'),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _resetPassword(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: _loading ? const CircularProgressIndicator() : const Text('Verify Code'),
                ),
              ] else ...[
                TextField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: _loading ? const CircularProgressIndicator() : const Text('Reset Password'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              if (_generatedCode != null) ...[
                // For demo: show the code (remove in production)
                Text('Demo code: $_generatedCode', style: const TextStyle(color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

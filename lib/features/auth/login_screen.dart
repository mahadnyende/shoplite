import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onForgotPassword;
  const LoginScreen({Key? key, required this.onLoginSuccess, required this.onForgotPassword}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final prefs = await SharedPreferences.getInstance();
    final storedUsername = prefs.getString('username') ?? 'admin';
    final storedPassword = prefs.getString('password') ?? 'password123';
    final inputUsername = _usernameController.text.trim();
    final inputPassword = _passwordController.text;
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay
    if (inputUsername == storedUsername && inputPassword == storedPassword) {
      widget.onLoginSuccess();
    } else {
      setState(() { _error = 'Invalid username or password.'; });
    }
    setState(() { _loading = false; });
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
              // Branding/logo
              Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(MdiIcons.storefront, size: 40, color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 12),
                  Text('ShopLite', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Sign in to your account', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 28),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? MdiIcons.eye : MdiIcons.eyeOff),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : widget.onForgotPassword,
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.login, size: 22),
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          label: _loading
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Powered by Apophen
              Column(
                children: [
                  Divider(height: 32, thickness: 1, indent: 40, endIndent: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Powered by ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      Text('Apophen', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

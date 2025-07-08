import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:io';
import '../../core/db.dart';
import '../../widgets/footer.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final String systemVersion;
  final VoidCallback? onSettingsSaved;
  SettingsScreen({
    required this.themeMode,
    required this.onThemeChanged,
    required this.systemVersion,
    this.onSettingsSaved,
  });
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  final _businessNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _logoController = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      loading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    _usernameController.text = prefs.getString('username') ?? 'admin';
    _passwordController.text = prefs.getString('password') ?? 'password123';
    _businessNameController.text =
        prefs.getString('business_name') ?? 'ShopLite';
    _contactController.text = prefs.getString('business_contact') ?? '';
    _addressController.text = prefs.getString('business_address') ?? '';
    _logoController.text = prefs.getString('business_logo') ?? '';
    setState(() {
      loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text.trim());
    await prefs.setString('password', _passwordController.text.trim());
    await prefs.setString('business_name', _businessNameController.text.trim());
    await prefs.setString('business_contact', _contactController.text.trim());
    await prefs.setString('business_address', _addressController.text.trim());
    await prefs.setString('business_logo', _logoController.text.trim());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Settings saved.')));
    widget.onSettingsSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Profile Card
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
                            radius: 40,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _logoController.text.isNotEmpty
                                ? (_logoController.text.startsWith('http')
                                          ? NetworkImage(_logoController.text)
                                          : FileImage(
                                              File(_logoController.text),
                                            ))
                                      as ImageProvider
                                : null,
                            child: _logoController.text.isEmpty
                                ? Icon(
                                    MdiIcons.store,
                                    size: 40,
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
                                  _businessNameController.text.isNotEmpty
                                      ? _businessNameController.text
                                      : 'Business Name',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      MdiIcons.phone,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      _contactController.text.isNotEmpty
                                          ? _contactController.text
                                          : 'Contact',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      MdiIcons.mapMarker,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      _addressController.text.isNotEmpty
                                          ? _addressController.text
                                          : 'Address',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Column(
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(MdiIcons.imageEditOutline),
                                label: Text('Change Photo'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  FilePickerResult? result = await FilePicker
                                      .platform
                                      .pickFiles(type: FileType.image);
                                  if (result != null &&
                                      result.files.single.path != null) {
                                    setState(() {
                                      _logoController.text =
                                          result.files.single.path!;
                                    });
                                    await _saveSettings();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Account Section
                  Text(
                    'Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Divider(),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(MdiIcons.account),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(MdiIcons.lock),
                            border: OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword ? MdiIcons.eyeOff : MdiIcons.eye,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                              tooltip: _showPassword
                                  ? 'Hide Password'
                                  : 'Show Password',
                            ),
                          ),
                          obscureText: !_showPassword,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Business Info Section
                  Text(
                    'Business Info',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Divider(),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _businessNameController,
                          decoration: InputDecoration(
                            labelText: 'Business Name',
                            prefixIcon: Icon(MdiIcons.storefront),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _contactController,
                          decoration: InputDecoration(
                            labelText: 'Contact',
                            prefixIcon: Icon(MdiIcons.phone),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(MdiIcons.mapMarker),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Photo Path (advanced)
                  ExpansionTile(
                    leading: Icon(MdiIcons.tune, color: Colors.blueGrey),
                    title: Text(
                      'Advanced',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      TextField(
                        controller: _logoController,
                        decoration: InputDecoration(
                          labelText: 'Shop Photo (URL or Path)',
                          prefixIcon: Icon(MdiIcons.image),
                          border: OutlineInputBorder(),
                          helperText:
                              'You can paste a URL or pick a file above.',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Theme and System
                  Row(
                    children: [
                      Icon(MdiIcons.palette, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text('Theme:', style: theme.textTheme.bodyLarge),
                      SizedBox(width: 12),
                      DropdownButton<ThemeMode>(
                        value: widget.themeMode,
                        onChanged: (mode) => widget.onThemeChanged(mode!),
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Row(
                              children: [
                                Icon(
                                  MdiIcons.whiteBalanceSunny,
                                  color: Colors.amber,
                                ), // Light theme icon
                                SizedBox(width: 6),
                                Text('Light'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Row(
                              children: [
                                Icon(
                                  MdiIcons.weatherNight,
                                  color: Colors.blueGrey,
                                ), // Dark theme icon
                                SizedBox(width: 6),
                                Text('Dark'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Text(
                        'System Version: ${widget.systemVersion}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  SizedBox(height: 32),
                  Row(
                    children: [
                      Spacer(),
                      ElevatedButton.icon(
                        icon: Icon(MdiIcons.contentSave),
                        onPressed: _saveSettings,
                        label: Text('Save Settings'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),
                  Footer(),
                ],
              ),
            ),
    );
  }
}

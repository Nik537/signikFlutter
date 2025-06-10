import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _brokerIpController;
  late TextEditingController _brokerPortController;
  late TextEditingController _deviceNameController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _brokerIpController = TextEditingController();
    _brokerPortController = TextEditingController();
    _deviceNameController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Parse current broker URL - handle both formats
    final currentUrl = prefs.getString('broker_url') ?? AppConfig.brokerUrl;
    
    // Convert to consistent format for parsing
    String urlToParse = currentUrl;
    if (currentUrl.startsWith('ws://')) {
      urlToParse = currentUrl.replaceFirst('ws://', 'http://');
    } else if (!currentUrl.startsWith('http://')) {
      urlToParse = 'http://$currentUrl';
    }
    
    final uri = Uri.parse(urlToParse);
    
    setState(() {
      _brokerIpController.text = uri.host;
      _brokerPortController.text = uri.hasPort ? uri.port.toString() : '8000';
      _deviceNameController.text = prefs.getString('device_name') ?? 'Signik Android Tablet';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    
    // Build new broker URL - just the base URL without /ws
    final newBrokerUrl = 'http://${_brokerIpController.text}:${_brokerPortController.text}';
    
    // Save settings
    await prefs.setString('broker_url', newBrokerUrl);
    await prefs.setString('device_name', _deviceNameController.text);
    
    // Update AppConfig
    AppConfig.setBrokerUrl(newBrokerUrl);
    AppConfig.setDeviceName(_deviceNameController.text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved. Please restart the app to apply changes.'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true); // Return true to indicate settings changed
    }
  }

  @override
  void dispose() {
    _brokerIpController.dispose();
    _brokerPortController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF0066CC),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Broker Settings Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cloud, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Broker Settings',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _brokerIpController,
                            decoration: const InputDecoration(
                              labelText: 'Broker IP Address',
                              hintText: '192.168.1.100',
                              prefixIcon: Icon(Icons.computer),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter broker IP';
                              }
                              // Basic IP validation
                              final ipRegex = RegExp(
                                r'^(\d{1,3}\.){3}\d{1,3}$|^[a-zA-Z0-9.-]+$'
                              );
                              if (!ipRegex.hasMatch(value)) {
                                return 'Please enter a valid IP address or hostname';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _brokerPortController,
                            decoration: const InputDecoration(
                              labelText: 'Broker Port',
                              hintText: '8000',
                              prefixIcon: Icon(Icons.settings_ethernet),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter broker port';
                              }
                              final port = int.tryParse(value);
                              if (port == null || port < 1 || port > 65535) {
                                return 'Please enter a valid port (1-65535)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Device Settings Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tablet_android, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Device Settings',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _deviceNameController,
                            decoration: const InputDecoration(
                              labelText: 'Device Name',
                              hintText: 'Signik Android Tablet',
                              prefixIcon: Icon(Icons.label),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter device name';
                              }
                              if (value.length < 3) {
                                return 'Device name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Info Card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Changes will take effect after restarting the app',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
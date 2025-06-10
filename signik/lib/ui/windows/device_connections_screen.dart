import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/signik_device.dart';
import '../../services/connection_manager.dart';
import '../../services/device_connections_service.dart';

class DeviceConnectionsScreen extends StatefulWidget {
  const DeviceConnectionsScreen({Key? key}) : super(key: key);

  @override
  State<DeviceConnectionsScreen> createState() => _DeviceConnectionsScreenState();
}

class _DeviceConnectionsScreenState extends State<DeviceConnectionsScreen> {
  late DeviceConnectionsService _connectionsService;
  late ConnectionManager _connectionManager;
  String? _selectedPcId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _connectionsService = DeviceConnectionsService();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() => _isLoading = true);
    await _connectionsService.loadConnections();
    
    // Auto-select the current PC
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final currentPcId = _connectionManager.deviceId;
        if (currentPcId != null) {
          setState(() {
            _selectedPcId = currentPcId;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _saveConnections() async {
    await _connectionsService.saveConnections();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connections saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    _connectionManager = Provider.of<ConnectionManager>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Row(
          children: [
            Icon(Icons.device_hub, size: 24),
            SizedBox(width: 12),
            Text('Device Connection Manager'),
          ],
        ),
        actions: [
          // Save Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _saveConnections,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066CC),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar - PC List
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066CC),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.computer, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'PC Devices',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // PC Info
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current PC',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_connectionManager.currentDevice != null) ...[
                                Card(
                                  elevation: 2,
                                  color: const Color(0xFFE3F2FD),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                      color: Color(0xFF0066CC),
                                      width: 2,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFF0066CC),
                                      child: Icon(
                                        Icons.desktop_windows,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      _connectionManager.currentDevice!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0066CC),
                                      ),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        const Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _connectionManager.currentDevice!.ipAddress ?? 'No IP',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'This PC',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Android Devices',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Select Android devices that can receive PDFs from this PC',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else
                                const Center(
                                  child: Text('Connecting to broker...'),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Right Panel - Android Device Connections
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.android, color: Colors.green.shade600, size: 24),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Android Device Connections',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Configure which Android devices can receive PDFs',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Android Device Grid
                Expanded(
                  child: _buildAndroidDeviceGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidDeviceGrid() {
    if (_selectedPcId == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final androidDevices = _connectionManager.devices
        .where((d) => d.type == 'android')
        .toList();
    
    final connectedDeviceIds = _connectionsService.getConnectedDevices(_selectedPcId!);
    
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: androidDevices.length,
        itemBuilder: (context, index) {
          final device = androidDevices[index];
          final isConnected = connectedDeviceIds.contains(device.id);
          
          return _buildDeviceCard(device, isConnected);
        },
      ),
    );
  }

  Widget _buildDeviceCard(SignikDevice device, bool isConnected) {
    return Card(
      elevation: isConnected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isConnected ? const Color(0xFF0066CC) : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (isConnected) {
              _connectionsService.removeConnection(_selectedPcId!, device.id);
            } else {
              _connectionsService.addConnection(_selectedPcId!, device.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Device Icon and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.tablet_android,
                    size: 32,
                    color: isConnected ? const Color(0xFF0066CC) : Colors.grey.shade400,
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device.isOnline ? Colors.green : Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: (device.isOnline ? Colors.green : Colors.red).withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Device Name
              Text(
                device.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
                  color: isConnected ? const Color(0xFF0066CC) : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // IP Address
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.language, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      device.ipAddress ?? 'No IP',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Connection Status and Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Connection Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontSize: 11,
                        color: isConnected ? Colors.green.shade700 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Test Connection Button
                  IconButton(
                    icon: const Icon(Icons.speed, size: 18),
                    color: const Color(0xFF0066CC),
                    tooltip: 'Test Connection',
                    onPressed: device.isOnline ? () => _testConnection(device) : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection(SignikDevice device) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Testing connection...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Test the connection
    try {
      await _connectionManager.testDeviceConnection(device.id);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection to ${device.name} successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection to ${device.name} failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
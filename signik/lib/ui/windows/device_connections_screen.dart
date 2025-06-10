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
    setState(() => _isLoading = false);
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
                // PC List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _connectionManager.devices
                              .where((d) => d.type == 'windows')
                              .length,
                          itemBuilder: (context, index) {
                            final pcs = _connectionManager.devices
                                .where((d) => d.type == 'windows')
                                .toList();
                            final pc = pcs[index];
                            final isSelected = _selectedPcId == pc.id;
                            
                            return Card(
                              elevation: isSelected ? 2 : 0,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected 
                                      ? const Color(0xFF0066CC) 
                                      : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected 
                                      ? const Color(0xFF0066CC) 
                                      : Colors.grey.shade300,
                                  child: Icon(
                                    Icons.desktop_windows,
                                    color: isSelected ? Colors.white : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  pc.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF0066CC) : Colors.black87,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: pc.isOnline ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      pc.ipAddress ?? 'No IP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: pc.id == _connectionManager.currentDevice?.id
                                    ? Container(
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
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedPcId = pc.id;
                                  });
                                },
                              ),
                            );
                          },
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
                          if (_selectedPcId != null)
                            Text(
                              'Managing connections for: ${_connectionManager.devices.firstWhere((d) => d.id == _selectedPcId).name}',
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
                  child: _selectedPcId == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'Select a PC to manage its connections',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildAndroidDeviceGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidDeviceGrid() {
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
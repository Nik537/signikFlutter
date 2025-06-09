import 'package:flutter/material.dart';
import '../../models/signik_device.dart';
import '../../models/device_connection.dart';
import '../../services/connection_manager.dart' as cm;

class DeviceConnectionTab extends StatefulWidget {
  final cm.ConnectionManager connectionManager;

  const DeviceConnectionTab({
    super.key,
    required this.connectionManager,
  });

  @override
  State<DeviceConnectionTab> createState() => _DeviceConnectionTabState();
}

class _DeviceConnectionTabState extends State<DeviceConnectionTab> {
  List<SignikDevice> _allDevices = [];
  List<SignikDevice> _availableDevices = [];
  List<DeviceConnection> _myConnections = [];
  String _statusMessage = 'Loading devices...';
  bool _isLoading = false;
  DeviceType _filterType = DeviceType.android;

  @override
  void initState() {
    super.initState();
    _refreshData();
    
    // Listen to connection manager state
    widget.connectionManager.connectionState.listen((state) {
      if (state == cm.ConnectionState.connected) {
        _refreshData();
      }
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Refreshing data...';
    });

    try {
      await Future.wait([
        _refreshAllDevices(),
        _refreshAvailableDevices(),
        _refreshMyConnections(),
      ]);
      
      setState(() {
        _statusMessage = 'Data updated successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error refreshing data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAllDevices() async {
    try {
      final devices = await widget.connectionManager.getAllDevices();
      setState(() {
        _allDevices = devices;
      });
    } catch (e) {
      print('Error getting all devices: $e');
    }
  }

  Future<void> _refreshAvailableDevices() async {
    try {
      final devices = await widget.connectionManager.getOnlineDevices(
        deviceType: _filterType,
      );
      
      // Filter out our own device
      final filteredDevices = devices.where((d) => 
        d.id != widget.connectionManager.deviceId
      ).toList();
      
      setState(() {
        _availableDevices = filteredDevices;
      });
    } catch (e) {
      print('Error getting available devices: $e');
    }
  }

  Future<void> _refreshMyConnections() async {
    try {
      final connections = await widget.connectionManager.getMyConnections();
      setState(() {
        _myConnections = connections;
      });
    } catch (e) {
      print('Error getting my connections: $e');
    }
  }

  Future<void> _connectToDevice(SignikDevice device) async {
    try {
      await widget.connectionManager.connectToDevice(device.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection request sent to ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Refresh connections after a delay to allow processing
      await Future.delayed(const Duration(seconds: 1));
      await _refreshMyConnections();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectFromDevice(DeviceConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device'),
        content: Text(
          'Are you sure you want to disconnect from ${connection.otherDevice?.name ?? 'this device'}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.connectionManager.updateConnectionStatus(
          connection.id, 
          ConnectionStatus.disconnected,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Disconnected from ${connection.otherDevice?.name}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        await _refreshMyConnections();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to disconnect: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with refresh button
          Row(
            children: [
              Text(
                'Device Connection Management',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshData,
                  tooltip: 'Refresh all data',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _statusMessage.contains('Error') ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Row(
              children: [
                // Left side - All Devices
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'All Devices (${_allDevices.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Expanded(
                          child: _buildAllDevicesTable(),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Right side - Available Devices and Connections
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      // Available Devices
                      Expanded(
                        flex: 1,
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Text(
                                      'Available for Connection',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const Spacer(),
                                    DropdownButton<DeviceType>(
                                      value: _filterType,
                                      items: DeviceType.values.map((type) {
                                        return DropdownMenuItem(
                                          value: type,
                                          child: Text(type.name.toUpperCase()),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _filterType = value;
                                          });
                                          _refreshAvailableDevices();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _buildAvailableDevicesTable(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // My Connections
                      Expanded(
                        flex: 1,
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'My Connections (${_myConnections.length})',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              Expanded(
                                child: _buildMyConnectionsTable(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDevicesTable() {
    if (_allDevices.isEmpty) {
      return const Center(
        child: Text('No devices found'),
      );
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('IP')),
        ],
        rows: _allDevices.map((device) {
          return DataRow(
            cells: [
              DataCell(Text(device.name)),
              DataCell(Chip(
                label: Text(device.deviceType.name.toUpperCase()),
                backgroundColor: device.deviceType == DeviceType.windows 
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.green.withOpacity(0.2),
              )),
              DataCell(Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: device.isOnline ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(device.isOnline ? 'Online' : 'Offline'),
                ],
              )),
              DataCell(Text(device.ipAddress ?? 'Unknown')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAvailableDevicesTable() {
    if (_availableDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No ${_filterType.name} devices available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _availableDevices.length,
            itemBuilder: (context, index) {
              final device = _availableDevices[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    device.deviceType == DeviceType.android 
                      ? Icons.phone_android 
                      : Icons.computer,
                    color: Colors.green,
                  ),
                  title: Text(device.name),
                  subtitle: Text('${device.deviceType.name} • ${device.ipAddress}'),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                    onPressed: () => _connectToDevice(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyConnectionsTable() {
    if (_myConnections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No active connections',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect to devices above to start',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _myConnections.length,
      itemBuilder: (context, index) {
        final connection = _myConnections[index];
        final otherDevice = connection.otherDevice;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Icon(
              otherDevice?.deviceType == DeviceType.android 
                ? Icons.phone_android 
                : Icons.computer,
              color: _getConnectionStatusColor(connection.status),
            ),
            title: Text(otherDevice?.name ?? 'Unknown Device'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${otherDevice?.deviceType.name} • ${otherDevice?.ipAddress}'),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _getConnectionStatusColor(connection.status),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      connection.status.name.toUpperCase(),
                      style: TextStyle(
                        color: _getConnectionStatusColor(connection.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (connection.status == ConnectionStatus.connected)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Send PDF'),
                    onPressed: () {
                      // This will be handled by the main app
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ready to send PDF to ${otherDevice?.name}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('Disconnect'),
                  onPressed: () => _disconnectFromDevice(connection),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Color _getConnectionStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.pending:
        return Colors.orange;
      case ConnectionStatus.rejected:
        return Colors.red;
      case ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }
} 
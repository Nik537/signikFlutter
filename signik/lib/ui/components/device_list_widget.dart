import 'package:flutter/material.dart';
import '../../models/signik_device.dart';
import '../../models/device_connection.dart';

/// Reusable device list widget
class DeviceListWidget extends StatelessWidget {
  final List<SignikDevice> devices;
  final List<DeviceConnection>? connections;
  final void Function(SignikDevice device)? onDeviceTap;
  final void Function(SignikDevice device)? onConnect;
  final void Function(String connectionId)? onDisconnect;
  final String title;
  final String emptyMessage;
  final bool showConnectionActions;

  const DeviceListWidget({
    super.key,
    required this.devices,
    this.connections,
    this.onDeviceTap,
    this.onConnect,
    this.onDisconnect,
    required this.title,
    this.emptyMessage = 'No devices found',
    this.showConnectionActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Chip(
                label: Text(
                  '${devices.length}',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.blue.shade100,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Device list
        Expanded(
          child: devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.devices_other,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final connection = _getConnectionForDevice(device.id);
                    
                    return DeviceListItem(
                      device: device,
                      connection: connection,
                      onTap: onDeviceTap != null 
                          ? () => onDeviceTap!(device)
                          : null,
                      onConnect: showConnectionActions && onConnect != null
                          ? () => onConnect!(device)
                          : null,
                      onDisconnect: showConnectionActions && 
                          onDisconnect != null && 
                          connection != null
                          ? () => onDisconnect!(connection.id)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  DeviceConnection? _getConnectionForDevice(String deviceId) {
    if (connections == null) return null;
    
    for (final conn in connections!) {
      if (conn.windowsDeviceId == deviceId || 
          conn.androidDeviceId == deviceId) {
        return conn;
      }
    }
    return null;
  }
}

/// Individual device list item
class DeviceListItem extends StatelessWidget {
  final SignikDevice device;
  final DeviceConnection? connection;
  final VoidCallback? onTap;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const DeviceListItem({
    super.key,
    required this.device,
    this.connection,
    this.onTap,
    this.onConnect,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = connection?.status == ConnectionStatus.connected;
    final isPending = connection?.status == ConnectionStatus.pending;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Device icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getDeviceColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getDeviceIcon(),
                  color: _getDeviceColor(),
                ),
              ),
              const SizedBox(width: 12),
              
              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          device.isOnline ? Icons.circle : Icons.circle_outlined,
                          size: 8,
                          color: device.isOnline ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          device.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          device.ipAddress,
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
              
              // Connection status/actions
              if (isConnected)
                Chip(
                  label: const Text(
                    'Connected',
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green.shade100,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: onDisconnect,
                )
              else if (isPending)
                Chip(
                  label: const Text(
                    'Pending',
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.orange.shade100,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              else if (onConnect != null && device.isOnline)
                ElevatedButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Connect'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon() {
    return device.deviceType == DeviceType.windows
        ? Icons.desktop_windows
        : Icons.phone_android;
  }

  Color _getDeviceColor() {
    if (!device.isOnline) return Colors.grey;
    return device.deviceType == DeviceType.windows
        ? Colors.blue
        : Colors.green;
  }
}
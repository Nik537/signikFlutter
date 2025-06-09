import 'package:flutter/material.dart';
import '../models/signik_device.dart';

class DeviceSelectionDialog extends StatelessWidget {
  final List<SignikDevice> devices;
  final String documentName;

  const DeviceSelectionDialog({
    super.key,
    required this.devices,
    required this.documentName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Send "$documentName" to Device'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose which device should receive this PDF:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (devices.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('No Android devices are currently online'),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final timeSinceHeartbeat = DateTime.now().difference(device.lastHeartbeat);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: device.isOnline ? Colors.green : Colors.grey,
                          child: Icon(
                            Icons.tablet_android,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          device.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('IP: ${device.ipAddress}'),
                            Text(
                              device.isOnline 
                                ? 'Online • Last seen ${_formatDuration(timeSinceHeartbeat)} ago'
                                : 'Offline • Last seen ${_formatDuration(timeSinceHeartbeat)} ago',
                              style: TextStyle(
                                color: device.isOnline ? Colors.green : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: device.isOnline 
                          ? const Icon(Icons.arrow_forward_ios, size: 16)
                          : const Icon(Icons.block, color: Colors.grey, size: 16),
                        enabled: device.isOnline,
                        onTap: device.isOnline 
                          ? () => Navigator.of(context).pop(device)
                          : null,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (devices.where((d) => d.isOnline).length == 1)
          ElevatedButton(
            onPressed: () {
              final onlineDevice = devices.firstWhere((d) => d.isOnline);
              Navigator.of(context).pop(onlineDevice);
            },
            child: const Text('Send to Only Device'),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inHours}h';
    }
  }
} 
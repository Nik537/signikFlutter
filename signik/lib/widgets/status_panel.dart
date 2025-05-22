import 'package:flutter/material.dart';

class StatusPanel extends StatelessWidget {
  final String status;
  final String? ip;
  final int? port;
  final bool connected;
  final bool hideStatus;

  const StatusPanel({
    super.key,
    required this.status,
    this.ip,
    this.port,
    this.connected = false,
    this.hideStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Icon(connected ? Icons.check_circle : Icons.info_outline, color: connected ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ip != null && port != null) ...[
                  Text('Server running at:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('IP: $ip', style: Theme.of(context).textTheme.bodyMedium),
                  Text('Port: $port', style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (!hideStatus) Text(status, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 
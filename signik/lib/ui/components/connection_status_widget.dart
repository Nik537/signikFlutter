import 'package:flutter/material.dart';

/// Reusable connection status widget
class ConnectionStatusWidget extends StatelessWidget {
  final bool isConnected;
  final String statusMessage;
  final int deviceCount;
  final VoidCallback? onRefresh;

  const ConnectionStatusWidget({
    super.key,
    required this.isConnected,
    required this.statusMessage,
    this.deviceCount = 0,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error,
            color: isConnected ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              statusMessage,
              style: TextStyle(
                color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (deviceCount > 0) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(
                '$deviceCount device${deviceCount != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.blue.shade100,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              iconSize: 20,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              tooltip: 'Refresh devices',
            ),
          ],
        ],
      ),
    );
  }
}
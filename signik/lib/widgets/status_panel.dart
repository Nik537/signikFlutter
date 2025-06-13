import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'common/connection_status_indicator.dart';

/// A panel widget that displays connection status and server information
class StatusPanel extends StatelessWidget {
  final String status;
  final String? ip;
  final int? port;
  final bool connected;
  final bool hideStatus;
  final Widget? trailing;

  const StatusPanel({
    super.key,
    required this.status,
    this.ip,
    this.port,
    this.connected = false,
    this.hideStatus = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.backgroundColorValue),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ip != null && port != null) ...[
                  Text(
                    'Server Info',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.wifi, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        ip ?? 'Unknown IP',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (port != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.dns, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Port $port',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (!hideStatus) ...[
                  if (ip != null && port != null) const SizedBox(height: 8),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: connected ? Colors.green.shade700 : Colors.grey.shade700,
                      fontWeight: connected ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
} 
import 'package:flutter/material.dart';

/// A reusable widget for showing connection status
class ConnectionStatusIndicator extends StatelessWidget {
  final bool isConnected;
  final double size;
  final bool showLabel;
  final String? customLabel;

  const ConnectionStatusIndicator({
    Key? key,
    required this.isConnected,
    this.size = 8.0,
    this.showLabel = false,
    this.customLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? Colors.green : Colors.red;
    final label = customLabel ?? (isConnected ? 'Online' : 'Offline');

    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
    }

    return _buildDot(color);
  }

  Widget _buildDot(Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: size / 2,
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }
}

/// A hub icon that changes based on connection status
class ConnectionHubIcon extends StatelessWidget {
  final bool isConnected;
  final double size;

  const ConnectionHubIcon({
    Key? key,
    required this.isConnected,
    this.size = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Icon(
      isConnected ? Icons.hub : Icons.hub_outlined,
      color: isConnected ? Colors.green : Colors.grey,
      size: size,
    );
  }
}
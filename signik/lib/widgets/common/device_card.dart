import 'package:flutter/material.dart';
import '../../models/signik_device.dart';
import '../../core/constants.dart';
import 'connection_status_indicator.dart';

/// A reusable card widget for displaying device information
class DeviceCard extends StatelessWidget {
  final SignikDevice device;
  final bool isSelected;
  final bool isConnected;
  final VoidCallback? onTap;
  final VoidCallback? onTestConnection;
  final Widget? trailing;

  const DeviceCard({
    Key? key,
    required this.device,
    this.isSelected = false,
    this.isConnected = false,
    this.onTap,
    this.onTestConnection,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected || isConnected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected || isConnected 
              ? const Color(AppConstants.primaryColorValue) 
              : Colors.transparent,
          width: isSelected || isConnected ? 2 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader(),
              _buildDeviceInfo(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(
          device.type == 'android' ? Icons.tablet_android : Icons.desktop_windows,
          size: 32,
          color: isSelected || isConnected 
              ? const Color(AppConstants.primaryColorValue) 
              : Colors.grey.shade400,
        ),
        ConnectionStatusIndicator(isConnected: device.isOnline),
      ],
    );
  }

  Widget _buildDeviceInfo() {
    return Column(
      children: [
        Text(
          device.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected || isConnected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected || isConnected 
                ? const Color(AppConstants.primaryColorValue) 
                : Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
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
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (trailing != null) 
          trailing!
        else
          _buildConnectionStatus(),
        if (onTestConnection != null && device.isOnline)
          IconButton(
            icon: const Icon(Icons.speed, size: 18),
            color: const Color(AppConstants.primaryColorValue),
            tooltip: AppConstants.tooltipTestConnection,
            onPressed: onTestConnection,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
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
    );
  }
}

/// A list tile version of the device card for use in lists
class DeviceListTile extends StatelessWidget {
  final SignikDevice device;
  final bool isSelected;
  final bool showConnectionStatus;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? subtitle;

  const DeviceListTile({
    Key? key,
    required this.device,
    this.isSelected = false,
    this.showConnectionStatus = true,
    this.onTap,
    this.trailing,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 2 : 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected 
              ? const Color(AppConstants.primaryColorValue) 
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected 
              ? const Color(AppConstants.primaryColorValue) 
              : Colors.grey.shade300,
          child: Icon(
            device.type == 'android' ? Icons.tablet_android : Icons.desktop_windows,
            color: isSelected ? Colors.white : Colors.grey.shade600,
            size: 20,
          ),
        ),
        title: Text(
          device.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? const Color(AppConstants.primaryColorValue) : Colors.black87,
          ),
        ),
        subtitle: subtitle ?? (showConnectionStatus ? Row(
          children: [
            ConnectionStatusIndicator(
              isConnected: device.isOnline,
              showLabel: true,
            ),
            const SizedBox(width: 12),
            Text(
              device.ipAddress ?? 'No IP',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ) : null),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
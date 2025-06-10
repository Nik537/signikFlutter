import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/signik_device.dart';
import '../models/signik_document.dart';
import '../services/connection_manager.dart' as cm;
import '../services/device_connections_service.dart';
import '../ui/windows/device_connections_screen.dart';
import 'signed_documents_list.dart';

class SidebarWithTabs extends StatefulWidget {
  final List<SignikDocument> signedDocuments;
  final Function(SignikDocument) onOpenDocument;
  final DeviceConnectionsService connectionsService;
  final VoidCallback onConnectionsChanged;

  const SidebarWithTabs({
    Key? key,
    required this.signedDocuments,
    required this.onOpenDocument,
    required this.connectionsService,
    required this.onConnectionsChanged,
  }) : super(key: key);

  @override
  State<SidebarWithTabs> createState() => _SidebarWithTabsState();
}

class _SidebarWithTabsState extends State<SidebarWithTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late cm.ConnectionManager _connectionManager;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _connectionManager = context.watch<cm.ConnectionManager>();
    
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          // Tab Bar
          Container(
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
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(
                  icon: Icon(Icons.description),
                  text: 'Documents',
                ),
                Tab(
                  icon: Icon(Icons.device_hub),
                  text: 'Connections',
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Documents Tab
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Signed Documents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: SignedDocumentsList(
                        documents: widget.signedDocuments,
                        onOpen: widget.onOpenDocument,
                      ),
                    ),
                  ],
                ),
                // Connections Tab
                _buildConnectionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsTab() {
    final currentPcId = _connectionManager.deviceId;
    if (currentPcId == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final connectedDeviceIds = widget.connectionsService.getConnectedDevices(currentPcId);
    final connectedDevices = _connectionManager.devices
        .where((d) => d.type == 'android' && d.isOnline && connectedDeviceIds.contains(d.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connected Devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Android devices that can receive PDFs',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        // Connected devices list
        Expanded(
          child: connectedDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tablet_android, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No connected devices',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add devices in the connection manager',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: connectedDevices.length,
                  itemBuilder: (context, index) {
                    final device = connectedDevices[index];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF0066CC),
                          child: Icon(
                            Icons.tablet_android,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          device.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
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
                              device.ipAddress ?? 'No IP',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.speed, size: 18),
                          color: const Color(0xFF0066CC),
                          tooltip: 'Test Connection',
                          onPressed: () => _testConnection(device),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Connection Manager Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openDeviceConnectionsScreen,
              icon: const Icon(Icons.settings),
              label: const Text('Open Connection Manager'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066CC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _testConnection(SignikDevice device) async {
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
          content: Text('Connection to ${device.name} failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _openDeviceConnectionsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: _connectionManager,
          child: const DeviceConnectionsScreen(),
        ),
      ),
    );
    
    // Reload connections after returning
    await widget.connectionsService.loadConnections();
    widget.onConnectionsChanged();
  }

}
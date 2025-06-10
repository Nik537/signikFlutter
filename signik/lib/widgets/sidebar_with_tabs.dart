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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.device_hub,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Manage Device Connections',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Configure which Android devices each PC can send documents to',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openDeviceConnectionsScreen,
              icon: const Icon(Icons.settings),
              label: const Text('Open Connection Manager'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066CC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
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
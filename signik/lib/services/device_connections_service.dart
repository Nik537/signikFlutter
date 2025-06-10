import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DeviceConnectionsService {
  static const String _fileName = 'device_connections.json';
  
  // Map of PC device ID to list of connected Android device IDs
  Map<String, List<String>> _connections = {};
  
  // Get connections for a specific PC
  List<String> getConnectedDevices(String pcId) {
    return _connections[pcId] ?? [];
  }
  
  // Add a connection between PC and Android device
  void addConnection(String pcId, String androidDeviceId) {
    if (!_connections.containsKey(pcId)) {
      _connections[pcId] = [];
    }
    if (!_connections[pcId]!.contains(androidDeviceId)) {
      _connections[pcId]!.add(androidDeviceId);
    }
  }
  
  // Remove a connection between PC and Android device
  void removeConnection(String pcId, String androidDeviceId) {
    if (_connections.containsKey(pcId)) {
      _connections[pcId]!.remove(androidDeviceId);
      if (_connections[pcId]!.isEmpty) {
        _connections.remove(pcId);
      }
    }
  }
  
  // Toggle connection status
  void toggleConnection(String pcId, String androidDeviceId) {
    if (getConnectedDevices(pcId).contains(androidDeviceId)) {
      removeConnection(pcId, androidDeviceId);
    } else {
      addConnection(pcId, androidDeviceId);
    }
  }
  
  // Check if a specific Android device is available for a PC
  bool isDeviceAvailable(String pcId, String androidDeviceId) {
    return getConnectedDevices(pcId).contains(androidDeviceId);
  }
  
  // Get all PCs that can send to a specific Android device
  List<String> getPCsForAndroidDevice(String androidDeviceId) {
    List<String> pcs = [];
    _connections.forEach((pcId, androidDevices) {
      if (androidDevices.contains(androidDeviceId)) {
        pcs.add(pcId);
      }
    });
    return pcs;
  }
  
  // Load connections from file
  Future<void> loadConnections() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(jsonString);
        
        _connections = {};
        json.forEach((key, value) {
          if (value is List) {
            _connections[key] = List<String>.from(value);
          }
        });
      } else {
        // If no file exists, create default connections
        _connections = {};
      }
    } catch (e) {
      print('Error loading connections: $e');
      _connections = {};
    }
  }
  
  // Save connections to file
  Future<void> saveConnections() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      final jsonString = jsonEncode(_connections);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error saving connections: $e');
      throw Exception('Failed to save device connections');
    }
  }
  
  // Clear all connections
  void clearAllConnections() {
    _connections.clear();
  }
  
  // Get statistics about connections
  Map<String, int> getConnectionStats() {
    Map<String, int> stats = {
      'totalPCs': _connections.keys.length,
      'totalConnections': 0,
      'averageConnectionsPerPC': 0,
    };
    
    int totalConnections = 0;
    _connections.forEach((_, devices) {
      totalConnections += devices.length;
    });
    
    stats['totalConnections'] = totalConnections;
    if (stats['totalPCs']! > 0) {
      stats['averageConnectionsPerPC'] = (totalConnections / stats['totalPCs']!).round();
    }
    
    return stats;
  }
  
  // Import connections from JSON string (for backup/restore)
  void importConnections(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      _connections = {};
      json.forEach((key, value) {
        if (value is List) {
          _connections[key] = List<String>.from(value);
        }
      });
    } catch (e) {
      throw Exception('Invalid connections data format');
    }
  }
  
  // Export connections to JSON string (for backup/restore)
  String exportConnections() {
    return jsonEncode(_connections);
  }
}
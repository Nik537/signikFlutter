import 'dart:async';
import 'broker_service.dart';

class HeartbeatService {
  final BrokerService _brokerService;
  Timer? _heartbeatTimer;
  final Duration _interval;
  bool _isRunning = false;

  HeartbeatService(this._brokerService, {Duration? interval})
      : _interval = interval ?? const Duration(seconds: 10);

  /// Start sending periodic heartbeats
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _heartbeatTimer = Timer.periodic(_interval, (timer) async {
      try {
        await _brokerService.sendHeartbeat();
        print('Heartbeat sent successfully');
      } catch (e) {
        print('Failed to send heartbeat: $e');
        // Continue trying - don't stop the timer on failure
      }
    });
    
    print('Heartbeat service started with ${_interval.inSeconds}s interval');
  }

  /// Stop sending heartbeats
  void stop() {
    if (!_isRunning) return;
    
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;
    
    print('Heartbeat service stopped');
  }

  /// Check if heartbeat service is running
  bool get isRunning => _isRunning;

  /// Send a single heartbeat immediately
  Future<void> sendHeartbeat() async {
    try {
      await _brokerService.sendHeartbeat();
    } catch (e) {
      print('Failed to send manual heartbeat: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
} 
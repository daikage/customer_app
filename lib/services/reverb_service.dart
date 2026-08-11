import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';

/// Connects to Laravel Reverb (a Pusher-protocol-compatible WebSocket server)
/// and subscribes to channels for real-time ride updates, chat, and driver location.
class ReverbService {
  ReverbService._();
  static final ReverbService instance = ReverbService._();

  // ──────────────────────────────────────────────────────────
  // Configure these to match your Reverb server
  // ──────────────────────────────────────────────────────────
  static const String _reverbHost = 'backend-production-dzqjad.laravel.cloud';
  static const int _reverbPort = 443;
  static const String _reverbScheme = 'wss';
  static const String _reverbAppKey = '4phwo505nfakoseuxte5';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _socketId;
  bool _connected = false;

  final _eventController = StreamController<ReverbEvent>.broadcast();

  /// A broadcast stream of all incoming events.
  Stream<ReverbEvent> get events => _eventController.stream;

  bool get isConnected => _connected;

  /// Connect to the Reverb WebSocket server.
  Future<void> connect() async {
    if (_connected) return;

    final uri = Uri(
      scheme: _reverbScheme,
      host: _reverbHost,
      port: _reverbPort,
      path: '/app/$_reverbAppKey',
      queryParameters: {
        'protocol': '7',
        'client': 'dart',
        'version': '1.0',
        'flash': 'false',
      },
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _connected = true;

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
    } catch (e) {
      _connected = false;
      // Retry after delay
      Future.delayed(const Duration(seconds: 5), connect);
    }
  }

  void _onMessage(dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      final event = data['event'] as String? ?? '';
      final channelName = data['channel'] as String?;

      if (event == 'pusher:connection_established') {
        final connectionData = jsonDecode(data['data'] as String) as Map<String, dynamic>;
        _socketId = connectionData['socket_id'] as String?;
        _connected = true;
        // Notify listeners (RealtimeBindings) so channel subscriptions can be
        // (re)established now that the socket id is available for auth.
        _eventController.add(ReverbEvent(event: event, channel: null, data: {}));
        return;
      }

      if (event == 'pusher:error') {
        return;
      }

      // Parse the event data
      dynamic eventData;
      if (data['data'] is String) {
        eventData = jsonDecode(data['data'] as String);
      } else {
        eventData = data['data'];
      }

      _eventController.add(ReverbEvent(
        event: event,
        channel: channelName,
        data: eventData is Map ? (eventData as Map).cast<String, dynamic>() : {},
      ));
    } catch (_) {
      // Ignore malformed messages
    }
  }

  void _onError(Object error) {
    _connected = false;
    Future.delayed(const Duration(seconds: 5), connect);
  }

  void _onDone() {
    _connected = false;
    Future.delayed(const Duration(seconds: 5), connect);
  }

  /// Subscribe to a public channel.
  void subscribe(String channel) {
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channel},
    });
  }

  /// Subscribe to a private channel (requires auth).
  Future<void> subscribePrivate(String channel) async {
    if (_socketId == null) return;

    try {
      final response = await ApiService.instance.dio.post(
        '/broadcasting/auth',
        data: {
          'socket_id': _socketId,
          'channel_name': 'private-$channel',
        },
      );
      final authData = response.data as Map<String, dynamic>;

      _send({
        'event': 'pusher:subscribe',
        'data': {
          'channel': 'private-$channel',
          'auth': authData['auth'],
        },
      });
    } catch (_) {
      // Auth failed — channel subscription won't work
    }
  }

  /// Subscribe to a presence channel (requires auth).
  Future<void> subscribePresence(String channel) async {
    if (_socketId == null) return;

    try {
      final response = await ApiService.instance.dio.post(
        '/broadcasting/auth',
        data: {
          'socket_id': _socketId,
          'channel_name': 'presence-$channel',
        },
      );
      final authData = response.data as Map<String, dynamic>;

      _send({
        'event': 'pusher:subscribe',
        'data': {
          'channel': 'presence-$channel',
          'auth': authData['auth'],
          'channel_data': authData['channel_data'],
        },
      });
    } catch (_) {
      // Auth failed
    }
  }

  /// Unsubscribe from a channel.
  void unsubscribe(String channel) {
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channel},
    });
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  /// Disconnect from the WebSocket server.
  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _socketId = null;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}

class ReverbEvent {
  final String event;
  final String? channel;
  final Map<String, dynamic> data;

  const ReverbEvent({
    required this.event,
    this.channel,
    this.data = const {},
  });

  @override
  String toString() => 'ReverbEvent(event: $event, channel: $channel, data: $data)';
}

/// Provider that exposes the global ReverbService instance.
final reverbServiceProvider = Provider<ReverbService>((ref) {
  return ReverbService.instance;
});

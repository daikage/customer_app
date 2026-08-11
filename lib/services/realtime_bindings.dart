import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import 'reverb_service.dart';

/// The raw stream of realtime events coming from the Reverb socket,
/// exposed as a Riverpod provider so widgets can subscribe to it.
final reverbEventsProvider = StreamProvider.autoDispose<ReverbEvent>((ref) {
  return ReverbService.instance.events;
});

/// Keeps the Reverb WebSocket in sync with the customer's auth + ride state and
/// routes incoming events (ride status, driver location, chat) into the ride
/// provider. It renders its [child] unchanged, so it adds no layout of its own.
class RealtimeBindings extends ConsumerStatefulWidget {
  const RealtimeBindings({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RealtimeBindings> createState() => _RealtimeBindingsState();
}

class _RealtimeBindingsState extends ConsumerState<RealtimeBindings> {
  int? _subscribedRideId;

  @override
  Widget build(BuildContext context) {
    // Keep the socket alive while the user is signed in.
    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      final isLoggedIn = next.isLoggedIn;

      if (isLoggedIn && !wasLoggedIn) {
        _subscribedRideId = null;
        ref.read(reverbServiceProvider).connect();
        _syncSubscriptions();
      } else if (!isLoggedIn && wasLoggedIn) {
        _subscribedRideId = null;
        ref.read(reverbServiceProvider).disconnect();
      }
    });

    // Subscribe/unsubscribe as the active ride changes.
    ref.listen<RideState>(rideProvider, (previous, next) {
      _syncSubscriptions();
    });

    // Route realtime events into app state.
    ref.listen(reverbEventsProvider, (previous, AsyncValue<ReverbEvent>? next) {
      final event = next?.value;
      if (event == null) return;
      _handleEvent(event);
    });

    return widget.child;
  }

  /// Ensures the socket is subscribed to exactly the channels the current
  /// state requires. Safe to call repeatedly (idempotent).
  void _syncSubscriptions() {
    final reverb = ref.read(reverbServiceProvider);

    if (!ref.read(authProvider).isLoggedIn) {
      _subscribedRideId = null;
      return;
    }

    final rideState = ref.read(rideProvider);
    final rideId = rideState.ride?['id'] as int?;
    final status = rideState.ride?['status'] as String?;
    final isTerminal = status == 'completed' || status == 'cancelled';

    if (rideId != null && !isTerminal) {
      if (_subscribedRideId != rideId) {
        if (_subscribedRideId != null) {
          reverb.unsubscribe('private-ride.$_subscribedRideId');
          reverb.unsubscribe('presence-ride.$_subscribedRideId');
        }
        _subscribedRideId = rideId;
        reverb.subscribePrivate('ride.$rideId');
        reverb.subscribePresence('ride.$rideId');
      }
    } else if (_subscribedRideId != null) {
      reverb.unsubscribe('private-ride.$_subscribedRideId');
      reverb.unsubscribe('presence-ride.$_subscribedRideId');
      _subscribedRideId = null;
    }
  }

  Future<void> _handleEvent(ReverbEvent event) async {
    final rideNotifier = ref.read(rideProvider.notifier);

    switch (event.event) {
      case 'pusher:connection_established':
        // Socket (re)connected – re-establish the channel subscriptions.
        _syncSubscriptions();
        break;

      case 'RideStatusUpdated':
        final payload = event.data['ride'];
        if (payload is Map) {
          final payloadRide = (payload).cast<String, dynamic>();
          final payloadId = payloadRide['id'];
          final newStatus = payloadRide['status'];
          final currentRide = ref.read(rideProvider).ride;

          if (currentRide != null &&
              payloadId == currentRide['id'] &&
              newStatus is String) {
            rideNotifier.updateRideLocally({
              ...currentRide,
              ...payloadRide,
            });
            if (newStatus == 'completed' || newStatus == 'cancelled') {
              // Keep the local record so the UI shows the final state;
              // nothing to refresh from the server afterwards.
              return;
            }
          }
        }
        // Pull the authoritative ride record (full driver info, timestamps…).
        rideNotifier.fetchActive();
        break;

      case 'DriverLocationUpdated':
        _applyDriverLocation(event.data);
        break;

      case 'MessageSent':
        final message = event.data['message'];
        if (message is Map) {
          rideNotifier.appendMessage((message).cast<String, dynamic>());
        }
        break;
    }
  }

  void _applyDriverLocation(Map<String, dynamic> data) {
    final currentRide = ref.read(rideProvider).ride;
    if (currentRide == null) return;

    final rideId = data['rideId'];
    final lat = data['lat'];
    final lng = data['lng'];
    if (rideId != currentRide['id'] || lat == null || lng == null) return;

    final driver = (currentRide['driver'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    driver['last_lat'] = lat;
    driver['last_lng'] = lng;
    if (data['heading'] != null) driver['heading'] = data['heading'];

    ref.read(rideProvider.notifier).updateRideLocally({
      ...currentRide,
      'driver': driver,
    });
  }
}
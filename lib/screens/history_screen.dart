import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/ride_provider.dart';
import '../utils/app_theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(rideProvider.notifier).fetchHistory());
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideProvider);
    final history = rideState.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
      ),
      body: rideState.loading && history.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final ride = history[index];
                    return _buildRideCard(ride);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No past rides yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed and cancelled rides\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final status = ride['status'] as String? ?? 'completed';
    final isCancelled = status == 'cancelled';
    final date = ride['created_at'] != null 
        ? DateTime.tryParse(ride['created_at']) 
        : null;
    final dateStr = date != null ? DateFormat('MMM d, yyyy • h:mm a').format(date) : '';
    
    // Minimalist Shadcn-inspired card
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200), // Sharp, clean border
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCancelled ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isCancelled ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    serviceTypeIcon(ride['service_type'] ?? 'single'),
                    color: serviceTypeColor(ride['service_type'] ?? 'single'),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₦${ride['actual_fare'] ?? ride['estimated_fare']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        serviceTypeLabel(ride['service_type'] ?? 'single'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Addresses
            _buildAddressRow(Icons.my_location_rounded, ride['pickup_address'], Colors.blue),
            Padding(
              padding: const EdgeInsets.only(left: 7.5, top: 4, bottom: 4),
              child: Container(width: 1.5, height: 12, color: Colors.grey.shade300),
            ),
            _buildAddressRow(Icons.location_on_rounded, ride['dropoff_address'], AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String? address, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address ?? 'Unknown Location',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

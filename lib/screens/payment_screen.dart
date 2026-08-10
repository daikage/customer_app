import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/payment_provider.dart';
import '../utils/app_theme.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final int rideId;
  final double amount;
  final String pickupAddress;
  final String dropoffAddress;

  const PaymentScreen({
    super.key,
    required this.rideId,
    required this.amount,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedGateway = 'paystack';

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.primary),
        ),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Ride Summary Card ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.soft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ride Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.circle,
                    'Pickup',
                    widget.pickupAddress,
                    AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_on,
                    'Dropoff',
                    widget.dropoffAddress,
                    AppColors.error,
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₦${widget.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 24),

            // ── Payment Method ────────────────────────────────────
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),

            _GatewayOption(
              label: 'Paystack',
              subtitle: 'Card, Bank Transfer, USSD',
              icon: Icons.credit_card_rounded,
              selected: _selectedGateway == 'paystack',
              color: const Color(0xFF00C3F7),
              isDark: isDark,
              onTap: () => setState(() => _selectedGateway = 'paystack'),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 10),

            _GatewayOption(
              label: 'Flutterwave',
              subtitle: 'Card, Mobile Money, Bank',
              icon: Icons.account_balance_wallet_rounded,
              selected: _selectedGateway == 'flutterwave',
              color: const Color(0xFFF5A623),
              isDark: isDark,
              onTap: () => setState(() => _selectedGateway = 'flutterwave'),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 32),

            // ── Status messages ────────────────────────────────────
            if (paymentState.status == 'completed')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Payment successful! You can close this screen.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (paymentState.error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  paymentState.error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),

            if (paymentState.status != 'completed') ...[
              const SizedBox(height: 8),

              // ── Pay Button ──────────────────────────────────────
              FilledButton(
                onPressed: paymentState.loading
                    ? null
                    : () async {
                        await ref.read(paymentProvider.notifier).initialize(
                              rideId: widget.rideId,
                              amount: widget.amount,
                              gateway: _selectedGateway,
                            );

                        final url = ref.read(paymentProvider).authorizationUrl;
                        if (url != null && mounted) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: paymentState.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Pay ₦${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ).animate().fadeIn(delay: 300.ms),

              // ── Verify Button (shown after initialization) ────────
              if (paymentState.status == 'pending' &&
                  paymentState.reference != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: paymentState.loading
                      ? null
                      : () async {
                          await ref.read(paymentProvider.notifier).verify(
                                gateway: _selectedGateway,
                                reference: paymentState.reference!,
                              );
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                    ),
                  ),
                  child: const Text(
                    'I\'ve completed payment — Verify',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GatewayOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _GatewayOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)] : AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? color : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

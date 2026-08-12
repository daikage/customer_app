import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_theme.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(walletProvider.notifier).fetchWalletAndTransactions());
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController();
    String selectedGateway = 'paystack';
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Top up Wallet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (₦)',
                    prefixIcon: const Icon(Icons.money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedGateway,
                  decoration: InputDecoration(
                    labelText: 'Payment Gateway',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'paystack', child: Text('Paystack')),
                    DropdownMenuItem(value: 'flutterwave', child: Text('Flutterwave')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedGateway = val);
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final amount = double.tryParse(amountController.text);
                            if (amount == null || amount < 100) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Enter a valid amount (Min 100)')),
                              );
                              return;
                            }
                            setState(() => isLoading = true);
                            try {
                              final url = await ref
                                  .read(walletProvider.notifier)
                                  .topupWallet(amount, selectedGateway);
                              Navigator.pop(context); // Close bottom sheet
                              
                              if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
                                throw Exception('Could not launch payment gateway');
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                              setState(() => isLoading = false);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Proceed to Pay', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    ).then((_) {
      // Refresh wallet balance when coming back
      ref.read(walletProvider.notifier).fetchWalletAndTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.primary),
        ),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: state.loading && state.wallet == null
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.wallet == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => ref
                              .read(walletProvider.notifier)
                              .fetchWalletAndTransactions(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(walletProvider.notifier)
                      .fetchWalletAndTransactions(),
                  color: AppColors.primary,
                  child: Column(
                    children: [
                      // ── Balance card ────────────────────────────────
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppShadows.glow(AppColors.primary),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Wallet Balance',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '₦${state.wallet?['balance'] ?? '0.00'}',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_rounded,
                                      color: AppColors.accentLight, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${state.transactions.length} transaction${state.transactions.length != 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _showTopUpDialog,
                                icon: const Icon(Icons.add, color: AppColors.primary),
                                label: const Text(
                                  'Top Up Wallet',
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: 0.1),

                      // ── Header ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Row(
                          children: [
                            const Text(
                              'Transaction History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${state.transactions.length} total',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      // ── Transactions list ──────────────────────────
                      Expanded(
                        child: state.transactions.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                        Icons.receipt_long_outlined,
                                        size: 64,
                                        color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No transactions yet',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your payment history will appear here',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: state.transactions.length,
                                itemBuilder: (ctx, i) {
                                  final txn = state.transactions[i];
                                  return _buildTransactionCard(
                                      txn, isDark, i);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTransactionCard(
      Map<String, dynamic> txn, bool isDark, int index) {
    final status = txn['payment_status'] as String? ?? 'pending';
    final isCompleted = status == 'completed';
    final isFailed = status == 'failed';

    final date = txn['created_at'] != null
        ? DateTime.tryParse(txn['created_at'])
        : null;
    final dateStr =
        date != null ? DateFormat('MMM d, yyyy • h:mm a').format(date) : '';

    final Color statusColor;
    final IconData statusIcon;
    if (isCompleted) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (isFailed) {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn['payment_method'] != null
                      ? '${(txn['payment_method'] as String).substring(0, 1).toUpperCase()}${(txn['payment_method'] as String).substring(1)}'
                      : 'Payment',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₦${txn['amount'] ?? '0.00'}',
                style: TextStyle(
                  color: isCompleted ? AppColors.success : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index));
  }
}

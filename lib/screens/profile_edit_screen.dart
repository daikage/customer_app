import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _nameC;
  late final TextEditingController _emailC;
  late final TextEditingController _phoneC;
  bool _saving = false;
  String? _error;

  // Password change
  final _currentPwC = TextEditingController();
  final _newPwC = TextEditingController();
  final _confirmPwC = TextEditingController();
  bool _changingPw = false;
  String? _pwError;
  String? _pwSuccess;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameC = TextEditingController(text: user?['name'] as String? ?? '');
    _emailC = TextEditingController(text: user?['email'] as String? ?? '');
    _phoneC = TextEditingController(text: user?['phone'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _currentPwC.dispose();
    _newPwC.dispose();
    _confirmPwC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final response = await ApiService.instance.dio.put('/user', data: {
        'name': _nameC.text.trim(),
        'email': _emailC.text.trim(),
        'phone': _phoneC.text.trim(),
      });
      final user = (response.data['user'] as Map).cast<String, dynamic>();
      // Update the auth state with new user data
      ref.read(authProvider.notifier).restore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } on Exception catch (e) {
      setState(() => _error = ApiService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPwC.text != _confirmPwC.text) {
      setState(() => _pwError = 'Passwords do not match');
      return;
    }
    setState(() { _changingPw = true; _pwError = null; _pwSuccess = null; });
    try {
      await ApiService.instance.dio.post('/change-password', data: {
        'current_password': _currentPwC.text,
        'new_password': _newPwC.text,
        'new_password_confirmation': _confirmPwC.text,
      });
      _currentPwC.clear();
      _newPwC.clear();
      _confirmPwC.clear();
      setState(() => _pwSuccess = 'Password changed successfully!');
    } on Exception catch (e) {
      setState(() => _pwError = ApiService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _changingPw = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.primary),
        ),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile Fields ────────────────────────────────
          _sectionLabel('PERSONAL INFORMATION'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _nameC,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailC,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneC,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.05),

          const SizedBox(height: 28),

          // ── Change Password ─────────────────────────────
          _sectionLabel('CHANGE PASSWORD'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _currentPwC,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newPwC,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPwC,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                ),
                if (_pwError != null) ...[
                  const SizedBox(height: 12),
                  Text(_pwError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                if (_pwSuccess != null) ...[
                  const SizedBox(height: 12),
                  Text(_pwSuccess!, style: const TextStyle(color: AppColors.success, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _changingPw ? null : _changePassword,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _changingPw
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

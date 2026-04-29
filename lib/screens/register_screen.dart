import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/theme/app_colors.dart';
import '../core/api_client.dart';
import '../core/constants/api_constants.dart';
import '../core/services/local_db_service.dart';
import '../data/auth_repository.dart';
import '../widgets/glassmorphic_card.dart';

/// Register screen with client-side validation.
class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegisterSuccess;
  const RegisterScreen({super.key, required this.onRegisterSuccess});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _repo = AuthRepository();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _openApiSettings() async {
    final controller = TextEditingController(
      text:
          LocalDbService.getPreference<String>('api_base_url') ??
          ApiConstants.baseUrl,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('API Base URL'),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'http://192.168.1.10:8000',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (saved == true) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        await LocalDbService.savePreference('api_base_url', value);
        ApiClient.updateBaseUrl(value);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('API base URL updated')));
        }
      }
    }
  }

  Future<void> _register() async {
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.register(
        username: username,
        email: email,
        password: password,
      );

      if (mounted) {
        // Navigate back to login and pass credentials to pre-fill
        Navigator.pop(context, {'username': username, 'password': password});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Akun berhasil dibuat! Silakan login.'),
            backgroundColor: AppColors.buyGreen.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? e.response?.data['detail']
          : null;
      setState(
        () => _error =
            detail?.toString() ?? 'Connection error. Is the backend running?',
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GlassmorphicCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create your account to get started',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _usernameCtrl,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _confirmCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onSubmitted: (_) => _register(),
                  ),
                  const SizedBox(height: 16),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.sellRedBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.sellRedLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _openApiSettings,
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('API Settings'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

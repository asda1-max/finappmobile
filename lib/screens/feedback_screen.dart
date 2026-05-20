import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/theme/app_colors.dart';
import '../core/theme/input_decorators.dart';
import '../core/services/session_service.dart';
import '../data/feedback_repository.dart';
import '../core/constants/api_constants.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/premium_alert_overlay.dart';
import '../core/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _saranController = TextEditingController();
  final TextEditingController _kesanController = TextEditingController();
  final FeedbackRepository _repo = FeedbackRepository();
  String _rating = '5';
  bool _isLoading = false;
  List<FeedbackModel> _feedbacks = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadFeedbacks();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final token = await SessionService.getToken();
      if (token == null) return;
      final parts = token.split('.');
      if (parts.length != 3) return;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      final userId = decoded['sub'] as String?;
      if (mounted) {
        setState(() => _currentUserId = userId);
      }
    } catch (_) {
      // Ignore decode errors
    }
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoading = true);
    try {
      final feedbacks = await _repo.getFeedbacks();
      if (mounted) {
        setState(() {
          _feedbacks = feedbacks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _saranController.dispose();
    _kesanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saranController.text.trim().isEmpty ||
        _kesanController.text.trim().isEmpty) {
      PremiumAlertOverlay.showStatus(
        context,
        title: 'Form Belum Lengkap',
        message: 'Mohon isi saran dan kesan.',
        icon: Icons.warning_amber_rounded,
        accentColor: AppColors.holdAmber,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await SessionService.getToken();
      if (token == null) throw Exception('No token');

      await _repo.createFeedback(
        token,
        rating: _rating,
        kesan: _kesanController.text,
        saran: _saranController.text,
      );

      if (mounted) {
        PremiumAlertOverlay.showStatus(
          context,
          title: 'Terima Kasih! ✨',
          message: 'Feedback Anda telah tersimpan.',
          icon: Icons.favorite_rounded,
          accentColor: AppColors.buyGreen,
        );
      }

      _saranController.clear();
      _kesanController.clear();
      setState(() => _rating = '5');
      
      await _loadFeedbacks();
    } catch (e) {
      if (mounted) {
        PremiumAlertOverlay.showStatus(
          context,
          title: 'Gagal Mengirim',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.sellRed,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteFeedback(String id) async {
    try {
      final token = await SessionService.getToken();
      if (token == null) return;
      await _repo.deleteFeedback(token, id);
      await _loadFeedbacks();
    } catch (e) {
      if (mounted) {
        PremiumAlertOverlay.showStatus(
          context,
          title: 'Gagal Menghapus',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.sellRed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading && _feedbacks.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.feedback_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: const Text(
                          'Saran & Kesan TPM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Berikan feedback singkat untuk evaluasi mata kuliah TPM.',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 16),

                  GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Penilaian Anda',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _rating,
                          dropdownColor: AppColors.surface,
                          decoration: AppInputDecoration.dropdown(
                            labelText: 'Skor (1-5)',
                          ),
                          items: ['1', '2', '3', '4', '5']
                              .map((score) => DropdownMenuItem(
                                    value: score,
                                    child: Text(score),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _rating = v ?? '5'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _kesanController,
                          maxLines: 3,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: AppInputDecoration.standard(
                            labelText: 'Kesan',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _saranController,
                          maxLines: 3,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: AppInputDecoration.standard(
                            labelText: 'Saran',
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submit,
                            icon: _isLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(_isLoading ? 'Mengirim...' : 'Kirim Feedback'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  if (_feedbacks.isNotEmpty) ...[
                    const Text(
                      'Feedback Sebelumnya',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._feedbacks.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassmorphicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary.withValues(alpha: 0.2),
                                        ),
                                        child: ClipOval(
                                          child: f.profilePic != null
                                              ? CachedNetworkImage(
                                                  imageUrl: '${Uri.parse(ApiClient.instance.options.baseUrl).resolve(f.profilePic!).toString()}',
                                                  fit: BoxFit.cover,
                                                  width: 24,
                                                  height: 24,
                                                  placeholder: (context, url) => const Center(
                                                    child: SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child: CircularProgressIndicator(strokeWidth: 1.5),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => Center(
                                                    child: Text(
                                                      (f.username ?? '?').isNotEmpty ? (f.username ?? '?')[0].toUpperCase() : '?',
                                                      style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)
                                                    ),
                                                  ),
                                                )
                                              : Center(
                                                  child: Text(
                                                    (f.username ?? '?').isNotEmpty ? (f.username ?? '?')[0].toUpperCase() : '?',
                                                    style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)
                                                  ),
                                                ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      f.username ?? 'User',
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(f.rating, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 8),
                                    if (_currentUserId != null && f.userId == _currentUserId)
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.delete_outline, color: AppColors.sellRed, size: 16),
                                        onPressed: () => _deleteFeedback(f.id),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Kesan: ${f.kesan}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('Saran: ${f.saran}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        )
                      )
                    )).toList(),
                  ]
                ],
              ),
      ),
    );
  }
}

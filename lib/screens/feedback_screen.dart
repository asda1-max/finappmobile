import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/session_service.dart';
import '../data/feedback_repository.dart';
import '../core/constants/api_constants.dart';
import '../widgets/glassmorphic_card.dart';

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
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoading = true);
    try {
      final token = await SessionService.getToken();
      if (token != null) {
        // Just extract user id from simple decode for checking ownership
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          // We can't easily decode base64 without dart:convert but we can just use an endpoint if needed.
          // Since we changed the backend to send user_id on login, let's just fetch it from session if we saved it.
          // Wait, we didn't save user_id in SessionService. We'll rely on backend checking or just not show delete if not matched.
          // Let's just fetch feedbacks first.
        }
      }
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi saran dan kesan.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terima kasih! Feedback tersimpan.')),
        );
      }

      _saranController.clear();
      _kesanController.clear();
      setState(() => _rating = '5');
      
      await _loadFeedbacks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim feedback: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus feedback: $e')),
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
                          decoration: InputDecoration(
                            labelText: 'Skor (1-5)',
                            labelStyle: TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.cardBorder),
                            ),
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
                          decoration: InputDecoration(
                            labelText: 'Kesan',
                            labelStyle: TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.cardBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _saranController,
                          maxLines: 3,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Saran',
                            labelStyle: TextStyle(color: AppColors.textTertiary),
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.cardBorder),
                            ),
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
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                      backgroundImage: f.profilePic != null 
                                          ? NetworkImage('${ApiConstants.baseUrl}${f.profilePic}') 
                                          : null,
                                      child: f.profilePic == null 
                                          ? Text(
                                              (f.username ?? '?').isNotEmpty ? (f.username ?? '?')[0].toUpperCase() : '?',
                                              style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)
                                            )
                                          : null,
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

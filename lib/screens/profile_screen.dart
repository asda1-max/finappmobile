import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/session_service.dart';
import '../widgets/glassmorphic_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = '...';
  String _email = '...';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final username = await SessionService.getUsername();
    final email = await SessionService.getEmail();
    if (mounted) {
      setState(() {
        _username = username ?? 'User';
        _email = email ?? '-';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Row(
              children: [
                const Icon(Icons.person_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Profil',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            GlassmorphicCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _username,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Portfolio Strategist',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Profil',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Username', value: _username),
                  _InfoRow(label: 'Email', value: _email),
                  _InfoRow(label: 'Mata Kuliah', value: 'TPM'),
                  _InfoRow(label: 'Minat', value: 'Analisis Saham & Fintech'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Portfolio Goals',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      _StatChip(label: 'Risk', value: 'Medium'),
                      SizedBox(width: 8),
                      _StatChip(label: 'Horizon', value: '3-5 Tahun'),
                      SizedBox(width: 8),
                      _StatChip(label: 'Target', value: '12%/th'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fokus pada saham growth dan value dengan sinyal hybrid scoring.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

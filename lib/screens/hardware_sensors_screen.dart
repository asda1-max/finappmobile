import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glassmorphic_card.dart';

class HardwareSensorsScreen extends StatelessWidget {
  const HardwareSensorsScreen({super.key});

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
                const Icon(Icons.memory_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Hardware Sensors',
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
              'Daftar sensor yang terdeteksi dan data live.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),

            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🧩 Sensor Perangkat',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SensorCard(
                    title: 'Accelerometer',
                    subtitle: 'Stabilitas gerakan perangkat',
                    icon: Icons.speed_rounded,
                    stream: accelerometerEventStream(),
                  ),
                  const SizedBox(height: 12),
                  _SensorCard(
                    title: 'Gyroscope',
                    subtitle: 'Rotasi orientasi sudut',
                    icon: Icons.screen_rotation_rounded,
                    stream: gyroscopeEventStream(),
                  ),
                  const SizedBox(height: 12),
                  _SensorCard(
                    title: 'Magnetometer',
                    subtitle: 'Medan magnet sekitar',
                    icon: Icons.explore_rounded,
                    stream: magnetometerEventStream(),
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

class _SensorCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Stream<dynamic> stream;

  const _SensorCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final x = (data?.x ?? 0).toDouble();
        final y = (data?.y ?? 0).toDouble();
        final z = (data?.z ?? 0).toDouble();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        )),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('x: ${x.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      )),
                  Text('y: ${y.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      )),
                  Text('z: ${z.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

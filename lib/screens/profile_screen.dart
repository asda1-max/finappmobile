import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/input_decorators.dart';
import '../core/services/session_service.dart';
import '../core/constants/api_constants.dart';
import '../data/auth_repository.dart';
import '../data/stock_repository.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/premium_alert_overlay.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepo = AuthRepository();
  final StockRepository _stockRepo = StockRepository();
  final ImagePicker _picker = ImagePicker();
  
  String _username = '';
  String _email = '';
  String? _profilePic;
  int? _prefStabilitas;
  int? _prefPertumbuhan;
  int? _prefDividen;
  int? _prefRisiko;
  bool _isLoading = false;

  Map<String, dynamic>? _recommendedPreset;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final username = await SessionService.getUsername();
    final email = await SessionService.getEmail();
    final profilePic = await SessionService.getProfilePic();
    var prefStabilitas = await SessionService.getPrefStabilitas();
    var prefPertumbuhan = await SessionService.getPrefPertumbuhan();
    var prefDividen = await SessionService.getPrefDividen();
    var prefRisiko = await SessionService.getPrefRisiko();

    if (prefStabilitas == null && prefPertumbuhan == null && prefDividen == null && prefRisiko == null) {
      try {
        final token = await SessionService.getToken();
        if (token != null) {
          final profile = await _authRepo.getProfile(token);
          prefStabilitas = profile.prefStabilitas;
          prefPertumbuhan = profile.prefPertumbuhan;
          prefDividen = profile.prefDividen;
          prefRisiko = profile.prefRisiko;
          await SessionService.saveSession(
            token: token,
            username: profile.username,
            email: profile.email,
            profilePic: profile.profilePic,
            prefStabilitas: prefStabilitas,
            prefPertumbuhan: prefPertumbuhan,
            prefDividen: prefDividen,
            prefRisiko: prefRisiko,
          );
        }
      } catch (_) {
        // ignore profile fetch errors
      }
    }
    
    if (mounted) {
      setState(() {
        _username = username ?? 'User';
        _email = email ?? '-';
        _profilePic = profilePic;
        _prefStabilitas = prefStabilitas;
        _prefPertumbuhan = prefPertumbuhan;
        _prefDividen = prefDividen;
        _prefRisiko = prefRisiko;
      });
      _fetchRecommendation();
    }
  }

  Future<void> _fetchRecommendation() async {
    if (_prefStabilitas != null || _prefRisiko != null) {
      try {
        final preset = await _authRepo.getHybridPreset(
          _prefStabilitas ?? 3, 
          _prefPertumbuhan ?? 3,
          _prefDividen ?? 3,
          _prefRisiko ?? 3
        );
        if (mounted) {
          setState(() {
            _recommendedPreset = preset;
          });
        }
      } catch (e) {
        // Silently fail if recommendation endpoint is not reachable
      }
    }
  }

  Future<void> _applyRecommendation() async {
    if (_recommendedPreset == null) return;
    
    setState(() => _isLoading = true);
    try {
      final token = await SessionService.getToken();
      if (token == null) throw Exception("No token");

      // We extract the actual preset data
      final Map<String, dynamic> useCagr = _recommendedPreset!['use_cagr'];
      final Map<String, dynamic> noCagr = _recommendedPreset!['no_cagr'];

      // We submit this to the hybrid config endpoint using existing repository
      await _stockRepo.saveHybridConfig(
        useCagrWeights: List<double>.from(useCagr['weights'].map((x) => x.toDouble())),
        useCagrRec: useCagr['recommended'].toDouble(),
        useCagrBuy: useCagr['buy'].toDouble(),
        useCagrRisk: useCagr['risk'].toDouble(),
        noCagrWeights: List<double>.from(noCagr['weights'].map((x) => x.toDouble())),
        noCagrRec: noCagr['recommended'].toDouble(),
        noCagrBuy: noCagr['buy'].toDouble(),
        noCagrRisk: noCagr['risk'].toDouble(),
      );

      if (mounted) {
        PremiumAlertOverlay.showStatus(
          context,
          title: 'Konfigurasi Diterapkan',
          message: 'Rekomendasi hybrid berhasil diaplikasikan',
          icon: Icons.check_circle_rounded,
          accentColor: AppColors.buyGreen,
        );
      }
    } catch (e) {
      if (mounted) {
        PremiumAlertOverlay.showStatus(
          context,
          title: 'Gagal',
          message: 'Tidak bisa menerapkan konfigurasi: $e',
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.sellRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      
      setState(() => _isLoading = true);
      
      final token = await SessionService.getToken();
      if (token == null) throw Exception("No token");
      
      final newUrl = await _authRepo.uploadProfilePicture(token, image.path);
      
      await SessionService.saveSession(
        token: token,
        username: _username,
        email: _email,
        profilePic: newUrl,
        prefStabilitas: _prefStabilitas,
        prefPertumbuhan: _prefPertumbuhan,
        prefDividen: _prefDividen,
        prefRisiko: _prefRisiko,
      );
      
      setState(() {
        _profilePic = newUrl;
        _isLoading = false;
      });
      
      if (mounted) {
        PremiumAlertOverlay.showStatus(
          context,
          title: 'Foto Profil Diperbarui',
          message: 'Upload berhasil!',
          icon: Icons.camera_alt_rounded,
          accentColor: AppColors.buyGreen,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        PremiumAlertOverlay.showStatus(
          context,
          title: 'Upload Gagal',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.sellRed,
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileModal(
        initialUsername: _username,
        initialEmail: _email,
        initialPrefStabilitas: _prefStabilitas,
        initialPrefPertumbuhan: _prefPertumbuhan,
        initialPrefDividen: _prefDividen,
        initialPrefRisiko: _prefRisiko,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final token = await SessionService.getToken();
        if (token == null) throw Exception("No token");
        
        final updatedUser = await _authRepo.updateProfile(
          token,
          username: result['username'],
          email: result['email'],
          password: result['password'],
          prefStabilitas: result['pref_stabilitas'],
          prefPertumbuhan: result['pref_pertumbuhan'],
          prefDividen: result['pref_dividen'],
          prefRisiko: result['pref_risiko'],
        );
        
        await SessionService.saveSession(
          token: (await SessionService.getToken())!,
          username: updatedUser.username,
          email: updatedUser.email,
          profilePic: _profilePic,
          prefStabilitas: updatedUser.prefStabilitas,
          prefPertumbuhan: updatedUser.prefPertumbuhan,
          prefDividen: updatedUser.prefDividen,
          prefRisiko: updatedUser.prefRisiko,
        );
        
        setState(() {
          _username = updatedUser.username;
          _email = updatedUser.email;
          _prefStabilitas = updatedUser.prefStabilitas;
          _prefPertumbuhan = updatedUser.prefPertumbuhan;
          _prefDividen = updatedUser.prefDividen;
          _prefRisiko = updatedUser.prefRisiko;
        });
        
        await _fetchRecommendation();
        
        if (mounted) {
          PremiumAlertOverlay.showStatus(
            context,
            title: 'Profil Diperbarui',
            message: 'Perubahan berhasil disimpan',
            icon: Icons.check_circle_rounded,
            accentColor: AppColors.buyGreen,
          );
        }
      } catch (e) {
        if (mounted) {
          String errMsg = e.toString();
          if (errMsg.contains('400')) {
            errMsg = 'Username or email may already be taken.';
          }
          PremiumAlertOverlay.showStatus(
            context,
            title: 'Update Gagal',
            message: errMsg,
            icon: Icons.error_outline_rounded,
            accentColor: AppColors.sellRed,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Memuat profil...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary),
                        onPressed: _editProfile,
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  GlassmorphicCard(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _uploadImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                backgroundImage: _profilePic != null
                                    ? NetworkImage('${ApiConstants.baseUrl}$_profilePic')
                                    : null,
                                child: _profilePic == null
                                    ? Text(
                                        _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 14, color: AppColors.textSecondary),
                              )
                            ],
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
                                child: Text(
                                  'Skala Risiko: ${_prefRisiko ?? 3}/5',
                                  style: const TextStyle(
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
                        _InfoRow(label: 'Stabilitas', value: '${_prefStabilitas ?? 3}/5'),
                        _InfoRow(label: 'Pertumbuhan', value: '${_prefPertumbuhan ?? 3}/5'),
                        _InfoRow(label: 'Dividen', value: '${_prefDividen ?? 3}/5'),
                        _InfoRow(label: 'Toleransi Risiko', value: '${_prefRisiko ?? 3}/5'),
                      ],
                    ),
                  ),
                  
                  if (_recommendedPreset != null) ...[
                    const SizedBox(height: 16),
                    GlassmorphicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Rekomendasi Konfigurasi Hybrid',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Berdasarkan skala preferensi Anda, sistem telah menghasilkan bobot MCDM yang optimal.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _applyRecommendation,
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Terapkan Konfigurasi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
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
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileModal extends StatefulWidget {
  final String initialUsername;
  final String initialEmail;
  final int? initialPrefStabilitas;
  final int? initialPrefPertumbuhan;
  final int? initialPrefDividen;
  final int? initialPrefRisiko;

  const _EditProfileModal({
    required this.initialUsername,
    required this.initialEmail,
    this.initialPrefStabilitas,
    this.initialPrefPertumbuhan,
    this.initialPrefDividen,
    this.initialPrefRisiko,
  });

  @override
  State<_EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<_EditProfileModal> {
  late TextEditingController _userCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passCtrl;
  
  late double _prefStabilitas;
  late double _prefPertumbuhan;
  late double _prefDividen;
  late double _prefRisiko;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController(text: widget.initialUsername);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _passCtrl = TextEditingController();
    
    _prefStabilitas = (widget.initialPrefStabilitas ?? 3).toDouble();
    _prefPertumbuhan = (widget.initialPrefPertumbuhan ?? 3).toDouble();
    _prefDividen = (widget.initialPrefDividen ?? 3).toDouble();
    _prefRisiko = (widget.initialPrefRisiko ?? 3).toDouble();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      margin: EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              _buildTextField('Username', _userCtrl, Icons.person_outline),
              const SizedBox(height: 16),
              
              _buildTextField('Email', _emailCtrl, Icons.email_outlined),
              const SizedBox(height: 16),
              
              _buildTextField('New Password (Optional)', _passCtrl, Icons.lock_outline, obscure: true),
              const SizedBox(height: 24),
              const Text('Preferensi Investasi (Skala 1-5)', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              _buildSliderRow('Stabilitas', _prefStabilitas, (val) => setState(() => _prefStabilitas = val)),
              _buildSliderRow('Pertumbuhan', _prefPertumbuhan, (val) => setState(() => _prefPertumbuhan = val)),
              _buildSliderRow('Dividen', _prefDividen, (val) => setState(() => _prefDividen = val)),
              _buildSliderRow('Toleransi Risiko', _prefRisiko, (val) => setState(() => _prefRisiko = val)),
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.textTertiary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'username': _userCtrl.text.isNotEmpty ? _userCtrl.text : null,
                          'email': _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
                          'password': _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
                          'pref_stabilitas': _prefStabilitas.toInt(),
                          'pref_pertumbuhan': _prefPertumbuhan.toInt(),
                          'pref_dividen': _prefDividen.toInt(),
                          'pref_risiko': _prefRisiko.toInt(),
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: AppInputDecoration.standard(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            Text('${value.toInt()}', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.cardBorder,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
            valueIndicatorTextStyle: const TextStyle(color: Colors.white),
          ),
          child: Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: value.toInt().toString(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

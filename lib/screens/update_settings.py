import re

with open("settings_screen.dart", "r") as f:
    content = f.read()

# Add imports
imports_add = """import '../core/theme/app_colors.dart';
import '../core/services/session_service.dart';
import '../data/auth_repository.dart';"""
content = content.replace("import '../core/theme/app_colors.dart';", imports_add)

# Add variables
vars_old = """
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _repo = StockRepository();
  bool _loading = true;
  String? _statusMsg;
"""
vars_new = """
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _repo = StockRepository();
  final _authRepo = AuthRepository();
  bool _loading = true;
  String? _statusMsg;
  Map<String, dynamic>? _profilePreset;
  String? _portfolioGoals;
  String? _minat;
"""
content = content.replace(vars_old, vars_new)

# Update initState
init_old = """
  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadAlertPrefs();
  }
"""
init_new = """
  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadAlertPrefs();
    _loadProfilePreset();
  }
  
  Future<void> _loadProfilePreset() async {
    final goals = await SessionService.getPortfolioGoals();
    final minat = await SessionService.getMinat();
    if (goals != null || minat != null) {
      setState(() {
        _portfolioGoals = goals;
        _minat = minat;
      });
      try {
        final preset = await _authRepo.getHybridPreset(goals ?? '', minat ?? '');
        setState(() {
          _profilePreset = preset;
        });
      } catch (e) {
        // silently fail
      }
    }
  }

  void _applyProfilePreset() {
    if (_profilePreset == null) return;
    final useCagr = _profilePreset!['use_cagr'];
    final noCagr = _profilePreset!['no_cagr'];
    
    _useCagrWeights.setAll(0, List<double>.from(useCagr['weights'].map((x) => x.toDouble())));
    _useCagrRec = useCagr['recommended'].toDouble();
    _useCagrBuy = useCagr['buy'].toDouble();
    _useCagrRisk = useCagr['risk'].toDouble();
    
    _noCagrWeights.setAll(0, List<double>.from(noCagr['weights'].map((x) => x.toDouble())));
    _noCagrRec = noCagr['recommended'].toDouble();
    _noCagrBuy = noCagr['buy'].toDouble();
    _noCagrRisk = noCagr['risk'].toDouble();
    
    setState(() => _statusMsg = 'Profile Preset applied');
  }
"""
content = content.replace(init_old, init_new)

# Update build to add button
chips_old = """
                _PresetChip(
                  label: '🚀 Growth Aggressive',
                  color: AppColors.sellRed,
                  onTap: () => _applyPreset('growth'),
                ),
              ],
"""
chips_new = """
                _PresetChip(
                  label: '🚀 Growth Aggressive',
                  color: AppColors.sellRed,
                  onTap: () => _applyPreset('growth'),
                ),
                if (_profilePreset != null)
                  _PresetChip(
                    label: '✨ Profile Preset',
                    color: AppColors.primary,
                    onTap: _applyProfilePreset,
                  ),
              ],
"""
content = content.replace(chips_old, chips_new)

with open("settings_screen.dart", "w") as f:
    f.write(content)


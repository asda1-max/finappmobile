import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glassmorphic_card.dart';

/// Data class for a financial branch location.
class BranchLocation {
  final String name;
  final String type; // 'bank' or 'sekuritas'
  final String institution;
  final double lat;
  final double lng;
  final String address;
  final String city;

  const BranchLocation({
    required this.name,
    required this.type,
    required this.institution,
    required this.lat,
    required this.lng,
    required this.address,
    required this.city,
  });

  IconData get icon =>
      type == 'bank' ? Icons.account_balance : Icons.bar_chart;
  Color get color => type == 'bank' ? AppColors.primary : AppColors.buyGreen;
}

/// Curated list of major bank & sekuritas branches in Indonesia.
const List<BranchLocation> _allBranches = [
  // ── Jakarta ──
  BranchLocation(
      name: 'BCA KCU Wisma BCA',
      type: 'bank', institution: 'BCA',
      lat: -6.1753, lng: 106.8272,
      address: 'Jl. Jend. Sudirman Kav. 22-23', city: 'Jakarta'),
  BranchLocation(
      name: 'Bank Mandiri Kantor Pusat',
      type: 'bank', institution: 'Mandiri',
      lat: -6.2146, lng: 106.8451,
      address: 'Jl. Jend. Gatot Subroto Kav. 36-38', city: 'Jakarta'),
  BranchLocation(
      name: 'BRI Kantor Pusat',
      type: 'bank', institution: 'BRI',
      lat: -6.2200, lng: 106.8437,
      address: 'Gedung BRI 1, Jl. Jend. Sudirman Kav. 44-46', city: 'Jakarta'),
  BranchLocation(
      name: 'BNI Kantor Pusat',
      type: 'bank', institution: 'BNI',
      lat: -6.2250, lng: 106.8455,
      address: 'Jl. Jend. Sudirman Kav. 1', city: 'Jakarta'),
  BranchLocation(
      name: 'BCA KCP Kelapa Gading',
      type: 'bank', institution: 'BCA',
      lat: -6.1594, lng: 106.9080,
      address: 'Mall Kelapa Gading', city: 'Jakarta'),
  BranchLocation(
      name: 'Mirae Asset Sekuritas Jakarta',
      type: 'sekuritas', institution: 'Mirae Asset',
      lat: -6.2242, lng: 106.8487,
      address: 'Treasury Tower Lt. 50, SCBD', city: 'Jakarta'),
  BranchLocation(
      name: 'Indo Premier Sekuritas',
      type: 'sekuritas', institution: 'Indo Premier',
      lat: -6.2130, lng: 106.8133,
      address: 'Wisma GKBI Lt. 7', city: 'Jakarta'),
  BranchLocation(
      name: 'Mandiri Sekuritas',
      type: 'sekuritas', institution: 'Mandiri Sekuritas',
      lat: -6.2146, lng: 106.8451,
      address: 'Gedung Mandiri Lt. 4', city: 'Jakarta'),
  BranchLocation(
      name: 'BNI Sekuritas',
      type: 'sekuritas', institution: 'BNI Sekuritas',
      lat: -6.2250, lng: 106.8460,
      address: 'Gedung BNI Lt. 25', city: 'Jakarta'),
  BranchLocation(
      name: 'IDX (Bursa Efek Indonesia)',
      type: 'sekuritas', institution: 'IDX',
      lat: -6.2200, lng: 106.8098,
      address: 'Jl. Jend. Sudirman Kav. 52-53', city: 'Jakarta'),

  // ── Surabaya ──
  BranchLocation(
      name: 'BCA KCU Surabaya',
      type: 'bank', institution: 'BCA',
      lat: -7.2575, lng: 112.7521,
      address: 'Jl. Pemuda No. 27-31', city: 'Surabaya'),
  BranchLocation(
      name: 'Bank Mandiri Surabaya',
      type: 'bank', institution: 'Mandiri',
      lat: -7.2621, lng: 112.7502,
      address: 'Jl. Basuki Rahmat No. 129', city: 'Surabaya'),
  BranchLocation(
      name: 'BRI Surabaya Rajawali',
      type: 'bank', institution: 'BRI',
      lat: -7.2331, lng: 112.7379,
      address: 'Jl. Rajawali No. 26', city: 'Surabaya'),
  BranchLocation(
      name: 'Mirae Asset Surabaya',
      type: 'sekuritas', institution: 'Mirae Asset',
      lat: -7.2615, lng: 112.7415,
      address: 'Jl. Embong Malang No. 7', city: 'Surabaya'),

  // ── Bandung ──
  BranchLocation(
      name: 'BCA KCU Bandung',
      type: 'bank', institution: 'BCA',
      lat: -6.9175, lng: 107.6191,
      address: 'Jl. Asia Afrika No. 140', city: 'Bandung'),
  BranchLocation(
      name: 'Bank Mandiri Bandung',
      type: 'bank', institution: 'Mandiri',
      lat: -6.9218, lng: 107.6060,
      address: 'Jl. R.E. Martadinata No. 152', city: 'Bandung'),
  BranchLocation(
      name: 'BRI Bandung',
      type: 'bank', institution: 'BRI',
      lat: -6.9147, lng: 107.6098,
      address: 'Jl. Asia Afrika No. 57', city: 'Bandung'),

  // ── Medan ──
  BranchLocation(
      name: 'BCA KCU Medan',
      type: 'bank', institution: 'BCA',
      lat: 3.5952, lng: 98.6722,
      address: 'Jl. Diponegoro No. 18', city: 'Medan'),
  BranchLocation(
      name: 'Bank Mandiri Medan',
      type: 'bank', institution: 'Mandiri',
      lat: 3.5905, lng: 98.6781,
      address: 'Jl. Pulau Pinang No. 1', city: 'Medan'),

  // ── Semarang ──
  BranchLocation(
      name: 'BCA KCU Semarang',
      type: 'bank', institution: 'BCA',
      lat: -6.9932, lng: 110.4203,
      address: 'Jl. Pemuda No. 90', city: 'Semarang'),
  BranchLocation(
      name: 'BRI Semarang',
      type: 'bank', institution: 'BRI',
      lat: -6.9847, lng: 110.4093,
      address: 'Jl. Jend. Sudirman No. 5', city: 'Semarang'),

  // ── Yogyakarta ──
  BranchLocation(
      name: 'BCA KCU Yogyakarta',
      type: 'bank', institution: 'BCA',
      lat: -7.7886, lng: 110.3655,
      address: 'Jl. Jend. Sudirman No. 31', city: 'Yogyakarta'),
  BranchLocation(
      name: 'Bank Mandiri Yogyakarta',
      type: 'bank', institution: 'Mandiri',
      lat: -7.7912, lng: 110.3649,
      address: 'Jl. Jend. Sudirman No. 7', city: 'Yogyakarta'),

  // ── Makassar ──
  BranchLocation(
      name: 'BCA KCU Makassar',
      type: 'bank', institution: 'BCA',
      lat: -5.1374, lng: 119.4079,
      address: 'Jl. Ahmad Yani No. 8', city: 'Makassar'),

  // ── Bali ──
  BranchLocation(
      name: 'BCA KCU Denpasar',
      type: 'bank', institution: 'BCA',
      lat: -8.6557, lng: 115.2197,
      address: 'Jl. Hasanuddin No. 58', city: 'Denpasar'),
];

/// Nearby financial institutions screen using Location Based Service.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // 'all', 'bank', 'sekuritas'
  BranchLocation? _selectedBranch;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled';
          _loading = false;
          // Default to Jakarta
          _currentPosition = const LatLng(-6.2088, 106.8456);
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permission denied';
            _loading = false;
            _currentPosition = const LatLng(-6.2088, 106.8456);
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permissions permanently denied';
          _loading = false;
          _currentPosition = const LatLng(-6.2088, 106.8456);
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not get location: $e';
        _loading = false;
        _currentPosition = const LatLng(-6.2088, 106.8456);
      });
    }
  }

  List<BranchLocation> get _filteredBranches {
    if (_filter == 'all') return _allBranches;
    return _allBranches.where((b) => b.type == _filter).toList();
  }

  double _distanceKm(BranchLocation branch) {
    if (_currentPosition == null) return 0;
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      _currentPosition!,
      LatLng(branch.lat, branch.lng),
    );
  }

  List<BranchLocation> get _sortedByDistance {
    final branches = List<BranchLocation>.from(_filteredBranches);
    if (_currentPosition != null) {
      branches.sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));
    }
    return branches;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: const Text(
                          'Nearby',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find bank & sekuritas branches near you',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '🏦 Banks',
                    selected: _filter == 'bank',
                    onTap: () => setState(() => _filter = 'bank'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '📊 Sekuritas',
                    selected: _filter == 'sekuritas',
                    onTap: () => setState(() => _filter = 'sekuritas'),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.my_location,
                        color: AppColors.primary, size: 20),
                    onPressed: () {
                      if (_currentPosition != null) {
                        _mapController.move(_currentPosition!, 13);
                      }
                    },
                  ),
                ],
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.holdAmberBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_rounded,
                          size: 14, color: AppColors.holdAmber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.holdAmberLight)),
                      ),
                    ],
                  ),
                ),
              ),

            // Map
            Expanded(
              flex: 3,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentPosition ??
                                const LatLng(-6.2088, 106.8456),
                            initialZoom: 12,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.finappmobile',
                            ),
                            MarkerLayer(
                              markers: [
                                // Current location marker
                                if (_currentPosition != null)
                                  Marker(
                                    point: _currentPosition!,
                                    width: 24,
                                    height: 24,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white,
                                            width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Branch markers
                                ..._filteredBranches.map((branch) =>
                                    Marker(
                                      point: LatLng(
                                          branch.lat, branch.lng),
                                      width: 36,
                                      height: 36,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedBranch =
                                                branch),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: branch.color,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: branch.color
                                                    .withValues(
                                                        alpha: 0.3),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Icon(branch.icon,
                                              color: Colors.white,
                                              size: 18),
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Selected branch info
            if (_selectedBranch != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GlassmorphicCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedBranch!.color
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_selectedBranch!.icon,
                            color: _selectedBranch!.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedBranch!.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _selectedBranch!.address,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_distanceKm(_selectedBranch!).toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                          Text(
                            _selectedBranch!.city,
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Nearest branches list
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ListView.builder(
                  itemCount: min(_sortedByDistance.length, 10),
                  itemBuilder: (context, index) {
                    final branch = _sortedByDistance[index];
                    final dist = _distanceKm(branch);
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedBranch = branch);
                        _mapController.move(
                            LatLng(branch.lat, branch.lng), 15);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedBranch == branch
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(branch.icon,
                                color: branch.color, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    branch.name,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    branch.institution,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${dist.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

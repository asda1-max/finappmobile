import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/input_decorators.dart';
import '../widgets/glassmorphic_card.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<_GlossaryItem> _items = const [
    _GlossaryItem(
      term: 'PBV',
      fullName: 'Price to Book Value',
      description:
          'Rasio harga pasar terhadap nilai buku saham. Makin kecil biasanya makin murah, tapi tetap harus lihat sektor dan kualitas bisnis.',
    ),
    _GlossaryItem(
      term: 'PER',
      fullName: 'Price Earning Ratio',
      description:
          'Rasio harga saham terhadap laba per saham. Dipakai untuk melihat apakah saham tergolong mahal atau murah berdasarkan laba.',
    ),
    _GlossaryItem(
      term: 'ROE',
      fullName: 'Return on Equity',
      description:
          'Mengukur kemampuan perusahaan menghasilkan laba dari modal pemegang saham. Semakin tinggi biasanya semakin efisien.',
    ),
    _GlossaryItem(
      term: 'EPS',
      fullName: 'Earnings Per Share',
      description:
          'Laba bersih yang dihasilkan per lembar saham. EPS yang tumbuh stabil biasanya menandakan bisnis yang sehat.',
    ),
    _GlossaryItem(
      term: 'CAGR',
      fullName: 'Compound Annual Growth Rate',
      description:
          'Tingkat pertumbuhan rata-rata per tahun dalam periode tertentu. Dipakai untuk melihat tren pertumbuhan jangka panjang.',
    ),
    _GlossaryItem(
      term: 'MOS',
      fullName: 'Margin of Safety',
      description:
          'Selisih antara harga wajar dan harga pasar. MOS positif biasanya menandakan ada ruang aman untuk beli.',
    ),
    _GlossaryItem(
      term: 'Dividend Yield',
      fullName: 'Imbal Hasil Dividen',
      description:
          'Persentase dividen tahunan dibanding harga saham saat ini. Berguna untuk investor yang mengejar pendapatan pasif.',
    ),
    _GlossaryItem(
      term: 'Debt to Equity',
      fullName: 'Rasio Utang terhadap Ekuitas',
      description:
          'Mengukur seberapa besar utang perusahaan dibanding modal sendiri. Semakin kecil biasanya semakin aman, kecuali sektor tertentu seperti bank.',
    ),
    _GlossaryItem(
      term: 'Current Ratio',
      fullName: 'Rasio Lancar',
      description:
          'Mengukur kemampuan perusahaan membayar kewajiban jangka pendek dengan aset lancarnya.',
    ),
    _GlossaryItem(
      term: 'Market Cap',
      fullName: 'Market Capitalization',
      description:
          'Nilai total perusahaan di pasar saham. Biasanya dipakai untuk membedakan saham big cap, mid cap, dan small cap.',
    ),
    _GlossaryItem(
      term: 'Free Cashflow',
      fullName: 'Arus Kas Bebas',
      description:
          'Uang kas yang tersisa setelah perusahaan membayar kebutuhan operasional dan belanja modal. Positif sering dianggap bagus.',
    ),
    _GlossaryItem(
      term: 'Graham Number',
      fullName: 'Nilai Wajar ala Graham',
      description:
          'Estimasi harga wajar sederhana berdasarkan EPS dan book value. Dipakai untuk melihat apakah saham undervalued.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((item) {
      if (query.isEmpty) return true;
      return item.term.toLowerCase().contains(query) ||
          item.fullName.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Glossary Saham',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Daftar istilah saham penting yang bisa dicek cepat.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: AppInputDecoration.search(
                hintText: 'Cari istilah seperti PBV, PER, ROE...',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            ...filtered.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item.term,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.fullName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Istilah tidak ditemukan.',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlossaryItem {
  final String term;
  final String fullName;
  final String description;

  const _GlossaryItem({
    required this.term,
    required this.fullName,
    required this.description,
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../products/data/models/company.dart';
import '../../application/kasa_provider.dart';
import '../../data/models/kasa_entry.dart';
import '../../data/models/kasa_expense_category.dart';
import '../../data/models/kasa_opening_balance.dart';
import '../../data/repositories/kasa_reconciliation_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Kasa (gelir-gider defteri) ekranı — KARAR v1.9
//
// Yerleşim: hero-önderli TEK kolon (iki-sütun defter/spreadsheet YASAK).
//   1. Hero: birikimli yıl kasası (₺) + altın ray. Altında seçili günün
//      Nakit+POS kırılımı + açılış = sakin destek (ray YOK).
//   2. Tarih seçici (bugün default) + yıl göstergesi (yıl bazlı defter).
//   3. Gelir / Gider sekmeleri.
//   4. Gelir: 4 gün-sonu alanı (Nakit · İş Bankası POS · Akbank POS · Garanti
//      POS). Kaydet → kasa_entries'e yaz + kanal başına mutabakat rozeti.
//   5. Gider: kategori + tutar + not + firma autocomplete; gün içi çok kalem.
//   6. Açılış bakiyesi: mütevazı bölüm.
// ═══════════════════════════════════════════════════════════════════════════

// ── Sayısal giriş yardımcısı ────────────────────────────────────────────────
// Virgül ve nokta ondalık ayıracını kabul eder (ürün formu deseni). Boş / geçersiz
// giriş 0 döner.
num _parseAmount(String raw) {
  final s = raw.trim().replaceAll(',', '.');
  if (s.isEmpty) return 0;
  return num.tryParse(s) ?? 0;
}

// Sadece tarih (saat yok) — entry_date date türüyle ve provider eşitliğiyle uyumlu.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// POS bankaları: (alan etiketi, kasa_entries.note anahtarı). POS tabanı = 3'ünün
// toplamı. Her banka ayrı kasa_entries kalemi olarak (channel='pos', note=anahtar)
// saklanır; böylece banka kırılımı korunur ve cumulativeIncome Σ tutarlı kalır.
const List<(String, String)> _posBanks = [
  ('İş Bankası POS', 'İş Bankası'),
  ('Akbank POS', 'Akbank'),
  ('Garanti POS', 'Garanti'),
];

/// Kasa ekranı üst sekmeleri: Gelir · Gider · Firma Giderleri (yıl bazlı rapor).
enum _KasaTab { gelir, gider, firmaGiderleri }

class KasaScreen extends ConsumerStatefulWidget {
  const KasaScreen({super.key});

  @override
  ConsumerState<KasaScreen> createState() => _KasaScreenState();
}

class _KasaScreenState extends ConsumerState<KasaScreen> {
  DateTime _date = _dateOnly(DateTime.now());
  _KasaTab _tab = _KasaTab.gelir;

  int get _fiscalYear => _date.year;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2021),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() => _date = _dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobil = context.isMobile;

    final icerik = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Başlık ────────────────────────────────────────────────────────
        const Text(
          'Kasa Defteri',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSizes.space16),

        // ── İmza: Hero (birikimli yıl kasası) + günlük kırılım destek ────
        _KasaHero(date: _date, fiscalYear: _fiscalYear),
        const SizedBox(height: AppSizes.space16),

        // ── Tarih seçici + yıl göstergesi ─────────────────────────────────
        _TarihSeciciSatiri(
          date: _date,
          fiscalYear: _fiscalYear,
          onPick: _pickDate,
        ),
        const SizedBox(height: AppSizes.space16),

        // ── Gelir / Gider / Firma Giderleri sekmeleri ─────────────────────
        // Responsive (QA v1.9.5): mobilde kısa etiket "Firmalar" + ikonsuz
        // segmentler → 360px'e kesilmeden sığar; masaüstünde ikonlu tam
        // etiket "Firma Giderleri" ama tek satır (softWrap kapalı — segment
        // içinde 2 satıra kırılmasın). Yatay scroll sarmalı ek güvence.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_KasaTab>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _KasaTab.gelir,
                label: const Text(
                  'Gelir',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
                icon: mobil ? null : const Icon(Icons.south_west, size: 18),
              ),
              ButtonSegment(
                value: _KasaTab.gider,
                label: const Text(
                  'Gider',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
                icon: mobil ? null : const Icon(Icons.north_east, size: 18),
              ),
              ButtonSegment(
                value: _KasaTab.firmaGiderleri,
                label: Text(
                  mobil ? 'Firmalar' : 'Firma Giderleri',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
                icon: mobil
                    ? null
                    : const Icon(Icons.storefront_outlined, size: 18),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: AppSizes.space16),

        // ── Seçili sekme içeriği ──────────────────────────────────────────
        if (_tab == _KasaTab.gelir)
          _GelirSekmesi(
            key: ValueKey('gelir-$_date'),
            date: _date,
            fiscalYear: _fiscalYear,
          )
        else if (_tab == _KasaTab.gider)
          _GiderSekmesi(
            key: ValueKey('gider-$_date'),
            date: _date,
            fiscalYear: _fiscalYear,
          )
        else
          _FirmaGiderleriSekmesi(fiscalYear: _fiscalYear),
        const SizedBox(height: AppSizes.space24),

        // ── Açılış bakiyesi (mütevazı bölüm) ──────────────────────────────
        _AcilisBakiyesiBolumu(fiscalYear: _fiscalYear),
        const SizedBox(height: AppSizes.space24),
      ],
    );

    // Masaüstünde ferah tek kolon (ortalanmış, sınırlı genişlik); mobilde tam
    // genişlik.
    if (mobil) {
      return SingleChildScrollView(child: icerik);
    }
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (ctx, c) => Center(
          child: SizedBox(
            width: c.maxWidth < 760 ? c.maxWidth : 760,
            child: icerik,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hero — birikimli yıl kasası (₺) + altın ray (§4). Altında seçili günün
// Nakit+POS kırılımı + açılış = sakin destek (type.body tabular, ray YOK).
// ═══════════════════════════════════════════════════════════════════════════

class _KasaHero extends ConsumerWidget {
  final DateTime date;
  final int fiscalYear;

  const _KasaHero({required this.date, required this.fiscalYear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobil = context.isMobile;
    final ozetAsync = ref.watch(
      kasaCumulativeSummaryProvider(
        KasaSummaryQuery(fiscalYear: fiscalYear, uptoDate: date),
      ),
    );
    final gunAsync = ref.watch(
      kasaDailyChannelIncomeProvider(
        KasaDailyQuery(fiscalYear: fiscalYear, date: date),
      ),
    );
    final acilisAsync = ref.watch(kasaOpeningBalanceProvider(fiscalYear));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space20,
        vertical: AppSizes.space20,
      ),
      // Hero yüzeyi KENARLIKSIZ (§5 hero istisnası): beyaz zemin + yumuşak gölge.
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppSizes.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İki başlık: SOLA hizalı Kasa Birikimi · SAĞA hizalı İşletme Giderleri.
          Row(
            children: [
              Expanded(
                child: Text(
                  '$fiscalYear YILI KASA BİRİKİMİ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: Text(
                  '$fiscalYear YILI İŞLETME GİDERLERİ',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space8),
          // SOL: kasa birikimi hero + altın ray · SAĞ: işletme giderleri (kırmızı, − öneki, ray YOK).
          ozetAsync.when(
            loading: () => const SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, s) => Text(
              '—',
              style: TextStyle(
                fontSize: mobil ? 30 : 38,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
            data: (ozet) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SOL: kasa birikimi (hero) + altın ray.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatCurrency(ozet.income),
                          style: TextStyle(
                            fontSize: mobil ? 30 : 38,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: -0.5,
                            color: AppColors.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.space6),
                      // Altın aksan rayı — yalnız kasa birikimi (hero) altında (~%40).
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.4,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusPill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                // SAĞ: işletme giderleri — kırmızı + eksi öneki, ray YOK.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '−${formatCurrency(ozet.expense)}',
                          style: TextStyle(
                            fontSize: mobil ? 30 : 38,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: -0.5,
                            color: AppColors.danger,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.space16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSizes.space12),
          // Seçili günün kırılımı + açılış — sakin destek (ray YOK).
          Text(
            '${formatShortDate(date)} — Gün Kırılımı',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSizes.space8),
          Wrap(
            spacing: AppSizes.space20,
            runSpacing: AppSizes.space12,
            children: [
              _DestekMetrik(
                etiket: 'Nakit',
                deger: gunAsync.valueOrNull?.nakit,
                renk: AppColors.cash,
              ),
              _DestekMetrik(
                etiket: 'POS',
                deger: gunAsync.valueOrNull?.pos,
                renk: AppColors.pos,
              ),
              _DestekMetrik(
                etiket: 'Yıl Açılışı',
                deger: acilisAsync.valueOrNull?.openingIncome ?? 0,
                renk: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hero altındaki sakin destek metriği: küçük renk noktası + etiket + tabular
/// tutar. Ray/vurgu yok.
class _DestekMetrik extends StatelessWidget {
  final String etiket;
  final num? deger;
  final Color renk;

  const _DestekMetrik({
    required this.etiket,
    required this.deger,
    required this.renk,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSizes.space6),
            Text(
              etiket,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space4),
        Text(
          deger == null ? '—' : formatCurrency(deger!),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tarih seçici + yıl göstergesi
// ═══════════════════════════════════════════════════════════════════════════

class _TarihSeciciSatiri extends StatelessWidget {
  final DateTime date;
  final int fiscalYear;
  final VoidCallback onPick;

  const _TarihSeciciSatiri({
    required this.date,
    required this.fiscalYear,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                formatDate(date),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.goldBorder),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space12,
              ),
              minimumSize: const Size(0, 48),
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.space12),
        // Yıl göstergesi (yıl bazlı defter).
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space16,
            vertical: AppSizes.space12,
          ),
          decoration: BoxDecoration(
            color: AppColors.goldBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_note, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSizes.space6),
              Text(
                'Mali Yıl $fiscalYear',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GELİR SEKMESİ — 4 gün-sonu alanı + kaydet + kanal başına mutabakat rozeti
// ═══════════════════════════════════════════════════════════════════════════

class _GelirSekmesi extends ConsumerStatefulWidget {
  final DateTime date;
  final int fiscalYear;

  const _GelirSekmesi({
    super.key,
    required this.date,
    required this.fiscalYear,
  });

  @override
  ConsumerState<_GelirSekmesi> createState() => _GelirSekmesiState();
}

class _GelirSekmesiState extends ConsumerState<_GelirSekmesi> {
  final _nakitCtrl = TextEditingController();
  late final List<TextEditingController> _bankCtrls =
      List.generate(_posBanks.length, (_) => TextEditingController());

  bool _yukleniyor = true;
  bool _kaydediyor = false;

  // Kaydetten sonra kanal başına mutabakat sonuçları.
  KasaReconcileResult? _nakitRecon;
  KasaReconcileResult? _posRecon;

  @override
  void initState() {
    super.initState();
    _mevcutGunuYukle();
  }

  @override
  void dispose() {
    _nakitCtrl.dispose();
    for (final c in _bankCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // Seçili günün mevcut gelir kalemlerini alanlara doldurur (gün düzenleme).
  Future<void> _mevcutGunuYukle() async {
    try {
      final entries = await ref.read(kasaRepositoryProvider).fetchEntries(
            fiscalYear: widget.fiscalYear,
            date: widget.date,
            direction: 'gelir',
          );
      if (!mounted) return;
      num nakit = 0;
      final bankTutar = List<num>.filled(_posBanks.length, 0);
      for (final e in entries) {
        if (e.channel == KasaChannel.nakit) {
          nakit += e.amount;
        } else if (e.channel == KasaChannel.pos) {
          final idx = _posBanks.indexWhere((b) => b.$2 == e.note);
          if (idx >= 0) {
            bankTutar[idx] += e.amount;
          } else {
            // Not eşleşmeyen (tek POS kalemi / eski kayıt) → ilk bankaya topla.
            bankTutar[0] += e.amount;
          }
        }
      }
      if (nakit > 0) _nakitCtrl.text = _tutarYaz(nakit);
      for (var i = 0; i < _posBanks.length; i++) {
        if (bankTutar[i] > 0) _bankCtrls[i].text = _tutarYaz(bankTutar[i]);
      }
      setState(() => _yukleniyor = false);
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // Alan içi düz gösterim (binlik ayraç yok — düzenlemeyi bozmamak için).
  String _tutarYaz(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  num get _posToplam =>
      _bankCtrls.fold<num>(0, (t, c) => t + _parseAmount(c.text));

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    final repo = ref.read(kasaRepositoryProvider);
    final recon = ref.read(kasaReconciliationServiceProvider);
    final nakit = _parseAmount(_nakitCtrl.text);
    final posToplam = _posToplam;

    try {
      // 1. Günün mevcut gelir kalemlerini temizle (çift kayıt olmasın).
      final mevcut = await repo.fetchEntries(
        fiscalYear: widget.fiscalYear,
        date: widget.date,
        direction: 'gelir',
      );
      for (final e in mevcut) {
        await repo.deleteEntry(e.id);
      }

      // 2. Nakit tek kalem (channel=nakit). 0 ise kalem yazılmaz.
      if (nakit > 0) {
        await repo.addEntry(KasaEntry(
          entryDate: widget.date,
          fiscalYear: widget.fiscalYear,
          direction: KasaDirection.gelir,
          channel: KasaChannel.nakit,
          amount: nakit,
        ));
      }

      // 3. POS için 3 banka AYRI kalem (channel=pos, note=banka adı). Banka
      //    kırılımı korunur; cumulativeIncome Σ ve dailyChannelIncome(pos)
      //    tutarlı kalır.
      for (var i = 0; i < _posBanks.length; i++) {
        final tutar = _parseAmount(_bankCtrls[i].text);
        if (tutar > 0) {
          await repo.addEntry(KasaEntry(
            entryDate: widget.date,
            fiscalYear: widget.fiscalYear,
            direction: KasaDirection.gelir,
            channel: KasaChannel.pos,
            amount: tutar,
            note: _posBanks[i].$2,
          ));
        }
      }

      // 4. Kanal başına mutabakat (Nakit alanı → nakit; 3 POS toplamı → pos).
      final nakitRes = await recon.reconcile(
        fiscalYear: widget.fiscalYear,
        date: widget.date,
        channel: KasaChannel.nakit,
        expectedAmount: nakit,
      );
      final posRes = await recon.reconcile(
        fiscalYear: widget.fiscalYear,
        date: widget.date,
        channel: KasaChannel.pos,
        expectedAmount: posToplam,
      );

      if (!mounted) return;
      setState(() {
        _nakitRecon = nakitRes;
        _posRecon = posRes;
        _kaydediyor = false;
      });

      // Hero + günlük kırılım + kalem listelerini yenile.
      ref.invalidate(kasaCumulativeSummaryProvider);
      ref.invalidate(kasaDailyChannelIncomeProvider);
      ref.invalidate(kasaEntriesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gün geliri kaydedildi ve mutabakat yapıldı.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _kaydediyor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Padding(
        padding: EdgeInsets.all(AppSizes.space24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: AppSizes.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gün Sonu Gelir Girişi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.space4),
          const Text(
            'Nakit ve banka POS gün-sonu değerlerini girin. Kaydet, sistem tabanıyla mutabakat yapar.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSizes.space16),

          // Nakit alanı — sol yeşil şerit.
          _KanalGelirAlani(
            controller: _nakitCtrl,
            etiket: 'Nakit',
            seritRenk: AppColors.cash,
            recon: _nakitRecon,
          ),
          const SizedBox(height: AppSizes.space12),

          // 3 POS bankası — sol POS mavisi şerit.
          for (var i = 0; i < _posBanks.length; i++) ...[
            _KanalGelirAlani(
              controller: _bankCtrls[i],
              etiket: _posBanks[i].$1,
              seritRenk: AppColors.pos,
              // POS mutabakat rozeti sadece son (3.) bankanın altında bir kez —
              // taban 3 bankanın TOPLAMI olduğundan tek yerde gösterilir.
              // Kapsam öneki ("POS toplamı"), farkın tek bankaya değil 3 banka
              // toplamına ait olduğunu netleştirir.
              recon: i == _posBanks.length - 1 ? _posRecon : null,
              reconKapsam: 'POS toplamı',
            ),
            const SizedBox(height: AppSizes.space12),
          ],

          const SizedBox(height: AppSizes.space4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _kaydediyor ? null : _kaydet,
              icon: _kaydediyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_kaydediyor ? 'Kaydediliyor…' : 'Kaydet ve Mutabakat Yap'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek kanal gün-sonu gelir alanı: sol renk şeridi + etiket + tabular giriş.
/// Dolu renk zemin YOK (§5 — kanal duvarı olmaz); kimlik ince şeritle taşınır.
/// Altında (varsa) mutabakat rozeti.
class _KanalGelirAlani extends StatelessWidget {
  final TextEditingController controller;
  final String etiket;
  final Color seritRenk;
  final KasaReconcileResult? recon;

  /// Rozet kapsam öneki (ör. 'POS toplamı') — sistem tabanı birden çok alanın
  /// toplamıysa farkın tek alana ait olmadığını belirtir. Tek kanallı alanda
  /// (Nakit) null bırakılır.
  final String? reconKapsam;

  const _KanalGelirAlani({
    required this.controller,
    required this.etiket,
    required this.seritRenk,
    this.recon,
    this.reconKapsam,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              // Sol renk şeridi (ince kanal kimliği).
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: seritRenk,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              SizedBox(
                width: 130,
                child: Text(
                  etiket,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    prefixText: '₺ ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.space12,
                      vertical: AppSizes.space12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (recon != null)
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              top: AppSizes.space8,
            ),
            child: _MutabakatRozeti(recon: recon!, kapsam: reconKapsam),
          ),
      ],
    );
  }
}

/// Mutabakat rozeti: sistem tabanı vs beyan edilen → fark. Semantik renk
/// (+düzeltme success/nötr, −düzeltme danger). ALTIN DEĞİL (§5 — imza rayı
/// yalnız hero'ya ait). "Fiyat güncellendi" pill diliyle aynı satır-içi geri
/// bildirim.
class _MutabakatRozeti extends StatelessWidget {
  final KasaReconcileResult recon;

  /// Kapsam öneki (ör. 'POS toplamı') — sistem tabanı birden çok alanın
  /// (İş + Akbank + Garanti) toplamı olduğunda farkın tek alana ait
  /// olmadığını netleştirir. Null ise önek basılmaz (Nakit tek kanal).
  final String? kapsam;

  const _MutabakatRozeti({required this.recon, this.kapsam});

  @override
  Widget build(BuildContext context) {
    final fark = recon.adjustmentAmount;
    final Color renk;
    final IconData ikon;
    final String metin;
    if (fark == 0) {
      renk = AppColors.success;
      ikon = Icons.check_circle_outline;
      metin = 'Mutabık — sistem ${formatCurrency(recon.systemBase)}';
    } else if (fark > 0) {
      // +düzeltme = ek gelir. Nötr/olumlu.
      renk = AppColors.success;
      ikon = Icons.trending_up;
      metin =
          'Ek gelir +${formatCurrency(fark)} · sistem ${formatCurrency(recon.systemBase)}';
    } else {
      // −düzeltme = iade.
      renk = AppColors.danger;
      ikon = Icons.trending_down;
      metin =
          'İade ${formatCurrency(fark)} · sistem ${formatCurrency(recon.systemBase)}';
    }
    // Kapsam öneki: "POS toplamı: İade −₺110,00 · sistem ₺31.000,00".
    final gosterilen = kapsam == null ? metin : '$kapsam: $metin';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space6,
      ),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: renk),
          const SizedBox(width: AppSizes.space6),
          Flexible(
            child: Text(
              gosterilen,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: renk,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GİDER SEKMESİ — kategori + tutar + not + firma autocomplete + gün içi liste
// ═══════════════════════════════════════════════════════════════════════════

class _GiderSekmesi extends ConsumerStatefulWidget {
  final DateTime date;
  final int fiscalYear;

  const _GiderSekmesi({
    super.key,
    required this.date,
    required this.fiscalYear,
  });

  @override
  ConsumerState<_GiderSekmesi> createState() => _GiderSekmesiState();
}

class _GiderSekmesiState extends ConsumerState<_GiderSekmesi> {
  final _tutarCtrl = TextEditingController();
  final _notCtrl = TextEditingController();
  String? _kategori;
  String? _firmaId;
  bool _ekleniyor = false;

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _notCtrl.dispose();
    super.dispose();
  }

  Future<void> _yeniKategoriEkle() async {
    final ctrl = TextEditingController();
    final ad = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yeni Gider Kalemi'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Kalem adı',
            hintText: 'ör. Kira, Elektrik',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (ad == null || ad.isEmpty) return;
    await ref.read(kasaRepositoryProvider).addExpenseCategory(ad);
    ref.invalidate(kasaExpenseCategoriesProvider);
    if (mounted) setState(() => _kategori = ad);
  }

  Future<void> _giderEkle() async {
    final tutar = _parseAmount(_tutarCtrl.text);
    if (_kategori == null || _kategori!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir gider kalemi seçin.')),
      );
      return;
    }
    if (tutar <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutar 0\'dan büyük olmalı.')),
      );
      return;
    }
    setState(() => _ekleniyor = true);
    try {
      await ref.read(kasaRepositoryProvider).addEntry(KasaEntry(
            entryDate: widget.date,
            fiscalYear: widget.fiscalYear,
            direction: KasaDirection.gider,
            category: _kategori,
            companyId: _firmaId,
            amount: tutar,
            note: _notCtrl.text.trim().isEmpty ? null : _notCtrl.text.trim(),
          ));
      if (!mounted) return;
      _tutarCtrl.clear();
      _notCtrl.clear();
      setState(() {
        _firmaId = null;
        _ekleniyor = false;
      });
      ref.invalidate(kasaEntriesProvider);
      ref.invalidate(kasaCumulativeSummaryProvider);
      ref.invalidate(kasaProductPurchasesProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ekleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gider eklenemedi: $e')),
      );
    }
  }

  Future<void> _giderSil(KasaEntry e) async {
    await ref.read(kasaRepositoryProvider).deleteEntry(e.id);
    ref.invalidate(kasaEntriesProvider);
    ref.invalidate(kasaCumulativeSummaryProvider);
    ref.invalidate(kasaProductPurchasesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final kategorilerAsync = ref.watch(kasaExpenseCategoriesProvider);
    final giderlerAsync = ref.watch(
      kasaEntriesProvider(
        KasaEntriesQuery(
          fiscalYear: widget.fiscalYear,
          date: widget.date,
          direction: 'gider',
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Gider giriş kartı ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: AppSizes.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gider Ekle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.space16),

              // Kategori + yeni kalem.
              Row(
                children: [
                  Expanded(
                    child: kategorilerAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => Text('Kategori yüklenemedi: $e',
                          style: const TextStyle(color: AppColors.danger)),
                      data: (kategoriler) => _KategoriDropdown(
                        kategoriler: kategoriler,
                        secili: _kategori,
                        onChanged: (v) => setState(() {
                          _kategori = v;
                          // Firma hanesi YALNIZ 'Ürün Alımı' kaleminde açılır
                          // (KARAR v1.9.4): başka kaleme geçilirse seçim temizlenir.
                          if (v != 'Ürün Alımı') _firmaId = null;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.space8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _yeniKategoriEkle,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Kalem'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.goldBorder),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space12),

              // Tutar.
              TextField(
                controller: _tutarCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  labelText: 'Tutar',
                  prefixText: '₺ ',
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSizes.space12),

              // Firma autocomplete (`/` deseni — satış canlı arama örüntüsü).
              // Kademeli açılım (design-tokens §5, KARAR v1.9.4): firma hanesi
              // YALNIZ 'Ürün Alımı' gider kalemi seçiliyken görünür.
              if (_kategori == 'Ürün Alımı') ...[
                _FirmaAramaAlani(
                  key: const ValueKey('gider-firma'),
                  onSelected: (company) => _firmaId = company?.id,
                ),
                const SizedBox(height: AppSizes.space12),
              ],

              // Not.
              TextField(
                controller: _notCtrl,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSizes.space16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _ekleniyor ? null : _giderEkle,
                  icon: _ekleniyor
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: Text(_ekleniyor ? 'Ekleniyor…' : 'Gideri Ekle'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.space16),

        // ── Gün içi gider listesi ──────────────────────────────────────────
        const Text(
          'Bugünkü Giderler',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        giderlerAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSizes.space16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, s) => Text('Giderler yüklenemedi: $e',
              style: const TextStyle(color: AppColors.danger)),
          data: (giderler) {
            if (giderler.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.space16),
                child: Text(
                  'Bu güne ait gider kaydı yok.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              );
            }
            final toplam =
                giderler.fold<num>(0, (t, e) => t + e.amount);
            return Column(
              children: [
                for (final e in giderler) _GiderSatiri(entry: e, onSil: _giderSil),
                const SizedBox(height: AppSizes.space8),
                // Gün toplamı — nötr tabular (danger değil).
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Gün Toplamı: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      formatCurrency(toplam),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Gider kategorisi dropdown'u.
class _KategoriDropdown extends StatelessWidget {
  final List<KasaExpenseCategory> kategoriler;
  final String? secili;
  final ValueChanged<String?> onChanged;

  const _KategoriDropdown({
    required this.kategoriler,
    required this.secili,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Seçili değer listede yoksa (yeni eklendi ama henüz yenilenmedi) null'a düş.
    final gecerliSecili =
        kategoriler.any((k) => k.name == secili) ? secili : null;
    return DropdownButtonFormField<String>(
      initialValue: gecerliSecili,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Gider Kalemi',
        isDense: true,
      ),
      items: kategoriler
          .map((k) => DropdownMenuItem(value: k.name, child: Text(k.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Gün içi gider liste satırı — kategori/firma/not + tutar + sil.
class _GiderSatiri extends StatelessWidget {
  final KasaEntry entry;
  final Future<void> Function(KasaEntry) onSil;

  const _GiderSatiri({required this.entry, required this.onSil});

  @override
  Widget build(BuildContext context) {
    final altBilgi = [
      if (entry.companyName != null && entry.companyName!.isNotEmpty)
        entry.companyName!,
      if (entry.note != null && entry.note!.isNotEmpty) entry.note!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.category ?? 'Gider',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (altBilgi.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    altBilgi,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          Text(
            formatCurrency(entry.amount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            onPressed: () => onSil(entry),
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
            tooltip: 'Sil',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Firma autocomplete alanı — satış ekranı `_LiveProductSearchField` örüntüsünün
/// yeniden kullanımı (OverlayPortal + CompositedTransformFollower +
/// TextFieldTapRegion). `companies.name` üzerinde Türkçe-duyarlı arama.
class _FirmaAramaAlani extends ConsumerStatefulWidget {
  final void Function(Company?) onSelected;

  const _FirmaAramaAlani({super.key, required this.onSelected});

  @override
  ConsumerState<_FirmaAramaAlani> createState() => _FirmaAramaAlaniState();
}

class _FirmaAramaAlaniState extends ConsumerState<_FirmaAramaAlani> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  Timer? _debounce;
  List<Company> _results = [];
  bool _loading = false;
  double _fieldWidth = 320;
  int _queryToken = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _portal.hide();
  }

  void _onChanged(String value) {
    // Kullanıcı metni elle değiştirdiyse önceki firma seçimi geçersiz.
    widget.onSelected(null);
    final query = value.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() => _results = []);
      _portal.hide();
      return;
    }
    final token = ++_queryToken;
    setState(() => _loading = true);
    if (!_portal.isShowing) _portal.show();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final results =
            await ref.read(kasaRepositoryProvider).searchCompanies(query);
        if (!mounted || token != _queryToken) return;
        if (_controller.text.trim() != query) return;
        setState(() {
          _results = results;
          _loading = false;
        });
        if (_results.isNotEmpty && _focusNode.hasFocus) {
          _portal.show();
        } else {
          _portal.hide();
        }
      } catch (_) {
        if (!mounted || token != _queryToken) return;
        setState(() {
          _results = [];
          _loading = false;
        });
      }
    });
  }

  void _select(Company company) {
    widget.onSelected(company);
    _controller.text = company.name;
    _debounce?.cancel();
    _queryToken++;
    setState(() {
      _results = [];
      _loading = false;
    });
    _portal.hide();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: TextFieldTapRegion(
              child: SizedBox(width: _fieldWidth, child: _buildDropdown()),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth.isFinite) {
              _fieldWidth = constraints.maxWidth;
            }
            return TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                labelText: 'Firma (opsiyonel)',
                hintText: 'Firma adı yazın…',
                prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                isDense: true,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      // §Gölge: siyah yerine lacivert-tint (palet token'ı AppColors.primary).
      // Material.shadowColor tek renk alır; cardShadow/elevatedShadow bir
      // BoxShadow listesi olduğundan doğrudan atanamaz → tint tek renkle taşınır.
      shadowColor: AppColors.primary.withValues(alpha: 0.20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: _loading && _results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Firma bulunamadı.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, i) {
                        final c = _results[i];
                        return InkWell(
                          onTap: () => _select(c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.space12,
                              vertical: AppSizes.space12,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_outlined,
                                    size: 16, color: AppColors.textMuted),
                                const SizedBox(width: AppSizes.space8),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FİRMA GİDERLERİ SEKMESİ — yıl içi 'Ürün Alımı' giderlerinin firma bazlı
// raporu (KARAR v1.9.4). Üstte sakin özet (ALTIN RAY YOK — ikinci hero olmaz),
// altında toplam tutara göre azalan firma kartları; kart açılınca ödeme dökümü.
// ═══════════════════════════════════════════════════════════════════════════

class _FirmaGiderleriSekmesi extends ConsumerWidget {
  final int fiscalYear;

  const _FirmaGiderleriSekmesi({required this.fiscalYear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alimlarAsync = ref.watch(kasaProductPurchasesProvider(fiscalYear));

    return alimlarAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSizes.space24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, s) => Text(
        'Firma giderleri yüklenemedi: $e',
        style: const TextStyle(color: AppColors.danger),
      ),
      data: (entries) {
        // Firma bazlı gruplama: companyId (yoksa companyName) anahtarıyla.
        final gruplar = <String, List<KasaEntry>>{};
        for (final e in entries) {
          final anahtar = e.companyId ?? e.companyName ?? '';
          gruplar.putIfAbsent(anahtar, () => []).add(e);
        }
        // Firmalar toplam tutara göre azalan; ödemeler repo'dan zaten tarihe
        // göre azalan gelir (order entry_date desc).
        final firmalar = gruplar.values.toList()
          ..sort((a, b) {
            final ta = a.fold<num>(0, (t, e) => t + e.amount);
            final tb = b.fold<num>(0, (t, e) => t + e.amount);
            return tb.compareTo(ta);
          });
        final genelToplam = entries.fold<num>(0, (t, e) => t + e.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sakin özet — ALTIN RAY YOK (ikinci hero olmaz) ────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              decoration: AppSizes.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fiscalYear Yılı Toplam Ürün Alımı',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space8),
                  Text(
                    formatCurrency(genelToplam),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.space16),

            // ── Firma listesi / boş durum ─────────────────────────────────
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.space16),
                child: Center(
                  child: Text(
                    'Bu yıl için ürün alımı kaydı yok.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              for (final odemeler in firmalar)
                _FirmaGiderKarti(odemeler: odemeler),
          ],
        );
      },
    );
  }
}

/// Tek firmanın yıl içi ürün-alımı kartı: başlıkta firma adı + yıl toplamı,
/// açılınca tarih/tutar döküm satırları (ince divider'lı).
class _FirmaGiderKarti extends StatelessWidget {
  final List<KasaEntry> odemeler;

  const _FirmaGiderKarti({required this.odemeler});

  @override
  Widget build(BuildContext context) {
    final ad = (odemeler.first.companyName?.isNotEmpty ?? false)
        ? odemeler.first.companyName!
        : 'Bilinmeyen Firma';
    final toplam = odemeler.fold<num>(0, (t, e) => t + e.amount);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // ExpansionTile'ın kendi üst/alt çizgileri kapatılır — kart kenarlığı
        // zaten konteynerde.
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ad,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Text(
              formatCurrency(toplam),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        children: [
          for (var i = 0; i < odemeler.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatShortDate(odemeler[i].entryDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    formatCurrency(odemeler[i].amount),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSizes.space8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AÇILIŞ BAKİYESİ — mütevazı bölüm (hero değil). Yıl bazlı opening_income /
// opening_expense. Düzenle → dialog → upsertOpeningBalance.
// ═══════════════════════════════════════════════════════════════════════════

class _AcilisBakiyesiBolumu extends ConsumerWidget {
  final int fiscalYear;

  const _AcilisBakiyesiBolumu({required this.fiscalYear});

  Future<void> _duzenle(
    BuildContext context,
    WidgetRef ref,
    KasaOpeningBalance? mevcut,
  ) async {
    final gelirCtrl = TextEditingController(
      text: (mevcut?.openingIncome ?? 0) == 0
          ? ''
          : (mevcut!.openingIncome).toString(),
    );
    final giderCtrl = TextEditingController(
      text: (mevcut?.openingExpense ?? 0) == 0
          ? ''
          : (mevcut!.openingExpense).toString(),
    );
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$fiscalYear Yıl Açılışı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Yıl başı devreden değerler (otomatik devir yoktur; elle girilir).',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSizes.space16),
            TextField(
              controller: gelirCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Açılış Geliri',
                prefixText: '₺ ',
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            TextField(
              controller: giderCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Açılış Gideri',
                prefixText: '₺ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (kaydet != true) return;
    await ref.read(kasaRepositoryProvider).upsertOpeningBalance(
          fiscalYear,
          _parseAmount(gelirCtrl.text),
          _parseAmount(giderCtrl.text),
        );
    ref.invalidate(kasaOpeningBalanceProvider);
    ref.invalidate(kasaCumulativeSummaryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acilisAsync = ref.watch(kasaOpeningBalanceProvider(fiscalYear));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: acilisAsync.when(
              loading: () => const Text('Açılış bakiyesi yükleniyor…',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              error: (e, s) => Text('Açılış okunamadı: $e',
                  style: const TextStyle(fontSize: 12, color: AppColors.danger)),
              data: (acilis) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$fiscalYear Yıl Açılışı',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    'Gelir ${formatCurrency(acilis?.openingIncome ?? 0)} · '
                    'Gider ${formatCurrency(acilis?.openingExpense ?? 0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _duzenle(context, ref, acilisAsync.valueOrNull),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Düzenle'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

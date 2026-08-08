import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/connectivity/connectivity_status_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/network_timeout.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/tts_service.dart';
import '../../../../core/widgets/instrument_hero.dart';
import '../../../products/data/local/product_local_cache_dao.dart';
import '../../application/barcode_cache.dart';
import '../../application/barcode_focus_notifier.dart';
import '../../application/payment_input_notifier.dart';
import '../../application/sale_sync_service.dart';
import '../../application/sales_cart_notifier.dart';
import '../../data/local/pending_sale_dao.dart';
import '../../data/models/pending_sale.dart';
import '../../data/models/sale.dart';

/// Ödeme paneli — §6.8(a) "üç bölge" düzeni:
///   1. **Üstte sabit:** `InstrumentHero` (kaydırmaz, asla kırpılmaz),
///   2. **Ortada kayan:** ödeme türü butonları + Parçalı input'ları + özet/uyarılar,
///   3. **Altta sabit:** ana aksiyon ("Satışı Tamamla") — her çözünürlükte görünür.
class PaymentPanel extends ConsumerStatefulWidget {
  /// Orta (kayan) bölgenin kaydırma denetleyicisi. Mobil ödeme sheet'i kendi
  /// `DraggableScrollableSheet` controller'ını buraya geçirir: böylece sheet'in
  /// sürükleme davranışı korunur **ve panelin dışında ikinci bir kaydırma
  /// açılmaz** → iç içe kaydırma oluşmaz (sheet artık `SingleChildScrollView`
  /// kullanmaz, tek kaydırılabilir bu panelin orta bölgesidir).
  final ScrollController? scrollController;

  const PaymentPanel({super.key, this.scrollController});

  @override
  ConsumerState<PaymentPanel> createState() => _PaymentPanelState();
}

class _PaymentPanelState extends ConsumerState<PaymentPanel> {
  bool _completing = false;
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();

  /// Dışarıdan controller gelmeyen (masaüstü) bağlamda orta bölgenin kendi
  /// kaydırma denetleyicisi. `Scrollbar`'ın görünür bir tutamak çizebilmesi
  /// için gerekir — §6.8(a): kaydırma varsa görsel ipucu ZORUNLU, "gizli
  /// kaydırma" tekrar etmemeli.
  final _panelScrollController = ScrollController();

  @override
  void dispose() {
    _cashController.dispose();
    _cardController.dispose();
    _panelScrollController.dispose();
    super.dispose();
  }

  void _syncControllers(PaymentInputState payment) {
    final cashText = payment.cashSplit == 0 ? '' : payment.cashSplit.toString();
    if (_cashController.text != cashText) _cashController.text = cashText;

    final cardText = payment.cardSplit == 0 ? '' : payment.cardSplit.toString();
    if (_cardController.text != cardText) _cardController.text = cardText;
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesCartProvider);
    final tab = salesState.active;
    final payment = ref.watch(paymentInputProvider);
    final paymentNotifier = ref.read(paymentInputProvider.notifier);
    final isReturnMode = salesState.isReturnMode;
    _syncControllers(payment);

    final cartEmpty = tab.items.isEmpty;

    // v1 offline satış kapsamı yalnız Nakit/POS'tur (bkz. plan notu) — Açık
    // Hesap/Parçalı/İade müşteri arama + borç defteri gerektirdiğinden
    // offline'da pasif kalır, Nakit/POS'a DOKUNULMAZ.
    final offline =
        !kIsWeb && ref.watch(connectivityStatusServiceProvider).phase == ConnectivityPhase.offline;

    // Ana aksiyon YALNIZ mod seçimi gerektiren türlerde vardır (Nakit/POS zaten
    // tek dokunuşta tamamlar → onların butonu orta bölgede kalır, §6.8(a)).
    final anaAksiyonVar = !isReturnMode &&
        (payment.type == PaymentType.parcali ||
            payment.type == PaymentType.acikHesap);

    // Orta bölgenin kaydırma denetleyicisi: mobil sheet kendi controller'ını
    // geçer (sürükleme davranışı korunur), masaüstünde panelin kendi controller'ı.
    final scrollController =
        widget.scrollController ?? _panelScrollController;

    return LayoutBuilder(
      builder: (context, constraints) {
        // ── §6.8(a) ÜÇ BÖLGE: [1] üstte sabit hero · [2] ortada kayan içerik ·
        // [3] altta sabit ana aksiyon. Dıştaki iki bölge kaydırma alanının
        // DIŞINDADIR → "Satışı Tamamla" hiçbir çözünürlükte kaybolmaz.
        //
        // Kaydırma YALNIZCA panelin yüksekliği sınırlıysa devreye girer
        // (masaüstü sütunu: `ConstrainedBox(maxHeight:)` · mobil sheet:
        // `Expanded`). Sınırsız yükseklikli bir bağlamda (dışarıda bir
        // `SingleChildScrollView` varsa) panel kendi kaydırmasını AÇMAZ →
        // iç içe kaydırma olmaz; ayrıca sınırsız yükseklikte `Flexible`
        // "non-zero flex + unbounded height" ile çökertirdi, bu dal onu da önler.
        final kaydirilabilir = constraints.hasBoundedHeight;
        final ortaBolge = _buildOrtaBolge(
          tab: tab,
          payment: payment,
          paymentNotifier: paymentNotifier,
          isReturnMode: isReturnMode,
          cartEmpty: cartEmpty,
          offline: offline,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── [1] Üstte sabit — imza öğesi (§4 + §6.3): ekranın TEK
                // hero'su = sepet GENEL TOPLAM. Koyu enstrüman paneli; ray
                // normalde altın, iadede danger. Kaydırma alanının dışında
                // olduğu için asla kırpılmaz.
                // 🇬🇧 seslendirme butonu hero panelinin İÇİNDE durur (yalnız web).
                InstrumentHero(
                  label: isReturnMode ? 'İADE TUTARI · ₺' : 'TOPLAM · ₺',
                  amount: tab.total,
                  railColor: isReturnMode ? AppColors.danger : AppColors.gold,
                  // §6.8(c): iade rakamı koyu panelde AA sağlasın diye ham
                  // `danger` değil, beyazla parlatılmış hâli basılır. Normal
                  // modda varsayılan beyaz.
                  amountColor: isReturnMode
                      ? instrumentPanelReadable(AppColors.danger)
                      : Colors.white,
                  // Kompakt trailing (§6.7(h)/1): 40×40 ikon butonu hero tutarın
                  // genişliğinden pay ALMAZ → tutar ekranın en baskın öğesi kalır.
                  trailingTight: true,
                  // Buton sabit ölçülü (Container 40/48) → ne dikeyde ne yatayda
                  // paneli şişirir; ek Align/heightFactor sarmalayıcısı GEREKMEZ.
                  trailing: kIsWeb ? _SpeakTotalButton(amount: tab.total) : null,
                ),
                const SizedBox(height: AppSizes.space16),
                // ── [2] Ortada kayan.
                if (kaydirilabilir)
                  Flexible(
                    // Tight yükseklik (mobil sheet `Expanded`) → orta bölge
                    // kalan alanı doldurur, ana aksiyon panelin dibine yapışır.
                    // Loose yükseklik (masaüstü `ConstrainedBox`) → panel
                    // içeriği kadar yer kaplar, yalnız üst sınırı aşarsa orta
                    // bölge kaydırılır.
                    fit: constraints.hasTightHeight
                        ? FlexFit.tight
                        : FlexFit.loose,
                    child: Scrollbar(
                      controller: scrollController,
                      // Kaydırma gerçekten devredeyse tutamak görünür olur
                      // (içerik sığıyorsa Flutter tutamağı zaten çizmez).
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: scrollController,
                        // Mobil sheet'i içerik kısayken de sürükleyebilmek için.
                        physics: widget.scrollController != null
                            ? const AlwaysScrollableScrollPhysics()
                            : null,
                        child: ortaBolge,
                      ),
                    ),
                  )
                else
                  ortaBolge,
                // ── [3] Altta sabit — ana aksiyon.
                if (anaAksiyonVar) ...[
                  const Divider(height: AppSizes.space24),
                  ElevatedButton(
                    onPressed: (cartEmpty || _completing || offline)
                        ? null
                        : () => _completeSale(tab, payment),
                    child: _completing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Satışı Tamamla'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// [2] Orta (kayan) bölge — §6.8(a): ödeme türü butonları + grup
  /// mikro-etiketleri + Parçalı input'ları/özeti + açık hesap uyarıları.
  /// Ana aksiyon burada DEĞİLDİR (altta sabit bölgededir); Nakit/POS "tek
  /// dokunuşta tamamlar" butonları ise karar gereği burada kalır.
  Widget _buildOrtaBolge({
    required CustomerTabState tab,
    required PaymentInputState payment,
    required PaymentInput paymentNotifier,
    required bool isReturnMode,
    required bool cartEmpty,
    required bool offline,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isReturnMode) ...[
          // İade modu — sadece Nakit ve POS; ikisi de tek dokunuşta tamamlar.
          const _AksiyonGrupEtiketi('TEK DOKUNUŞTA TAMAMLAR'),
          const SizedBox(height: AppSizes.space8),
          Row(
            children: [
              Expanded(
                child: _PaymentTypeButton(
                  label: 'Nakit İade',
                  icon: Icons.payments_outlined,
                  color: AppColors.danger,
                  filled: true,
                  onTap: (cartEmpty || _completing || offline) ? null : () => _completeReturn(tab, PaymentType.nakit),
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              Expanded(
                child: _PaymentTypeButton(
                  label: 'POS İadesi',
                  icon: Icons.credit_card_outlined,
                  color: AppColors.danger,
                  filled: true,
                  onTap: (cartEmpty || _completing || offline) ? null : () => _completeReturn(tab, PaymentType.pos),
                ),
              ),
            ],
          ),
          if (offline) ...[
            const SizedBox(height: AppSizes.space12),
            const Text('İade çevrimdışıyken kullanılamaz — bağlantı gelince tekrar deneyin.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
          if (_completing) ...[
            const SizedBox(height: AppSizes.space16),
            const Center(child: CircularProgressIndicator()),
          ],
        ] else ...[
          // ── Ödeme aksiyonu iki sınıfa ayrılır: tek dokunuşta biten (dolu)
          // ve önce seçim isteyen (outline). Kasiyer hangi butonun satışı
          // hemen kapatacağını bir bakışta görür.
          const _AksiyonGrupEtiketi('TEK DOKUNUŞTA TAMAMLAR'),
          const SizedBox(height: AppSizes.space8),
          Row(
            children: [
              Expanded(
                child: _PaymentTypeButton(
                  label: 'Nakit',
                  icon: Icons.payments_outlined,
                  color: AppColors.cash,
                  filled: true,
                  onTap: (cartEmpty || _completing) ? null : () => _completeSaleDirectly(tab, PaymentType.nakit),
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              Expanded(
                child: _PaymentTypeButton(
                  label: 'POS',
                  icon: Icons.credit_card_outlined,
                  color: AppColors.pos,
                  filled: true,
                  onTap: (cartEmpty || _completing) ? null : () => _completeSaleDirectly(tab, PaymentType.pos),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          const _AksiyonGrupEtiketi('ÖNCE SEÇ, SONRA TAMAMLA'),
          const SizedBox(height: AppSizes.space8),
          Row(
            children: [
              Expanded(
                child: _PaymentTypeButton(
                  label: 'Açık Hesap',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.openAccount,
                  selected: payment.type == PaymentType.acikHesap,
                  onTap: (cartEmpty || _completing || offline)
                      ? null
                      : () => paymentNotifier.selectType(PaymentType.acikHesap, tab.total),
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              Expanded(
                child: _PaymentTypeButton(
                  label: 'Parçalı',
                  icon: Icons.call_split_outlined,
                  color: AppColors.splitPayment,
                  selected: payment.type == PaymentType.parcali,
                  onTap: (cartEmpty || _completing || offline)
                      ? null
                      : () => paymentNotifier.selectType(PaymentType.parcali, tab.total),
                ),
              ),
            ],
          ),
          if (offline) ...[
            const SizedBox(height: AppSizes.space8),
            const Text(
                'Açık Hesap/Parçalı çevrimdışıyken kullanılamaz (müşteri arama bağlantı gerektirir) — bağlantı gelince tekrar deneyin.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
          if (payment.type == PaymentType.parcali) ...[
            const SizedBox(height: AppSizes.space12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cashController,
                    decoration: const InputDecoration(labelText: 'Nakit'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => paymentNotifier.setCashSplit(num.tryParse(v.replaceAll(',', '.')) ?? 0),
                  ),
                ),
                const SizedBox(width: AppSizes.space8),
                Expanded(
                  child: TextFormField(
                    controller: _cardController,
                    decoration: const InputDecoration(labelText: 'Kart'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => paymentNotifier.setCardSplit(num.tryParse(v.replaceAll(',', '.')) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space8),
            // Okuma satırı + kırılım özeti yan yana: dikeyde yer kazanır,
            // ikisi de kayan bölgede kalır (ana aksiyon aşağıda sabit).
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Toplam Ödenen: ${formatCurrency(payment.cashSplit + payment.cardSplit)}',
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                _ParcaliSummary(
                  cashSplit: payment.cashSplit,
                  cardSplit: payment.cardSplit,
                  total: tab.total,
                ),
              ],
            ),
          ] else if (payment.type == PaymentType.acikHesap) ...[
            const SizedBox(height: AppSizes.space12),
            Text(
              'Açık Hesap: ${formatCurrency(tab.total)} müşteri hesabına borç olarak işlenecek.',
              style: const TextStyle(color: AppColors.danger),
            ),
            if (tab.customerId == null)
              const Padding(
                padding: EdgeInsets.only(top: AppSizes.space4),
                child: Text('Lütfen müşteri seçin.', style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ],
      ],
    );
  }

  // Satış başarıyla tamamlanınca masaüstü barkod alanına odak sinyali gönder
  // (decoupled tick). Yalnızca masaüstü: mobilde ödeme bottom sheet ile yapılır
  // ve klavye istenmeden açılmamalı, o yüzden odak zorlanmaz.
  void _requestBarcodeFocusIfDesktop() {
    if (!mounted || context.isMobile) return;
    ref.read(barcodeFocusRequestProvider.notifier).requestFocus();
  }

  bool get _knownOffline =>
      !kIsWeb && ref.read(connectivityStatusServiceProvider).phase == ConnectivityPhase.offline;

  /// İade — v1'de offline kapsam dışı (bkz. plan notu), yalnız online.
  /// Önceden hiçbir hata yakalanmıyordu (uncaught exception riski) — artık
  /// diğer tamamlama yollarıyla aynı hata mesajı deseni uygulanıyor.
  Future<void> _completeReturn(CustomerTabState tab, PaymentType type) async {
    if (tab.items.isEmpty) return;
    if (_knownOffline) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('İade çevrimdışıyken kullanılamaz.')));
      return;
    }

    setState(() => _completing = true);
    try {
      final saleCode = await withNetworkTimeout(ref.read(salesRepositoryProvider).completeReturn(
            items: tab.items,
            totalAmount: tab.total,
            paymentType: type,
            customerId: tab.customerId,
          ));

      ref.read(salesCartProvider.notifier).clearActiveTab();
      ref.read(paymentInputProvider.notifier).reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İade tamamlandı: $saleCode'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text('İade tamamlanamadı: ${e.message}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Bağlantı hatası — iade tamamlanamadı, tekrar deneyin.')));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  /// Nakit/POS — "tek dokunuşta tamamlar" yol. Offline'da (`_knownOffline`)
  /// veya ağ denemesi timeout'la başarısız olursa `_queueOfflineSale` ile
  /// kuyruğa düşer (`product_form_screen.dart` `_save()` ile aynı desen);
  /// sunucunun gerçek reddettiği durum (`PostgrestException`) sert hata
  /// olarak kalır, kuyruğa ALINMAZ.
  Future<void> _completeSaleDirectly(CustomerTabState tab, PaymentType type) async {
    if (tab.items.isEmpty) return;

    setState(() => _completing = true);
    final stopwatch = Stopwatch()..start();
    try {
      final num cashAmount = type == PaymentType.nakit ? tab.total : 0;
      final num cardAmount = type == PaymentType.pos ? tab.total : 0;

      String saleCode;
      var offlineQueued = false;
      if (_knownOffline) {
        saleCode = await _queueOfflineSale(tab,
            paymentType: type, paidAmount: tab.total, cashAmount: cashAmount, cardAmount: cardAmount);
        offlineQueued = true;
      } else {
        try {
          saleCode = await withNetworkTimeout(ref.read(salesRepositoryProvider).completeSale(
                items: tab.items,
                discountPercent: tab.discountPercent,
                totalAmount: tab.total,
                paidAmount: tab.total,
                paymentType: type,
                cashAmount: cashAmount,
                cardAmount: cardAmount,
                customerId: tab.customerId,
              ));
        } on PostgrestException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AppColors.danger, content: Text('Satış tamamlanamadı: ${e.message}')));
          }
          return;
        } catch (_) {
          if (kIsWeb) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  backgroundColor: AppColors.danger,
                  content: Text('Bağlantı hatası — satış tamamlanamadı, tekrar deneyin.')));
            }
            return;
          }
          saleCode = await _queueOfflineSale(tab,
              paymentType: type, paidAmount: tab.total, cashAmount: cashAmount, cardAmount: cardAmount);
          offlineQueued = true;
        }
      }

      ref.read(salesCartProvider.notifier).clearActiveTab();
      ref.read(paymentInputProvider.notifier).reset();
      _requestBarcodeFocusIfDesktop();

      stopwatch.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(offlineQueued
              ? 'Satış çevrimdışı kaydedildi — $saleCode, bağlantı gelince otomatik gönderilecek.'
              : 'Satış tamamlandı - $saleCode - ${stopwatch.elapsedMilliseconds}ms'),
        ));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  /// Ürünü senkron kuyruğuna yazar (v1 yalnız Nakit/POS — açık hesap/parçalı/
  /// iade bu yoldan GEÇMEZ). Yerel etkiler ANINDA uygulanır: `products_cache`
  /// stoğu düşer + `BarcodeCache` bellek indeksi tazelenir ki aynı offline
  /// oturumda ardışık taramalar doğru stok görsün (sunucu tarafı gerçek
  /// `sale_code`'u ve stok düşümünü SENKRON anında yapar, bkz. `SaleSyncService`).
  Future<String> _queueOfflineSale(
    CustomerTabState tab, {
    required PaymentType paymentType,
    required num paidAmount,
    required num cashAmount,
    required num cardAmount,
  }) async {
    final id = const Uuid().v4();
    final localSaleCode = 'ÇEVRİMDIŞI-${id.substring(0, 6).toUpperCase()}';
    final now = DateTime.now();

    final payload = PendingSalePayload(
      items: tab.items,
      discountPercent: tab.discountPercent,
      totalAmount: tab.total,
      paidAmount: paidAmount,
      paymentType: paymentType,
      cashAmount: cashAmount,
      cardAmount: cardAmount,
      customerId: tab.customerId,
    );
    await ref.read(pendingSaleDaoProvider).insert(PendingSale(
          id: id,
          payloadJson: jsonEncode(payload.toMap()),
          localSaleCode: localSaleCode,
          createdAt: now,
          updatedAt: now,
        ));

    final cacheDao = ref.read(productLocalCacheDaoProvider);
    final barcodeCache = ref.read(barcodeCacheProvider);
    for (final item in tab.items) {
      final productId = item.productId;
      if (productId == null) continue;
      await cacheDao.decrementStockLocally(productId, item.quantity);
      final updated = await cacheDao.fetchById(productId);
      if (updated != null) barcodeCache.put(updated);
    }

    await ref.read(saleSyncServiceProvider.notifier).notifyLocalQueueChanged();
    return localSaleCode;
  }

  /// Açık Hesap/Parçalı — v1'de offline kapsam dışı (müşteri arama + borç
  /// defteri ağ-bağlı, bkz. plan notu); `offline` bayrağı butonları zaten
  /// pasifleştirir, burası yalnız savunma amaçlı ikinci bir kapı (ör. mod
  /// online iken seçilip "Satışı Tamamla"ya basmadan önce bağlantı koptuysa).
  Future<void> _completeSale(CustomerTabState tab, PaymentInputState payment) async {
    if (tab.items.isEmpty) return;

    if (_knownOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Açık Hesap/Parçalı çevrimdışıyken kullanılamaz.')),
      );
      return;
    }

    if (payment.type == PaymentType.acikHesap && tab.customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Açık hesap için lütfen müşteri seçin.')),
      );
      return;
    }

    num cashAmount = 0;
    num cardAmount = 0;
    num paidAmount = 0;

    if (payment.type == PaymentType.parcali) {
      cashAmount = payment.cashSplit;
      cardAmount = payment.cardSplit;
      paidAmount = cashAmount + cardAmount;
    }

    setState(() => _completing = true);
    final stopwatch = Stopwatch()..start();
    try {
      final saleCode = await withNetworkTimeout(ref.read(salesRepositoryProvider).completeSale(
            items: tab.items,
            discountPercent: tab.discountPercent,
            totalAmount: tab.total,
            paidAmount: paidAmount,
            paymentType: payment.type,
            cashAmount: cashAmount,
            cardAmount: cardAmount,
            customerId: tab.customerId,
          ));

      ref.read(salesCartProvider.notifier).clearActiveTab();
      ref.read(paymentInputProvider.notifier).reset();
      _requestBarcodeFocusIfDesktop();

      stopwatch.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satış tamamlandı - $saleCode - ${stopwatch.elapsedMilliseconds}ms')),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text('Satış tamamlanamadı: ${e.message}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Bağlantı hatası — satış tamamlanamadı, tekrar deneyin.')));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }
}

/// Ödeme aksiyon grubu mikro-etiketi (§6.3 mikro-etiket dili, `type.utility`):
/// butonların hangi sınıfa ait olduğunu bir bakışta söyler.
class _AksiyonGrupEtiketi extends StatelessWidget {
  final String text;

  const _AksiyonGrupEtiketi(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.textMuted,
      ),
    );
  }
}

/// Hero toplamın yanındaki "İngilizce sesli oku" butonu — İngiliz bayrağı emoji
/// ikonu (yeni bir asset/paket eklemeden platformlar arası tutarlı görünüm için
/// emoji tercih edildi). Konuşma sırasında küçük bir yükleniyor göstergesine döner.
///
/// Koyu enstrüman paneli içinde yaşar: çemberi altın DEĞİL, `panel.control`
/// beyaz-alfa (§6.2 — bu ekranda altın yalnız hero rayı + reticle köşelerdedir).
class _SpeakTotalButton extends StatefulWidget {
  final num amount;
  const _SpeakTotalButton({required this.amount});

  @override
  State<_SpeakTotalButton> createState() => _SpeakTotalButtonState();
}

class _SpeakTotalButtonState extends State<_SpeakTotalButton> {
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    // Ses seçimini ÖNCEDEN ısıtmayı DENE (yalnız optimizasyon — tıklama anında
    // zaten tamamlanmışsa bekleme kısalır; tamamlanmadıysa `_speak` kendi
    // içinde zaten bekler, bu yüzden burada Future'ı beklemiyoruz).
    warmupTts();
  }

  Future<void> _speak() async {
    if (_speaking) return;
    setState(() => _speaking = true);
    try {
      await speakAmountInEnglish(widget.amount);
    } catch (_) {
      // Platform TTS çağrısı başarısız oldu — konsolu "uncaught" hatayla
      // kirletmeden sessizce yut, kullanıcıya yalnızca buton eski haline döner.
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mobil dokunma hedefi ≥ 48×48 (§3); masaüstünde 40 yeterli. Sabit ölçü →
    // hero panelinin kompakt trailing'i olarak ne dikeyde ne yatayda taşırmaz.
    final olcu = context.isMobile ? 48.0 : 40.0;
    return Tooltip(
      message: 'Toplamı İngilizce seslendir',
      // Şeffaf Material: dokunma dalgası koyu panelin ÜSTÜNDE çizilir (aksi
      // hâlde alttaki Card'a çizilir ve gradyanın altında kaybolur).
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          onTap: _speak,
          child: Container(
            width: olcu,
            height: olcu,
            alignment: Alignment.center,
            // `panel.control` (§6.2): kenarlık 0.24–0.30 · dolgu 0.04–0.08.
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: _speaking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('🇬🇧', style: TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }
}

class _ParcaliSummary extends StatelessWidget {
  final num cashSplit;
  final num cardSplit;
  final num total;

  const _ParcaliSummary({
    required this.cashSplit,
    required this.cardSplit,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final paid = cashSplit + cardSplit;
    final diff = total - paid;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space8, vertical: AppSizes.space6),
      decoration: BoxDecoration(
        color: AppColors.tableHeader,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SummaryLine(label: 'Nakit', amount: cashSplit, color: AppColors.cash),
          // §3: `space2` yalnız pill/rozet iç dolgusu içindir; layout aralığı
          // olarak kullanılamaz (§6.8(d)) → ölçeğin bir alt kademesi space4.
          const SizedBox(height: AppSizes.space4),
          _SummaryLine(label: 'Kart', amount: cardSplit, color: AppColors.pos),
          if (diff != 0) ...[
            const SizedBox(height: 2),
            _SummaryLine(
              label: diff > 0 ? 'Eksik' : 'Fazla',
              amount: diff.abs(),
              color: AppColors.danger,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;

  const _SummaryLine({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        Text(
          formatCurrency(amount),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Ödeme türü butonu (§5) — iki sınıfta yaşar:
/// • [filled] = **tek dokunuşta tamamlar** (Nakit/POS): türün renginde DOLU zemin
///   + beyaz ikon/etiket. Bastığın anda satış biter, bu yüzden en baskın olan bu.
/// • varsayılan = **önce seç, sonra tamamla** (Açık Hesap/Parçalı): nötr `divider`
///   kenarlıklı outline + sol renk şeridi; [selected] iken türün renginde dolgu.
/// Kenarlıkta altın KULLANILMAZ — bu ekranda altın yalnız hero rayı + reticle.
class _PaymentTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool filled;
  final VoidCallback? onTap;

  const _PaymentTypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final dolu = filled || selected;
    // §1: altın metin açık zemine yazılmaz → açık hesap outline'dayken etiket/ikon
    // lacivert (ink). Diğer türler kendi renginde okunur (AA sağlar).
    final isGold = color == AppColors.openAccount;

    final bg = dolu
        ? (disabled ? AppColors.divider : color)
        : AppColors.cardBg;
    final fg = disabled
        ? AppColors.textMuted
        : dolu
            ? Colors.white
            : isGold
                ? AppColors.primary
                : color;
    final borderColor = (dolu && !disabled) ? color : AppColors.divider;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        clipBehavior: Clip.antiAlias,
        // Mobil dokunma hedefi ≥ 48 (§3) — içerik zaten daha uzun, bu bir taban.
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: borderColor, width: dolu ? 1.5 : 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tür kimliği — sol renk şeridi (yalnız outline sınıfında; dolu
              // butonda zaten tüm zemin türün rengi).
              if (!filled)
                Container(
                  width: 4,
                  color: disabled
                      ? AppColors.textMuted
                      : selected
                          ? Colors.white
                          : color,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.space12, horizontal: AppSizes.space8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: fg, size: 22),
                      const SizedBox(height: AppSizes.space4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

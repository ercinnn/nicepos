import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/label_pool_repository.dart';
import '../data/labels_storage_repository.dart';
import '../data/models/discount_label_slot.dart';
import '../data/models/label_pool_item.dart';
import '../data/models/label_slot.dart';
import '../data/models/product_label_item.dart';
import '../data/models/tel_discount_label_slot.dart';

part 'labels_provider.g.dart';

/// Raf etiketi sayfası sabitleri (KARAR v1.10): 3 sütun × 8 satır = 24 etiket.
const int kLabelColumns = 3;
const int kLabelRows = 8;
const int kLabelCount = kLabelColumns * kLabelRows; // 24

/// Geniş Logo etiket sabitleri (KARAR v1.14): 2 sütun × 5 satır = 10 etiket/A4.
const int kWideCols = 2;
const int kWideRows = 5;
const int kWideCount = kWideCols * kWideRows; // 10

/// Tel Etiketi sayfası sabitleri: Raf Etiketi ile birebir aynı yükseklik/stil,
/// yalnız yan yana 4 adet (satır sayısı aynı kalır) → 4×8 = 32 etiket.
const int kTelColumns = 4;
const int kTelRows = kLabelRows;
const int kTelCount = kTelColumns * kTelRows; // 32


/// Etiket sayfasının durumu: 24 hanelik liste (`null` = boş hane) + mağaza logosu
/// (data URL / base64; hem önizleme hem baskıda kullanılır).
class LabelSheetState {
  final List<LabelSlot?> slots;
  final String? logoDataUrl;

  const LabelSheetState({required this.slots, this.logoDataUrl});

  factory LabelSheetState.initial() => LabelSheetState(
        slots: List<LabelSlot?>.filled(kLabelCount, null),
      );

  int get filledCount => slots.where((s) => s != null).length;

  LabelSheetState copyWith({
    List<LabelSlot?>? slots,
    String? logoDataUrl,
    bool clearLogo = false,
  }) {
    return LabelSheetState(
      slots: slots ?? this.slots,
      logoDataUrl: clearLogo ? null : (logoDataUrl ?? this.logoDataUrl),
    );
  }
}

/// Etiket sayfası durumunu tutar. `keepAlive` — kullanıcı başka sekmeye geçip
/// dönünce 24 hane + logo korunur (oturum içi kalıcılık; localStorage opsiyonel
/// bonus, KARAR v1.10). Satış sepeti notifier'ıyla aynı desen.
@Riverpod(keepAlive: true)
class LabelSheet extends _$LabelSheet {
  @override
  LabelSheetState build() => LabelSheetState.initial();

  /// [index] hanesine çözülmüş etiketi yerleştirir (barkod okutma + ürün lookup
  /// sonrası çağrılır).
  void setSlot(int index, LabelSlot slot) {
    if (index < 0 || index >= kLabelCount) return;
    final next = List<LabelSlot?>.from(state.slots);
    next[index] = slot;
    state = state.copyWith(slots: next);
  }

  /// [index] hanesini temizler (satır ✕).
  void clearSlot(int index) {
    if (index < 0 || index >= kLabelCount) return;
    final next = List<LabelSlot?>.from(state.slots);
    next[index] = null;
    state = state.copyWith(slots: next);
  }

  /// Tüm haneleri temizler (logo korunur).
  void clearAll() {
    state = state.copyWith(slots: List<LabelSlot?>.filled(kLabelCount, null));
  }

  /// Mağaza logosunu ayarlar (data URL). `null` → logo kaldır (fallback ikon).
  void setLogo(String? dataUrl) {
    if (dataUrl == null) {
      state = state.copyWith(clearLogo: true);
    } else {
      state = state.copyWith(logoDataUrl: dataUrl);
    }
  }
}

// ─── Geniş Logo etiket sayfası (KARAR v1.14) ─────────────────────────────────

/// Geniş Logo etiket sayfasının durumu: 10 hanelik liste (`null` = boş hane).
/// Logosuz (marka tentesi sabit asset) — dar-logo `LabelSheetState`'in 10-haneli
/// logosuz kopyası.
class LabelWideSheetState {
  final List<LabelSlot?> slots;

  const LabelWideSheetState({required this.slots});

  factory LabelWideSheetState.initial() => LabelWideSheetState(
        slots: List<LabelSlot?>.filled(kWideCount, null),
      );

  int get filledCount => slots.where((s) => s != null).length;

  LabelWideSheetState copyWith({List<LabelSlot?>? slots}) {
    return LabelWideSheetState(slots: slots ?? this.slots);
  }
}

/// Geniş Logo etiket sayfası durumunu tutar. `keepAlive` — sekme değişiminde 10
/// hane korunur (dar-logo `LabelSheet` deseninin logosuz 10-haneli kopyası; dar
/// 24-hane provider'ıyla KARIŞMAZ).
@Riverpod(keepAlive: true)
class LabelWideSheet extends _$LabelWideSheet {
  @override
  LabelWideSheetState build() => LabelWideSheetState.initial();

  void setSlot(int index, LabelSlot slot) {
    if (index < 0 || index >= kWideCount) return;
    final next = List<LabelSlot?>.from(state.slots);
    next[index] = slot;
    state = state.copyWith(slots: next);
  }

  void clearSlot(int index) {
    if (index < 0 || index >= kWideCount) return;
    final next = List<LabelSlot?>.from(state.slots);
    next[index] = null;
    state = state.copyWith(slots: next);
  }

  void clearAll() {
    state = state.copyWith(slots: List<LabelSlot?>.filled(kWideCount, null));
  }
}

// ─── Tel Etiketi sayfası ──────────────────────────────────────────────────────

/// Tel Etiketi sayfasının durumu: 32 hanelik liste (`null` = boş hane). Raf
/// Etiketi ile birebir aynı hücre tasarımını paylaşır (yalnız 4×8 ızgara);
/// mağaza logosu ayrı YÜKLENMEZ, Raf'ın kalıcı `LabelSheetState.logoDataUrl`
/// alanı doğrudan yeniden kullanılır (Poster sekmesinin zaten yaptığı gibi).
class LabelTelSheetState {
  final List<LabelSlot?> slots;

  const LabelTelSheetState({required this.slots});

  factory LabelTelSheetState.initial() => LabelTelSheetState(
        slots: List<LabelSlot?>.filled(kTelCount, null),
      );

  int get filledCount => slots.where((s) => s != null).length;

  LabelTelSheetState copyWith({List<LabelSlot?>? slots}) {
    return LabelTelSheetState(slots: slots ?? this.slots);
  }
}

/// Tel Etiketi sayfası durumunu tutar. `keepAlive` — sekme değişiminde 32 hane
/// korunur (Raf/Geniş Logo provider'larıyla KARIŞMAZ).
@Riverpod(keepAlive: true)
class LabelTelSheet extends _$LabelTelSheet {
  @override
  LabelTelSheetState build() => LabelTelSheetState.initial();

  void setSlot(int index, LabelSlot slot) {
    if (index < 0 || index >= kTelCount) return;
    final next = List<LabelSlot?>.from(state.slots);
    next[index] = slot;
    state = state.copyWith(slots: next);
  }

  void clearSlot(int index) {
    if (index < 0 || index >= kTelCount) return;
    final next = List<LabelSlot?>.from(state.slots);
    next[index] = null;
    state = state.copyWith(slots: next);
  }

  void clearAll() {
    state = state.copyWith(slots: List<LabelSlot?>.filled(kTelCount, null));
  }
}

// ─── Tel İndirim Etiketi sayfası ──────────────────────────────────────────────

/// Tel İndirim Etiketi sayfasının durumu: Tel Etiketi ile AYNI sabit 32 hane
/// (`kTelCount`/`kTelColumns`/`kTelRows` yeniden kullanılır — yeni bir ızgara
/// sabiti YOK, aynı fiziksel boyut). Sayfa geneli bir indirim türü+değeri
/// (`generalKind`/`generalValue`) tutar; hane kendi `useGeneral`'ı false ise
/// bu genelden etkilenmez (bkz. `TelDiscountLabelSlot`). Mağaza logosu ayrı
/// YÜKLENMEZ, Tel/Raf'ın kalıcı `LabelSheetState.logoDataUrl`'i paylaşılır.
class LabelTelDiscountSheetState {
  final List<TelDiscountLabelSlot?> slots;
  final TelDiscountKind generalKind;
  final num generalValue;

  const LabelTelDiscountSheetState({
    required this.slots,
    this.generalKind = TelDiscountKind.percent,
    this.generalValue = 0,
  });

  factory LabelTelDiscountSheetState.initial() => LabelTelDiscountSheetState(
        slots: List<TelDiscountLabelSlot?>.filled(kTelCount, null),
      );

  int get filledCount => slots.where((s) => s != null).length;

  LabelTelDiscountSheetState copyWith({
    List<TelDiscountLabelSlot?>? slots,
    TelDiscountKind? generalKind,
    num? generalValue,
  }) {
    return LabelTelDiscountSheetState(
      slots: slots ?? this.slots,
      generalKind: generalKind ?? this.generalKind,
      generalValue: generalValue ?? this.generalValue,
    );
  }
}

/// Tel İndirim Etiketi sayfası durumunu tutar. `keepAlive` — sekme
/// değişiminde 32 hane + genel indirim korunur (diğer etiket
/// provider'larıyla KARIŞMAZ).
@Riverpod(keepAlive: true)
class LabelTelDiscountSheet extends _$LabelTelDiscountSheet {
  @override
  LabelTelDiscountSheetState build() => LabelTelDiscountSheetState.initial();

  void setSlot(int index, TelDiscountLabelSlot slot) {
    if (index < 0 || index >= kTelCount) return;
    final next = List<TelDiscountLabelSlot?>.from(state.slots);
    next[index] = slot;
    state = state.copyWith(slots: next);
  }

  void clearSlot(int index) {
    if (index < 0 || index >= kTelCount) return;
    final next = List<TelDiscountLabelSlot?>.from(state.slots);
    next[index] = null;
    state = state.copyWith(slots: next);
  }

  void clearAll() {
    state = state.copyWith(
      slots: List<TelDiscountLabelSlot?>.filled(kTelCount, null),
    );
  }

  /// [index] hanesinin "genel indirimi kullan" tikini ayarlar (barkod/ürün/
  /// fiyat AYNI kalır).
  void setSlotUseGeneral(int index, bool value) {
    if (index < 0 || index >= state.slots.length) return;
    final current = state.slots[index];
    if (current == null) return;
    final next = List<TelDiscountLabelSlot?>.from(state.slots);
    next[index] = TelDiscountLabelSlot(
      barcode: current.barcode,
      productName: current.productName,
      oldPrice: current.oldPrice,
      createdAt: current.createdAt,
      useGeneral: value,
      ownKind: current.ownKind,
      ownValue: current.ownValue,
    );
    state = state.copyWith(slots: next);
  }

  /// [index] hanesinin kendi indirim türünü ayarlar (yalnız `useGeneral`
  /// false iken etkilidir).
  void setSlotOwnKind(int index, TelDiscountKind kind) {
    if (index < 0 || index >= state.slots.length) return;
    final current = state.slots[index];
    if (current == null) return;
    final next = List<TelDiscountLabelSlot?>.from(state.slots);
    next[index] = TelDiscountLabelSlot(
      barcode: current.barcode,
      productName: current.productName,
      oldPrice: current.oldPrice,
      createdAt: current.createdAt,
      useGeneral: current.useGeneral,
      ownKind: kind,
      ownValue: current.ownValue,
    );
    state = state.copyWith(slots: next);
  }

  /// [index] hanesinin kendi indirim değerini ayarlar (yalnız `useGeneral`
  /// false iken etkilidir).
  void setSlotOwnValue(int index, num? value) {
    if (index < 0 || index >= state.slots.length) return;
    final current = state.slots[index];
    if (current == null) return;
    final next = List<TelDiscountLabelSlot?>.from(state.slots);
    next[index] = TelDiscountLabelSlot(
      barcode: current.barcode,
      productName: current.productName,
      oldPrice: current.oldPrice,
      createdAt: current.createdAt,
      useGeneral: current.useGeneral,
      ownKind: current.ownKind,
      ownValue: value,
    );
    state = state.copyWith(slots: next);
  }

  /// Sayfa geneli indirim türünü ayarlar (% / ₺) — kendi türünü seçmemiş
  /// (`useGeneral: true`) tüm haneleri etkiler.
  void setGeneralKind(TelDiscountKind kind) {
    state = state.copyWith(generalKind: kind);
  }

  /// Sayfa geneli indirim değerini ayarlar.
  void setGeneralValue(num value) {
    state = state.copyWith(generalValue: value);
  }
}

// ─── İndirim Etiketi sayfası ──────────────────────────────────────────────────

/// İndirim Etiketi sayfasının durumu: sınırsız büyüyebilen hane listesi (2×2
/// A4 ızgara, 4/sayfa — barkod okutuldukça 2., 3. sayfaya taşar, bkz.
/// `paginateDiscountSlots`). `slots` her zaman TEK bir trailing `null`
/// (henüz taranmamış hane) ile biter; doldurulunca yeni bir `null` eklenir
/// (büyüme), dolu bir hane silinince liste küçülür. Raf/Tel ile aynı hücre
/// dilini paylaşır; mağaza logosu ayrı YÜKLENMEZ, sabit marka figürü
/// (`nice_logo_indirim.png`) kullanılır — hane başı `DiscountLabelSlot.showLogo`
/// tiki bu logonun o etikette basılıp basılmayacağını belirler.
/// [defaultPercent] — sayfa geneli "ana indirim %"; hane kendi yüzdesini
/// GİRMEMİŞSE (`DiscountLabelSlot.discountPercent == null`) bu değer geçerli
/// olur. Hane kendi yüzdesini girdiyse genel yüzde değişse bile o haneyi
/// ETKİLEMEZ.
class LabelDiscountSheetState {
  final List<DiscountLabelSlot?> slots;
  final num defaultPercent;

  const LabelDiscountSheetState({
    required this.slots,
    this.defaultPercent = 0,
  });

  factory LabelDiscountSheetState.initial() =>
      LabelDiscountSheetState(slots: [null]);

  int get filledCount => slots.where((s) => s != null).length;

  /// Baskıda oluşacak A4 sayfa sayısı (en az 1) — Ürün Etiketi'nin
  /// `pageCount` deseniyle aynı.
  int get pageCount => filledCount == 0
      ? 1
      : (filledCount + kDiscountCount - 1) ~/ kDiscountCount;

  LabelDiscountSheetState copyWith({
    List<DiscountLabelSlot?>? slots,
    num? defaultPercent,
  }) {
    return LabelDiscountSheetState(
      slots: slots ?? this.slots,
      defaultPercent: defaultPercent ?? this.defaultPercent,
    );
  }
}

/// İndirim Etiketi sayfası durumunu tutar. `keepAlive` — sekme değişiminde
/// hane listesi korunur (diğer etiket provider'larıyla KARIŞMAZ). Liste
/// sınırsız büyür (4/sayfa taşan A4, bkz. `paginateDiscountSlots`).
@Riverpod(keepAlive: true)
class LabelDiscountSheet extends _$LabelDiscountSheet {
  @override
  LabelDiscountSheetState build() => LabelDiscountSheetState.initial();

  /// [index]'teki haneyi ayarlar. Doldurulan hane listenin SON (boş) hanesiyse
  /// büyüme için yeni bir boş hane EKLENİR — liste her zaman tek bir boş
  /// hane ile biter (bir sonraki taramaya hazır, ekran tarafı bunu
  /// `_syncDiscountControllers` ile ayna görür).
  void setSlot(int index, DiscountLabelSlot slot) {
    if (index < 0 || index >= state.slots.length) return;
    final next = List<DiscountLabelSlot?>.from(state.slots);
    next[index] = slot;
    if (index == next.length - 1) next.add(null);
    state = state.copyWith(slots: next);
  }

  /// Yalnız yüzdeyi günceller (barkod/ürün/fiyat AYNI kalır) — "İndirim %"
  /// hanesine yazarken her tuş vuruşunda ürünü yeniden çözmeye gerek yok.
  /// `null` → hane kendi yüzdesini TEMİZLER (genel yüzdeye geri döner).
  void setDiscountPercent(int index, num? percent) {
    if (index < 0 || index >= state.slots.length) return;
    final current = state.slots[index];
    if (current == null) return;
    final next = List<DiscountLabelSlot?>.from(state.slots);
    next[index] = DiscountLabelSlot(
      barcode: current.barcode,
      productName: current.productName,
      oldPrice: current.oldPrice,
      discountPercent: percent,
      showLogo: current.showLogo,
      createdAt: current.createdAt,
    );
    state = state.copyWith(slots: next);
  }

  /// Hane-başı "logo göster" tiki (varsayılan false — bkz.
  /// `DiscountLabelSlot.showLogo`).
  void setShowLogo(int index, bool value) {
    if (index < 0 || index >= state.slots.length) return;
    final current = state.slots[index];
    if (current == null) return;
    final next = List<DiscountLabelSlot?>.from(state.slots);
    next[index] = current.copyWith(showLogo: value);
    state = state.copyWith(slots: next);
  }

  /// Sayfa geneli "ana indirim %"sini ayarlar — kendi yüzdesi olmayan (`null`)
  /// tüm haneleri etkiler.
  void setDefaultPercent(num percent) {
    state = state.copyWith(defaultPercent: percent);
  }

  /// "Ana İndirim %" satırındaki toplu tik — o anda DOLU olan TÜM hanelerin
  /// `showLogo`'sunu tek seferde [value] yapar (yalnız o an var olan haneleri
  /// etkiler, sonradan taranacak yeni haneler yine tiksiz başlar).
  void setAllShowLogo(bool value) {
    final next = [
      for (final s in state.slots) s?.copyWith(showLogo: value),
    ];
    state = state.copyWith(slots: next);
  }

  /// [index] zaten boşsa (trailing hane) no-op. DOLU bir haneyse listeden
  /// tamamen ÇIKARIR (sonraki haneler bir yukarı kayar) — liste her zaman
  /// tek bir trailing `null` ile bitecek şekilde korunur.
  void removeSlot(int index) {
    if (index < 0 || index >= state.slots.length) return;
    if (state.slots[index] == null) return;
    final next = List<DiscountLabelSlot?>.from(state.slots)..removeAt(index);
    if (next.isEmpty || next.last != null) next.add(null);
    state = state.copyWith(slots: next);
  }

  void clearAll() {
    state = state.copyWith(slots: [null]);
  }
}

// ─── Poster sayfası (KARAR v1.23 / v1.24) ────────────────────────────────────

/// Poster sayfasının durumu: barkod okutulan/ürün adıyla aranan ürünlerin
/// (ad + fiyat) büyümesi serbest bir liste. Sabit hane sayısı YOK (Yeni/Geniş
/// etiketlerin aksine) — 1 ürün de, 10+ ürün de olabilir; A4 sayfa doldukça
/// `paginatePosterItems` ile çok-sayfalıya böler. Aynı barkod tekrar
/// okutulursa (fiyat/ad güncellenmiş olabilir) mevcut satır YERİNDE
/// güncellenir, yeni satır EKLENMEZ (barkodu olmayan ürünler her zaman
/// eklenir — boş barkod eşleşmesiyle birbirinin üzerine YAZILMAZ).
/// [title] boşsa baskıda `kPosterDefaultTitle` kullanılır (KARAR v1.24).
class LabelPosterSheetState {
  final List<LabelSlot> items;
  final String title;
  final bool showBarcode;

  const LabelPosterSheetState({
    required this.items,
    this.title = '',
    this.showBarcode = false,
  });

  factory LabelPosterSheetState.initial() =>
      const LabelPosterSheetState(items: []);

  int get itemCount => items.length;

  /// Kullanıcı başlığı boşsa varsayılana düşer (baskı/önizleme bunu kullanır).
  String get effectiveTitle =>
      title.trim().isEmpty ? kPosterDefaultTitle : title.trim();

  LabelPosterSheetState copyWith({
    List<LabelSlot>? items,
    String? title,
    bool? showBarcode,
  }) {
    return LabelPosterSheetState(
      items: items ?? this.items,
      title: title ?? this.title,
      showBarcode: showBarcode ?? this.showBarcode,
    );
  }
}

/// Poster sayfası durumunu tutar. `keepAlive` — sekme değişiminde liste/
/// başlık/barkod tercihi korunur (diğer etiket provider'larıyla KARIŞMAZ).
/// Mağaza logosu dar-logo `LabelSheet`'in kalıcı store logosundan paylaşılır
/// (bu sekmede ayrı logo yükleme YOK).
@Riverpod(keepAlive: true)
class LabelPosterSheet extends _$LabelPosterSheet {
  @override
  LabelPosterSheetState build() => LabelPosterSheetState.initial();

  /// Barkodu zaten listede olan bir ürün tekrar okutulursa satırı yerinde
  /// günceller (fiyat/ad tazelenir); yoksa listenin sonuna ekler. Barkodu
  /// olmayan ürünler (ad araması ile eklenenler) eşleşme aranmadan HER ZAMAN
  /// eklenir — aksi halde boş barkod ("") ortak anahtar olup birbirinin
  /// üzerine yazardı.
  void addOrUpdateItem(LabelSlot slot) {
    if (slot.barcode.isNotEmpty) {
      final idx = state.items.indexWhere((it) => it.barcode == slot.barcode);
      if (idx >= 0) {
        final next = [...state.items];
        next[idx] = slot;
        state = state.copyWith(items: next);
        return;
      }
    }
    state = state.copyWith(items: [...state.items, slot]);
  }

  /// [index] kalemini listeden çıkarır.
  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final next = [...state.items]..removeAt(index);
    state = state.copyWith(items: next);
  }

  /// Tüm kalemleri temizler (başlık/barkod tercihi KORUNUR — yalnız liste sıfırlanır).
  void clearAll() => state = state.copyWith(items: []);

  /// Kullanıcının kendi başlığını ayarlar (boş → baskıda varsayılana döner).
  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  /// Her satırda ürün adının altında barkod numarasının da basılıp
  /// basılmayacağını ayarlar.
  void setShowBarcode(bool value) {
    state = state.copyWith(showBarcode: value);
  }
}

// ─── Ürün Etiketi sayfası (KARAR v1.21) ──────────────────────────────────────

/// Ürün Etiketi sayfasının durumu: adet-tabanlı kalem listesi (ürün adı ·
/// barkod · adet). Fiyat/logo YOK. Kalemler adet kadar çoğaltılıp 72'lik
/// ızgaraya dizilir; toplam > 72 ise 2., 3. sayfaya taşar. Diğer etiket
/// provider'larına (`LabelSheet`/`LabelWideSheet`/`LabelPosterSheet`) KARIŞMAZ.
class LabelProductSheetState {
  final List<ProductLabelItem> items;

  const LabelProductSheetState({required this.items});

  factory LabelProductSheetState.initial() =>
      const LabelProductSheetState(items: []);

  /// Adet kadar çoğaltılınca oluşacak toplam etiket sayısı.
  int get totalLabels => items.fold(0, (sum, it) => sum + it.quantity);

  /// Baskıda oluşacak A4 sayfa sayısı (en az 1; her sayfa 72 etiket).
  int get pageCount => totalLabels == 0
      ? 1
      : (totalLabels + kProductLabelPerPage - 1) ~/ kProductLabelPerPage;

  LabelProductSheetState copyWith({List<ProductLabelItem>? items}) {
    return LabelProductSheetState(items: items ?? this.items);
  }
}

/// Ürün Etiketi sayfası durumunu tutar. `keepAlive` — sekme değişiminde kalem
/// listesi korunur (UI-durumu provider'ı; dar/geniş/büyük etiket
/// provider'larıyla KARIŞMAZ). Mağaza logosu paylaşılmaz (bu sekmede logo yok).
@Riverpod(keepAlive: true)
class LabelProductSheet extends _$LabelProductSheet {
  @override
  LabelProductSheetState build() => LabelProductSheetState.initial();

  /// Listeye yeni bir kalem (ürün adı · barkod · adet) ekler.
  void addItem(ProductLabelItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  /// [index] kalemini listeden çıkarır.
  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final next = [...state.items]..removeAt(index);
    state = state.copyWith(items: next);
  }

  /// [index] kaleminin adedini günceller (0/negatif → kalem silinir).
  void updateQuantity(int index, int quantity) {
    if (index < 0 || index >= state.items.length) return;
    if (quantity <= 0) {
      removeItem(index);
      return;
    }
    final next = [...state.items];
    next[index] = next[index].copyWith(quantity: quantity);
    state = state.copyWith(items: next);
  }

  /// Tüm kalemleri temizler.
  void clearAll() => state = LabelProductSheetState.initial();
}

// ─── Kayıtlı PDF'ler — Supabase Storage (KARAR v1.11) ────────────────────────

/// `etiket_pdfleri` bucket'ı için Storage repository (tekil örüntü).
@Riverpod(keepAlive: true)
LabelsStorageRepository labelsStorageRepository(
  LabelsStorageRepositoryRef ref,
) =>
    LabelsStorageRepository();

/// Kayıtlı etiket PDF'lerinin listesi (yeni → eski). Kaydetme/silme sonrası
/// `ref.invalidate(savedLabelFilesProvider)` ile yenilenir (autoDispose).
@riverpod
Future<List<SavedLabelFile>> savedLabelFiles(SavedLabelFilesRef ref) {
  return ref.watch(labelsStorageRepositoryProvider).list();
}

// ─── Etiket Havuzu (0032_label_pool.sql) ─────────────────────────────────────
// Mobil ürün formundaki "Etiket" butonundan beslenen, kullanıcılar/cihazlar
// arası PAYLAŞILAN kuyruk (yukarıdaki tüm provider'ların oturum-içi `keepAlive`
// deseninin AKSİNE — DB'de kalıcı). Etiket sayfasındaki "Havuz" sekmesi bunu
// kullanır.

@Riverpod(keepAlive: true)
LabelPoolRepository labelPoolRepository(LabelPoolRepositoryRef ref) =>
    LabelPoolRepository();

/// [labelType] için henüz PDF'e alınmamış (kontrol=0) Havuz kalemleri.
/// keepAlive DEĞİL (diğer etiket state provider'larının aksine) — bu
/// paylaşılan sunucu verisi, Havuz sekmesinden çıkılınca serbest bırakılır,
/// tekrar girilince TAZE çekilir (başka kullanıcının eklediği görünsün diye).
@riverpod
Future<List<LabelPoolItem>> labelPoolPending(
  LabelPoolPendingRef ref,
  String labelType,
) {
  return ref.watch(labelPoolRepositoryProvider).fetchPending(labelType);
}

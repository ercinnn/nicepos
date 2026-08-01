import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/labels_storage_repository.dart';
import '../data/models/label_slot.dart';
import '../data/models/product_label_item.dart';

part 'labels_provider.g.dart';

/// Raf etiketi sayfası sabitleri (KARAR v1.10): 3 sütun × 8 satır = 24 etiket.
const int kLabelColumns = 3;
const int kLabelRows = 8;
const int kLabelCount = kLabelColumns * kLabelRows; // 24

/// Geniş Logo etiket sabitleri (KARAR v1.14): 2 sütun × 5 satır = 10 etiket/A4.
const int kWideCols = 2;
const int kWideRows = 5;
const int kWideCount = kWideCols * kWideRows; // 10


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

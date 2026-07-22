import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/labels_storage_repository.dart';
import '../data/models/label_slot.dart';

part 'labels_provider.g.dart';

/// Raf etiketi sayfası sabitleri (KARAR v1.10): 3 sütun × 8 satır = 24 etiket.
const int kLabelColumns = 3;
const int kLabelRows = 8;
const int kLabelCount = kLabelColumns * kLabelRows; // 24

/// Geniş Logo etiket sabitleri (KARAR v1.14): 2 sütun × 5 satır = 10 etiket/A4.
const int kWideCols = 2;
const int kWideRows = 5;
const int kWideCount = kWideCols * kWideRows; // 10

/// Büyük Etiket sabitleri (KARAR v1.19): A4 dikey, merkez haç ile 2 sütun × 2
/// satır = 4 A5 etiket/A4. Her çeyrek tam yarım sayfa (105×148.5mm), dış margin
/// YOK; merkez haç (dikey x=105mm / yatay y=148.5mm) = hücre ayraçları.
const int kQuadCols = 2;
const int kQuadRows = 2;
const int kQuadCount = kQuadCols * kQuadRows; // 4

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

// ─── Büyük Etiket sayfası (KARAR v1.19) ──────────────────────────────────────

/// Büyük Etiket sayfasının durumu: 4 hanelik liste (`null` = boş hane). Mağaza
/// logosu ayrı tutulmaz — dar-logo `LabelSheet`'in kalıcı store logosu
/// (`logoDataUrl`) paylaşılır. dar 24-hane / geniş 10-hane provider'larıyla
/// KARIŞMAZ (bağımsız `keepAlive` state).
class LabelQuadSheetState {
  final List<LabelSlot?> slots;

  const LabelQuadSheetState({required this.slots});

  factory LabelQuadSheetState.initial() => LabelQuadSheetState(
        slots: List<LabelSlot?>.filled(kQuadCount, null),
      );

  int get filledCount => slots.where((s) => s != null).length;

  LabelQuadSheetState copyWith({List<LabelSlot?>? slots}) {
    return LabelQuadSheetState(slots: slots ?? this.slots);
  }
}

/// Büyük Etiket sayfası durumunu tutar. `keepAlive` — sekme değişiminde 4 hane
/// korunur (dar-logo `LabelSheet` deseninin logosuz 4-haneli kopyası; dar
/// 24-hane / geniş 10-hane provider'larıyla KARIŞMAZ).
@Riverpod(keepAlive: true)
class LabelQuadSheet extends _$LabelQuadSheet {
  @override
  LabelQuadSheetState build() => LabelQuadSheetState.initial();

  void setSlot(int index, LabelSlot slot) {
    if (index < 0 || index >= kQuadCount) return;
    final next = List<LabelSlot?>.from(state.slots);
    next[index] = slot;
    state = state.copyWith(slots: next);
  }

  void clearSlot(int index) {
    if (index < 0 || index >= kQuadCount) return;
    final next = List<LabelSlot?>.from(state.slots);
    next[index] = null;
    state = state.copyWith(slots: next);
  }

  void clearAll() {
    state = state.copyWith(slots: List<LabelSlot?>.filled(kQuadCount, null));
  }
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

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/labels_storage_repository.dart';
import '../data/models/label_slot.dart';

part 'labels_provider.g.dart';

/// Raf etiketi sayfası sabitleri (KARAR v1.10): 3 sütun × 8 satır = 24 etiket.
const int kLabelColumns = 3;
const int kLabelRows = 8;
const int kLabelCount = kLabelColumns * kLabelRows; // 24

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

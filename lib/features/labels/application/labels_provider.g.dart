// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'labels_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$labelsStorageRepositoryHash() =>
    r'729452d5eb2df7031fa17cbf470aa2483d176813';

/// `etiket_pdfleri` bucket'ı için Storage repository (tekil örüntü).
///
/// Copied from [labelsStorageRepository].
@ProviderFor(labelsStorageRepository)
final labelsStorageRepositoryProvider =
    Provider<LabelsStorageRepository>.internal(
      labelsStorageRepository,
      name: r'labelsStorageRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelsStorageRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LabelsStorageRepositoryRef = ProviderRef<LabelsStorageRepository>;
String _$savedLabelFilesHash() => r'bfdbd27ffabebb05c0f85c9e73c8cb22e356f4c8';

/// Kayıtlı etiket PDF'lerinin listesi (yeni → eski). Kaydetme/silme sonrası
/// `ref.invalidate(savedLabelFilesProvider)` ile yenilenir (autoDispose).
///
/// Copied from [savedLabelFiles].
@ProviderFor(savedLabelFiles)
final savedLabelFilesProvider =
    AutoDisposeFutureProvider<List<SavedLabelFile>>.internal(
      savedLabelFiles,
      name: r'savedLabelFilesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedLabelFilesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SavedLabelFilesRef = AutoDisposeFutureProviderRef<List<SavedLabelFile>>;
String _$labelSheetHash() => r'0841c322011ac99e9ca0ac63999bc3c175acb3d7';

/// Etiket sayfası durumunu tutar. `keepAlive` — kullanıcı başka sekmeye geçip
/// dönünce 24 hane + logo korunur (oturum içi kalıcılık; localStorage opsiyonel
/// bonus, KARAR v1.10). Satış sepeti notifier'ıyla aynı desen.
///
/// Copied from [LabelSheet].
@ProviderFor(LabelSheet)
final labelSheetProvider =
    NotifierProvider<LabelSheet, LabelSheetState>.internal(
      LabelSheet.new,
      name: r'labelSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelSheet = Notifier<LabelSheetState>;
String _$labelWideSheetHash() => r'3c452c713ceb119547a9f92bf5ab83b21b77aae3';

/// Geniş Logo etiket sayfası durumunu tutar. `keepAlive` — sekme değişiminde 10
/// hane korunur (dar-logo `LabelSheet` deseninin logosuz 10-haneli kopyası; dar
/// 24-hane provider'ıyla KARIŞMAZ).
///
/// Copied from [LabelWideSheet].
@ProviderFor(LabelWideSheet)
final labelWideSheetProvider =
    NotifierProvider<LabelWideSheet, LabelWideSheetState>.internal(
      LabelWideSheet.new,
      name: r'labelWideSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelWideSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelWideSheet = Notifier<LabelWideSheetState>;
String _$labelQuadSheetHash() => r'992a542ccf94036c37b5069d647d18730c1a0088';

/// Büyük Etiket sayfası durumunu tutar. `keepAlive` — sekme değişiminde 4 hane
/// korunur (dar-logo `LabelSheet` deseninin logosuz 4-haneli kopyası; dar
/// 24-hane / geniş 10-hane provider'larıyla KARIŞMAZ).
///
/// Copied from [LabelQuadSheet].
@ProviderFor(LabelQuadSheet)
final labelQuadSheetProvider =
    NotifierProvider<LabelQuadSheet, LabelQuadSheetState>.internal(
      LabelQuadSheet.new,
      name: r'labelQuadSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelQuadSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelQuadSheet = Notifier<LabelQuadSheetState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

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
String _$labelPoolRepositoryHash() =>
    r'e6b2eae36c9e0df3b4dc844fe624279f606fb8ef';

/// See also [labelPoolRepository].
@ProviderFor(labelPoolRepository)
final labelPoolRepositoryProvider = Provider<LabelPoolRepository>.internal(
  labelPoolRepository,
  name: r'labelPoolRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$labelPoolRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LabelPoolRepositoryRef = ProviderRef<LabelPoolRepository>;
String _$labelPoolPendingHash() => r'37ceac49b1e67c9c4eff551b3446724be00e8033';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// [labelType] için henüz PDF'e alınmamış (kontrol=0) Havuz kalemleri.
/// keepAlive DEĞİL (diğer etiket state provider'larının aksine) — bu
/// paylaşılan sunucu verisi, Havuz sekmesinden çıkılınca serbest bırakılır,
/// tekrar girilince TAZE çekilir (başka kullanıcının eklediği görünsün diye).
///
/// Copied from [labelPoolPending].
@ProviderFor(labelPoolPending)
const labelPoolPendingProvider = LabelPoolPendingFamily();

/// [labelType] için henüz PDF'e alınmamış (kontrol=0) Havuz kalemleri.
/// keepAlive DEĞİL (diğer etiket state provider'larının aksine) — bu
/// paylaşılan sunucu verisi, Havuz sekmesinden çıkılınca serbest bırakılır,
/// tekrar girilince TAZE çekilir (başka kullanıcının eklediği görünsün diye).
///
/// Copied from [labelPoolPending].
class LabelPoolPendingFamily extends Family<AsyncValue<List<LabelPoolItem>>> {
  /// [labelType] için henüz PDF'e alınmamış (kontrol=0) Havuz kalemleri.
  /// keepAlive DEĞİL (diğer etiket state provider'larının aksine) — bu
  /// paylaşılan sunucu verisi, Havuz sekmesinden çıkılınca serbest bırakılır,
  /// tekrar girilince TAZE çekilir (başka kullanıcının eklediği görünsün diye).
  ///
  /// Copied from [labelPoolPending].
  const LabelPoolPendingFamily();

  /// [labelType] için henüz PDF'e alınmamış (kontrol=0) Havuz kalemleri.
  /// keepAlive DEĞİL (diğer etiket state provider'larının aksine) — bu
  /// paylaşılan sunucu verisi, Havuz sekmesinden çıkılınca serbest bırakılır,
  /// tekrar girilince TAZE çekilir (başka kullanıcının eklediği görünsün diye).
  ///
  /// Copied from [labelPoolPending].
  LabelPoolPendingProvider call(String labelType) {
    return LabelPoolPendingProvider(labelType);
  }

  @override
  LabelPoolPendingProvider getProviderOverride(
    covariant LabelPoolPendingProvider provider,
  ) {
    return call(provider.labelType);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'labelPoolPendingProvider';
}

/// [labelType] için henüz PDF'e alınmamış (kontrol=0) Havuz kalemleri.
/// keepAlive DEĞİL (diğer etiket state provider'larının aksine) — bu
/// paylaşılan sunucu verisi, Havuz sekmesinden çıkılınca serbest bırakılır,
/// tekrar girilince TAZE çekilir (başka kullanıcının eklediği görünsün diye).
///
/// Copied from [labelPoolPending].
class LabelPoolPendingProvider
    extends AutoDisposeFutureProvider<List<LabelPoolItem>> {
  /// [labelType] için henüz PDF'e alınmamış (kontrol=0) Havuz kalemleri.
  /// keepAlive DEĞİL (diğer etiket state provider'larının aksine) — bu
  /// paylaşılan sunucu verisi, Havuz sekmesinden çıkılınca serbest bırakılır,
  /// tekrar girilince TAZE çekilir (başka kullanıcının eklediği görünsün diye).
  ///
  /// Copied from [labelPoolPending].
  LabelPoolPendingProvider(String labelType)
    : this._internal(
        (ref) => labelPoolPending(ref as LabelPoolPendingRef, labelType),
        from: labelPoolPendingProvider,
        name: r'labelPoolPendingProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$labelPoolPendingHash,
        dependencies: LabelPoolPendingFamily._dependencies,
        allTransitiveDependencies:
            LabelPoolPendingFamily._allTransitiveDependencies,
        labelType: labelType,
      );

  LabelPoolPendingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.labelType,
  }) : super.internal();

  final String labelType;

  @override
  Override overrideWith(
    FutureOr<List<LabelPoolItem>> Function(LabelPoolPendingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LabelPoolPendingProvider._internal(
        (ref) => create(ref as LabelPoolPendingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        labelType: labelType,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<LabelPoolItem>> createElement() {
    return _LabelPoolPendingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LabelPoolPendingProvider && other.labelType == labelType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, labelType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LabelPoolPendingRef on AutoDisposeFutureProviderRef<List<LabelPoolItem>> {
  /// The parameter `labelType` of this provider.
  String get labelType;
}

class _LabelPoolPendingProviderElement
    extends AutoDisposeFutureProviderElement<List<LabelPoolItem>>
    with LabelPoolPendingRef {
  _LabelPoolPendingProviderElement(super.provider);

  @override
  String get labelType => (origin as LabelPoolPendingProvider).labelType;
}

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
String _$labelTelSheetHash() => r'db8bb78540f059bb8453ed9d7f4d75466a7cb976';

/// Tel Etiketi sayfası durumunu tutar. `keepAlive` — sekme değişiminde 32 hane
/// korunur (Raf/Geniş Logo provider'larıyla KARIŞMAZ).
///
/// Copied from [LabelTelSheet].
@ProviderFor(LabelTelSheet)
final labelTelSheetProvider =
    NotifierProvider<LabelTelSheet, LabelTelSheetState>.internal(
      LabelTelSheet.new,
      name: r'labelTelSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelTelSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelTelSheet = Notifier<LabelTelSheetState>;
String _$labelTelDiscountSheetHash() =>
    r'60fedf1412272c1b1807fe436572e3272669ed17';

/// Tel İndirim Etiketi sayfası durumunu tutar. `keepAlive` — sekme
/// değişiminde 32 hane + genel indirim korunur (diğer etiket
/// provider'larıyla KARIŞMAZ).
///
/// Copied from [LabelTelDiscountSheet].
@ProviderFor(LabelTelDiscountSheet)
final labelTelDiscountSheetProvider =
    NotifierProvider<
      LabelTelDiscountSheet,
      LabelTelDiscountSheetState
    >.internal(
      LabelTelDiscountSheet.new,
      name: r'labelTelDiscountSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelTelDiscountSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelTelDiscountSheet = Notifier<LabelTelDiscountSheetState>;
String _$labelDiscountSheetHash() =>
    r'733219c893571be24f6e8ee95ada9e5c1ece3ae3';

/// İndirim Etiketi sayfası durumunu tutar. `keepAlive` — sekme değişiminde
/// hane listesi korunur (diğer etiket provider'larıyla KARIŞMAZ). Liste
/// sınırsız büyür (4/sayfa taşan A4, bkz. `paginateDiscountSlots`).
///
/// Copied from [LabelDiscountSheet].
@ProviderFor(LabelDiscountSheet)
final labelDiscountSheetProvider =
    NotifierProvider<LabelDiscountSheet, LabelDiscountSheetState>.internal(
      LabelDiscountSheet.new,
      name: r'labelDiscountSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelDiscountSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelDiscountSheet = Notifier<LabelDiscountSheetState>;
String _$labelPosterSheetHash() => r'4b298861d1dfb0c92c553a95aa5c189c0eb0685d';

/// Poster sayfası durumunu tutar. `keepAlive` — sekme değişiminde liste/
/// başlık/barkod tercihi korunur (diğer etiket provider'larıyla KARIŞMAZ).
/// Mağaza logosu dar-logo `LabelSheet`'in kalıcı store logosundan paylaşılır
/// (bu sekmede ayrı logo yükleme YOK).
///
/// Copied from [LabelPosterSheet].
@ProviderFor(LabelPosterSheet)
final labelPosterSheetProvider =
    NotifierProvider<LabelPosterSheet, LabelPosterSheetState>.internal(
      LabelPosterSheet.new,
      name: r'labelPosterSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelPosterSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelPosterSheet = Notifier<LabelPosterSheetState>;
String _$labelProductSheetHash() => r'8a55c900946aa2dafbe695b9c95a9c7e86340ea3';

/// Ürün Etiketi sayfası durumunu tutar. `keepAlive` — sekme değişiminde kalem
/// listesi korunur (UI-durumu provider'ı; dar/geniş/büyük etiket
/// provider'larıyla KARIŞMAZ). Mağaza logosu paylaşılmaz (bu sekmede logo yok).
///
/// Copied from [LabelProductSheet].
@ProviderFor(LabelProductSheet)
final labelProductSheetProvider =
    NotifierProvider<LabelProductSheet, LabelProductSheetState>.internal(
      LabelProductSheet.new,
      name: r'labelProductSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelProductSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelProductSheet = Notifier<LabelProductSheetState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

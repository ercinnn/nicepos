import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../application/products_provider.dart';
import '../../data/models/company.dart';

/// Firma otomatik tamamlama alanı — paylaşılan (`product_form_screen.dart`
/// "Diğer Detaylar" formu + `missing_list_tab.dart` Eksik Listesi Firma
/// hücresi tıkla-düzenle akışı AYNI widget'ı kullanır).
///
/// KURAL: girilen önek (starts with, Türkçe-duyarlı) TAM 1 firmayla eşleşirse
/// overlay o tek öğeyi gösterir; 0 ya da ≥2 eşleşmede overlay HİÇ açılmaz.
/// Örn. firmalar = {PALA, PERDECİ}: "P"→2 eşleşme→kapalı, "PA"→1→PALA,
/// "PE"→1→PERDECİ. Seçim/Enter → alan tam firma adıyla dolar.
class CompanyAutocompleteField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final ValueChanged<String>? onSubmitted;
  // Sıkı hücre-içi kullanım (ör. bir rapor tablosunun tıkla-düzenle hücresi)
  // — etiketsiz, düşük dolgulu, `products_list_screen.dart` `_editableField`
  // ile aynı `isDense` deseni. false: product_form_screen.dart'taki normal
  // form görünümü (floating label, standart dolgu) KORUNUR.
  final bool dense;
  final bool autofocus;

  const CompanyAutocompleteField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.labelText = 'Firma',
    this.onSubmitted,
    this.dense = false,
    this.autofocus = false,
  });

  @override
  ConsumerState<CompanyAutocompleteField> createState() =>
      _CompanyAutocompleteFieldState();
}

class _CompanyAutocompleteFieldState
    extends ConsumerState<CompanyAutocompleteField> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  double _fieldWidth = 320;
  Company? _match; // önekle eşleşen TEK firma (varsa)

  // Türkçe küçük harf: önce I→ı, İ→i eşle, sonra toLowerCase().
  // (product_repository.dart'taki katlama mantığının aynısı.)
  static String _trLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) _portal.hide();
  }

  void _onChanged(String value) {
    final prefix = value.trim();
    if (prefix.isEmpty) {
      _match = null;
      _portal.hide();
      return;
    }
    final companies = ref.read(companiesProvider).value ?? const <Company>[];
    final needle = _trLower(prefix);
    // "starts with" önek filtresi (Türkçe-duyarlı).
    final matches =
        companies.where((c) => _trLower(c.name).startsWith(needle)).toList();
    // Overlay yalnızca TAM 1 eşleşmede açılır.
    if (matches.length == 1) {
      setState(() => _match = matches.first);
      if (widget.focusNode.hasFocus) _portal.show();
    } else {
      _match = null;
      _portal.hide();
    }
  }

  void _select(Company company) {
    widget.controller.text = company.name;
    widget.controller.selection = TextSelection.collapsed(
      offset: company.name.length,
    );
    _match = null;
    _portal.hide();
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // Firma listesini yükle/aboneliği canlı tut (onChanged ref.read ile okur).
    ref.watch(companiesProvider);
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final match = _match;
        if (match == null) return const SizedBox.shrink();
        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: TextFieldTapRegion(
              child: SizedBox(
                width: _fieldWidth,
                child: _buildDropdown(match),
              ),
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
              controller: widget.controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              style: widget.dense ? const TextStyle(fontSize: 13) : null,
              decoration: widget.dense
                  ? const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: AppSizes.space6,
                        horizontal: AppSizes.space8,
                      ),
                    )
                  : InputDecoration(labelText: widget.labelText),
              onChanged: _onChanged,
              onSubmitted: (value) {
                final match = _match;
                if (match != null) _select(match);
                _portal.hide();
                widget.onSubmitted?.call(widget.controller.text);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDropdown(Company match) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _select(match),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space12,
              vertical: AppSizes.space8,
            ),
            child: Text(
              match.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

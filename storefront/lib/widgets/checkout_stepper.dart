import 'package:flutter/material.dart';

import '../core/theme.dart';

// Checkout stepper — design-tokens.md §9. Yalnız akış-görünürlüğü içindir,
// bir ÖDEME adımı DEĞİLDİR (iyzico entegrasyonu henüz yok) — "Ödeme"
// kelimesi adım etiketi olarak KULLANILMAZ. Gold KULLANILMAZ.
class CheckoutStepper extends StatelessWidget {
  static const _labels = ['Sepet', 'Teslimat Bilgileri', 'Sipariş Onayı'];

  /// 0-tabanlı aktif adım index'i. Öncesindeki adımlar tamamlanmış, sonrası
  /// gelecek adım sayılır.
  final int activeIndex;

  const CheckoutStepper({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      if (i > 0) {
        final connectorDone = i <= activeIndex;
        children.add(
          Expanded(
            child: Padding(
              // 26px dairenin dikey merkeziyle hizalanır (yarıçap 13).
              padding: const EdgeInsets.only(top: 13, left: 4, right: 4),
              child: Container(
                height: 2,
                color: connectorDone ? StoreColors.navy : StoreColors.border,
              ),
            ),
          ),
        );
      }
      children.add(
        _StepDot(index: i, label: _labels[i], activeIndex: activeIndex),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final int activeIndex;

  const _StepDot({
    required this.index,
    required this.label,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    final completed = index < activeIndex;
    final active = index == activeIndex;

    Widget circle;
    if (completed) {
      circle = Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: StoreColors.navy,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.check, size: 12, color: Colors.white),
      );
    } else if (active) {
      circle = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: StoreColors.navy, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: StoreColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    } else {
      circle = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: StoreColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: StoreColors.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 4), // space.xs
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? StoreColors.textPrimary : StoreColors.textMuted,
          ),
        ),
      ],
    );
  }
}

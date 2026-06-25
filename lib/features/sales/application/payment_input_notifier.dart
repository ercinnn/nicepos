import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/sale.dart';

part 'payment_input_notifier.g.dart';

class PaymentInputState {
  final PaymentType type;
  final num paidAmount;
  final num cashSplit;
  final num cardSplit;

  const PaymentInputState({
    this.type = PaymentType.nakit,
    this.paidAmount = 0,
    this.cashSplit = 0,
    this.cardSplit = 0,
  });

  PaymentInputState copyWith({PaymentType? type, num? paidAmount, num? cashSplit, num? cardSplit}) {
    return PaymentInputState(
      type: type ?? this.type,
      paidAmount: paidAmount ?? this.paidAmount,
      cashSplit: cashSplit ?? this.cashSplit,
      cardSplit: cardSplit ?? this.cardSplit,
    );
  }
}

@Riverpod(keepAlive: true)
class PaymentInput extends _$PaymentInput {
  @override
  PaymentInputState build() => const PaymentInputState();

  void selectType(PaymentType type, num total) {
    switch (type) {
      case PaymentType.nakit:
      case PaymentType.pos:
        state = PaymentInputState(type: type, paidAmount: total);
        break;
      case PaymentType.acikHesap:
        state = PaymentInputState(type: type, paidAmount: 0);
        break;
      case PaymentType.parcali:
        state = PaymentInputState(type: type, cashSplit: total, cardSplit: 0);
        break;
    }
  }

  void setPaidAmount(num amount) => state = state.copyWith(paidAmount: amount);
  void setCashSplit(num amount) => state = state.copyWith(cashSplit: amount);
  void setCardSplit(num amount) => state = state.copyWith(cardSplit: amount);
  void reset() => state = const PaymentInputState();
}

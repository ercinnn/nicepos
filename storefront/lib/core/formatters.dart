import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

String formatCurrency(num value) => _currencyFormat.format(value);

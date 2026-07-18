import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);

final _dateFormat = DateFormat('dd/MM/yyyy', 'tr_TR');
final _dateTimeFormat = DateFormat('dd/MM/yyyy - HH:mm:ss', 'tr_TR');
final _shortDateFormat = DateFormat('dd MMM yyyy', 'tr_TR');

final _intFormat = NumberFormat.decimalPattern('tr_TR');
final _decimalFormat = NumberFormat('#,##0.##', 'tr_TR');

/// Tam sayıları binlik ayraçla, ondalıklı sayıları gerektiği kadar basamakla biçimler.
String formatNumber(num value) =>
    value == value.roundToDouble() ? _intFormat.format(value) : _decimalFormat.format(value);

String formatCurrency(num value) => _currencyFormat.format(value);
String formatDate(DateTime value) => _dateFormat.format(value);
String formatDateTime(DateTime value) => _dateTimeFormat.format(value);
String formatShortDate(DateTime value) => _shortDateFormat.format(value);

/// Türkçe büyük harf katlaması: Dart'ın yerleşik `toUpperCase()`'i i/İ, ı/I
/// çiftlerini yanlış katlar (ör. "kırmızı" → "KıRMıZı" değil "KIRMIZI"
/// olmalı) — önce i→İ, ı→I eşlenir, sonra `toUpperCase()` çağrılır.
String trUpperCase(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

const _ones = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
  'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
  'sixteen', 'seventeen', 'eighteen', 'nineteen',
];
const _tens = [
  '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
  'eighty', 'ninety',
];
const _scales = ['', 'thousand', 'million', 'billion', 'trillion'];

String _threeDigitsToWords(int n) {
  final parts = <String>[];
  if (n >= 100) {
    parts.add('${_ones[n ~/ 100]} hundred');
    n %= 100;
  }
  if (n >= 20) {
    var t = _tens[n ~/ 10];
    final rem = n % 10;
    if (rem > 0) t += '-${_ones[rem]}';
    parts.add(t);
  } else if (n > 0) {
    parts.add(_ones[n]);
  }
  return parts.join(' ');
}

/// Negatif olmayan bir tam sayıyı İngilizce kelimelere çevirir (ör. 1234 → "one thousand two hundred thirty-four").
String intToEnglishWords(int n) {
  if (n == 0) return 'zero';
  final groups = <int>[];
  var v = n;
  while (v > 0) {
    groups.add(v % 1000);
    v ~/= 1000;
  }
  final parts = <String>[];
  for (var i = groups.length - 1; i >= 0; i--) {
    if (groups[i] == 0) continue;
    final words = _threeDigitsToWords(groups[i]);
    parts.add(_scales[i].isEmpty ? words : '$words ${_scales[i]}');
  }
  return parts.join(' ');
}

/// Bir TL tutarını İngilizce konuşma metnine çevirir.
/// Örnek: 20 → "twenty turkish lira", 20.50 → "twenty turkish lira and fifty kuruş".
/// Ondalık yuvarlama hatasından kaçınmak için tutar kuruşa (×100) çevrilip tam
/// sayı üzerinden işlenir.
String amountToEnglishWords(num amount) {
  final totalKurus = (amount.abs() * 100).round();
  final lira = totalKurus ~/ 100;
  final kurus = totalKurus % 100;
  final liraWords = intToEnglishWords(lira);
  if (kurus == 0) {
    return '$liraWords turkish lira';
  }
  final kurusWords = intToEnglishWords(kurus);
  return '$liraWords turkish lira and $kurusWords kuruş';
}

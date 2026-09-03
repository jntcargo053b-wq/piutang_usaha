import 'package:flutter/services.dart';

/// Formats a numeric input as Indonesian Rupiah thousands-separated text.
///
/// The underlying value remains an integer Rupiah; separators are only for
/// display while the user is typing.
class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = _groupThousands(normalized);

    final digitsBeforeCursor = newValue.text
        .substring(0, newValue.selection.baseOffset.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final cursor = _cursorForDigitCount(formatted, digitsBeforeCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  static String _groupThousands(String value) {
    final first = value.length % 3;
    final buffer = StringBuffer();
    if (first != 0) {
      buffer.write(value.substring(0, first));
    }
    for (var i = first; i < value.length; i += 3) {
      if (buffer.length > 0) buffer.write('.');
      buffer.write(value.substring(i, i + 3));
    }
    return buffer.toString();
  }

  static int _cursorForDigitCount(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (_isDigit(formatted.codeUnitAt(i))) {
        seen++;
        if (seen == digitCount) return i + 1;
      }
    }
    return formatted.length;
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
}

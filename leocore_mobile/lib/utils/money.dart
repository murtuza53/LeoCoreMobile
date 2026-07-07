import 'package:intl/intl.dart';

/// BHD money formatting — always 3 decimals, grouped thousands, tabular figures.
///
/// Matches the prototype's `fmt()` which used
/// `toLocaleString('en-US', { minimumFractionDigits: 3, maximumFractionDigits: 3 })`.
class Money {
  static final NumberFormat _f = NumberFormat('#,##0.000', 'en_US');

  static String fmt(num n) => _f.format(n);
}

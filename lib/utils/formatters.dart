import 'package:intl/intl.dart';

class CurrencyFormatter {
  // Standard Philippine Peso format with commas and no decimals
  static final NumberFormat phPesos = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  // Standard comma formatter for counts (e.g., 1,000 customers)
  static final NumberFormat count = NumberFormat('#,###');

  // Helper method for easy access
  static String format(dynamic amount) => phPesos.format(amount);
}
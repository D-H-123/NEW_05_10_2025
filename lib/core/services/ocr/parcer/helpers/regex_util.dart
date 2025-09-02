// lib/services/ocr/parser/helpers/regex_util.dart
import 'package:intl/intl.dart';

class AmountMatch {
  final double amount;
  final String? currency;
  final int lineIndex;
  AmountMatch(this.amount, {this.currency, required this.lineIndex});
}

class RegexUtil {
  final List<RegExp> _dateRegexes = [
    // dd/mm/yyyy, d/m/yy etc.
    RegExp(r'\b(\d{1,2}[\/\.-]\d{1,2}[\/\.-]\d{2,4})\b'),
    // yyyy-mm-dd
    RegExp(r'\b(\d{4}[\/\.-]\d{1,2}[\/\.-]\d{1,2})\b'),
    // Month name dd, yyyy or dd Month yyyy
    RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*[ ,.-]+\d{1,2}[, ]+\d{4}\b', caseSensitive: false),
    RegExp(r'\b\d{1,2}[ ]+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*[ ,.-]*\d{4}\b', caseSensitive: false),
  ];

  // matches currency amounts with optional currency symbol - enhanced for multiple currencies
  final RegExp _moneyRegex = RegExp(r'([€£$¥₹₽₩₪₦₨₱₲₴₵₸₺₼₾₿])?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?)');

  // keywords for total - prioritize final amounts including tax
  final List<String> totalKeywords = [
    'TOTAL',
    'AMOUNT DUE',
    'BALANCE DUE',
    'AMOUNT',
    'NET TOTAL',
    'FINAL TOTAL',
    'GRAND TOTAL',
    'TOTAL DUE',
    'PAYMENT DUE',
    'CARD TOTAL',
    'CASH TOTAL',
    'RECEIPT TOTAL',
  ];

  // Enhanced currency codes and symbols mapping
  final Map<String, String> _currencySymbols = {
    'USD': '\$',    // US Dollar
    'EUR': '€',     // Euro
    'GBP': '£',     // British Pound
    'JPY': '¥',     // Japanese Yen
    'AUD': 'A\$',   // Australian Dollar
    'CAD': 'C\$',   // Canadian Dollar
    'CHF': 'CHF',   // Swiss Franc
    'CNY': '¥',     // Chinese Yuan
    'INR': '₹',     // Indian Rupee
    'RUB': '₽',     // Russian Ruble
    'KRW': '₩',     // South Korean Won
    'ILS': '₪',     // Israeli Shekel
    'NGN': '₦',     // Nigerian Naira
    'PKR': '₨',     // Pakistani Rupee
    'PHP': '₱',     // Philippine Peso
    'BGN': '₲',     // Bulgarian Lev
    'UAH': '₴',     // Ukrainian Hryvnia
    'GHS': '₵',     // Ghanaian Cedi
    'KZT': '₸',     // Kazakhstani Tenge
    'TRY': '₺',     // Turkish Lira
    'AZN': '₼',     // Azerbaijani Manat
    'GEL': '₾',     // Georgian Lari
    'BTC': '₿',     // Bitcoin
  };

  // Enhanced currency codes (ISO) — comprehensive list
  final RegExp _isoCurrency = RegExp(r'\b(USD|EUR|GBP|JPY|AUD|CAD|CHF|CNY|INR|RUB|KRW|ILS|NGN|PKR|PHP|BGN|UAH|GHS|KZT|TRY|AZN|GEL|BTC)\b', caseSensitive: false);
  final List<String> transportKeywords = ['FUEL','GAS','GASOLINE','DIESEL','PETROL'];
  final List<String> groceryKeywords = ['GROCERY','SUPERMARKET','MARKET','GROCER'];
  final List<String> restaurantKeywords = ['RESTAURANT','CAFE','DINER','PIZZA','BAR'];
  final List<String> pharmacyKeywords = ['PHARMACY','DRUG','APOTHECARY'];

  DateTime? findFirstDate(String text) {
    for (final rx in _dateRegexes) {
      final m = rx.firstMatch(text);
      if (m != null) {
        final str = m.group(0)!;
        final dt = _tryParseDate(str);
        if (dt != null) return dt;
      }
    }
    return null;
  }

  DateTime? _tryParseDate(String s) {
    final trials = [
      'dd/MM/yyyy',
      'd/M/yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'dd.MM.yyyy',
    ];
    for (final f in trials) {
      try {
        final df = DateFormat(f);
        return df.parseLoose(s);
      } catch (e) {
        // continue
      }
    }
    // try generic parse
    try {
      return DateTime.parse(s.replaceAll('.', '-').replaceAll('/', '-'));
    } catch (e) {
      return null;
    }
  }

  /// Infer category name from free-text content using simple keyword lists
  String? inferCategoryFromText(String text) {
    final up = text.toUpperCase();
    bool containsAny(List<String> words) => words.any((w) => up.contains(w));
    if (containsAny(transportKeywords)) return 'Transport';
    if (containsAny(groceryKeywords)) return 'Groceries';
    if (containsAny(restaurantKeywords)) return 'Food & Dining';
    if (containsAny(pharmacyKeywords)) return 'Pharmacy';
    return null;
  }

  /// returns currency symbol found in text or null
  String? findCurrencySymbol(String text) {
    // First check for currency symbols in the text
    final m = _moneyRegex.firstMatch(text);
    if (m != null && m.group(1) != null && m.group(1)!.isNotEmpty) {
      return m.group(1);
    }
    
    // Then check for ISO currency codes
    final c = _isoCurrency.firstMatch(text);
    if (c != null) return c.group(0);
    
    // Check for specific currency patterns
    if (text.contains('A\$') || text.contains('AUD')) return 'AUD';
    if (text.contains('C\$') || text.contains('CAD')) return 'CAD';
    if (text.contains('US\$') || text.contains('USD')) return 'USD';
    
    return null;
  }

  /// Detect currency from text with enhanced logic
  String? detectCurrency(String text) {
    print('🔍 MAGIC CURRENCY: Starting currency detection');
    print('🔍 MAGIC CURRENCY: Text length: ${text.length}');
    
    final upperText = text.toUpperCase();
    
    // Check for currency codes first
    final isoMatch = _isoCurrency.firstMatch(upperText);
    if (isoMatch != null) {
      print('🔍 MAGIC CURRENCY: Found ISO currency code: ${isoMatch.group(0)}');
      return isoMatch.group(0);
    }
    
    // Check for currency symbols
    for (final entry in _currencySymbols.entries) {
      if (text.contains(entry.value)) {
        print('🔍 MAGIC CURRENCY: Found currency symbol ${entry.value} -> ${entry.key}');
        return entry.key;
      }
    }
    
    // Check for specific patterns
    if (upperText.contains('DOLLAR') || upperText.contains('USD')) {
      print('🔍 MAGIC CURRENCY: Found USD pattern');
      return 'USD';
    }
    if (upperText.contains('EURO') || upperText.contains('EUR')) {
      print('🔍 MAGIC CURRENCY: Found EUR pattern');
      return 'EUR';
    }
    if (upperText.contains('POUND') || upperText.contains('GBP')) {
      print('🔍 MAGIC CURRENCY: Found GBP pattern');
      return 'GBP';
    }
    if (upperText.contains('YEN') || upperText.contains('JPY')) {
      print('🔍 MAGIC CURRENCY: Found JPY pattern');
      return 'JPY';
    }
    if (upperText.contains('AUS') || upperText.contains('AUD')) {
      print('🔍 MAGIC CURRENCY: Found AUD pattern');
      return 'AUD';
    }
    if (upperText.contains('CAN') || upperText.contains('CAD')) {
      print('🔍 MAGIC CURRENCY: Found CAD pattern');
      return 'CAD';
    }
    if (upperText.contains('SWISS') || upperText.contains('CHF')) {
      print('🔍 MAGIC CURRENCY: Found CHF pattern');
      return 'CHF';
    }
    if (upperText.contains('YUAN') || upperText.contains('CNY')) {
      print('🔍 MAGIC CURRENCY: Found CNY pattern');
      return 'CNY';
    }
    if (upperText.contains('RUPEE') || upperText.contains('INR')) {
      print('🔍 MAGIC CURRENCY: Found INR pattern');
      return 'INR';
    }
    if (upperText.contains('RUBLE') || upperText.contains('RUB')) {
      print('🔍 MAGIC CURRENCY: Found RUB pattern');
      return 'RUB';
    }
    if (upperText.contains('WON') || upperText.contains('KRW')) {
      print('🔍 MAGIC CURRENCY: Found KRW pattern');
      return 'KRW';
    }
    
    print('🔍 MAGIC CURRENCY: No currency detected');
    return null;
  }

  /// Get currency symbol from currency code
  String? getCurrencySymbol(String currencyCode) {
    return _currencySymbols[currencyCode.toUpperCase()];
  }

  /// Search lines for keywords like TOTAL and return first amount found on that line
  /// Prioritizes final amounts including tax
  AmountMatch? findTotalByKeywords(List<String> lines) {
    print('🔍 MAGIC TOTAL: Starting total detection with ${lines.length} lines');
    
    // First, look for final total keywords (highest priority)
    final finalTotalKeywords = ['AMOUNT DUE', 'BALANCE DUE', 'FINAL TOTAL', 'GRAND TOTAL', 'TOTAL DUE', 'PAYMENT DUE', ' RECEIPT TOTAL'];
    
    for (var i = 0; i < lines.length; i++) {
      final L = lines[i].toUpperCase();
      print('🔍 MAGIC TOTAL: Checking line $i: "$L"');
      
      for (final k in finalTotalKeywords) {
        if (L.contains(k)) {
          print('🔍 MAGIC TOTAL: Found final total keyword "$k" in line $i');
          final m = _moneyRegex.allMatches(lines[i]).toList();
          print('🔍 MAGIC TOTAL: Found ${m.length} money matches in line $i');
          
          if (m.isNotEmpty) {
            final last = m.last;
            final amt = _parseMoneyString(last.group(2)!);
            final currency = last.group(1);
            print('🔍 MAGIC TOTAL: Parsed amount: $amt, currency: $currency');
            
            if (amt != null) {
              print('🔍 MAGIC TOTAL: Returning final total: $amt');
              return AmountMatch(amt, currency: currency, lineIndex: i);
            }
          }
        }
      }
    }
    
    // Then look for regular total keywords
    print('🔍 MAGIC TOTAL: No final total found, checking regular total keywords');
    for (var i = 0; i < lines.length; i++) {
      final L = lines[i].toUpperCase();
      
      for (final k in totalKeywords) {
        if (L.contains(k)) {
          print('🔍 MAGIC TOTAL: Found regular total keyword "$k" in line $i');
          // extract last monetary token on the line
          final m = _moneyRegex.allMatches(lines[i]).toList();
          print('🔍 MAGIC TOTAL: Found ${m.length} money matches in line $i');
          
          if (m.isNotEmpty) {
            final last = m.last;
            final amt = _parseMoneyString(last.group(2)!);
            final currency = last.group(1);
            print('🔍 MAGIC TOTAL: Parsed amount: $amt, currency: $currency');
            
            if (amt != null) {
              print('🔍 MAGIC TOTAL: Returning regular total: $amt');
              return AmountMatch(amt, currency: currency, lineIndex: i);
            }
          }
        }
      }
    }
    
    print('🔍 MAGIC TOTAL: No total found by keywords');
    return null;
  }

  /// fallback: look for the largest monetary amount in the last N lines
  AmountMatch? findFallbackTotal(List<String> lines, {int tail = 6}) {
    final start = (lines.length - tail).clamp(0, lines.length);
    double? maxVal;
    int maxIdx = -1;
    String? currency;
    for (var i = start; i < lines.length; i++) {
      for (final m in _moneyRegex.allMatches(lines[i])) {
        final val = _parseMoneyString(m.group(2)!);
        if (val == null) continue;
        if (maxVal == null || val > maxVal) {
          maxVal = val;
          maxIdx = i;
          currency = m.group(1);
        }
      }
    }
    if (maxVal != null) return AmountMatch(maxVal, currency: currency, lineIndex: maxIdx);
    return null;
  }

  double? _parseMoneyString(String s) {
    // remove thousands separators intelligently
    s = s.replaceAll(' ', '');
    // If both dot and comma present: assume comma thousands, dot decimals OR vice versa based on positions.
    if (s.contains(',') && s.contains('.')) {
      // heuristic: if last separator is comma, interpret comma as decimal
      final lastComma = s.lastIndexOf(',');
      final lastDot = s.lastIndexOf('.');
      if (lastComma > lastDot) {
        s = s.replaceAll('.', '');
        s = s.replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else {
      // only commas or only dots
      // if comma present and no dot, treat comma as decimal if there are exactly 2 digits after it
      if (s.contains(',') && RegExp(r',\d{2}$').hasMatch(s)) {
        s = s.replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    }
    try {
      return double.parse(s);
    } catch (e) {
      return null;
    }
  }

  /// find amount for a label such as SUBTOTAL, TAX, VAT
  double? findAmountForLabel(List<String> lines, List<String> labels) {
    for (var i = 0; i < lines.length; i++) {
      final up = lines[i].toUpperCase();
      for (final label in labels) {
        if (up.contains(label)) {
          final matches = _moneyRegex.allMatches(lines[i]);
          if (matches.isNotEmpty) {
            final last = matches.last;
            return _parseMoneyString(last.group(2)!);
          }
          // maybe next token in next line
          if (i + 1 < lines.length) {
            final matchesNext = _moneyRegex.allMatches(lines[i + 1]);
            if (matchesNext.isNotEmpty) {
              return _parseMoneyString(matchesNext.last.group(2)!);
            }
          }
        }
      }
    }
    return null;
  }
}

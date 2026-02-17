import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_receipt/features/storage/models/bill_model.dart';

/// Singleton service for converting amounts using the Frankfurter API.
/// Conversion happens only at display time; stored receipt data is never modified.
class ExchangeRateService {
  ExchangeRateService._();
  static final ExchangeRateService instance = ExchangeRateService._();

  static const String _baseUrl = 'https://api.frankfurter.app/latest';

  /// In-memory cache: key = "fromCurrency_toCurrency", value = rate (1 from = rate to).
  final Map<String, double> _cache = {};

  /// Converts [amount] from [fromCurrency] to [toCurrency].
  /// Returns original amount if same currency or on API error (no crash).
  Future<double> convert(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    final from = _normalize(fromCurrency);
    final to = _normalize(toCurrency);
    if (from == to) return amount;
    if (amount == 0) return 0.0;

    final rate = await _getRate(from, to);
    if (rate == null) return amount; // fallback to original on error
    return amount * rate;
  }

  String _normalize(String c) {
    final s = (c.trim().toUpperCase());
    return s.isEmpty ? 'USD' : s;
  }

  String _cacheKey(String from, String to) => '${from}_$to';

  Future<double?> _getRate(String from, String to) async {
    final key = _cacheKey(from, to);
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final uri = Uri.parse('$_baseUrl?from=$from&to=$to');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Frankfurter API timeout'),
      );
      if (response.statusCode != 200) {
        _log('Frankfurter API error: ${response.statusCode}');
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = json['rates'] as Map<String, dynamic>?;
      final rate = rates?[to];
      if (rate == null) {
        _log('Frankfurter API: no rate for $to');
        return null;
      }
      final value = (rate is num) ? rate.toDouble() : null;
      if (value != null && value > 0) {
        _cache[key] = value;
        return value;
      }
    } catch (e) {
      _log('Exchange rate fetch error: $e');
    }
    return null;
  }

  void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print('[ExchangeRateService] $message');
      return true;
    }());
  }
}

/// Converts a bill's amount to the user's display currency.
/// Uses [displayCurrency] (e.g. from profile defaultCurrency).
/// Returns the converted amount; on error returns the original amount.
Future<double> convertBillToDisplayCurrency(
  Bill bill,
  String displayCurrency,
) async {
  final amount = bill.total ?? 0.0;
  final from = (bill.currency ?? 'USD').trim();
  if (from.isEmpty) return amount;
  return ExchangeRateService.instance.convert(
    amount,
    from,
    displayCurrency.trim().isEmpty ? 'USD' : displayCurrency,
  );
}

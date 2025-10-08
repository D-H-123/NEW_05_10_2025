import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'local_storage_service.dart';

class CurrencyState {
  final String currencyCode; // ISO 4217 e.g., USD
  const CurrencyState(this.currencyCode);
}

class CurrencyNotifier extends StateNotifier<CurrencyState> {
  CurrencyNotifier() : super(const CurrencyState('USD')) {
    _load();
  }

  Future<void> _load() async {
    final saved = LocalStorageService.getStringSetting(LocalStorageService.kCurrencyCode);
    if (saved != null && saved.isNotEmpty) {
      state = CurrencyState(saved);
      return;
    }
    final system = _systemDefaultCurrency();
    state = CurrencyState(system);
  }

  String _systemDefaultCurrency() {
    // Best-effort: map locale -> currency using NumberFormat
    try {
      final locale = PlatformDispatcher.instance.locale.toLanguageTag();
      final format = NumberFormat.simpleCurrency(locale: locale);
      final code = format.currencyName;
      if (code != null && code.isNotEmpty) return code;
    } catch (_) {}
    return 'USD';
  }

  Future<void> setCurrency(String code) async {
    state = CurrencyState(code);
    await LocalStorageService.setStringSetting(LocalStorageService.kCurrencyCode, code);
    await LocalStorageService.setBoolSetting(LocalStorageService.kHasCompletedCurrencySetup, true);
  }

  String symbolFor([String? code]) {
    final c = (code ?? state.currencyCode).toUpperCase();
    switch (c) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'CHF':
        return 'CHF';
      case 'INR':
        return '₹';
      case 'BRL':
        return 'R\$';
      default:
        try {
          return NumberFormat.simpleCurrency(name: c).currencySymbol;
        } catch (_) {
          return c;
        }
    }
  }
}

final currencyProvider = StateNotifierProvider<CurrencyNotifier, CurrencyState>((ref) {
  return CurrencyNotifier();
});



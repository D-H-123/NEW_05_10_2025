import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_receipt/features/storage/models/bill_model.dart';
import 'package:smart_receipt/core/models/custom_category.dart';


class LocalStorageService {
  static const String _billsBox = 'billsBox';
  static const String _merchantRulesBox = 'merchantRulesBox';
  static const String _ocrCorrectionsBox = 'ocrCorrectionsBox';
  static const String _settingsBox = 'settingsBox';
  static const String _billMetaBox = 'billMetaBox';
  static const String _customCategoriesBox = 'customCategoriesBox';
  // Settings keys
  static const String kDateTranslation = 'dateTranslation';
  static const String kLocation = 'location';
  static const String kCalendarResults = 'calendarResults';
  static const String kNotes = 'notes';
  static const String kCurrencyCode = 'currencyCode';
  static const String kHasCompletedCurrencySetup = 'hasCompletedCurrencySetup';
  static const String kHasCompletedOnboarding = 'hasCompletedOnboarding';
  static const String kMonthlyBudget = 'monthlyBudget';
  static const String kShowSharedExpenses = 'showSharedExpenses';

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
    Hive.registerAdapter(BillAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CustomCategoryAdapter());
    }

    // Use a fixed encryption key so data persists across app restarts
    // In production, this should be stored in secure storage (e.g., flutter_secure_storage)
    // For now, using a fixed key to ensure data persistence
    final encryptionKey = Uint8List.fromList([
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
    ]);

    await Hive.openBox<Bill>(
      _billsBox,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    // Persist user-learned merchant → category rules
    await Hive.openBox<String>(
      _merchantRulesBox,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    // User-provided OCR corrections (keyed by merchant+original -> corrected)
    await Hive.openBox<String>(
      _ocrCorrectionsBox,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    await Hive.openBox<dynamic>(
      _settingsBox,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    await Hive.openBox<dynamic>(
      _billMetaBox,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    // Custom categories box
    await Hive.openBox<CustomCategory>(
      _customCategoriesBox,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  static Box<Bill> get _box => Hive.box<Bill>(_billsBox);

  static List<Bill> getAllBills() => _box.values.toList();

  static Future<void> addBill(Bill bill) async {
    await _box.put(bill.id, bill);
  }

  // ===== Merchant → Category rule persistence =====
  static Box<String> get _rulesBox => Hive.box<String>(_merchantRulesBox);

  static Future<void> saveMerchantRule({required String merchant, required String category}) async {
    final key = merchant.trim().toLowerCase();
    await _rulesBox.put(key, category);
  }

  static String? getMerchantRule(String merchant) {
    final key = merchant.trim().toLowerCase();
    return _rulesBox.get(key);
  }

  static Map<String, String> getAllMerchantRules() {
    return Map<String, String>.from(_rulesBox.toMap());
  }

  // ===== OCR corrections persistence =====
  static Box<String> get _ocrBox => Hive.box<String>(_ocrCorrectionsBox);

  static String _normalize(String s) => s.trim().toLowerCase();

  static String _merchantScopedKey(String? merchant, String original) {
    final m = merchant == null || merchant.trim().isEmpty ? 'g' : 'm:${_normalize(merchant)}';
    return '$m|${_normalize(original)}';
  }

  static Future<void> saveOcrCorrection({String? merchant, required String original, required String corrected}) async {
    final key = _merchantScopedKey(merchant, original);
    await _ocrBox.put(key, corrected);
  }

  static Map<String, String> _getCorrections(String? merchant) {
    final map = <String, String>{};
    final all = _ocrBox.toMap().cast<String, String>();
    final mKey = merchant == null || merchant.trim().isEmpty ? null : 'm:${_normalize(merchant)}|';
    for (final entry in all.entries) {
      final k = entry.key;
      if (k.startsWith('g|') || (mKey != null && k.startsWith(mKey))) {
        final original = k.substring(k.indexOf('|') + 1);
        map[original] = entry.value;
      }
    }
    return map;
  }

  static String applyCorrectionsToText(String text, {String? merchant}) {
    var out = text;
    final corrections = _getCorrections(merchant);
    corrections.forEach((original, corrected) {
      final pattern = RegExp(RegExp.escape(original), caseSensitive: false);
      out = out.replaceAll(pattern, corrected);
    });
    return out;
  }

  // ===== Settings =====
  static Box<dynamic> get _settings => Hive.box<dynamic>(_settingsBox);

  static bool getBoolSetting(String key, {bool defaultValue = false}) {
    final v = _settings.get(key);
    if (v is bool) return v;
    return defaultValue;
  }

  static Future<void> setBoolSetting(String key, bool value) async {
    await _settings.put(key, value);
  }

  static String? getStringSetting(String key) {
    final v = _settings.get(key);
    if (v is String) return v;
    return null;
  }

  static Future<void> setStringSetting(String key, String value) async {
    await _settings.put(key, value);
  }

  static double? getDoubleSetting(String key) {
    final v = _settings.get(key);
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return null;
  }

  static Future<void> setDoubleSetting(String key, double value) async {
    await _settings.put(key, value);
  }

  // ===== Bill metadata (tags, location) =====
  static Box<dynamic> get _billMeta => Hive.box<dynamic>(_billMetaBox);

  static Future<void> setBillTags(String billId, List<String> tags) async {
    await _billMeta.put('tags:$billId', tags);
  }

  static List<String> getBillTags(String billId) {
    final v = _billMeta.get('tags:$billId');
    if (v is List) {
      return v.whereType<String>().toList();
    }
    return <String>[];
  }

  static Future<void> setBillLocation(String billId, String location) async {
    await _billMeta.put('loc:$billId', location);
  }

  static String? getBillLocation(String billId) {
    final v = _billMeta.get('loc:$billId');
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  static Future<void> addSampleData() async {
    if (_box.isEmpty) {
      await addBill(Bill(
        id: '1',
        imagePath: '',
        vendor: 'Grocery Store',
        date: DateTime.now().subtract(const Duration(days: 1)),
        total: 45.99,
        ocrText: 'Sample OCR text',
      ));
      await addBill(Bill(
        id: '2',
        imagePath: '',
        vendor: 'Electricity Company',
        date: DateTime.now().subtract(const Duration(days: 5)),
        total: 120.50,
        ocrText: 'Sample OCR text',
      ));
    }
  }

  // ===== Custom Categories =====
  static Box<CustomCategory> get _categoriesBox => Hive.box<CustomCategory>(_customCategoriesBox);

  /// Get all custom categories
  static List<CustomCategory> getAllCustomCategories() {
    return _categoriesBox.values.toList();
  }

  /// Get custom categories filtered by type (receipt, expense, subscription)
  static List<CustomCategory> getCustomCategoriesByType(String type) {
    return _categoriesBox.values
        .where((cat) => cat.availableIn.contains(type))
        .toList();
  }

  /// Add a new custom category
  static Future<void> addCustomCategory(CustomCategory category) async {
    await _categoriesBox.put(category.id, category);
  }

  /// Update an existing custom category
  static Future<void> updateCustomCategory(CustomCategory category) async {
    await _categoriesBox.put(category.id, category);
  }

  /// Delete a custom category
  static Future<void> deleteCustomCategory(String categoryId) async {
    await _categoriesBox.delete(categoryId);
  }

  /// Get a specific custom category by ID
  static CustomCategory? getCustomCategory(String categoryId) {
    return _categoriesBox.get(categoryId);
  }

  /// Check if a custom category with the same name exists
  static bool customCategoryExists(String name, {String? excludeId}) {
    final normalizedName = name.trim().toLowerCase();
    return _categoriesBox.values.any((cat) => 
      cat.name.trim().toLowerCase() == normalizedName && 
      (excludeId == null || cat.id != excludeId)
    );
  }
}

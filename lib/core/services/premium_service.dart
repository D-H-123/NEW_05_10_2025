import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum SubscriptionTier {
  free,
  basic,
  pro,
}

class PremiumService {
  static final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // ⚠️ DEBUG MODE - Set to true for testing premium features
  static const bool _debugPremiumEnabled = true; // ← Change to false for production
  
  // Subscription state
  static SubscriptionTier _currentTier = SubscriptionTier.free;
  static bool _isTrialActive = false;
  static DateTime? _trialEndDate;
  static int _scanCount = 0;
  static final int _maxFreeScans = 2;
  
  // Subscription tracking
  static String? _currentProductId;
  static DateTime? _subscriptionStartDate;
  static DateTime? _subscriptionEndDate;
  static bool _notificationsEnabled = true;
  
  // Product IDs from config
  static const String basicWeeklyId = 'smartreceipt_basic_weekly';
  static const String basicMonthlyId = 'smartreceipt_basic_monthly';
  static const String basicQuarterlyId = 'smartreceipt_basic_quarterly';
  static const String basicYearlyId = 'smartreceipt_basic_yearly';
  static const String proWeeklyId = 'smartreceipt_pro_weekly';
  static const String proMonthlyId = 'smartreceipt_pro_monthly';
  static const String proQuarterlyId = 'smartreceipt_pro_quarterly';
  static const String proYearlyId = 'smartreceipt_pro_yearly';
  
  // Initialize the service
  static Future<void> initialize() async {
    await _loadUserData();
    await _initializePurchases();
  }
  
  // Load user data from SharedPreferences
  static Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _scanCount = prefs.getInt('scan_count') ?? 0;
    _isTrialActive = prefs.getBool('trial_active') ?? false;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    final trialEnd = prefs.getString('trial_end');
    if (trialEnd != null) {
      _trialEndDate = DateTime.parse(trialEnd);
    }
    
    final subscriptionStart = prefs.getString('subscription_start');
    if (subscriptionStart != null) {
      _subscriptionStartDate = DateTime.parse(subscriptionStart);
    }
    
    final subscriptionEnd = prefs.getString('subscription_end');
    if (subscriptionEnd != null) {
      _subscriptionEndDate = DateTime.parse(subscriptionEnd);
    }
    
    _currentProductId = prefs.getString('current_product_id');
    
    // Check if trial has expired
    if (_isTrialActive && _trialEndDate != null && DateTime.now().isAfter(_trialEndDate!)) {
      _isTrialActive = false;
      await _saveUserData();
    }
    
    // Check if subscription has expired
    if (_subscriptionEndDate != null && DateTime.now().isAfter(_subscriptionEndDate!)) {
      _currentTier = SubscriptionTier.free;
      _currentProductId = null;
      _subscriptionStartDate = null;
      _subscriptionEndDate = null;
      await _saveUserData();
    }
    
    _updateTier();
  }
  
  // Save user data to SharedPreferences
  static Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scan_count', _scanCount);
    await prefs.setBool('trial_active', _isTrialActive);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    
    if (_trialEndDate != null) {
      await prefs.setString('trial_end', _trialEndDate!.toIso8601String());
    }
    
    if (_subscriptionStartDate != null) {
      await prefs.setString('subscription_start', _subscriptionStartDate!.toIso8601String());
    }
    
    if (_subscriptionEndDate != null) {
      await prefs.setString('subscription_end', _subscriptionEndDate!.toIso8601String());
    }
    
    if (_currentProductId != null) {
      await prefs.setString('current_product_id', _currentProductId!);
    }
  }
  
  // Initialize in-app purchases
  static Future<void> _initializePurchases() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) return;
    
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => print('Purchase error: $error'),
    );
    
    // Restore previous purchases
    await _restorePurchases();
  }
  
  // Handle purchase updates
  static void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        _handleSuccessfulPurchase(purchaseDetails);
      }
    }
  }
  
  // Handle successful purchase
  static void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    _currentProductId = purchaseDetails.productID;
    _subscriptionStartDate = DateTime.now();
    
    switch (purchaseDetails.productID) {
      case basicWeeklyId:
        _currentTier = SubscriptionTier.basic;
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 7));
        break;
      case basicMonthlyId:
        _currentTier = SubscriptionTier.basic;
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 30));
        break;
      case basicQuarterlyId:
        _currentTier = SubscriptionTier.basic;
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 90));
        break;
      case basicYearlyId:
        _currentTier = SubscriptionTier.basic;
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 365));
        break;
      case proWeeklyId:
        _currentTier = SubscriptionTier.pro;
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 7));
        break;
      case proMonthlyId:
        _currentTier = SubscriptionTier.pro;
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 30));
        break;
      case proQuarterlyId:
        _currentTier = SubscriptionTier.pro;
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 90));
        break;
      case proYearlyId:
        _currentTier = SubscriptionTier.pro;
        _subscriptionEndDate = DateTime.now().add(const Duration(days: 365));
        break;
    }
    
    _saveUserData();
  }
  
  // Restore previous purchases
  static Future<void> _restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Error restoring purchases: $e');
    }
  }
  
  // Update subscription tier based on current state
  static void _updateTier() {
    if (_isTrialActive) {
      _currentTier = SubscriptionTier.pro;
    } else {
      // Check for active subscriptions (this would be implemented with server validation)
      _currentTier = SubscriptionTier.free;
    }
  }
  
  // Getters
  static SubscriptionTier get currentTier => _currentTier;
  static bool get isPremium => _debugPremiumEnabled || _currentTier != SubscriptionTier.free;
  static bool get isTrialActive => _isTrialActive;
  static int get scanCount => _scanCount;
  static int get remainingFreeScans => _maxFreeScans - _scanCount;
  static bool get canScan => _scanCount < _maxFreeScans || isPremium;
  
  // Check if specific feature is available
  static bool get isOcrAvailable => isPremium;
  static bool get isCloudBackupAvailable => isPremium;
  static bool get isAdvancedAnalyticsAvailable => _currentTier == SubscriptionTier.pro;
  static bool get isUnlimitedScansAvailable => isPremium;
  static bool get isExportAvailable => isPremium;
  static bool get isTeamCollaborationAvailable => _currentTier == SubscriptionTier.pro;
  
  // Increment scan count
  static Future<void> incrementScanCount() async {
    if (!isPremium) {
      _scanCount++;
      await _saveUserData();
    }
  }
  
  // Start free trial
  static Future<void> startFreeTrial() async {
    _isTrialActive = true;
    _trialEndDate = DateTime.now().add(const Duration(days: 7));
    _currentTier = SubscriptionTier.pro;
    await     _saveUserData();
  }
  
  // Get subscription products
  static Future<List<ProductDetails>> getSubscriptionProducts() async {
    const Set<String> productIds = {
      basicWeeklyId,
      basicMonthlyId,
      basicQuarterlyId,
      basicYearlyId,
      proWeeklyId,
      proMonthlyId,
      proQuarterlyId,
      proYearlyId,
    };
    
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
    return response.productDetails;
  }
  
  // Purchase subscription
  static Future<bool> purchaseSubscription(String productId) async {
    try {
      final products = await getSubscriptionProducts();
      final product = products.firstWhere((p) => p.id == productId);
      
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('Purchase error: $e');
      return false;
    }
  }
  
  // Get premium features list based on tier
  static List<String> getPremiumFeatures(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return [
          '2 scans per month',
          'Basic OCR',
          'Local storage only',
          'Manual entries',
        ];
      case SubscriptionTier.basic:
        return [
          '50 scans per month',
          'Enhanced OCR accuracy',
          'Cloud backup',
          'Export to PDF/CSV',
          'Basic analytics',
          'Email support',
        ];
      case SubscriptionTier.pro:
        return [
          'Unlimited scans',
          'Premium OCR with AI',
          'Advanced analytics & insights',
          'Team collaboration',
          'API access',
          'Priority support',
          'Custom categories',
          'Receipt templates',
        ];
    }
  }
  
  
  // Get pricing information
  static Map<String, String> getPricingInfo() {
    return {
      'basic_monthly': '\$4.99/month',
      'basic_quarterly': '\$12.99/quarter (Save 13%)',
      'basic_yearly': '\$49.99/year (Save 17%)',
      'pro_weekly': '\$3.99/week',
      'pro_monthly': '\$9.99/month',
      'pro_quarterly': '\$24.99/quarter (Save 17%)',
      'pro_yearly': '\$99.99/year (Save 17%)',
    };
  }
  
  // Testing methods
  static void setPremiumStatus(bool status) {
    _currentTier = status ? SubscriptionTier.pro : SubscriptionTier.free;
  }

  static Future<void> resetScanCount() async {
    _scanCount = 0;
    await _saveUserData();
  }
  
  
  // Enable/disable notifications
  static Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _saveUserData();
  }
  
  // Get subscription info
  static String? get currentProductId => _currentProductId;
  static DateTime? get subscriptionStartDate => _subscriptionStartDate;
  static DateTime? get subscriptionEndDate => _subscriptionEndDate;
  static bool get notificationsEnabled => _notificationsEnabled;
  
  // Get subscription type string
  static String get subscriptionType {
    if (_currentProductId == null) return 'Free';
    
    if (_currentProductId!.contains('weekly')) {
      return 'Weekly';
    } else if (_currentProductId!.contains('monthly')) {
      return 'Monthly';
    } else if (_currentProductId!.contains('quarterly')) {
      return 'Quarterly';
    } else if (_currentProductId!.contains('yearly')) {
      return 'Yearly';
    }
    return 'Unknown';
  }
  
  // Get days until renewal
  static int? get daysUntilRenewal {
    if (_subscriptionEndDate == null) return null;
    return _subscriptionEndDate!.difference(DateTime.now()).inDays;
  }
  
  // Get days until trial ends
  static int? get daysUntilTrialEnds {
    if (!_isTrialActive || _trialEndDate == null) return null;
    return _trialEndDate!.difference(DateTime.now()).inDays;
  }
  
  // Check if subscription is expiring soon (within 7 days)
  static bool get isSubscriptionExpiringSoon {
    if (_subscriptionEndDate == null) return false;
    return daysUntilRenewal != null && daysUntilRenewal! <= 7;
  }
  
  // Check if trial is ending soon (within 3 days)
  static bool get isTrialEndingSoon {
    if (!_isTrialActive || _trialEndDate == null) return false;
    return daysUntilTrialEnds != null && daysUntilTrialEnds! <= 3;
  }
  
  // Dispose resources
  static void dispose() {
    _subscription?.cancel();
  }
}

class PremiumService {
  static bool _isPremium = false; // This will be replaced with actual subscription logic
  
  // Check if user has premium access
  static bool get isPremium => _isPremium;
  
  // Set premium status (for testing)
  static void setPremiumStatus(bool status) {
    _isPremium = status;
  }
  
  // Check if OCR feature is available
  static bool get isOcrAvailable => _isPremium;
  
  // Get premium features list
  static List<String> get premiumFeatures => [
    'OCR Text Extraction',
    'Smart Receipt Parsing',
    'Item Recognition',
    'Export to PDF',
    'Cloud Backup',
    'Advanced Analytics',
  ];
  
  // Show premium upgrade dialog
  static void showPremiumUpgrade() {
    // This will be implemented with actual subscription logic
    print('Premium upgrade requested');
  }
}

// Core configuration & TODO keys. Replace placeholders before production.
class Config {
  static const appName = 'SmartReceipt';
  // Subscription product IDs for in-app purchases
  static const List<String> subscriptionProductIds = [
    'smartreceipt_basic_monthly',
    'smartreceipt_basic_yearly', 
    'smartreceipt_pro_monthly',
    'smartreceipt_pro_yearly'
  ];
  // TODO: Add Firebase / Sentry DSN here or use env vars
  static const String sentryDsn = '';
}

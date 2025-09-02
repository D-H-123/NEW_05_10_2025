import 'package:shared_preferences/shared_preferences.dart';

class GuestLimitService {
  static const _key = 'guest_scans';
  static const int maxScans = 2;

  Future<int> getScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  Future<void> incrementScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = await getScanCount();
    await prefs.setInt(_key, count + 1);
  }

  Future<bool> canScan() async {
    final count = await getScanCount();
    return count < maxScans;
  }
}

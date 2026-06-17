import 'package:flutter/services.dart';

/// Bridges Android's NotificationListenerService to Flutter.
/// The Kotlin side sends parsed UPI notifications via this channel.
class NotificationService {
  static const _channel = MethodChannel('upi_tracker/notifications');
  static const _upiPackages = {
    'com.google.android.apps.nbu.paisa.user': 'GPay',
    'com.phonepe.app':                        'PhonePe',
    'net.one97.paytm':                        'Paytm',
    'in.org.npci.upiapp':                     'BHIM',
    'in.amazon.mShop.android.shopping':       'AmazonPay',
  };

  static Function(Map<String, dynamic>)? onExpense;

  static Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onExpense') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        onExpense?.call(data);
      }
    });
  }

  static Future<bool> isPermissionGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isPermissionGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationSettings() =>
      _channel.invokeMethod('openNotificationSettings');

  static Map<String, String> get upiPackages => _upiPackages;
}

/// Auto-categorize based on payee / notification text
class AutoCategorizer {
  static const _rules = {
    'Food & Dining': [
      'swiggy','zomato','dominos','pizza','kfc','mcdonalds','burger',
      'restaurant','cafe','hotel','food','dhaba','chai','biryani',
    ],
    'Transport': [
      'uber','ola','rapido','auto','cab','taxi','metro','irctc',
      'train','flight','indigo','petrol','diesel','fuel','toll','redbus',
    ],
    'Grocery': [
      'bigbasket','grofers','blinkit','jiomart','dmart','reliance fresh',
      'grocery','vegetables','milk','dairy','supermarket','kirana',
    ],
    'Bills': [
      'airtel','jio','vodafone','bsnl','recharge','electricity','bescom',
      'tneb','water','gas','cylinder','netflix','hotstar','spotify',
      'broadband','wifi','insurance','lic','postpaid',
    ],
    'Health': [
      'pharmacy','medical','hospital','clinic','doctor','apollo',
      'netmeds','pharmeasy','1mg','medplus','diagnostics','medicine',
    ],
    'Shopping': [
      'amazon','flipkart','myntra','ajio','nykaa','meesho','snapdeal',
      'reliance digital','croma','shopping','mall','store',
    ],
    'Transfer': [
      'transfer','sent to','paid to','wallet','neft','imps','rtgs',
    ],
  };

  static String detect(String text) {
    final lower = text.toLowerCase();
    for (final entry in _rules.entries) {
      if (entry.value.any((kw) => lower.contains(kw))) return entry.key;
    }
    return 'Other';
  }
}

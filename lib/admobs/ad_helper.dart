import 'package:flutter/foundation.dart';

class AdHelper {
  // Your Production App ID: ca-app-pub-7494179033430216~8361068959

  /// Returns the Native Ad Placement ID string
  static String get nativeAdUnitId {
    if (kDebugMode) {
      // Official Google Native Test ID
      return 'ca-app-pub-3940256099942544/2247696110';
    } else {
      // Your REAL Production Native Ad Unit ID from AdMob
      return 'ca-app-pub-7494179033430216~8972166133';
    }
  }

  /// Returns the Banner Ad Placement ID string
  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Official Google Banner Test ID
      return 'ca-app-pub-3940256099942544/6300978111';
    } else {
      // 🟩 FIX: Swap this placeholder string out for your real 10-digit ID code!
      return 'ca-app-pub-7494179033430216/1219201568';
    }
  }

  /// Returns the Interstitial Ad Placement ID string
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // Official Google Interstitial Test ID
      return 'ca-app-pub-3940256099942544/1033173712';
    } else {
      // 🟩 ADDED: Create an Interstitial Ad Unit on your AdMob Dashboard and paste it here
      return 'ca-app-pub-7494179033430216/4636802475';
    }
  }
}
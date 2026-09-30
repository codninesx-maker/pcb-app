import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

class pharmacistNativeAd extends StatefulWidget {
  const pharmacistNativeAd({super.key});

  @override
  State<pharmacistNativeAd> createState() => _pharmacistNativeAdState();
}

class _pharmacistNativeAdState extends State<pharmacistNativeAd> with AutomaticKeepAliveClientMixin {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  // Ensures the ad state is preserved when scrolled out of view
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 10.0,
      ),
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('LOKKO_NATIVE_AD: Loaded successfully.');
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, LoadAdError error) {
          debugPrint('profile_NATIVE_AD_ERR: Failed to load: ${error.message}');
          // Must dispose of failed ads to free resources
          ad.dispose();
          if (mounted) {
            setState(() => _isLoaded = false);
          }
        },
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    // Native ads have a large memory footprint; explicit disposal is mandatory
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Required contract for AutomaticKeepAliveClientMixin
    super.build(context);

    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 320,
          minHeight: 320,
          maxWidth: 400,
          maxHeight: 400,
        ),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
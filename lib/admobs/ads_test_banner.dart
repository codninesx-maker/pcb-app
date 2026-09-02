import 'package:doctor_profile/admobs/ad_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';



class DoctorTestBanner extends StatefulWidget {
  final AdSize adSize;
  const DoctorTestBanner({super.key, this.adSize = AdSize.banner});

  @override
  State<DoctorTestBanner> createState() => _DoctorTestBannerState();
}

class _DoctorTestBannerState extends State<DoctorTestBanner> with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initialize after the first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAd();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    if (!mounted) return;

    debugPrint("DOCTOR_UI_ADS: Requesting banner...");

    _bannerAd = BannerAd(
      // Use your central AdHelper to keep production/debug IDs managed in one place
      adUnitId: AdHelper.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("DOCTOR_UI_ADS: Error: ${error.message}");
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _isLoaded = false;
          });
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
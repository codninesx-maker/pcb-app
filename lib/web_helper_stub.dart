import 'package:doctor_profile/dashboard/dashboard_view_screen.dart';
import 'package:flutter/foundation.dart'; // <--- Make sure this is present
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart' 
    if (dart.library.html) 'ads_stub.dart';

import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart';

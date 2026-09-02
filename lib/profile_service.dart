import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorService {
  static final _supabase = Supabase.instance.client;

  // This is your Single Source of Truth for fetching data
  static Future<List<dynamic>> getAllDoctors() async {
    return await _supabase.from('doctor').select();
  }
}
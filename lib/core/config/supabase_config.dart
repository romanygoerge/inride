import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://fylruevfksmqnkykqkin.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      debugPrint('[SupabaseConfig] Supabase inRide initialized successfully.');
    } catch (e) {
      debugPrint('[SupabaseConfig] Error initializing Supabase: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}

import 'package:flutter/material.dart';
import '../services/stripe_service.dart';

class StripeConfig {
  // Initialize Stripe when the app starts
  static Future<void> init() async {
    try {
      await StripeService.init();
      debugPrint('Stripe initialized successfully in test mode');
    } catch (e) {
      debugPrint('Warning: Failed to initialize Stripe (using test mode simulation): $e');
      // We'll continue with simulation even if initialization fails
    }
  }
} 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  // We're using Stripe in test mode, so we don't need a backend.
  // In production, you should NOT expose your API keys in the app
  static const String testPublishableKey = 'pk_test_51OCpGjII9qtgzWsKDINgASUbDrZE8LdJFgGaNDYBimG0Yc3sW9vP5iR3AdYznvZgAjWPQyDPHNcRDgciVsv8QTAZ005mWVtb1Z';

  // Initialize Stripe
  static Future<void> init() async {
    Stripe.publishableKey = testPublishableKey;
    await Stripe.instance.applySettings();
  }

  // Directly display a simulated payment card form instead of using PaymentSheet
  static Future<bool> presentPaymentSheet(
      BuildContext context, int amount, String currency) async {
    try {
      debugPrint('Starting payment simulation for amount: $amount $currency');
      
      // In a real app, we'd create a payment intent on our server
      // For this simulation, we'll just show a success dialog
      await Future.delayed(const Duration(seconds: 1));
      
      debugPrint('Payment simulation completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error in payment simulation: $e');
      return false;
    }
  }

  // Get test cards
  static List<Map<String, String>> getTestCards() {
    return [
      {'number': '4242 4242 4242 4242', 'description': 'Success (Visa)'},
      {'number': '4000 0025 0000 3155', 'description': '3D Secure (Visa)'},
      {'number': '4000 0000 0000 9995', 'description': 'Decline (Visa)'},
    ];
  }
} 
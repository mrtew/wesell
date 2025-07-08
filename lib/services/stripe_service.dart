import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  // We're using Stripe in test mode, so we don't need a backend.
  // In production, you should NOT expose your API keys in the app
  // TODO: NEVER expose your secret key in production. For demo purposes only.
  static const String _publishableKey =
      'pk_test_51RiGHVHBjFa3rzJxlSQDOov0M4bQWBBU7vFP9EndgwsjG9X2j0CZp7Kg9XQb9WPBEsZMtLIapwSWiqLOmlWVfWu100yBTBR7F4';
  static const String _secretKey =
      'sk_test_51RiGHVHBjFa3rzJxArq81IWunhgO7W0F6L1OPVoRZwJyGASaTiQCLCZjJejryuYzOrphg2FfWtBw7CE5jyWTHCiH00aj6OKDJ6';

  // Initialize Stripe (should be called once at app startup)
  static Future<void> init() async {
    Stripe.publishableKey = _publishableKey;
    // Set a dummy merchant identifier (required for Apple Pay). Not used on Android.
    Stripe.merchantIdentifier = 'wesell_demo';
    await Stripe.instance.applySettings();
  }

  /// Creates a PaymentIntent on Stripe's servers **using the secret key**.
  /// Returns the decoded json response containing the `client_secret`.
  static Future<Map<String, dynamic>> _createPaymentIntent({
    required int amount,
    required String currency,
  }) async {
    final body = {
      'amount': amount.toString(),
      'currency': currency,
      'payment_method_types[]': 'card',
    };

    final response = await http.post(
      Uri.parse('https://api.stripe.com/v1/payment_intents'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create PaymentIntent: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Presents the Stripe PaymentSheet for the provided amount (in the
  /// smallest currency unit, e.g. cents).
  /// Returns `true` if the payment succeeds, `false` if the user cancels or an
  /// error occurs.
  static Future<bool> presentPaymentSheet(
    BuildContext context,
    int amount,
    String currency,
  ) async {
    try {
      // 1. Create PaymentIntent on Stripe
      final paymentIntent = await _createPaymentIntent(
        amount: amount,
        currency: currency,
      );
      final clientSecret = paymentIntent['client_secret'];

      // 2. Initialise the PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'WeSell',

          style: ThemeMode.system,
          allowsDelayedPaymentMethods: true,
        ),
      );

      // 3. Present the PaymentSheet to the user
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      debugPrint('StripeException: ${e.error.localizedMessage}');
      return false;
    } catch (e) {
      debugPrint('Error in presentPaymentSheet: $e');
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

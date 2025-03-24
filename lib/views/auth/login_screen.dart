import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/user_controller.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final UserController _userController = UserController();
  final AuthController _authController = AuthController();
  
  bool _isOtpSent = false;
  bool _isGetSMSButtonEnabled = true;
  bool _isLoginButtonEnabled = true;
  int _resendTimer = 0;
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Send OTP code
  Future<void> _sendOtp() async {
    if (!_isGetSMSButtonEnabled) return;
    
    // Disable button to prevent spam
    setState(() {
      _isGetSMSButtonEnabled = false;
      _resendTimer = 60; // 60 seconds cooldown
      _isOtpSent = true;
    });
    
    // Start the cooldown timer
    _startCooldownTimer();
    
    final phoneNumber = '+60${_phoneController.text.trim()}';
    
    try {
      await _authController.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (usually on Android)
          // await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          // Handle verification failure
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
          setState(() {
            _isGetSMSButtonEnabled = true;
            _resendTimer = 0;
            _isOtpSent = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          // OTP has been sent, save the verification ID
          ref.read(verificationIdProvider.notifier).state = verificationId;
          
          setState(() {
            _isOtpSent = true;
          });
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code sent!')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending OTP: $e')),
      );
      setState(() {
        _isGetSMSButtonEnabled = true;
        _resendTimer = 0;
        _isOtpSent = false;
      });
    }
  }
  
  // Start the cooldown timer
  void _startCooldownTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_resendTimer > 0 && mounted) {
        setState(() {
          _resendTimer--;
        });
        _startCooldownTimer();
      } else if (mounted) {
        setState(() {
          _isGetSMSButtonEnabled = true;
          _isOtpSent = false;
        });
      }
    });
  }

  // Verify OTP and sign in
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty || _otpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid OTP code')),
      );
      return;
    }
    
    setState(() {
      _isLoginButtonEnabled = false;
    });
    
    final verificationId = ref.read(verificationIdProvider);
    
    if (verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification ID not found. Please try again')),
      );
      setState(() {
        _isLoginButtonEnabled = true;
      });
      return;
    }
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: _otpController.text.trim(),
      );
      
      await _signInWithCredential(credential);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
      setState(() {
        _isLoginButtonEnabled = true;
      });
    }
  }
  
  // Sign in with credential and handle user creation/update
  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final UserCredential userCredential = 
          await _authController.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Check if the user is new or existing and update Firestore
        await _userController.getOrCreateUser(
          user.uid, 
          user.phoneNumber ?? '+60${_phoneController.text.trim()}',
        );
        
        // Navigate to home on successful login
        if (!mounted) return;
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoginButtonEnabled = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                const Text(
                  'Login to WeSell',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 50),
                
                // Phone number input
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Phone',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 50),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        enabled: !_isOtpSent,
                        decoration: InputDecoration(
                          hintText: 'Enter phone number',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          prefixText: '+60 ',
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 1,
                  color: Colors.grey[400],
                ),
                
                // OTP input
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'SMS Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: 'Enter verification code',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    // Get OTP button
                    TextButton(
                      onPressed: _isGetSMSButtonEnabled ? _sendOtp : null,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        minimumSize: const Size(40, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _resendTimer > 0 
                            ? '${_resendTimer}s'
                            : 'Get SMS',
                        style: TextStyle(
                          color: _isGetSMSButtonEnabled ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 1,
                  color: Colors.grey[400],
                ),
                
                const SizedBox(height: 70),
                
                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoginButtonEnabled ? _verifyOtp : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: !_isLoginButtonEnabled
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

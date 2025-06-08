import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  BuildContext? _context;
  String? _currentUserId;

  // Initialize notification service
  Future<void> initialize(BuildContext context, String userId) async {
    debugPrint('NotificationService.initialize called for user: $userId');
    _context = context;
    _currentUserId = userId;
    
    try {
      // Request notification permissions
      debugPrint('Requesting notification permissions...');
      await _requestPermissions();
      
      // Initialize local notifications
      debugPrint('Initializing local notifications...');
      await _initializeLocalNotifications();
      
      // Get and save FCM token
      debugPrint('Getting and saving FCM token...');
      await _saveTokenToDatabase(userId);
      
      // Configure FCM handlers
      debugPrint('Configuring FCM handlers...');
      await _configureFCMHandlers();
      
      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM token refreshed: $newToken');
        _saveTokenToDatabase(userId, token: newToken);
      });
      
      debugPrint('NotificationService initialization completed successfully');
    } catch (e) {
      debugPrint('Error during notification service initialization: $e');
      rethrow;
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'wesell_channel',
        'WeSell Notifications',
        description: 'Notifications for WeSell app',
        importance: Importance.high,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null && _context != null) {
      try {
        final data = jsonDecode(response.payload!);
        final type = data['type'] as String?;
        
        if (type == 'purchase') {
          debugPrint('Payment notification tapped - purchase completed successfully');
          // Just log the tap, no navigation needed for payment notifications
        }
      } catch (e) {
        debugPrint('Error handling notification tap: $e');
      }
    }
  }

  // Configure FCM handlers
  Future<void> _configureFCMHandlers() async {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle notification taps when app is in background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      _handleNotificationNavigation(message.data);
    });
    
    // Check if app was opened from a notification
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }
    
    // Add FCM token debugging
    _fcm.onTokenRefresh.listen((String token) {
      debugPrint('FCM Token refreshed: ${token.substring(0, 20)}...');
      if (_currentUserId != null) {
        _saveTokenToDatabase(_currentUserId!, token: token);
      }
    });
  }

  // Handle navigation from notification data
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    if (_context == null) return;
    
    final type = data['type'] as String?;
    
    if (type == 'purchase') {
      debugPrint('Payment notification opened - purchase completed successfully');
      // Just log the action, no navigation needed for payment notifications
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    
    if (notification != null) {
      final androidDetails = AndroidNotificationDetails(
        'wesell_channel',
        'WeSell Notifications',
        channelDescription: 'Notifications for WeSell app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        details,
        payload: jsonEncode(message.data),
      );
    }
  }

  // Save FCM token to database
  Future<void> _saveTokenToDatabase(String userId, {String? token}) async {
    try {
      debugPrint('Attempting to save FCM token for user: $userId');
      String? fcmToken = token ?? await _fcm.getToken();
      
      if (fcmToken != null) {
        debugPrint('FCM Token obtained: ${fcmToken.substring(0, 20)}...');
        
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': fcmToken,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('FCM Token saved successfully to Firestore for user: $userId');
        
        // Verify the token was saved by reading it back
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final savedToken = userData['fcmToken'] as String?;
          if (savedToken != null) {
            debugPrint('Verified FCM token saved: ${savedToken.substring(0, 20)}...');
          } else {
            debugPrint('WARNING: FCM token not found in user document after save!');
          }
        }
      } else {
        debugPrint('ERROR: Could not obtain FCM token!');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // Send notification to specific users
  Future<void> sendNotification({
    required List<String> userIds,
    required String transactionId,
    required String type,
    required String title,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      debugPrint('Creating notification for users: $userIds');
      debugPrint('Current user ID: $_currentUserId');
      debugPrint('Notification title: $title');
      
      // Create notification document
      final notificationRef = _firestore.collection('notifications').doc();
      final Map<String, Object> notificationData = {
        'userIds': userIds,
        'transactionId': transactionId,
        'type': type,
        'title': title,
        'content': content,
        'createdAt': Timestamp.now(),
      };
      
      // Add additional data if provided
      if (additionalData != null) {
        additionalData.forEach((key, value) {
          if (value != null) {
            notificationData[key] = value;
          }
        });
      }
      
      await notificationRef.set(notificationData);
      
      debugPrint('Notification document created successfully in Firestore');
      debugPrint('Cloud Functions will handle FCM sending');
      
      // Remove the local notification fallback since Cloud Functions handle this
      // The local notification was causing the buyer to see all notifications
      
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  // Test local notification (for debugging purposes only)
  Future<void> testLocalNotification({
    required String title,
    required String content,
    Map<String, dynamic>? data,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'wesell_channel',
        'WeSell Notifications',
        channelDescription: 'Notifications for WeSell app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        content,
        details,
        payload: jsonEncode(data ?? {}),
      );
      
      debugPrint('Test local notification shown: $title');
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  // Emergency fallback for testing - shows local notification immediately
  Future<void> showEmergencyTestNotification({
    required String title,
    required String content,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('🚨 Emergency test notification: $title');
      
      final androidDetails = AndroidNotificationDetails(
        'wesell_channel',
        'WeSell Notifications',
        channelDescription: 'Notifications for WeSell app',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        content,
        details,
        payload: jsonEncode(data ?? {}),
      );
      
      debugPrint('🚨 Emergency test notification shown successfully');
    } catch (e) {
      debugPrint('Error showing emergency test notification: $e');
    }
  }

  // Update context (call this when navigation context changes)
  void updateContext(BuildContext context) {
    _context = context;
  }

  // Dispose method
  void dispose() {
    _context = null;
    _currentUserId = null;
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  // You can process the message here if needed
} 
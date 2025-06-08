/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentCreated, onDocumentUpdated} =
 *   require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

// Initialize Firebase Admin
initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/write-firebase-functions

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Cloud Function to send notifications when a new notification
// document is created
exports.sendNotification = onDocumentCreated(
    "notifications/{notificationId}",
    async (event) => {
      const notification = event.data.data();
      const notificationId = event.params.notificationId;

      console.log("=== NOTIFICATION FUNCTION TRIGGERED ===");
      console.log("Notification ID:", notificationId);
      console.log("Notification data:", JSON.stringify(notification, null, 2));

      // Get the user IDs who should receive the notification
      const userIds = notification.userIds || [];

      if (userIds.length === 0) {
        console.log("No users to send notification to");
        return null;
      }

      console.log("Target user IDs:", userIds);

      // Prepare the notification payload
      const payload = {
        notification: {
          title: notification.title,
          body: notification.content,
        },
        data: {
          type: notification.type,
          transactionId: notification.transactionId,
          notificationId: notificationId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      // Add seller and buyer IDs if they exist (for payment notifications)
      if (notification.sellerId) {
        payload.data.sellerId = notification.sellerId;
      }
      if (notification.buyerId) {
        payload.data.buyerId = notification.buyerId;
      }
      if (notification.itemId) {
        payload.data.itemId = notification.itemId;
      }

      console.log("Notification payload:", JSON.stringify(payload, null, 2));

      // Get FCM tokens for all users
      const tokens = [];
      const db = getFirestore();

      for (const userId of userIds) {
        try {
          console.log(`Fetching FCM token for user: ${userId}`);
          const userDoc = await db
              .collection("users")
              .doc(userId)
              .get();

          if (userDoc.exists) {
            const userData = userDoc.data();
            console.log(`User ${userId} data:`, {
              username: userData.username,
              hasFcmToken: !!userData.fcmToken,
              tokenPreview: userData.fcmToken ?
                userData.fcmToken.substring(0, 20) + "..." : "null",
            });

            if (userData.fcmToken) {
              tokens.push(userData.fcmToken);
              console.log(`Added FCM token for user ${userId}`);
            } else {
              console.log(`WARNING: User ${userId} has no FCM token!`);
            }
          } else {
            console.log(`ERROR: User document ${userId} does not exist!`);
          }
        } catch (error) {
          const errorMsg = `Error getting FCM token for user ${userId}:`;
          console.error(errorMsg, error);
        }
      }

      console.log(`Total FCM tokens collected: ${tokens.length}`);

      if (tokens.length === 0) {
        console.log("No FCM tokens found for users");
        return null;
      }

      // Send notifications to all tokens
      try {
        console.log("Sending notifications to", tokens.length, "devices...");
        const messaging = getMessaging();
        const response = await messaging.sendEachForMulticast({
          tokens: tokens,
          notification: payload.notification,
          data: payload.data,
          android: {
            priority: "high",
            ttl: 0, // No caching, immediate delivery
            notification: {
              channelId: "wesell_channel",
              priority: "high",
              defaultSound: true,
              sticky: false,
              localOnly: false,
              defaultVibrateTimings: true,
              visibility: "public",
            },
            collapseKey: `wesell_${payload.data.type}_${Date.now()}`,
          },
          apns: {
            headers: {
              "apns-priority": "10", // Immediate delivery
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                "alert": {
                  title: payload.notification.title,
                  body: payload.notification.body,
                },
                "sound": "default",
                "badge": 1,
                "content-available": 1,
                "mutable-content": 1,
              },
            },
          },
          fcmOptions: {
            analyticsLabel: "payment_notification",
          },
        });

        const count = response.successCount;
        console.log(`Successfully sent ${count} notifications`);

        if (response.failureCount > 0) {
          const failCount = response.failureCount;
          console.log(`Failed to send ${failCount} notifications`);
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const token = tokens[idx];
              const shortToken = token.substring(0, 20);
              console.error(`Failed to send to token ${shortToken}...`);
              console.error("Error:", resp.error);
            }
          });
        }

        console.log("=== NOTIFICATION FUNCTION COMPLETED ===");
        return response;
      } catch (error) {
        console.error("Error sending notifications:", error);
        throw error;
      }
    });

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Cloud Function to send notifications when a new notification document is created
exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    // Get the user IDs who should receive the notification
    const userIds = notification.userIds || [];
    
    if (userIds.length === 0) {
      console.log('No users to send notification to');
      return null;
    }
    
    // Prepare the notification payload
    const payload = {
      notification: {
        title: notification.title,
        body: notification.content,
      },
      data: {
        type: notification.type,
        transactionId: notification.transactionId,
        notificationId: context.params.notificationId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      }
    };
    
    // Add additional data fields if they exist
    if (notification.chatId) {
      payload.data.chatId = notification.chatId;
    }
    if (notification.sellerId) {
      payload.data.sellerId = notification.sellerId;
    }
    if (notification.buyerId) {
      payload.data.buyerId = notification.buyerId;
    }
    if (notification.itemId) {
      payload.data.itemId = notification.itemId;
    }
    
    // Get FCM tokens for all users
    const tokens = [];
    
    for (const userId of userIds) {
      try {
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();
          
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmToken) {
            tokens.push(userData.fcmToken);
          }
        }
      } catch (error) {
        console.error(`Error getting FCM token for user ${userId}:`, error);
      }
    }
    
    if (tokens.length === 0) {
      console.log('No FCM tokens found for users');
      return null;
    }
    
    // Send notifications to all tokens
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: payload.notification,
        data: payload.data,
        android: {
          priority: 'high',
          notification: {
            channelId: 'wesell_channel',
            priority: 'high',
            defaultSound: true,
          }
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: payload.notification.title,
                body: payload.notification.body,
              },
              sound: 'default',
              badge: 1,
            }
          }
        }
      });
      
      console.log(`Successfully sent ${response.successCount} notifications`);
      
      if (response.failureCount > 0) {
        console.log(`Failed to send ${response.failureCount} notifications`);
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to token ${tokens[idx]}:`, resp.error);
          }
        });
      }
      
      return response;
    } catch (error) {
      console.error('Error sending notifications:', error);
      throw error;
    }
  });

// Cloud Function to handle chat notifications
exports.sendChatNotification = functions.firestore
  .document('chats/{chatId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const previousData = change.before.data();
    
    // Check if a new message was added
    const newMessages = newData.messages || [];
    const previousMessages = previousData.messages || [];
    
    if (newMessages.length <= previousMessages.length) {
      return null; // No new messages
    }
    
    // Get the latest message
    const latestMessage = newMessages[newMessages.length - 1];
    const senderId = latestMessage.senderId;
    
    // Determine the receiver
    const userIds = newData.userIds;
    const receiverId = userIds.sender === senderId ? userIds.receiver : userIds.sender;
    
    // Get sender and receiver data
    const [senderDoc, receiverDoc] = await Promise.all([
      admin.firestore().collection('users').doc(senderId).get(),
      admin.firestore().collection('users').doc(receiverId).get()
    ]);
    
    if (!senderDoc.exists || !receiverDoc.exists) {
      console.log('Sender or receiver not found');
      return null;
    }
    
    const senderData = senderDoc.data();
    const receiverData = receiverDoc.data();
    
    if (!receiverData.fcmToken) {
      console.log('Receiver has no FCM token');
      return null;
    }
    
    // Prepare notification payload
    const payload = {
      notification: {
        title: senderData.username || 'New Message',
        body: latestMessage.type === 'text' 
          ? latestMessage.content.substring(0, 100) + (latestMessage.content.length > 100 ? '...' : '')
          : 'Sent an image',
      },
      data: {
        type: 'chat',
        chatId: context.params.chatId,
        senderId: senderId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: receiverData.fcmToken,
      android: {
        priority: 'high',
        notification: {
          channelId: 'wesell_channel',
          priority: 'high',
          defaultSound: true,
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: senderData.username || 'New Message',
              body: latestMessage.type === 'text' 
                ? latestMessage.content.substring(0, 100) + (latestMessage.content.length > 100 ? '...' : '')
                : 'Sent an image',
            },
            sound: 'default',
            badge: 1,
          }
        }
      }
    };
    
    try {
      await admin.messaging().send(payload);
      console.log('Chat notification sent successfully');
    } catch (error) {
      console.error('Error sending chat notification:', error);
    }
  }); 
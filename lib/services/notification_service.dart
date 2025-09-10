import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/home/post_detail_screen.dart';
import 'package:halisaharakip_app/screens/matches/match_detail_screen.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();

    final fcmToken = await _firebaseMessaging.getToken();
    print('-----------');
    print('FCM Token: $fcmToken');
    print('-----------');
    if (fcmToken != null) {
      await _saveTokenToDatabase(fcmToken);
    }
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);

    _setupInteractedMessage();
    _setupForegroundMessageListener();
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        // Önce kullanıcı dokümanının var olup olmadığını kontrol et
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          final existingTokens = List<String>.from(userDoc.data()?['fcmTokens'] ?? []);
          
          // Eğer token zaten varsa, tekrar ekleme
          if (!existingTokens.contains(token)) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'fcmTokens': FieldValue.arrayUnion([token]),
            });
            print('Yeni FCM token kaydedildi: $token');
          } else {
            print('FCM token zaten mevcut, tekrar kaydedilmiyor: $token');
          }
        } else {
          print('Kullanıcı dokümanı henüz oluşturulmamış, FCM token kaydedilemedi');
        }
      } catch (e) {
        print('FCM token kaydedilemedi: $e');
      }
    }
  }

  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Uygulama açıkken bir bildirim geldi!');
      print('Mesaj verisi: ${message.data}');

      // Firestore'a bildirim kaydet
      _saveNotificationToFirestore(message);

      if (message.notification != null) {
        print('Mesaj ayrıca bir bildirim içeriyor: ${message.notification}');
        if (navigatorKey.currentState != null) {
          showSnackBar(
            navigatorKey.currentState!.context,
            '${message.notification!.title}\n${message.notification!.body}',
          );
        }
      }
    });
  }

  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final title = message.notification?.title ?? 'Yeni Bildirim';
      final body = message.notification?.body ?? '';
      final type = message.data['type'] ?? 'general';
      final postId = message.data['postId'];
      final matchId = message.data['matchId'];

      // Son 5 dakika içinde aynı bildirim var mı kontrol et (daha hızlı)
      final fiveMinutesAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 5))
      );
      
      final existingNotification = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('title', isEqualTo: title)
          .where('type', isEqualTo: type)
          .where('createdAt', isGreaterThan: fiveMinutesAgo)
          .limit(1)
          .get();

      // Eğer aynı bildirim son 5 dakika içinde varsa, tekrar kaydetme
      if (existingNotification.docs.isNotEmpty) {
        print('Aynı bildirim son 5 dakika içinde zaten mevcut, tekrar kaydedilmiyor');
        return;
      }

      final notificationData = {
        'userId': currentUser.uid,
        'title': title,
        'body': body,
        'type': type,
        'postId': postId,
        'matchId': matchId,
        'isRead': false,
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);
      print('Bildirim Firestore\'a kaydedildi: $title');
    } catch (e) {
      print('Bildirim Firestore\'a kaydedilemedi: $e');
    }
  }

  void _setupInteractedMessage() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Bildirime tıklandı ve uygulama açıldı: ${message.data}');

      final postId = message.data['postId'];
      final matchId = message.data['matchId'];

      if (postId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: postId),
          ),
        );
      } else if (matchId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => MatchDetailScreen(matchId: matchId),
          ),
        );
      }
    });
  }
}

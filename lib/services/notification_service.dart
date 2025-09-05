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
          // Kullanıcı dokümanı varsa fcmTokens alanını güncelle
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'fcmTokens': FieldValue.arrayUnion([token]),
          });
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

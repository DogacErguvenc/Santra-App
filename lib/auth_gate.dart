// lib/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/auth_page.dart'; // GÜNCELLEME
import 'package:halisaharakip_app/screens/main_layout.dart';
import 'package:halisaharakip_app/services/notification_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.userChanges().listen((User? user) {
      if (user != null) {
        print("Kullanıcı giriş yaptı, bildirimler başlatılıyor...");
        NotificationService().initNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          return const MainLayout();
        } else {
          // GÜNCELLEME: Artık LoginScreen yerine AuthPage'i gösteriyoruz.
          return const AuthPage();
        }
      },
    );
  }
}

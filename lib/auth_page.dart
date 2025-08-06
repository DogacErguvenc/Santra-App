// lib/auth_page.dart

import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/auth/login_screen.dart';
import 'package:halisaharakip_app/screens/auth/register_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Başlangıçta giriş sayfasını göster
  bool showLoginPage = true;

  // Sayfalar arasında geçiş yapacak olan fonksiyon
  void toggleScreens() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginScreen(showRegisterPage: toggleScreens);
    } else {
      return RegisterScreen(showLoginPage: toggleScreens);
    }
  }
}

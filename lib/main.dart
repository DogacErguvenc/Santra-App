import 'package:flutter/foundation.dart'; // Geliştirme modunu kontrol etmek için eklendi
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'package:halisaharakip_app/services/notification_service.dart';

void main() async {
  // Flutter binding'lerinin hazır olduğundan emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase ve Tarih formatlama gibi servisleri aynı anda başlatıyoruz
  await Future.wait([
    initializeDateFormatting('tr_TR', null),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  ]);

  // --- APP CHECK KODU GÜNCELLENDİ ---
  // Uygulamanın modunu (debug/release) otomatik olarak kontrol et
  await FirebaseAppCheck.instance.activate(
    // kDebugMode, Flutter'ın sağladığı ve uygulamanın o an
    // "debug" modda mı yoksa "release" (canlı) modda mı çalıştığını
    // bildiren bir değişkendir.
    androidProvider: kDebugMode
        ? AndroidProvider.debug // EĞER GELİŞTİRME MODUNDAYSA: debug kullan
        : AndroidProvider
            .playIntegrity, // EĞER CANLI SÜRÜMDEYSE: playIntegrity kullan
  );

  // Uygulamayı çalıştırıyoruz
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Mevcut tema ayarların olduğu gibi korundu
    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.tealAccent,
        brightness: Brightness.dark,
        primary: Colors.tealAccent[400],
        secondary: Colors.teal[300],
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.grey[850],
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.tealAccent[400],
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.tealAccent[400],
        unselectedItemColor: Colors.grey[500],
      ),
    );

    return MaterialApp(
      // Global navigator key'in olduğu gibi korundu
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Santra',
      theme: darkTheme,
      home: const AuthGate(),
    );
  }
}

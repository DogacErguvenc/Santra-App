import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EmailVerificationService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // E-posta doğrulama durumunu kontrol et
  static Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Firebase Auth'un e-posta doğrulama durumunu güncellemesi için birden fazla deneme
      for (int i = 0; i < 3; i++) {
        await user.reload();
        if (user.emailVerified) {
          return true;
        }
        // Her deneme arasında kısa bir bekleme
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      return user.emailVerified;
    }
    return false;
  }

  // E-posta doğrulama e-postası gönder
  static Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Firestore'da e-posta doğrulama durumunu güncelle
  static Future<void> updateEmailVerificationInFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _functions.httpsCallable('updateEmailVerificationStatus').call();
      }
    } catch (e) {
      print('Firestore güncelleme hatası: $e');
      // Fallback: Manuel güncelleme
      await _updateEmailVerificationManually();
    }
  }

  // Manuel Firestore güncelleme (fallback) - Artık kullanılmıyor
  static Future<void> _updateEmailVerificationManually() async {
    // Bu fonksiyon artık kullanılmıyor çünkü doğrudan Firestore güncellemesi
    // permission hatasına neden oluyor. Cloud Function kullanılıyor.
    print('Manuel güncelleme artık desteklenmiyor. Cloud Function kullanın.');
  }

  // Kullanıcının e-posta doğrulama durumunu Firestore'dan kontrol et
  static Future<bool> checkEmailVerificationFromFirestore() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return userDoc.data()?['emailVerified'] ?? false;
      }
    }
    return false;
  }

  // E-posta doğrulama sürecini başlat
  static Future<void> startEmailVerificationProcess() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      // E-posta gönder
      await sendVerificationEmail();
      
      // E-posta gönderme tarihini kaydet
      try {
        await _functions.httpsCallable('updateEmailVerificationSentAt').call();
      } catch (e) {
        print('E-posta gönderme tarihi kaydedilemedi: $e');
      }
    }
  }

  // E-posta doğrulama tamamlandığında çağrılacak
  static Future<void> onEmailVerificationComplete() async {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified) {
      // Cloud Function kullanarak güvenli güncelleme yap
      try {
        await _functions.httpsCallable('updateEmailVerificationStatus').call();
      } catch (e) {
        print('E-posta doğrulama durumu güncellenemedi: $e');
        // Hata olsa bile devam et, çünkü Firebase Auth'da doğrulama tamamlandı
      }
    }
  }
}

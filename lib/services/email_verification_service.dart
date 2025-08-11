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
      await user.reload();
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

  // Manuel Firestore güncelleme (fallback)
  static Future<void> _updateEmailVerificationManually() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'emailVerified': user.emailVerified,
        'emailVerificationUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
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

      // Firestore'da durumu güncelle
      await _firestore.collection('users').doc(user.uid).update({
        'emailVerificationSentAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
      });
    }
  }

  // E-posta doğrulama tamamlandığında çağrılacak
  static Future<void> onEmailVerificationComplete() async {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified) {
      // Firestore'u güncelle
      await _firestore.collection('users').doc(user.uid).update({
        'emailVerified': true,
        'emailVerificationCompletedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

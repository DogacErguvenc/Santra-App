import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/auth/email_verification_screen.dart';
import 'package:halisaharakip_app/screens/legal/legal_document_screen.dart';
import 'package:halisaharakip_app/services/email_verification_service.dart';
import 'package:halisaharakip_app/utils/legal_texts.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class RegisterScreen extends StatefulWidget {
  final VoidCallback showLoginPage;
  const RegisterScreen({super.key, required this.showLoginPage});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoading = false;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<String?> _getDeviceId() async {
    // DÜZELTME: Sınıfın doğru adı DeviceInfoPlugin
    final deviceInfoPlugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      print("Cihaz ID'si alınamadı: $e");
    }
    return null;
  }

  Future<void> _signUp() async {
    if (_isLoading) return;

    if (!_agreedToTerms) {
      showSnackBar(context,
          'Devam etmek için Kullanım Koşullarını ve Gizlilik Politikasını kabul etmelisiniz.',
          isError: true);
      return;
    }
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      showSnackBar(context, 'Lütfen ad ve soyad alanlarını doldurunuz.',
          isError: true);
      return;
    }
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      showSnackBar(context, 'Şifreler eşleşmiyor.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceId = await _getDeviceId();
      if (deviceId != null) {
        final bannedDeviceDoc = await FirebaseFirestore.instance
            .collection('bannedDevices')
            .doc(deviceId)
            .get();
        if (bannedDeviceDoc.exists) {
          if (mounted)
            showSnackBar(
                context, 'Bu cihazdan yeni hesap oluşturulması engellenmiştir.',
                isError: true);
          setState(() => _isLoading = false);
          return;
        }
      }

      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'fullName': fullName,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': Timestamp.now(),
        'role': 'Oyuncu',
        'teamId': null,
        'deviceId': deviceId,
        'isBanned': false,
        'emailVerified': false,
        'emailVerificationSentAt': null,
        'emailVerificationCompletedAt': null,
      });

      // E-posta doğrulama sürecini başlat
      await EmailVerificationService.startEmailVerificationProcess();

      // E-posta doğrulama ekranına yönlendir
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const EmailVerificationScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted)
        showSnackBar(context, e.message ?? 'Bilinmeyen bir hata oluştu.',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_soccer, size: 100),
                const SizedBox(height: 50),
                const Text('Halisaha Rakip',
                    style:
                        TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Hesap Oluştur', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 50),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.deepPurple),
                              borderRadius: BorderRadius.circular(12)),
                          hintText: 'Ad',
                          fillColor: Colors.grey[800],
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.deepPurple),
                              borderRadius: BorderRadius.circular(12)),
                          hintText: 'Soyad',
                          fillColor: Colors.grey[800],
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.deepPurple),
                        borderRadius: BorderRadius.circular(12)),
                    hintText: 'E-posta',
                    fillColor: Colors.grey[800],
                    filled: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.deepPurple),
                        borderRadius: BorderRadius.circular(12)),
                    hintText: 'Şifre',
                    fillColor: Colors.grey[800],
                    filled: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.deepPurple),
                        borderRadius: BorderRadius.circular(12)),
                    hintText: 'Şifreyi Onayla',
                    fillColor: Colors.grey[800],
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (bool? value) {
                          setState(() {
                            _agreedToTerms = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12),
                            children: [
                              const TextSpan(text: 'Kayıt olarak, '),
                              TextSpan(
                                text: 'Kullanım Koşullarını',
                                style: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(context)
                                        .push(MaterialPageRoute(
                                      builder: (context) =>
                                          const LegalDocumentScreen(
                                        title: 'Kullanım Koşulları',
                                        documentContent:
                                            LegalTexts.termsOfService,
                                      ),
                                    ));
                                  },
                              ),
                              const TextSpan(text: ' ve '),
                              TextSpan(
                                text: 'Gizlilik Politikasını',
                                style: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(context)
                                        .push(MaterialPageRoute(
                                      builder: (context) =>
                                          const LegalDocumentScreen(
                                        title: 'Gizlilik Politikası',
                                        documentContent:
                                            LegalTexts.privacyPolicy,
                                      ),
                                    ));
                                  },
                              ),
                              const TextSpan(
                                  text:
                                      ' okuduğunuzu ve kabul ettiğinizi onaylarsınız.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  GestureDetector(
                    onTap: _signUp,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: Text('Kayıt Ol',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                    ),
                  ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Zaten bir hesabın var mı?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: widget.showLoginPage,
                      child: const Text(' Giriş Yap',
                          style: TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.bold)),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

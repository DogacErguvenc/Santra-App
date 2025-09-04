import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/services/email_verification_service.dart';
import 'package:halisaharakip_app/screens/main_layout.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _isEmailSent = false;
  Timer? _timer;
  int _timeLeft = 60;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0 && mounted) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    setState(() => _isLoading = true);

    try {
      await EmailVerificationService.startEmailVerificationProcess();
      setState(() {
        _isEmailSent = true;
        _timeLeft = 60;
      });
      _startTimer();
      if (mounted) {
        showSnackBar(context, 'Doğrulama e-postası gönderildi!',
            isError: false);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'E-posta gönderilemedi: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkEmailVerification() async {
    setState(() => _isLoading = true);

    try {
      final isVerified = await EmailVerificationService.isEmailVerified();
      if (isVerified) {
        // Firestore'u güncelle
        await EmailVerificationService.onEmailVerificationComplete();

        if (mounted) {
          showSnackBar(context, 'E-posta doğrulandı!', isError: false);
          // Sayaç ve timer'ı güvenli şekilde durdur
          _timer?.cancel();
          _timer = null;
          // Ana layout'a yönlendir ve geri dönüş stack'ini temizle
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainLayout()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          showSnackBar(context,
              'E-posta henüz doğrulanmamış. Lütfen e-postanızı kontrol edin.',
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Bir hata oluştu: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-posta Doğrulama'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 100,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 30),
                const Text(
                  'E-posta Adresinizi Doğrulayın',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Hesabınızı aktifleştirmek için e-posta adresinize gönderilen doğrulama bağlantısına tıklayın.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                if (_isEmailSent) ...[
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Doğrulama e-postası gönderildi!',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  ElevatedButton(
                    onPressed: _checkEmailVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'E-postamı Doğruladım',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_timeLeft == 0) ...[
                    ElevatedButton(
                      onPressed: _sendVerificationEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'E-postayı Tekrar Gönder',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Tekrar göndermek için $_timeLeft saniye bekleyin',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () async {
                    // Timer'ı durdur
                    _timer?.cancel();
                    _timer = null;

                    // Kullanıcıyı çıkış yaptır
                    await FirebaseAuth.instance.signOut();

                    if (mounted) {
                      // Ana sayfaya yönlendir
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/',
                        (route) => false,
                      );
                    }
                  },
                  child: const Text(
                    'Farklı E-posta ile Kayıt Ol',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/auth_gate.dart';
import 'package:halisaharakip_app/screens/admin/admin_user_list_screen.dart';
import 'package:halisaharakip_app/screens/legal/legal_document_screen.dart';
import 'package:halisaharakip_app/screens/profile/edit_profile_screen.dart';
import 'package:halisaharakip_app/screens/profile/team_invites_screen.dart';
import 'package:halisaharakip_app/utils/legal_texts.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSendingEmail = false;
  bool _isUploading = false;
  bool _isAdmin = false;
  bool _isChangingEmail = false;

  @override
  void initState() {
    super.initState();
    // initState'te artık async işlem yapmıyoruz, doğrudan _checkAdminStatus çağırıyoruz.
    _checkAdminStatus();
  }

  // --- YENİ LOGOUT FONKSİYONU ---
  // Kod tekrarını önlemek için çıkış yapma mantığını bir fonksiyona taşıdık.
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // pushAndRemoveUntil ile tüm geçmiş ekranları temizleyip giriş ekranına dönüyoruz.
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    }
  }

  // --- GÜNCELLENEN FONKSİYON ---
  // Artık hatayı yakalayıp kullanıcıyı çıkışa yönlendiriyor.
  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idTokenResult =
          await user.getIdTokenResult(true); // Token'ı yenilemeye zorla
      if (mounted) {
        setState(() {
          _isAdmin = idTokenResult.claims?['admin'] == true;
        });
      }
    } on FirebaseAuthException catch (e) {
      // E-posta değişikliği gibi durumlarda token geçersiz hale gelir.
      // Bu hatayı yakaladığımızda kullanıcıyı bilgilendirip çıkış yaptırıyoruz.
      if (e.code == 'user-token-expired' ||
          e.message!.contains('credential is no longer valid')) {
        if (mounted) {
          showSnackBar(context,
              'Kimlik bilgileriniz değiştiği için yeniden giriş yapmanız gerekiyor.');
          // Kısa bir gecikmeyle logout fonksiyonunu çağırıyoruz ki kullanıcı mesajı görebilsin.
          Future.delayed(const Duration(seconds: 2), () => _logout());
        }
      }
    }
  }

  // ... Diğer fonksiyonlar (_pickAndUploadImage, _sendPasswordResetEmail, vb.) değişmeden kalıyor ...
  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
    if (pickedFile == null) return;
    setState(() => _isUploading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final imageFile = File(pickedFile.path);
      final filePath = 'profile_images/${currentUser.uid}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(filePath);
      await storageRef.putFile(imageFile);
      final downloadURL = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'photoURL': downloadURL});
      if (mounted) showSnackBar(context, 'Profil resmi başarıyla güncellendi!');
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Resim yüklenirken bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_isSendingEmail) return;
    setState(() => _isSendingEmail = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      showSnackBar(context, 'Kullanıcı e-postası bulunamadı.', isError: true);
      setState(() => _isSendingEmail = false);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted)
        showSnackBar(context,
            'Şifre sıfırlama e-postası gönderildi. Lütfen gelen kutunuzu kontrol edin.');
    } on FirebaseAuthException catch (e) {
      if (mounted)
        showSnackBar(context, 'Bir hata oluştu: ${e.message}', isError: true);
    } finally {
      if (mounted)
        setState(() {
          _isSendingEmail = false;
        });
    }
  }

  void _showChangeEmailDialog() {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController newEmailController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('E-posta Adresini Değiştir'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Güvenlik nedeniyle, lütfen mevcut şifrenizi girin.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newEmailController,
                  decoration:
                      const InputDecoration(labelText: 'Yeni E-posta Adresi'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Lütfen geçerli bir e-posta adresi girin.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Mevcut Şifre'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen şifrenizi girin.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(); // Dialog'u kapat
                  _changeEmail(
                    newEmailController.text.trim(),
                    passwordController.text.trim(),
                  );
                }
              },
              child: const Text('Güncelle'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeEmail(String newEmail, String password) async {
    if (_isChangingEmail) return;
    setState(() => _isChangingEmail = true);

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        showSnackBar(context, "Kullanıcı bulunamadı.", isError: true);
        setState(() => _isChangingEmail = false);
      }
      return;
    }

    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    try {
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);
      if (mounted) {
        showSnackBar(context,
            'Doğrulama e-postası $newEmail adresine gönderildi. Lütfen linke tıklayarak değişikliği tamamlayın.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Bir hata oluştu.';
      if (e.code == 'wrong-password') {
        errorMessage = 'Mevcut şifreniz yanlış.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage =
            'Bu e-posta adresi zaten başka bir hesap tarafından kullanılıyor.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Girdiğiniz yeni e-posta adresi geçersiz.';
      } else {
        errorMessage = e.message ?? errorMessage;
      }
      if (mounted) showSnackBar(context, errorMessage, isError: true);
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Beklenmedik bir hata oluştu: ${e.toString()}',
            isError: true);
    } finally {
      if (mounted) setState(() => _isChangingEmail = false);
    }
  }

  Future<void> _launchURL(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted)
        showSnackBar(context, 'Link açılamadı: ${url.toString()}',
            isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Bu durum _checkAdminStatus'teki logout sonrası oluşabilir.
      // AuthGate'e yönlendirme zaten yapıldığı için burada basit bir bekleme göstergesi yeterli.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Kullanıcı bilgileri alınamadı.'));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final photoURL = userData['photoURL'];

        return SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height - kToolbarHeight - 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: photoURL != null
                                  ? CachedNetworkImageProvider(photoURL)
                                  : null,
                              child: photoURL == null
                                  ? const Icon(Icons.person,
                                      size: 60, color: Colors.grey)
                                  : null,
                            ),
                            if (_isUploading) const CircularProgressIndicator(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(userData['fullName'] ?? 'İsim Yok',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(currentUser.email ?? 'E-posta Yok',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[400])),
                      const SizedBox(height: 12),
                      _TeamInvitesSection(currentUserId: currentUser.uid),
                      const Divider(height: 40, thickness: 1),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit_outlined),
                              title: const Text('Profili Düzenle'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(
                                      currentUserData: userData),
                                ));
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading:
                                  const Icon(Icons.alternate_email_outlined),
                              title: const Text('E-postayı Değiştir'),
                              trailing: _isChangingEmail
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.chevron_right),
                              onTap: _showChangeEmailDialog,
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading: const Icon(Icons.lock_reset_outlined),
                              title: const Text('Şifre Değiştir'),
                              trailing: _isSendingEmail
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.chevron_right),
                              onTap: _sendPasswordResetEmail,
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading: const Icon(Icons.policy_outlined),
                              title: const Text('Gizlilik Politikası'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      const LegalDocumentScreen(
                                    title: 'Gizlilik Politikası',
                                    documentContent: LegalTexts.privacyPolicy,
                                  ),
                                ));
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading: const Icon(Icons.description_outlined),
                              title: const Text('Kullanım Koşulları'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      const LegalDocumentScreen(
                                    title: 'Kullanım Koşulları',
                                    documentContent: LegalTexts.termsOfService,
                                  ),
                                ));
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading: const Icon(Icons.feedback_outlined,
                                  color: Colors.cyanAccent),
                              title: const Text('Geri Bildirimde Bulun',
                                  style: TextStyle(color: Colors.cyanAccent)),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.cyanAccent),
                              onTap: () {
                                _launchURL(Uri.parse(
                                    'https://forms.gle/D57K1VcdUxcQfUSY6'));
                              },
                            ),
                            if (_isAdmin)
                              Column(
                                children: [
                                  const Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                      color: Colors.red),
                                  ListTile(
                                    leading: const Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.redAccent),
                                    title: const Text('Admin Paneli',
                                        style:
                                            TextStyle(color: Colors.redAccent)),
                                    trailing: const Icon(Icons.chevron_right,
                                        color: Colors.redAccent),
                                    onTap: () {
                                      Navigator.of(context)
                                          .push(MaterialPageRoute(
                                        builder: (context) =>
                                            const AdminUserListScreen(),
                                      ));
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                    child: TextButton.icon(
                      // YENİ: Artık merkezi _logout fonksiyonunu çağırıyoruz
                      onPressed: _logout,
                      icon: Icon(Icons.logout, color: Colors.red[700]),
                      label: Text('Çıkış Yap',
                          style:
                              TextStyle(color: Colors.red[700], fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TeamInvitesSection extends StatelessWidget {
  final String currentUserId;
  const _TeamInvitesSection({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('team_invites')
          .where('playerId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final invites = snapshot.data!.docs;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Takım Davetleri', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TeamInvitesScreen(),
                          ),
                        );
                      },
                      child: const Text('Tümünü Gör'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...invites.take(2).map((doc) {
                  final invite = doc.data() as Map<String, dynamic>;
                  final teamName = invite['teamName'] ?? 'Takım';
                  final captainName = invite['captainName'] ?? 'Kaptan';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Kaptan: $captainName', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const TeamInvitesScreen(),
                              ),
                            );
                          },
                          child: const Text('Gör', style: TextStyle(color: Colors.blue)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (invites.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${invites.length - 2} davet daha',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}


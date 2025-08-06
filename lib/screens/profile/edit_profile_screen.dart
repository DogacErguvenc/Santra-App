import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  // Bu ekrana, düzenlenecek kullanıcının mevcut bilgilerini gönderiyoruz.
  final Map<String, dynamic> currentUserData;

  const EditProfileScreen({super.key, required this.currentUserData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _fullNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Controller'ı, kullanıcının mevcut adıyla başlatıyoruz.
    _fullNameController =
        TextEditingController(text: widget.currentUserData['fullName']);
  }

  Future<void> _updateProfile() async {
    final newName = _fullNameController.text.trim();
    if (newName.isEmpty) {
      showSnackBar(context, 'Ad Soyad alanı boş bırakılamaz.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // 'users' koleksiyonundaki ilgili kullanıcının dokümanını güncelliyoruz.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fullName': newName});

        if (mounted) {
          showSnackBar(context, 'Profil başarıyla güncellendi!');
          Navigator.of(context).pop(); // Bir önceki ekrana geri dön
        }
      }
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Profil güncellenirken bir hata oluştu.',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _updateProfile,
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Değişiklikleri Kaydet'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

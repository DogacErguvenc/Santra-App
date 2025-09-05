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
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late bool _isSearchable;
  late bool _isTeamSearchable;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Controller'ları, kullanıcının mevcut ad ve soyadıyla başlatıyoruz.
    _firstNameController = TextEditingController(
        text: widget.currentUserData['firstName'] ?? '');
    _lastNameController = TextEditingController(
        text: widget.currentUserData['lastName'] ?? '');
    _isSearchable = (widget.currentUserData['isSearchable'] as bool?) ?? true;
    _isTeamSearchable = (widget.currentUserData['isTeamSearchable'] as bool?) ?? true;
  }

  Future<void> _updateProfile() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    
    if (firstName.isEmpty || lastName.isEmpty) {
      showSnackBar(context, 'Ad ve Soyad alanları boş bırakılamaz.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final fullName = '$firstName $lastName';
        
        // 'users' koleksiyonundaki ilgili kullanıcının dokümanını güncelliyoruz.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'firstName': firstName,
          'lastName': lastName,
          'fullName': fullName,
          'fullName_lowercase': fullName.toLowerCase(),
          'displayName': fullName, // displayName alanını da güncelle
          'isSearchable': _isSearchable,
          'isTeamSearchable': _isTeamSearchable,
        });

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
    _firstNameController.dispose();
    _lastNameController.dispose();
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Soyad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Aramalarda görün'),
              subtitle: const Text('Adınız oyuncu arama sonuçlarında listelensin'),
              value: _isSearchable,
              onChanged: (val) => setState(() => _isSearchable = val),
            ),
            SwitchListTile(
              title: const Text('Takım aramalarında görün'),
              subtitle: const Text('Başka takımlar benim ismimi aratarak davet atabilsin'),
              value: _isTeamSearchable,
              onChanged: (val) => setState(() => _isTeamSearchable = val),
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

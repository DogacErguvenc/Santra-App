import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Yeni paketi import ediyoruz
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';

class AdminUserListScreen extends StatelessWidget {
  const AdminUserListScreen({super.key});

  // GÜNCELLEME: Fonksiyon artık direkt Firestore'a yazmak yerine Cloud Function'ı çağırıyor.
  Future<void> _toggleBanUser(BuildContext context, String userId,
      String userName, bool isCurrentlyBanned) async {
    final String actionText =
        isCurrentlyBanned ? 'banını kaldırmak' : 'banlamak';

    // Onay diyalogu aynı kalıyor
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onay'),
        content: Text(
            '$userName adlı kullanıcıyı $actionText istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Eminim'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 'toggleUserBanStatus' adlı Cloud Function'ımızı çağırıyoruz
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('toggleUserBanStatus');

      // Fonksiyona gerekli parametreleri gönderiyoruz
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'banStatus':
            !isCurrentlyBanned, // Mevcut durumun tersini yap (banlı ise banı kaldır, değilse banla)
      });

      // Fonksiyondan dönen başarılı mesajını gösteriyoruz
      if (context.mounted) {
        showSnackBar(context, result.data['message'] ?? 'İşlem başarılı.');
      }
    } on FirebaseFunctionsException catch (e) {
      // Fonksiyondan dönen olası hataları gösteriyoruz
      if (context.mounted) {
        showSnackBar(context, 'Bir hata oluştu: ${e.message}', isError: true);
      }
    } catch (e) {
      // Diğer olası hatalar için
      if (context.mounted) {
        showSnackBar(context, 'Bilinmeyen bir hata oluştu: $e', isError: true);
      }
    }
  }

  void _showUserActionsDialog(BuildContext context, String userName,
      String userId, bool isBanned, String userRole) {
    // Kendi kendini banlamayı engelle
    if (userId == FirebaseAuth.instance.currentUser?.uid) {
      showSnackBar(context, 'Kendi kendinize işlem yapamazsınız.',
          isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(userName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isBanned ? Icons.check_circle : Icons.block,
                    color: isBanned ? Colors.green : Colors.red),
                title: Text(isBanned
                    ? 'Kullanıcının Banını Kaldır'
                    : 'Kullanıcıyı Banla'),
                onTap: () {
                  Navigator.of(context).pop(); // Önce diyalogu kapat
                  _toggleBanUser(context, userId, userName, isBanned);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.admin_panel_settings, color: Colors.amber),
                title: const Text('Admin Yap / Adminliği Al'),
                onTap: () {
                  Navigator.of(context).pop();
                  showSnackBar(context,
                      '$userName için rol değiştirme özelliği yakında eklenecek.');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Kapat'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Kullanıcılar getirilirken bir hata oluştu.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Sistemde hiç kullanıcı bulunmuyor.'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final userRole = userData['role'] ?? 'Oyuncu';
              final userName = userData['fullName'] ?? 'İsimsiz Kullanıcı';
              final isBanned = userData['isBanned'] ?? false;

              return Card(
                color: isBanned ? Colors.red.withOpacity(0.1) : null,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: userRole == 'admin'
                        ? Colors.redAccent.withOpacity(0.3)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                    child: Icon(
                      userRole == 'admin'
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      color: userRole == 'admin'
                          ? Colors.redAccent
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(userName),
                  subtitle: Text(userData['email'] ?? 'E-posta Yok'),
                  trailing: isBanned
                      ? const Icon(Icons.block, color: Colors.red)
                      : null,
                  onTap: () {
                    _showUserActionsDialog(
                        context, userName, userId, isBanned, userRole);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

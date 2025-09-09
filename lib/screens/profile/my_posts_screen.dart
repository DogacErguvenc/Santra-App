import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/home/post_detail_screen.dart';
import 'package:halisaharakip_app/screens/profile/edit_post_screen.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class MyPostsScreen extends StatelessWidget {
  // DÜZELTME: const kurucu artık sorunsuz çalışıyor çünkü sabit olmayan alan kaldırıldı.
  const MyPostsScreen({super.key});

  Future<void> _deletePost(BuildContext context, String postId, String status) async {
    String dialogTitle = 'İlanı Sil';
    String dialogContent = 'Bu ilanı ve gelen tüm teklifleri kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.';
    
    if (status == 'Beklemede') {
      dialogTitle = 'Bekleyen İlanı Sil';
      dialogContent = 'Bu ilan henüz admin onayından geçmemiş. Silmek istediğinize emin misiniz?';
    } else if (status == 'Reddedildi') {
      dialogTitle = 'Reddedilen İlanı Sil';
      dialogContent = 'Bu ilan admin tarafından reddedilmiş. Silmek istediğinize emin misiniz?';
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: Text(dialogContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(postId);
      final challenges = await postRef.collection('challenges').get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in challenges.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(postRef);
      await batch.commit();

      // DÜZELTME: showSnackBar artık direkt olarak gelen context'i kullanıyor.
      if (context.mounted) {
        showSnackBar(context, 'İlan başarıyla silindi.');
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'İlan silinirken bir hata oluştu: $e',
            isError: true);
      }
    }
  }

  // DÜZELTME: Gereksiz olan scaffoldKey kaldırıldı.
  // final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(
          child: Text('Bu ekranı görmek için giriş yapmalısınız.'));
    }

    return Scaffold(
      // DÜZELTME: key: scaffoldKey satırı kaldırıldı.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('captainId', isEqualTo: currentUser.uid)
            // 'status' filtresini kaldırdım, böylece hem aktif hem dolu ilanlar görünür
            // .where('status', isEqualTo: 'Aktif')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('İlanlar getirilirken bir sorun oluştu.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Henüz oluşturulmuş bir ilanınız bulunmuyor.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final myPosts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: myPosts.length,
            itemBuilder: (context, index) {
              final postDoc = myPosts[index];
              final postData = postDoc.data() as Map<String, dynamic>;
              final formattedDate = DateFormat('dd MMMM, HH:mm', 'tr_TR')
                  .format((postData['matchTimestamp'] as Timestamp).toDate());
              final status = postData['status'] ?? 'Bilinmiyor';
              final adminApproved = postData['adminApproved'] ?? false;
              final rejectionReason = postData['rejectionReason'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ListTile(
                  title: Text(postData['pitchName'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Durum: $status - $formattedDate"),
                      if (status == 'Beklemede')
                        const Text(
                          "Admin onayı bekleniyor...",
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (status == 'Reddedildi')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "İlan reddedildi",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (rejectionReason != null && rejectionReason.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Reddetme Sebebi:",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      rejectionReason,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      else if (status == 'Aktif' && adminApproved)
                        const Text(
                          "✓ Admin onaylandı",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  // Tüm ilanlar silinebilir, 'Aktif' ve 'Reddedildi' ilanlar düzenlenebilir
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'Aktif' || status == 'Reddedildi')
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.blueAccent),
                          tooltip: 'Düzenle',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditPostScreen(post: postDoc),
                              ),
                            );
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red[700]),
                        tooltip: 'İlanı Sil',
                        onPressed: () => _deletePost(context, postDoc.id, status),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PostDetailScreen(postId: postDoc.id),
                      ),
                    );
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

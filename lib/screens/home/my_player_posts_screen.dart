import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class MyPlayerPostsScreen extends StatefulWidget {
  const MyPlayerPostsScreen({super.key});

  @override
  State<MyPlayerPostsScreen> createState() => _MyPlayerPostsScreenState();
}

class _MyPlayerPostsScreenState extends State<MyPlayerPostsScreen> {
  bool _isDeleting = false;

  Future<void> _deletePlayerPost(String postId) async {
    if (_isDeleting) return;

    final shouldDelete = await _showDeleteConfirmationDialog();
    if (!shouldDelete) return;

    setState(() => _isDeleting = true);

    try {
      await FirebaseFirestore.instance
          .collection('player_posts')
          .doc(postId)
          .delete();

      if (mounted) {
        showSnackBar(context, 'Oyuncu ilanı başarıyla silindi!');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'İlan silinirken bir hata oluştu: $e',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('İlanı Sil'),
          content: const Text(
            'Bu oyuncu ilanını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Bu ekranı görmek için giriş yapmalısınız.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyuncu İlanlarım'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('player_posts')
            .where('playerId', isEqualTo: currentUser.uid)
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_search,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz oluşturulmuş bir oyuncu ilanınız bulunmuyor.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Takım bulmak için ilan oluşturun!',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final playerPosts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: playerPosts.length,
            itemBuilder: (context, index) {
              final post = playerPosts[index];
              final postData = post.data() as Map<String, dynamic>;
              final postId = post.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık ve durum
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              postData['position'] ?? 'Pozisyon Belirtilmemiş',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: postData['status'] == 'Aktif'
                                  ? Colors.green
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              postData['status'] ?? 'Bilinmiyor',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Deneyim
                      if (postData['experience'] != null &&
                          postData['experience'].toString().isNotEmpty)
                        _buildInfoRow(
                          Icons.work_outline,
                          'Deneyim',
                          postData['experience'],
                        ),

                      // İlçe
                      if (postData['district'] != null)
                        _buildInfoRow(
                          Icons.location_on_outlined,
                          'İlçe',
                          postData['district'],
                        ),

                      // Oyun Seviyesi
                      if (postData['gameLevel'] != null)
                        _buildInfoRow(
                          Icons.sports_soccer_outlined,
                          'Oyun Seviyesi',
                          postData['gameLevel'],
                        ),

                      // Notlar
                      if (postData['notes'] != null &&
                          postData['notes'].toString().isNotEmpty)
                        _buildInfoRow(
                          Icons.note_alt_outlined,
                          'Notlar',
                          postData['notes'],
                        ),

                      // İletişim Bilgileri
                      if (postData['contactInfo'] != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'İletişim Bilgileri:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildContactInfo(postData['contactInfo']),
                      ],

                      // Oluşturulma Tarihi
                      const SizedBox(height: 12),
                      Text(
                        'Oluşturulma: ${_formatDate(postData['createdAt'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),

                      // Silme Butonu
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isDeleting
                              ? null
                              : () => _deletePlayerPost(postId),
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          label: Text(_isDeleting ? 'Siliniyor...' : 'İlanı Sil'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(Map<String, dynamic> contactInfo) {
    final List<Widget> contactWidgets = [];

    if (contactInfo['phone'] != null &&
        contactInfo['phone'].toString().isNotEmpty) {
      contactWidgets.add(
        _buildContactRow(Icons.phone, 'Telefon', contactInfo['phone']),
      );
    }

    if (contactInfo['socialMedia'] != null &&
        contactInfo['socialMedia'].toString().isNotEmpty) {
      contactWidgets.add(
        _buildContactRow(
            Icons.alternate_email, 'Sosyal Medya', contactInfo['socialMedia']),
      );
    }

    if (contactInfo['other'] != null &&
        contactInfo['other'].toString().isNotEmpty) {
      contactWidgets.add(
        _buildContactRow(Icons.chat_bubble_outline, 'Diğer', contactInfo['other']),
      );
    }

    return Column(children: contactWidgets);
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Bilinmiyor';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Bilinmiyor';
      }
      
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return 'Bilinmiyor';
    }
  }
}

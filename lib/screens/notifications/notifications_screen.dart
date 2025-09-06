import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/home/post_detail_screen.dart';
import 'package:halisaharakip_app/screens/matches/match_detail_screen.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Kullanıcı bulunamadı')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all),
            tooltip: 'Tümünü Okundu İşaretle',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUser.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Bildirimler yüklenirken bir hata oluştu'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Henüz bildiriminiz yok',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              return _buildNotificationCard(notification.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(String notificationId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Bildirim';
    final body = data['body'] ?? '';
    final isRead = data['isRead'] ?? false;
    final createdAt = data['createdAt'] as Timestamp?;
    final type = data['type'] ?? 'general';
    final postId = data['postId'];
    final matchId = data['matchId'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRead ? null : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRead ? Colors.grey : Colors.blue,
          child: Icon(
            _getNotificationIcon(type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty) ...[
              Text(body),
              const SizedBox(height: 4),
            ],
            if (createdAt != null)
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate()),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () => _handleNotificationTap(
          notificationId,
          type,
          postId,
          matchId,
          isRead,
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'match_invite':
        return Icons.sports_soccer;
      case 'team_invite':
        return Icons.group_add;
      case 'match_result':
        return Icons.emoji_events;
      case 'post_comment':
        return Icons.comment;
      case 'general':
      default:
        return Icons.notifications;
    }
  }

  void _handleNotificationTap(
    String notificationId,
    String type,
    String? postId,
    String? matchId,
    bool isRead,
  ) async {
    // Bildirimi okundu olarak işaretle
    if (!isRead) {
      await _markAsRead(notificationId);
    }

    // İlgili sayfaya yönlendir
    if (postId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(postId: postId),
        ),
      );
    } else if (matchId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MatchDetailScreen(matchId: matchId),
        ),
      );
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      showSnackBar(context, 'Bildirim güncellenirken hata oluştu', isError: true);
    }
  }

  Future<void> _markAllAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      showSnackBar(context, 'Tüm bildirimler okundu olarak işaretlendi');
    } catch (e) {
      showSnackBar(context, 'Bildirimler güncellenirken hata oluştu', isError: true);
    }
  }
}

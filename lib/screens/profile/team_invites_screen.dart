import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class TeamInvitesScreen extends StatefulWidget {
  const TeamInvitesScreen({super.key});

  @override
  State<TeamInvitesScreen> createState() => _TeamInvitesScreenState();
}

class _TeamInvitesScreenState extends State<TeamInvitesScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Hata: Kullanıcı bulunamadı.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Takım Davetleri'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('team_invites')
            .where('playerId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Davetler yüklenirken bir hata oluştu.'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Henüz takım davetiniz bulunmuyor.'),
            );
          }

          final invites = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index].data() as Map<String, dynamic>;
              return _buildInviteCard(invite, invites[index].id);
            },
          );
        },
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> inviteData, String inviteId) {
    final teamName = inviteData['teamName'] ?? 'İsimsiz Takım';
    final teamLogoURL = inviteData['teamLogoURL'];
    final captainName = inviteData['captainName'] ?? 'İsimsiz Kaptan';
    final createdAt = inviteData['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: teamLogoURL != null
                      ? NetworkImage(teamLogoURL)
                      : null,
                  child: teamLogoURL == null
                      ? const Icon(Icons.shield)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Kaptan: $captainName',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (createdAt != null)
                  Text(
                    DateFormat('dd/MM').format(createdAt.toDate()),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu takıma katılmak ister misiniz?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectInvite(inviteId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptInvite(inviteId, inviteData),
                    child: const Text('Kabul Et'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptInvite(String inviteId, Map<String, dynamic> inviteData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Kullanıcının zaten bir takımda olup olmadığını kontrol et
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();
      
      if (userData?['teamId'] != null) {
        showSnackBar(context, 'Zaten bir takımda bulunuyorsunuz.', isError: true);
        return;
      }

      // Batch işlemi ile daveti kabul et ve kullanıcıyı takıma ekle
      final batch = FirebaseFirestore.instance.batch();
      
      // Kullanıcıyı takıma ekle
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
        {
          'teamId': inviteData['teamId'],
          'role': 'Oyuncu',
        },
      );
      
      // Daveti kabul edildi olarak işaretle
      batch.update(
        FirebaseFirestore.instance.collection('team_invites').doc(inviteId),
        {
          'status': 'accepted',
          'respondedAt': Timestamp.now(),
        },
      );
      
      // Diğer bekleyen davetleri reddet
      final otherInvitesQuery = await FirebaseFirestore.instance
          .collection('team_invites')
          .where('playerId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();
      
      for (final doc in otherInvitesQuery.docs) {
        if (doc.id != inviteId) {
          batch.update(doc.reference, {
            'status': 'rejected',
            'respondedAt': Timestamp.now(),
          });
        }
      }
      
      await batch.commit();
      
      if (mounted) {
        showSnackBar(context, 'Takıma başarıyla katıldınız!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Davet kabul edilirken bir hata oluştu: $e', isError: true);
      }
    }
  }

  Future<void> _rejectInvite(String inviteId) async {
    try {
      await FirebaseFirestore.instance
          .collection('team_invites')
          .doc(inviteId)
          .update({
        'status': 'rejected',
        'respondedAt': Timestamp.now(),
      });
      
      if (mounted) {
        showSnackBar(context, 'Davet reddedildi.');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Davet reddedilirken bir hata oluştu: $e', isError: true);
      }
    }
  }
}

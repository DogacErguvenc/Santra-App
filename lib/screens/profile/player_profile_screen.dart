import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PlayerProfileScreen extends StatelessWidget {
  final String playerId;

  const PlayerProfileScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oyuncu Profili')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(playerId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Oyuncu bulunamadı.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final fullName = data['fullName'] ?? 'İsimsiz Oyuncu';
          final avatarUrl = data['avatarUrl'];
          final teamName = data['teamName'];
          final position = data['position'];
          final level = data['level'];
          final bio = data['bio'];

          final matchesPlayed = data['stats']?['matches'] ?? 0;
          final goals = data['stats']?['goals'] ?? 0;
          final assists = data['stats']?['assists'] ?? 0;
          final motm = data['stats']?['motm'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, size: 48) : null,
                      ),
                      const SizedBox(height: 12),
                      Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      if (teamName != null) ...[
                        const SizedBox(height: 4),
                        Text(teamName, style: TextStyle(color: Colors.grey[400])),
                      ],
                      if (position != null || level != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [position, level].where((e) => e != null && e.toString().isNotEmpty).join(' • '),
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InviteActionsSection(targetUserId: playerId, targetUserTeamId: data['teamId']),
                const SizedBox(height: 16),
                if (bio != null && (bio as String).isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Hakkında', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                if (bio != null && (bio as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(bio, style: const TextStyle(fontSize: 14)),
                  ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('İstatistikler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(label: 'Maç', value: matchesPlayed.toString(), icon: Icons.sports_soccer),
                            _StatItem(label: 'Gol', value: goals.toString(), icon: Icons.sports_soccer_outlined),
                            _StatItem(label: 'Asist', value: assists.toString(), icon: Icons.assistant_photo),
                            _StatItem(label: 'MOTM', value: motm.toString(), icon: Icons.star),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InviteActionsSection extends StatelessWidget {
  final String targetUserId;
  final String? targetUserTeamId;

  const _InviteActionsSection({required this.targetUserId, required this.targetUserTeamId});

  Future<void> _sendInvite(BuildContext context, String myTeamId, String? myTeamName, String myUserId) async {
    try {
      // Takım adını güvenilir kaynaktan al (users yerine teams)
      String teamNameToUse = myTeamName ?? 'Takım';
      try {
        final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(myTeamId).get();
        final teamData = teamDoc.data();
        if (teamData != null && teamData['teamName'] != null) {
          teamNameToUse = teamData['teamName'];
        }
      } catch (_) {}
      final inviteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('teamInvites')
          .doc(myTeamId);
      // merge:true ile yeniden davet gönderildiğinde de 'pending' olarak güncellenir
      await inviteRef.set({
        'teamId': myTeamId,
        'teamName': teamNameToUse,
        'captainId': myUserId,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet gönderildi.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet gönderilemedi: $e')),
      );
    }
  }

  Future<void> _acceptInvite(BuildContext context, String myUserId, String teamId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(myUserId);
      final userSnap = await userRef.get();
      final currentTeamId = userSnap.data()?['teamId'];
      if (currentTeamId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Önce mevcut takımınızdan ayrılmalısınız.')),
        );
        return;
      }
      await userRef.update({'teamId': teamId, 'role': 'Oyuncu'});
      final inviteRef = userRef.collection('teamInvites').doc(teamId);
      await inviteRef.update({'status': 'accepted'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takıma katıldınız.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet kabul edilemedi: $e')),
      );
    }
  }

  Future<void> _declineInvite(BuildContext context, String myUserId, String teamId) async {
    try {
      final inviteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(myUserId)
          .collection('teamInvites')
          .doc(teamId);
      await inviteRef.update({'status': 'declined'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet reddedildi.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet reddedilemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final isViewingOwnProfile = currentUser.uid == targetUserId;
    if (isViewingOwnProfile) {
      // Show incoming invites
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('teamInvites')
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
                  const Text('Takım Davetleri', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...invites.map((doc) {
                    final invite = doc.data() as Map<String, dynamic>;
                    final teamId = invite['teamId'];
                    final teamName = invite['teamName'] ?? 'Takım';
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
                          Expanded(child: Text(teamName)),
                          TextButton(
                            onPressed: () => _declineInvite(context, currentUser.uid, teamId),
                            child: const Text('Reddet', style: TextStyle(color: Colors.redAccent)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _acceptInvite(context, currentUser.uid, teamId),
                            child: const Text('Kabul Et'),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
      );
    }

    // Viewing another player's profile: show invite button if current user is captain and has a team
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
      builder: (context, myUserSnap) {
        if (!myUserSnap.hasData) return const SizedBox.shrink();
        final myData = myUserSnap.data!.data() as Map<String, dynamic>;
        final myRole = myData['role'];
        final myTeamId = myData['teamId'];
        final myTeamName = myData['teamName'];
        final isCaptain = myRole == 'Kaptan';
        final canInvite = isCaptain && myTeamId != null && (targetUserTeamId == null);

        if (!canInvite) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.center,
          child: ElevatedButton.icon(
            onPressed: () => _sendInvite(context, myTeamId, myTeamName, currentUser.uid),
            icon: const Icon(Icons.mail_outline),
            label: const Text('Takıma Davet Et'),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.tealAccent[400]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    );
  }
}



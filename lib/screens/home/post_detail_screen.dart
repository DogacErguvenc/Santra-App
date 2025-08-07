import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:halisaharakip_app/screens/home/team_profile_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _isLoading = false;

  Future<void> _launchURL(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showSnackBar(context, 'Bu link açılamadı: ${url.toString()}',
            isError: true);
      }
    }
  }

  Future<void> _challengeTeam(String postCaptainId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final myTeamId = userDoc.data()?['teamId'];

      if (myTeamId == null) {
        showSnackBar(context, 'Rakip olmak için bir takımınız olmalı.',
            isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final myTeamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(myTeamId)
          .get();
      final myTeamName = myTeamDoc.data()?['teamName'];

      final challengeRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('challenges')
          .doc(currentUser.uid);

      await challengeRef.set({
        'challengerTeamName': myTeamName,
        'challengerCaptainId': currentUser.uid,
        'challengerTeamId': myTeamId,
        'status': 'beklemede',
        'createdAt': Timestamp.now(),
      });

      // --- YENİDEN EKLENEN BÖLÜM ---
      if (mounted) {
        showSnackBar(context, 'Rakip olma isteği başarıyla iletildi!');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Bir hata oluştu: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptChallenge(
      Map<String, dynamic> postData, Map<String, dynamic> challengeData) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final homeTeamId = postData['teamId'];
    final challengerCaptainId = challengeData['challengerCaptainId'];
    final challengerTeamId = challengeData['challengerTeamId'];

    try {
      final homeTeamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(homeTeamId)
          .get();
      final homeTeamName = homeTeamDoc.data()?['teamName'] ?? 'Ev Sahibi Takım';

      final batch = FirebaseFirestore.instance.batch();

      // 1. İlanın durumunu 'Dolu' yap
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      batch.update(postRef, {'status': 'Dolu'});

      // 2. Meydan okumanın durumunu 'kabul edildi' yap
      final challengeRef =
          postRef.collection('challenges').doc(challengerCaptainId);
      batch.update(challengeRef, {'status': 'kabul edildi'});

      // 3. Yeni bir 'matches' belgesi oluştur
      final matchRef = FirebaseFirestore.instance.collection('matches').doc();
      batch.set(matchRef, {
        'homeTeamId': homeTeamId,
        'homeTeamName': homeTeamName,
        'homeCaptainId': postData['captainId'],
        'awayTeamId': challengerTeamId,
        'awayTeamName': challengeData['challengerTeamName'],
        'awayCaptainId': challengerCaptainId,
        'matchTimestamp': postData['matchTimestamp'],
        'pitchName': postData['pitchName'],
        'district': postData['district'],
        'createdAt': Timestamp.now(),
        'status': 'Ayarlandı',
        'postId': widget.postId,
        'participantUids': [postData['captainId'], challengerCaptainId],
      });

      await batch.commit();

      if (mounted) {
        showSnackBar(context, 'Meydan okuma kabul edildi! Maç oluşturuldu.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'İstek kabul edilirken hata oluştu: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _declineChallenge(String challengerCaptainId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('challenges')
          .doc(challengerCaptainId) // Belge ID'si meydan okuyan kaptanın ID'si
          .update({'status': 'reddedildi'});

      if (mounted) showSnackBar(context, 'Meydan okuma reddedildi.');
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'İstek reddedilirken hata oluştu: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildChallengesList(String postId, Map<String, dynamic> postData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gelen Rakip Olma İstekleri',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Divider(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('challenges')
              .where('status', isEqualTo: 'beklemede')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Text('İstekler getirilirken bir sorun oluştu.');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text('Henüz yeni bir istek yok.');
            }
            final challenges = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: challenges.length,
              itemBuilder: (context, index) {
                final challengeData =
                    challenges[index].data() as Map<String, dynamic>;
                final challengerCaptainId = challenges[index].id;
                return Card(
                  color: Colors.grey[800],
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    title: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeamProfileScreen(
                              teamId: challengeData['challengerTeamId'] ?? '',
                              teamName: challengeData['challengerTeamName'] ??
                                  'İsimsiz Takım',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        challengeData['challengerTeamName'] ?? 'İsimsiz Takım',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ),
                    subtitle: Text('Durum:  [39m${challengeData['status']}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          icon: const Icon(Icons.check,
                              color: Colors.greenAccent),
                          onPressed: () =>
                              _acceptChallenge(postData, challengeData)),
                      IconButton(
                          icon:
                              const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () =>
                              _declineChallenge(challengerCaptainId)),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildChallengerView(String postCaptainId, String currentUserId) {
    return StreamBuilder<DocumentSnapshot>(
      // Kendi meydan okuma belgemizi anlık olarak dinliyoruz
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('challenges')
          .doc(currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Eğer bir challenge belgesi yoksa veya reddedildiyse, "Rakip Ol" butonunu göster.
        if (!snapshot.hasData ||
            !snapshot.data!.exists ||
            snapshot.data!.get('status') == 'reddedildi') {
          bool isRejected = snapshot.hasData &&
              snapshot.data!.exists &&
              snapshot.data!.get('status') == 'reddedildi';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isRejected)
                Card(
                  color: Colors.red[900],
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                        'Rakip olma isteğiniz reddedildi. Tekrar deneyebilirsiniz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              if (isRejected) const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: () => _challengeTeam(postCaptainId),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size(double.infinity, 50)),
                  child: Text(isRejected ? 'Tekrar Rakip Ol' : 'Rakip Ol')),
            ],
          );
        }

        // Eğer varsa ve durumu "beklemede" veya "kabul edildi" ise bilgi kartı göster.
        final challengeData = snapshot.data!.data() as Map<String, dynamic>;
        final status = challengeData['status'];

        if (status == 'beklemede') {
          return const Card(
              color: Colors.blueGrey,
              child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('İstek gönderildi, rakibin yanıtı bekleniyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white))));
        } else {
          // status == 'kabul edildi'
          return Card(
              color: Colors.green[800],
              child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text('Meydan okumanız kabul edildi! Maç ayarlandı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white))));
        }
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.grey[400]),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildContactInfoSection(Map<String, dynamic>? contactInfo) {
    if (contactInfo == null) return const SizedBox.shrink();
    final String phone = contactInfo['phone'] ?? '';
    final String socialMedia = contactInfo['socialMedia'] ?? '';
    final String other = contactInfo['other'] ?? '';

    if (phone.isEmpty && socialMedia.isEmpty && other.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 32),
      const Text('Paylaşılan İletişim Bilgileri',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      if (phone.isNotEmpty)
        ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Telefon'),
            subtitle: Text(phone),
            onTap: () => _launchURL(Uri.parse('tel:$phone'))),
      if (socialMedia.isNotEmpty)
        ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Sosyal Medya'),
            subtitle: SelectableText(socialMedia)),
      if (other.isNotEmpty)
        ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Diğer'),
            subtitle: SelectableText(other)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('İlan Detayı')),
      body: currentUser == null
          ? const Center(child: Text("Bu bölüm için giriş yapmalısınız."))
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .get(),
              builder: (context, postSnapshot) {
                if (postSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (postSnapshot.hasError ||
                    !postSnapshot.hasData ||
                    !postSnapshot.data!.exists) {
                  return const Center(child: Text('İlan bulunamadı.'));
                }

                final postData =
                    postSnapshot.data!.data() as Map<String, dynamic>;
                final formattedDate = DateFormat('dd MMMM HH:mm', 'tr_TR')
                    .format((postData['matchTimestamp'] as Timestamp).toDate());
                final isPostOwner = postData['captainId'] == currentUser.uid;
                final isPostFilled = postData['status'] == 'Dolu';

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      Text(postData['pitchName'] ?? 'İsimsiz Saha',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                          Icons.calendar_today, 'Maç Tarihi', formattedDate),
                      _buildDetailRow(Icons.shield_outlined, 'Oyun Seviyesi',
                          postData['gameLevel'] ?? 'Belirtilmemiş'),
                      _buildDetailRow(Icons.notes, 'Maç Notları',
                          postData['notes'] ?? 'Yok'),
                      _buildContactInfoSection(postData['contactInfo']),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (isPostFilled)
                        Card(
                          color: Colors.grey.shade700,
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                                child: Text('Bu ilan için rakip bulundu.',
                                    style: TextStyle(fontSize: 16))),
                          ),
                        )
                      else if (isPostOwner)
                        _buildChallengesList(widget.postId, postData)
                      else
                        _buildChallengerView(
                            postData['captainId'], currentUser.uid),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

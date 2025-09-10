import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/matches/match_detail_screen.dart';
import 'package:intl/intl.dart';

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Lütfen giriş yapın.'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final userTeamId =
            (userSnapshot.data!.data() as Map<String, dynamic>)['teamId'];

        if (userTeamId == null) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
                'Onaylanmış maçlarınızı görmek için bir takımda olmalısınız.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .where('participantUids', arrayContains: currentUser.uid)
              .orderBy('matchTimestamp',
                  descending: true) // En yeni maçlar en üstte
              .snapshots(),
          builder: (context, matchSnapshot) {
            if (matchSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (matchSnapshot.hasError) {
              return const Center(
                  child: Text('Maçlar getirilirken bir sorun oluştu.'));
            }
            if (!matchSnapshot.hasData || matchSnapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('Henüz ayarlanmış bir maçınız yok.',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
              );
            }

            // YENİ MANTIK: Maçları iki ayrı listeye ayırma
            final allMatches = matchSnapshot.data!.docs;
            final List<DocumentSnapshot> upcomingMatches = [];
            final List<DocumentSnapshot> pastMatches = [];

            for (var matchDoc in allMatches) {
              final matchData = matchDoc.data() as Map<String, dynamic>;
              if (matchData['status'] == 'Onaylandı') {
                pastMatches.add(matchDoc);
              } else {
                upcomingMatches.add(matchDoc);
              }
            }

            // YENİ ARAYÜZ: İki listeyi de başlıklarıyla gösteren yapı
            return ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                // Gelecek Maçlar Bölümü
                _buildSectionHeader('Gelecek Maçlar'),
                if (upcomingMatches.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Yaklaşan bir maçınız yok.',
                              style: TextStyle(color: Colors.grey))))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: upcomingMatches.length,
                    itemBuilder: (context, index) {
                      return _buildMatchCard(
                          context, upcomingMatches[index], userTeamId,
                          isPastMatch: false);
                    },
                  ),

                const SizedBox(height: 20),
                const Divider(),

                // Biten Maçlar Bölümü
                _buildSectionHeader('Biten Maçlar'),
                if (pastMatches.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Henüz tamamlanmış bir maçınız yok.',
                              style: TextStyle(color: Colors.grey))))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pastMatches.length,
                    itemBuilder: (context, index) {
                      return _buildMatchCard(
                          context, pastMatches[index], userTeamId,
                          isPastMatch: true);
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // YENİ YARDIMCI WIDGET: Başlıkları oluşturmak için
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  // YENİ YARDIMCI WIDGET: Maç kartlarını oluşturmak için (tekrarı önler)
  Widget _buildMatchCard(
      BuildContext context, DocumentSnapshot matchDoc, String userTeamId,
      {required bool isPastMatch}) {
    final matchData = matchDoc.data() as Map<String, dynamic>;
    final matchId = matchDoc.id;
    final currentUser = FirebaseAuth.instance.currentUser!;

    // Kullanıcının hangi takımda olduğunu belirle
    final bool isHomeTeam = matchData['homeCaptainId'] == currentUser.uid;
    final String myTeamName = isHomeTeam
        ? matchData['homeTeamName']
        : matchData['awayTeamName'];
    final String opponentTeamName = isHomeTeam
        ? matchData['awayTeamName']
        : matchData['homeTeamName'];

    final matchDate = (matchData['matchTimestamp'] as Timestamp).toDate();
    final formattedDate =
        DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(matchDate);

    // Biten maçlar için skor, gelecek maçlar için tarih göster
    final String subtitleText = isPastMatch
        ? 'Skor: ${matchData['homeScore']} - ${matchData['awayScore']}'
        : '${matchData['pitchName']}\n$formattedDate';

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.sports_soccer)),
        title: Text('$myTeamName vs $opponentTeamName',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitleText),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MatchDetailScreen(matchId: matchId),
            ),
          );
        },
      ),
    );
  }
}

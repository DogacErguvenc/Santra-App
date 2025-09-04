import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/home/team_profile_screen.dart';
import 'package:halisaharakip_app/screens/main_layout.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sıralama'),
        automaticallyImplyLeading: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // GÜNCELLEME: Sadece en az 1 maç yapmış takımları getirmek için 'where' kuralı eklendi.
        stream: FirebaseFirestore.instance
            .collection('teams')
            .where('matchesPlayed', isGreaterThan: 0) // YENİ KURAL
            .orderBy('points', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // GÜNCELLEME: Index oluşturulana kadar hata mesajını kullanıcıya daha anlaşılır gösterelim.
          if (snapshot.hasError) {
            print(snapshot.error); // Hatayı konsola yazdır.
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Sıralama getirilirken bir sorun oluştu. Genellikle bu, veritabanı index\'i gerektirir. Lütfen Debug Console\'daki linke tıklayarak index\'i oluşturun.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Sıralamada gösterilecek takım bulunamadı.'));
          }

          final teams = snapshot.data!.docs;

          return ListView.builder(
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index].data() as Map<String, dynamic>;
              final rank = index + 1;
              final points = team['points'] ?? 0;
              final wins = team['wins'] ?? 0;
              final draws = team['draws'] ?? 0;
              final losses = team['losses'] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('$rank',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(
                    team['teamName'] ?? 'İsimsiz Takım',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle:
                      Text('Puan: $points  (G: $wins B: $draws M: $losses)'),
                  trailing: const Icon(Icons.bar_chart),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamProfileScreen(
                          teamId: teams[index].id,
                          teamName: team['teamName'] ?? 'İsimsiz Takım',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 3, // Takımım
        onTap: (index) {
          if (index == 3) {
            Navigator.of(context).pop();
            return;
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MainLayout(initialIndex: index)),
            (route) => false,
          );
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Ana Sayfa'),
          BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined),
              activeIcon: Icon(Icons.article),
              label: 'İlanlarım'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_available_outlined),
              activeIcon: Icon(Icons.event_available),
              label: 'Maçlarım'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield),
              label: 'Takımım'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }
}

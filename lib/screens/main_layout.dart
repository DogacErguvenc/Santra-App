import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/home/create_post_view.dart';
import 'package:halisaharakip_app/screens/home/create_team_view.dart';
import 'package:halisaharakip_app/screens/home/posts_list_view.dart';
import 'package:halisaharakip_app/screens/home/profile_screen.dart';
import 'package:halisaharakip_app/screens/home/team_screen.dart';
import 'package:halisaharakip_app/screens/leaderboard/leaderboard_screen.dart';
import 'package:halisaharakip_app/screens/matches/my_matches_screen.dart';
import 'package:halisaharakip_app/screens/profile/my_posts_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
          body: Center(child: Text("Hata: Kullanıcı bulunamadı.")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: Text("Kullanıcı verisi bulunamadı.")));
        }

        final userData = snapshot.data!;
        final userRole = (userData.data() as Map<String, dynamic>)['role'];
        final userTeamId = (userData.data() as Map<String, dynamic>)['teamId'];

        final bool canPost =
            (userRole == 'Kaptan' || userRole == 'admin') && userTeamId != null;

        final List<Widget> screens = [
          const PostsListView(),
          const LeaderboardScreen(),
          // DÜZELTME: MyPostsScreen artık parametre almıyor.
          userTeamId != null
              ? const MyPostsScreen()
              : const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                          'İlanlarını görmek için bir takımda olmalısın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey)))),
          const MyMatchesScreen(),
          userTeamId == null
              ? CreateTeamView(onTeamCreated: () => setState(() {}))
              : TeamScreen(userDoc: userData, teamId: userTeamId),
          // DÜZELTME: ProfileScreen artık parametre almıyor.
          const ProfileScreen(),
        ];

        final List<String> appBarTitles = [
          'Santra', // Ana sayfa başlığı
          'Sıralama',
          'Aktif İlanlarım',
          'Maçlarım',
          'Takımım',
          'Profilim',
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(appBarTitles[_selectedIndex]),
            actions: [
              IconButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Çıkış Yap'),
            ],
          ),
          body: screens.elementAt(_selectedIndex),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Ana Sayfa'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.leaderboard_outlined),
                  activeIcon: Icon(Icons.leaderboard),
                  label: 'Sıralama'),
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
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
          floatingActionButton: (_selectedIndex == 0 && canPost)
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const CreatePostView()));
                  },
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}

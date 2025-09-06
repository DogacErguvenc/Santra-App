import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/home/create_post_view.dart';
import 'package:halisaharakip_app/screens/home/create_team_view.dart';
import 'package:halisaharakip_app/screens/home/posts_list_view.dart';
import 'package:halisaharakip_app/screens/home/profile_screen.dart';
import 'package:halisaharakip_app/screens/home/team_screen.dart';
import 'package:halisaharakip_app/screens/matches/my_matches_screen.dart';
import 'package:halisaharakip_app/screens/notifications/notifications_screen.dart';
import 'package:halisaharakip_app/screens/profile/my_posts_screen.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;

  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget? _buildFloatingActionButton(bool canPost) {
    if (_selectedIndex == 0 && canPost) {
      // Ana sayfa - Maç ilanı oluştur
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const CreatePostView()));
        },
        child: const Icon(Icons.add),
      );
    } else if (_selectedIndex == 1 && canPost) {
      // İlanlarım - Maç ilanı oluştur
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const CreatePostView()));
        },
        child: const Icon(Icons.add),
      );
    }
    return null;
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
        final bool hasTeam = userTeamId != null && userTeamId.toString().isNotEmpty;

        final bool canPost =
            (userRole == 'Kaptan' || userRole == 'admin') && hasTeam;

        final List<Widget> screens = [
          const PostsListView(),
          // DÜZELTME: MyPostsScreen artık parametre almıyor.
          hasTeam
              ? const MyPostsScreen()
              : const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                          'İlanlarını görmek için bir takımda olmalısın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey)))),
          const MyMatchesScreen(),
          hasTeam
              ? TeamScreen(userDoc: userData, teamId: userTeamId.toString())
              : CreateTeamView(onTeamCreated: () => setState(() {})),
          // DÜZELTME: ProfileScreen artık parametre almıyor.
          const ProfileScreen(),
        ];

        final List<String> appBarTitles = [
          'Santra', // Ana sayfa başlığı
          'Aktif İlanlarım',
          'Maçlarım',
          'Takımım',
          'Profilim',
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(appBarTitles[_selectedIndex]),
            actions: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: currentUser.uid)
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, notificationSnapshot) {
                  final unreadCount = notificationSnapshot.hasData 
                      ? notificationSnapshot.data!.docs.length 
                      : 0;
                  
                  return Stack(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications_outlined),
                        tooltip: 'Bildirimler',
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
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
          floatingActionButton: _buildFloatingActionButton(canPost),
        );
      },
    );
  }
}

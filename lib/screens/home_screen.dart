import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/home/create_post_view.dart';
import 'package:halisaharakip_app/screens/home/create_team_view.dart';
import 'package:halisaharakip_app/screens/home/posts_list_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('Kullanıcı bulunamadı.'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Scaffold ekleyerek yüklenme animasyonunun tam ekranda düzgün görünmesini sağlıyoruz
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('Bir hata oluştu.')));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Kullanıcı verisi bulunamadı.')),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final teamId = userData['teamId'];

        // Bu ekranda body ve floatingActionButton aynı anda gösterildiği için,
        // Scaffold'un içinde olmaları gerekiyor. Bu yüzden onu main_layout'tan buraya taşıdık.
        // Artık main_layout sadece sekmeleri yönetiyor.
        return Scaffold(
          // Body'yi teamId'ye göre belirliyoruz
          body: teamId == null
              ? CreateTeamView(
                  // DEĞİŞİKLİK BURADA:
                  // CreateTeamView'a, işi bittiğinde bu ekranı
                  // yeniden çizmesini söyleyecek olan fonksiyonu gönderiyoruz.
                  onTeamCreated: () {
                    setState(() {});
                  },
                )
              : const PostsListView(),
          // Yüzen eylem butonunu role'e göre belirliyoruz (sadece Kaptanlar görür)
          floatingActionButton: userData['role'] == 'Kaptan'
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreatePostView(),
                      ),
                    );
                  },
                  backgroundColor: Colors.blueGrey[800],
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }
}

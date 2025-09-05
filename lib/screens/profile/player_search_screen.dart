import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halisaharakip_app/screens/profile/player_profile_screen.dart';

class PlayerSearchScreen extends StatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  State<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends State<PlayerSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String searchText = _controller.text.trim().toLowerCase();
    Query usersQuery = FirebaseFirestore.instance
        .collection('users')
        .where('isSearchable', isEqualTo: true);
    if (searchText.isNotEmpty) {
      usersQuery = usersQuery
          .orderBy('fullName_lowercase')
          .startAt([searchText])
          .endAt(['$searchText\uf8ff'])
          .limit(50);
    } else {
      usersQuery = usersQuery.orderBy('createdAt', descending: true).limit(20);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Oyuncu Ara')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'İsim yazarak oyuncu ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _controller.clear()),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9çÇğĞıİöÖşŞüÜ ]'),
                ),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: usersQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Arama sırasında bir hata oluştu.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Sonuç bulunamadı.'));
                }
                final users = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData = users[index].data() as Map<String, dynamic>;
                    final fullName = userData['fullName'] ?? 'İsimsiz Oyuncu';
                    final teamName = userData['teamName'];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(fullName),
                      subtitle: teamName != null ? Text(teamName) : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerProfileScreen(playerId: users[index].id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



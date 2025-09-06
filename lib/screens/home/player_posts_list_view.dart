import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/screens/profile/player_profile_screen.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class PlayerPostsListView extends StatefulWidget {
  const PlayerPostsListView({super.key});

  @override
  State<PlayerPostsListView> createState() => _PlayerPostsListViewState();
}

class _PlayerPostsListViewState extends State<PlayerPostsListView> {
  String _selectedDistrict = 'Tümü';
  String _selectedPosition = 'Tümü';
  String _selectedGameLevel = 'Tümü';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _districts = [
    'Tümü',
    'Adalar',
    'Arnavutköy',
    'Ataşehir',
    'Avcılar',
    'Bağcılar',
    'Bahçelievler',
    'Bakırköy',
    'Başakşehir',
    'Bayrampaşa',
    'Beşiktaş',
    'Beykoz',
    'Beylikdüzü',
    'Beyoğlu',
    'Büyükçekmece',
    'Çatalca',
    'Çekmeköy',
    'Esenler',
    'Esenyurt',
    'Eyüpsultan',
    'Fatih',
    'Gaziosmanpaşa',
    'Güngören',
    'Kadıköy',
    'Kağıthane',
    'Kartal',
    'Küçükçekmece',
    'Maltepe',
    'Pendik',
    'Sancaktepe',
    'Sarıyer',
    'Silivri',
    'Sultanbeyli',
    'Sultangazi',
    'Şile',
    'Şişli',
    'Tuzla',
    'Ümraniye',
    'Üsküdar',
    'Zeytinburnu'
  ];

  final List<String> _positions = [
    'Tümü',
    'Kaleci',
    'Defans',
    'Orta Saha',
    'Forvet',
    'Kanat',
    'Libero',
    'Stoper',
    'Bek',
    'Ofansif Orta Saha',
    'Defansif Orta Saha',
    'Santrafor',
    'İkinci Forvet'
  ];

  final List<String> _gameLevels = ['Tümü', 'Başlangıç', 'Orta', 'İleri Düzey'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendTeamInvite(String playerId, String playerName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Kullanıcının takım bilgilerini al
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();
      
      if (userData?['teamId'] == null) {
        showSnackBar(context, 'Takım daveti göndermek için bir takımda olmalısınız.', isError: true);
        return;
      }

      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(userData!['teamId'])
          .get();
      final teamData = teamDoc.data();
      
      if (teamData == null) {
        showSnackBar(context, 'Takım bilgileri bulunamadı.', isError: true);
        return;
      }

      // Aynı oyuncuya daha önce davet gönderilip gönderilmediğini kontrol et
      final existingInviteQuery = await FirebaseFirestore.instance
          .collection('team_invites')
          .where('playerId', isEqualTo: playerId)
          .where('captainId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (existingInviteQuery.docs.isNotEmpty) {
        showSnackBar(context, 'Bu oyuncuya zaten bir davet gönderdiniz.', isError: true);
        return;
      }

      // Oyuncu ilanı açmışsa, takım davetlerini kabul etmeye istekli demektir
      // Bu yüzden isTeamSearchable kontrolü yapmıyoruz

      // Davet gönder
      await FirebaseFirestore.instance.collection('team_invites').add({
        'teamId': userData['teamId'],
        'teamName': teamData['teamName'],
        'teamLogoURL': teamData['logoURL'],
        'captainId': currentUser.uid,
        'captainName': userData['fullName'],
        'playerId': playerId,
        'playerName': playerName,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      showSnackBar(context, '$playerName isimli oyuncuya takım daveti gönderildi!');
    } catch (e) {
      showSnackBar(context, 'Davet gönderilirken bir hata oluştu: $e', isError: true);
    }
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('İlçe', _selectedDistrict, _districts, (value) {
            setState(() => _selectedDistrict = value);
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Pozisyon', _selectedPosition, _positions, (value) {
            setState(() => _selectedPosition = value);
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Seviye', _selectedGameLevel, _gameLevels, (value) {
            setState(() => _selectedGameLevel = value);
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String currentValue, List<String> options, Function(String) onChanged) {
    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: $currentValue'),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => options.map((option) => PopupMenuItem<String>(
        value: option,
        child: Text(option),
      )).toList(),
      onSelected: onChanged,
    );
  }

  Widget _buildPlayerPostCard(Map<String, dynamic> postData, String postId, bool isCaptain) {
    final playerName = postData['playerName'] ?? 'İsimsiz Oyuncu';
    final position = postData['position'] ?? '';
    final experience = postData['experience'] ?? '';
    final district = postData['district'] ?? '';
    final gameLevel = postData['gameLevel'] ?? '';
    final notes = postData['notes'] ?? '';
    final createdAt = postData['createdAt'] as Timestamp?;
    final playerImageURL = postData['playerImageURL'];

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
                  backgroundImage: playerImageURL != null
                      ? NetworkImage(playerImageURL)
                      : null,
                  child: playerImageURL == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        position,
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
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.location_on, district),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.sports_soccer, gameLevel),
              ],
            ),
            if (experience.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Deneyim: $experience',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlayerProfileScreen(playerId: postData['playerId']),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text('Profili Gör'),
                  ),
                ),
                if (isCaptain) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendTeamInvite(postData['playerId'], playerName),
                      icon: const Icon(Icons.group_add, size: 16),
                      label: const Text('Davet Gönder'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyuncu İlanları'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('Kullanıcı bilgileri bulunamadı.'));
          }
          
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final userRole = userData['role'];
          final userTeamId = userData['teamId'];
          final bool isCaptain = userRole == 'Kaptan' && userTeamId != null;
          
          return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Oyuncu ara...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                _buildFilterChips(),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('player_posts')
                  .where('status', isEqualTo: 'Aktif')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Oyuncu ilanları yüklenirken bir hata oluştu.'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Henüz oyuncu ilanı bulunmuyor.'),
                  );
                }

                final posts = snapshot.data!.docs;
                List<QueryDocumentSnapshot> filteredPosts = posts.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // Arama filtresi
                  final searchQuery = _searchController.text.toLowerCase();
                  if (searchQuery.isNotEmpty) {
                    final playerName = (data['playerName'] ?? '').toLowerCase();
                    final position = (data['position'] ?? '').toLowerCase();
                    final experience = (data['experience'] ?? '').toLowerCase();
                    final notes = (data['notes'] ?? '').toLowerCase();
                    
                    if (!playerName.contains(searchQuery) &&
                        !position.contains(searchQuery) &&
                        !experience.contains(searchQuery) &&
                        !notes.contains(searchQuery)) {
                      return false;
                    }
                  }
                  
                  // İlçe filtresi
                  if (_selectedDistrict != 'Tümü') {
                    if (data['district'] != _selectedDistrict) {
                      return false;
                    }
                  }
                  
                  // Pozisyon filtresi
                  if (_selectedPosition != 'Tümü') {
                    if (data['position'] != _selectedPosition) {
                      return false;
                    }
                  }
                  
                  // Seviye filtresi
                  if (_selectedGameLevel != 'Tümü') {
                    if (data['gameLevel'] != _selectedGameLevel) {
                      return false;
                    }
                  }
                  
                  return true;
                }).toList();

                if (filteredPosts.isEmpty) {
                  return const Center(
                    child: Text('Filtrelere uygun oyuncu ilanı bulunamadı.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) {
                    final post = filteredPosts[index];
                    return _buildPlayerPostCard(
                      post.data() as Map<String, dynamic>,
                      post.id,
                      isCaptain,
                    );
                  },
                );
              },
            ),
          ),
          ],
        );
        },
      ),
    );
  }
}

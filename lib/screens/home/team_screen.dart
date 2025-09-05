import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halisaharakip_app/screens/leaderboard/leaderboard_screen.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:halisaharakip_app/screens/profile/player_profile_screen.dart';
import 'package:halisaharakip_app/screens/home/player_posts_list_view.dart';

class TeamScreen extends StatefulWidget {
  final DocumentSnapshot userDoc;
  final String teamId;

  const TeamScreen({super.key, required this.userDoc, required this.teamId});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _isDeleting = false;
  bool _isUploadingLogo = false;

  // --- YENİ EKLENEN FONKSİYON: Takım adı düzenleme diyaloğu ---
  Future<void> _showEditTeamNameDialog(String currentTeamName) async {
    final TextEditingController nameController =
        TextEditingController(text: currentTeamName);
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Takım Adını Düzenle'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Yeni Takım Adı'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Takım adı boş bırakılamaz.';
                }
                if (value.length > 25) {
                  return 'Takım adı en fazla 25 karakter olabilir.';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Kaydet'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text.trim();
                  try {
                    // Güvenlik kuralımız bu işleme sadece kaptanın izin vermesini sağlıyor.
                    await FirebaseFirestore.instance
                        .collection('teams')
                        .doc(widget.teamId)
                        .update({'teamName': newName});
                    if (mounted) {
                      showSnackBar(context, 'Takım adı başarıyla güncellendi.');
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      showSnackBar(
                          context, 'Güncelleme sırasında hata oluştu: $e',
                          isError: true);
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadLogo() async {
    if (_isUploadingLogo) return;

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
    if (pickedFile == null) return;

    setState(() => _isUploadingLogo = true);

    try {
      final imageFile = File(pickedFile.path);
      final filePath = 'team_logos/${widget.teamId}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(filePath);
      await storageRef.putFile(imageFile);
      final downloadURL = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .update({'logoURL': downloadURL});

      if (mounted) showSnackBar(context, 'Takım logosu başarıyla güncellendi!');
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Logo yüklenirken bir hata oluştu: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _removePlayer(String playerId, String playerName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Oyuncuyu Çıkar'),
          content: Text(
              '"$playerName" isimli oyuncuyu takımdan çıkarmak istediğinize emin misiniz?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Çıkar')),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(playerId)
          .update({'teamId': null, 'role': 'Oyuncu'});
      if (mounted) showSnackBar(context, '"$playerName" takımdan çıkarıldı.');
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Oyuncu çıkarılırken bir hata oluştu: $e',
            isError: true);
      }
    }
  }

  Future<void> _transferCaptaincy(
      String newCaptainId, String newCaptainName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaptanlığı Devret'),
        content: Text(
            'Kaptanlığı "$newCaptainName" isimli oyuncuya devretmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Devret')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final teamRef =
          FirebaseFirestore.instance.collection('teams').doc(widget.teamId);
      batch.update(teamRef, {'captainId': newCaptainId});
      final oldCaptainRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userDoc.id);
      batch.update(oldCaptainRef, {'role': 'Oyuncu'});
      final newCaptainRef =
          FirebaseFirestore.instance.collection('users').doc(newCaptainId);
      batch.update(newCaptainRef, {'role': 'Kaptan'});
      await batch.commit();
      if (mounted) showSnackBar(context, 'Kaptanlık başarıyla devredildi.');
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'İşlem sırasında hata oluştu: $e', isError: true);
      }
    }
  }

  Future<void> _leaveTeam() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Takımdan Ayrıl'),
        content: const Text('Bu takımdan ayrılmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Ayrıl')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userDoc.id)
          .update({'teamId': null, 'role': 'Oyuncu'});
      if (mounted) showSnackBar(context, 'Takımdan başarıyla ayrıldınız.');
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'İşlem sırasında hata oluştu: $e', isError: true);
      }
    }
  }

  Future<void> _deleteTeam() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final teamId = widget.teamId;
      final playersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('teamId', isEqualTo: teamId)
          .get();
      for (final playerDoc in playersQuery.docs) {
        batch.update(playerDoc.reference, {'teamId': null, 'role': 'Oyuncu'});
      }
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('teamId', isEqualTo: teamId)
          .get();
      for (final postDoc in postsQuery.docs) {
        batch.delete(postDoc.reference);
      }
      final matchesQuery = await FirebaseFirestore.instance
          .collection('matches')
          .where('participantTeamIds', arrayContains: teamId)
          .get();
      for (final matchDoc in matchesQuery.docs) {
        final matchData = matchDoc.data();
        if (matchData['awayTeamId'] == teamId) {
          final postId = matchData['postId'];
          if (postId != null) {
            final originalPostRef =
                FirebaseFirestore.instance.collection('posts').doc(postId);
            batch.update(originalPostRef, {'status': 'Aktif'});
            final challengesSnapshot =
                await originalPostRef.collection('challenges').get();
            for (var doc in challengesSnapshot.docs) {
              batch.delete(doc.reference);
            }
          }
        }
        batch.delete(matchDoc.reference);
      }
      final teamRef =
          FirebaseFirestore.instance.collection('teams').doc(teamId);
      batch.delete(teamRef);
      await batch.commit();
      if (mounted) {
        showSnackBar(
            context, 'Takım ve tüm ilişkili veriler kalıcı olarak silindi.');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Takım silinirken bir hata oluştu: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showDeleteTeamDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Takımı Kalıcı Olarak Sil'),
                content: const Text(
                    'Bu işlem geri alınamaz. Takım, tüm oyuncuları, ilanları ve maçlarıyla birlikte sistemden silinecektir. Emin misiniz?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('İptal')),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteTeam();
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Evet, Sil'))
                ]));
  }

  Widget _buildStatsCard(Map<String, dynamic> teamData) {
    final matchesPlayed = teamData['matchesPlayed'] ?? 0;
    final wins = teamData['wins'] ?? 0;
    final draws = teamData['draws'] ?? 0;
    final losses = teamData['losses'] ?? 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatColumn('Maç', matchesPlayed),
            _buildStatColumn('Galibiyet', wins),
            _buildStatColumn('Beraberlik', draws),
            _buildStatColumn('Mağlubiyet', losses),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .snapshots(),
      builder: (context, teamSnapshot) {
        if (teamSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (teamSnapshot.hasError || !teamSnapshot.data!.exists) {
          return const Center(child: Text("Takım bilgileri bulunamadı."));
        }

        final teamData = teamSnapshot.data!.data() as Map<String, dynamic>;
        final captainId = teamData['captainId'];
        final logoURL = teamData['logoURL'];
        final isCurrentUserTheCaptain = widget.userDoc.id == captainId;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: isCurrentUserTheCaptain ? _pickAndUploadLogo : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: logoURL != null
                            ? CachedNetworkImageProvider(logoURL)
                            : null,
                        child: logoURL == null
                            ? const Icon(Icons.shield,
                                size: 50, color: Colors.grey)
                            : null,
                      ),
                      if (isCurrentUserTheCaptain)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                              radius: 15,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.edit,
                                  size: 15, color: Colors.black)),
                        ),
                      if (_isUploadingLogo) const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- GÜNCELLENEN BÖLÜM: Takım Adı ve Düzenleme İkonu ---
              // Row yerine Stack kullanarak hem yazıyı ortalıyoruz hem de ikonu sağına koyuyoruz.
              Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Katman: Tamamen ortalanmış Takım Adı
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48.0), // İkonun üstüne gelmemesi için
                    child: Text(
                      teamData['teamName'] ?? 'İsimsiz Takım',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 2. Katman: Sağ tarafta konumlandırılmış Düzenle ikonu
                  if (isCurrentUserTheCaptain)
                    Positioned(
                      right: 0, // En sağa yasla
                      child: IconButton(
                        icon: Icon(Icons.edit_note, color: Colors.grey[400]),
                        onPressed: () =>
                            _showEditTeamNameDialog(teamData['teamName'] ?? ''),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatsCard(teamData),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.leaderboard),
                label: const Text('Sıralamayı Gör'),
              ),
              const SizedBox(height: 16),
              
              Card(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[700]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Text("Takım Davet Kodu:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400])),
                      const SizedBox(height: 4),
                      SelectableText(widget.teamId,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.teamId));
                  showSnackBar(context, 'Takım davet kodu panoya kopyalandı!');
                },
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text("Davet Kodunu Kopyala"),
              ),
              const Divider(height: 40, thickness: 1),
              Stack(
                alignment: Alignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 120),
                    child: Text(
                      "Takım Kadrosu",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PlayerPostsListView(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.people, size: 16),
                      label: const Text('Oyuncu İlanları', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildPlayerList(captainId),
              const Divider(height: 40, thickness: 1),
              if (_isDeleting)
                const Center(child: CircularProgressIndicator())
              else if (isCurrentUserTheCaptain)
                TextButton.icon(
                    onPressed: _showDeleteTeamDialog,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('Takımı Kalıcı Olarak Sil',
                        style: TextStyle(color: Colors.red)))
              else
                TextButton.icon(
                    onPressed: _leaveTeam,
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    label: const Text('Takımdan Ayrıl',
                        style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerList(String captainId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('teamId', isEqualTo: widget.teamId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
              child: Text('Oyuncular listelenirken bir hata oluştu.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Bu takımda henüz oyuncu yok.'));
        }

        final players = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index].data() as Map<String, dynamic>;
            final playerId = players[index].id;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(player['fullName'] ?? 'İsimsiz Oyuncu'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerProfileScreen(playerId: playerId),
                    ),
                  );
                },
                trailing: widget.userDoc.id == captainId
                    ? (widget.userDoc.id != playerId
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'remove') {
                                _removePlayer(playerId, player['fullName']);
                              }
                              if (value == 'make_captain') {
                                _transferCaptaincy(
                                    playerId, player['fullName']);
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                  value: 'make_captain',
                                  child: Text('Kaptan Yap')),
                              const PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Text('Takımdan Çıkar',
                                      style: TextStyle(color: Colors.red))),
                            ],
                          )
                        : Chip(
                            label: const Text('Kaptan'),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2)))
                    : (player['role'] == 'Kaptan'
                        ? Chip(
                            label: const Text('Kaptan'),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2))
                        : null),
              ),
            );
          },
        );
      },
    );
  }
}

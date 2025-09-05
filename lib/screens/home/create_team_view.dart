import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // YENİ EKLENEN VE HATAYI DÜZELTEN SATIR
import 'package:halisaharakip_app/screens/home/create_player_post_view.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';

class CreateTeamView extends StatefulWidget {
  final VoidCallback onTeamCreated;

  const CreateTeamView({super.key, required this.onTeamCreated});

  @override
  State<CreateTeamView> createState() => _CreateTeamViewState();
}

class _CreateTeamViewState extends State<CreateTeamView> {
  final _teamNameController = TextEditingController();
  final _teamCodeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createTeam() async {
    if (_isLoading) return;
    if (_teamNameController.text.trim().isEmpty) {
      showSnackBar(context, 'Takım adı boş olamaz.', isError: true);
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      DocumentReference teamDocRef =
          await FirebaseFirestore.instance.collection('teams').add({
        'teamName': _teamNameController.text.trim(),
        'captainId': currentUser.uid,
        'city': 'İstanbul',
        'createdAt': Timestamp.now(),
        'matchesPlayed': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'points': 0,
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'teamId': teamDocRef.id, 'role': 'Kaptan'});
      if (mounted) {
        showSnackBar(context, 'Takım başarıyla oluşturuldu!');
        widget.onTeamCreated();
      }
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Takım oluşturulurken bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinTeam() async {
    if (_isLoading) return;
    final teamCode = _teamCodeController.text.trim();
    if (teamCode.isEmpty) {
      showSnackBar(context, 'Lütfen bir takım kodu girin.', isError: true);
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamCode)
          .get();
      if (!teamDoc.exists) {
        if (mounted)
          showSnackBar(context, 'Geçersiz takım kodu. Lütfen kontrol edin.',
              isError: true);
        setState(() => _isLoading = false);
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'teamId': teamCode,
        'role': 'Oyuncu',
      });
      if (mounted) {
        showSnackBar(context, 'Takıma başarıyla katıldınız!');
        widget.onTeamCreated();
      }
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Takıma katılırken bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showJoinTeamDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bir Takıma Katıl'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nasıl bir takıma katılmak istiyorsun?'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showTeamCodeDialog();
                  },
                  icon: const Icon(Icons.group_add),
                  label: const Text('Takım Kodu ile Katıl'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreatePlayerPostView(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Takım Bulmak İçin İlan Oluştur'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }

  void _showTeamCodeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Takım Kodu ile Katıl'),
          content: TextField(
            controller: _teamCodeController,
            decoration: const InputDecoration(
              labelText: 'Takım Davet Kodu',
              hintText: 'Kaptanından aldığın kodu buraya yapıştır',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _joinTeam();
              },
              child: const Text('Katıl'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _teamCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Takım Oluştur veya Katıl',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Harika! Şimdi takımını kurma zamanı.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 30),
          TextField(
            controller: _teamNameController,
            decoration: const InputDecoration(
                labelText: 'Takım Adı',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shield_outlined)),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-Z0-9çÇğĞıİöÖşŞüÜ ]'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _createTeam,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Takımı Oluştur',
                      style: TextStyle(fontSize: 16)),
                ),
          const SizedBox(height: 20),
          const Row(children: [
            Expanded(child: Divider()),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('VEYA')),
            Expanded(child: Divider())
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _showJoinTeamDialog,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Mevcut Bir Takıma Katıl'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
          ),
          ],
        ),
      ),
    );
  }
}

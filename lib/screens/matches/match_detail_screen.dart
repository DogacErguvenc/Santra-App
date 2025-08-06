import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart'; // DÜZELTME: 'package.' yerine 'package:' kullanıldı.
import 'package:url_launcher/url_launcher.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  final _disputeHomeScoreController = TextEditingController();
  final _disputeAwayScoreController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _disputeHomeScoreController.dispose();
    _disputeAwayScoreController.dispose();
    super.dispose();
  }

  Future<void> _cancelMatch() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maçı İptal Et'),
        content: const Text(
            'Bu maçı iptal etmek istediğinize emin misiniz? Bu işlem geri alınamaz ve rakibinize bildirim gönderilir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, İptal Et'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('cancelMatch');
      final result = await callable
          .call<Map<String, dynamic>>({'matchId': widget.matchId});
      if (mounted) {
        showSnackBar(context, result.data['message']);
        Navigator.of(context).pop();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) showSnackBar(context, 'Hata: ${e.message}', isError: true);
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Bilinmeyen bir hata oluştu: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveScore() async {
    setState(() => _isProcessing = true);

    if (_homeScoreController.text.trim().isEmpty ||
        _awayScoreController.text.trim().isEmpty) {
      showSnackBar(context, 'Lütfen her iki takımın da skorunu girin.',
          isError: true);
      setState(() => _isProcessing = false);
      return;
    }
    final homeScore = int.tryParse(_homeScoreController.text.trim());
    final awayScore = int.tryParse(_awayScoreController.text.trim());
    if (homeScore == null || awayScore == null) {
      showSnackBar(context, 'Lütfen geçerli bir sayı girin.', isError: true);
      setState(() => _isProcessing = false);
      return;
    }
    if (homeScore > 31 || awayScore > 31) {
      showSnackBar(context, 'Bir takım en fazla 31 gol atabilir.',
          isError: true);
      setState(() => _isProcessing = false);
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({
        'homeScore': homeScore,
        'awayScore': awayScore,
        'status': 'Sonuç Girildi',
        'scoreEnteredAt': Timestamp.now(),
        'scoreEnteredBy': FirebaseAuth.instance.currentUser?.uid,
        'scoreReporterId': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) {
        showSnackBar(
            context, 'Skor kaydedildi! Rakip takımın onayı bekleniyor.');
        _homeScoreController.clear();
        _awayScoreController.clear();
      }
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Skor kaydedilirken bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmScore() async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({
        'status': 'Onaylandı',
        'confirmedAt': Timestamp.now(),
        'confirmedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted)
        showSnackBar(context, 'Skor başarıyla onaylandı ve kilitlendi!');
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Onaylama sırasında bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _acceptDisputedScore(
      int disputedHomeScore, int disputedAwayScore) async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({
        'homeScore': disputedHomeScore,
        'awayScore': disputedAwayScore,
        'status': 'Onaylandı',
        'confirmedAt': Timestamp.now(),
        'confirmedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted)
        showSnackBar(
            context, 'İtiraz edilen skor kabul edildi. Maç sonucu kilitlendi!');
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Onaylama sırasında bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _disputeScore() async {
    final newScores = await _showDisputeDialog();
    if (newScores == null) return;
    setState(() => _isProcessing = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final teamId = userDoc.data()?['teamId'];
      if (teamId == null) {
        showSnackBar(context, 'İtiraz etmek için bir takımda olmalısınız.',
            isError: true);
        setState(() => _isProcessing = false);
        return;
      }
      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .get();
      final teamName = teamDoc.data()?['teamName'] ?? 'Bilinmeyen Takım';
      final matchRef =
          FirebaseFirestore.instance.collection('matches').doc(widget.matchId);
      final disputeRef = matchRef.collection('disputes').doc();
      final batch = FirebaseFirestore.instance.batch();
      batch.update(matchRef, {
        'status': 'İtiraz Edildi',
        'dispute': {
          'disputedAt': Timestamp.now(),
          'disputedBy': currentUser.uid,
          'disputedHomeScore': newScores['home'],
          'disputedAwayScore': newScores['away'],
        }
      });
      batch.set(disputeRef,
          {'disputingTeamName': teamName, 'disputedAt': Timestamp.now()});
      await batch.commit();
      if (mounted)
        showSnackBar(context,
            'Skora itirazınız kaydedildi. Rakip takımın yanıtı bekleniyor.');
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'İtiraz sırasında bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<Map<String, int>?> _showDisputeDialog() async {
    return showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        _disputeHomeScoreController.clear();
        _disputeAwayScoreController.clear();
        return AlertDialog(
          title: const Text('Skora İtiraz Et'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Lütfen size göre doğru olan skoru girin:'),
            const SizedBox(height: 20),
            TextField(
                controller: _disputeHomeScoreController,
                decoration: const InputDecoration(labelText: 'Ev Sahibi Skoru'),
                keyboardType: TextInputType.number),
            TextField(
                controller: _disputeAwayScoreController,
                decoration: const InputDecoration(labelText: 'Deplasman Skoru'),
                keyboardType: TextInputType.number),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                final home = int.tryParse(_disputeHomeScoreController.text);
                final away = int.tryParse(_disputeAwayScoreController.text);
                if (home != null && away != null) {
                  if (home > 31 || away > 31) {
                    showSnackBar(context, 'Bir takım en fazla 31 gol atabilir.',
                        isError: true);
                    return;
                  }
                  Navigator.of(context).pop({'home': home, 'away': away});
                } else {
                  showSnackBar(context, 'Lütfen geçerli skorlar girin.',
                      isError: true);
                }
              },
              child: const Text('İtirazı Gönder'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maç Detayı')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text('Maç bulunamadı.'));

          final matchData = snapshot.data!.data() as Map<String, dynamic>;
          final currentUser = FirebaseAuth.instance.currentUser;

          return FutureBuilder<DocumentSnapshot>(
            future: currentUser != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get()
                : null,
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());

              bool isCaptain = false;
              bool isCaptainOfHomeTeam = false;
              bool isCaptainOfAwayTeam = false;
              if (currentUser != null &&
                  userSnapshot.hasData &&
                  userSnapshot.data!.exists) {
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                if (userData['role'] == 'Kaptan' ||
                    userData['role'] == 'admin') {
                  isCaptain = true;
                  if (userData['teamId'] == matchData['homeTeamId'])
                    isCaptainOfHomeTeam = true;
                  if (userData['teamId'] == matchData['awayTeamId'])
                    isCaptainOfAwayTeam = true;
                }
              }

              final homeTeamName = matchData['homeTeamName'] ?? 'Ev Sahibi';
              final awayTeamName = matchData['awayTeamName'] ?? 'Deplasman';
              final homeScore = matchData['homeScore']?.toString() ?? '-';
              final awayScore = matchData['awayScore']?.toString() ?? '-';
              final formattedDate = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR')
                  .format((matchData['matchTimestamp'] as Timestamp).toDate());
              final matchStatus = matchData['status'] ?? 'Ayarlandı';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Text("Maç Skoru",
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                    child: Text(homeTeamName,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold))),
                                Text('$homeScore : $awayScore',
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                    child: Text(awayTeamName,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (matchStatus == 'İtiraz Edildi' &&
                        matchData['dispute'] != null)
                      Card(
                          color: Colors.orange.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text("Rakibin İtiraz Ettiği Skor",
                                    style: TextStyle(
                                        color: Colors.orange[200],
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(
                                    '${matchData['dispute']['disputedHomeScore']} : ${matchData['dispute']['disputedAwayScore']}',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[100])),
                              ],
                            ),
                          )),
                    const SizedBox(height: 24),
                    const Divider(),
                    _buildInfoRow(
                        Icons.calendar_today, 'Maç Tarihi', formattedDate),
                    _buildInfoRow(Icons.location_on, 'Konum',
                        matchData['pitchName'] ?? 'Belirtilmemiş'),
                    const SizedBox(height: 32),
                    if (_isProcessing)
                      const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator())
                    else
                      _buildActionWidget(
                        matchData: matchData,
                        isCaptain: isCaptain,
                        isCaptainOfHomeTeam: isCaptainOfHomeTeam,
                        isCaptainOfAwayTeam: isCaptainOfAwayTeam,
                        currentUser: currentUser,
                      )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionWidget({
    required Map<String, dynamic> matchData,
    required bool isCaptain,
    required bool isCaptainOfHomeTeam,
    required bool isCaptainOfAwayTeam,
    User? currentUser,
  }) {
    final status = matchData['status'] ?? 'Ayarlandı';
    final scoreEnteredBy = matchData['scoreEnteredBy'];

    if (!isCaptain || (!isCaptainOfHomeTeam && !isCaptainOfAwayTeam)) {
      return const SizedBox.shrink();
    }

    switch (status) {
      case 'Ayarlandı':
        final matchTimestamp =
            (matchData['matchTimestamp'] as Timestamp).toDate();
        final bool canCancel = DateTime.now()
            .isBefore(matchTimestamp.subtract(const Duration(hours: 72)));
        return Column(
          children: [
            _buildScoreEntryWidget(),
            const SizedBox(height: 20),
            const Divider(),
            if (canCancel)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: TextButton.icon(
                  onPressed: _cancelMatch,
                  icon: const Icon(Icons.cancel_schedule_send,
                      color: Colors.redAccent),
                  label: const Text('Maçı İptal Et',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: Text(
                    "Maçın başlamasına 72 saatten az kaldığı için iptal edilemez.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center),
              ),
          ],
        );

      case 'Sonuç Girildi':
        return (currentUser?.uid == scoreEnteredBy)
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Rakip takımın onayı bekleniyor...',
                    textAlign: TextAlign.center))
            : _buildConfirmationWidget();

      case 'İtiraz Edildi':
        return (currentUser?.uid == scoreEnteredBy)
            ? _buildAcceptDisputeWidget(matchData['dispute'])
            : const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                    'İtirazınız iletildi. Rakip takımın onayı bekleniyor.',
                    textAlign: TextAlign.center));

      case 'Onaylandı':
        return Card(
            color: Colors.green.withOpacity(0.8),
            child: const ListTile(
                leading: Icon(Icons.check_circle),
                title: Text('Skor Onaylandı'),
                subtitle: Text('Bu skor kilitlenmiştir.')));

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAcceptDisputeWidget(Map<String, dynamic> disputeData) {
    return Column(
      children: [
        const Text(
            'Rakibiniz skora itiraz etti. İtiraz ettiği skoru kabul ediyor musunuz?',
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
            onPressed: () => _acceptDisputedScore(
                  disputeData['disputedHomeScore'],
                  disputeData['disputedAwayScore'],
                ),
            icon: const Icon(Icons.handshake),
            label: const Text('Rakibin Skorunu Onayla'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 50))),
      ],
    );
  }

  Widget _buildScoreEntryWidget() {
    return Column(
      children: [
        const Text('Skor Girişi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: TextField(
                    controller: _homeScoreController,
                    decoration: const InputDecoration(
                        labelText: 'Ev Sahibi Skoru',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
            const SizedBox(width: 10),
            const Text(":", style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _awayScoreController,
                    decoration: const InputDecoration(
                        labelText: 'Deplasman Skoru',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
            onPressed: _saveScore,
            icon: const Icon(Icons.save),
            label: const Text('Skoru Kaydet'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50))),
      ],
    );
  }

  Widget _buildConfirmationWidget() {
    return Column(
      children: [
        const Text(
            'Rakip takım skor girdi. Lütfen kontrol edip onaylayın veya itiraz edin.',
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
            onPressed: _confirmScore,
            icon: const Icon(Icons.check),
            label: const Text('Skoru Onayla'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50))),
        const SizedBox(height: 10),
        TextButton.icon(
            onPressed: _disputeScore,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Skora İtiraz Et'),
            style: TextButton.styleFrom(foregroundColor: Colors.red)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(width: 12),
        Text('$label:',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey[300])),
        const SizedBox(width: 8),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 15),
                textAlign: TextAlign.end)),
      ],
    );
  }
}

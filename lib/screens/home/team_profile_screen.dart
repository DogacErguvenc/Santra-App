import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:halisaharakip_app/screens/profile/player_profile_screen.dart';

class TeamProfileScreen extends StatelessWidget {
  final String teamId;
  final String teamName;

  const TeamProfileScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(teamName),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(teamId)
            .snapshots(),
        builder: (context, teamSnapshot) {
          if (teamSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (teamSnapshot.hasError || !teamSnapshot.data!.exists) {
            return const Center(
              child: Text('Takım bilgileri bulunamadı.'),
            );
          }

          final teamData = teamSnapshot.data!.data() as Map<String, dynamic>;
          final logoURL = teamData['logoURL'];
          final wins = teamData['wins'] ?? 0;
          final draws = teamData['draws'] ?? 0;
          final losses = teamData['losses'] ?? 0;
          final points = teamData['points'] ?? 0;
          final matchesPlayed = teamData['matchesPlayed'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTeamHeader(logoURL, teamName),
                const SizedBox(height: 24),
                _buildStatisticsCard(
                    wins, draws, losses, points, matchesPlayed),
                const SizedBox(height: 16),
                _buildRecentMatchesSection(),
                const SizedBox(height: 16),
                _buildTeamPlayersSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamHeader(String? logoURL, String teamName) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
              child: logoURL != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: logoURL,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.sports_soccer,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.sports_soccer,
                      size: 40,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Takım Profili',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(
      int wins, int draws, int losses, int points, int matchesPlayed) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İstatistikler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Puan', points.toString(), Icons.star),
                _buildStatItem(
                    'Maç', matchesPlayed.toString(), Icons.sports_soccer),
                _buildStatItem('Galibiyet', wins.toString(), Icons.trending_up),
                _buildStatItem('Beraberlik', draws.toString(), Icons.remove),
                _buildStatItem(
                    'Mağlubiyet', losses.toString(), Icons.trending_down),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.tealAccent[400]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentMatchesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Son Maçlar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .where('participantTeamIds', arrayContains: teamId)
                  .where('status', isEqualTo: 'Onaylandı')
                  .orderBy('matchTimestamp', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Text('Maçlar yüklenirken hata oluştu.');
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('Henüz maç oynanmamış.');
                }

                return Column(
                  children: snapshot.data!.docs.map((matchDoc) {
                    final matchData = matchDoc.data() as Map<String, dynamic>;
                    return _buildMatchItem(matchData);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchItem(Map<String, dynamic> matchData) {
    final homeTeamId = matchData['homeTeamId'];
    final awayTeamId = matchData['awayTeamId'];
    final homeScore = matchData['homeScore'];
    final awayScore = matchData['awayScore'];
    final matchTimestamp = matchData['matchTimestamp'] as Timestamp?;
    final isHomeTeam = homeTeamId == teamId;

    String homeTeamName = 'Bilinmeyen Takım';
    String awayTeamName = 'Bilinmeyen Takım';

    if (isHomeTeam) {
      homeTeamName = teamName;
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('teams')
            .doc(awayTeamId)
            .get(),
        builder: (context, awayTeamSnapshot) {
          if (awayTeamSnapshot.hasData && awayTeamSnapshot.data!.exists) {
            final awayTeamData =
                awayTeamSnapshot.data!.data() as Map<String, dynamic>;
            awayTeamName = awayTeamData['teamName'] ?? 'Bilinmeyen Takım';
          }

          return _buildMatchRow(
            homeTeamName,
            awayTeamName,
            homeScore,
            awayScore,
            matchTimestamp,
            isHomeTeam,
          );
        },
      );
    } else {
      awayTeamName = teamName;
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('teams')
            .doc(homeTeamId)
            .get(),
        builder: (context, homeTeamSnapshot) {
          if (homeTeamSnapshot.hasData && homeTeamSnapshot.data!.exists) {
            final homeTeamData =
                homeTeamSnapshot.data!.data() as Map<String, dynamic>;
            homeTeamName = homeTeamData['teamName'] ?? 'Bilinmeyen Takım';
          }

          return _buildMatchRow(
            homeTeamName,
            awayTeamName,
            homeScore,
            awayScore,
            matchTimestamp,
            isHomeTeam,
          );
        },
      );
    }
  }

  Widget _buildMatchRow(
    String homeTeamName,
    String awayTeamName,
    int? homeScore,
    int? awayScore,
    Timestamp? matchTimestamp,
    bool isHomeTeam,
  ) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final timeFormat = DateFormat('HH:mm');
    final matchDate = matchTimestamp?.toDate();

    Color resultColor = Colors.grey;
    if (homeScore != null && awayScore != null) {
      if (isHomeTeam) {
        resultColor = homeScore > awayScore
            ? Colors.green
            : (homeScore < awayScore ? Colors.red : Colors.orange);
      } else {
        resultColor = awayScore > homeScore
            ? Colors.green
            : (awayScore < homeScore ? Colors.red : Colors.orange);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: resultColor, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  matchDate != null
                      ? dateFormat.format(matchDate)
                      : 'Tarih yok',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  matchDate != null ? timeFormat.format(matchDate) : '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    homeTeamName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isHomeTeam ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${homeScore ?? '-'} - ${awayScore ?? '-'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    awayTeamName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          !isHomeTeam ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamPlayersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Takım Oyuncuları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('teamId', isEqualTo: teamId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Text('Oyuncular yüklenirken hata oluştu.');
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('Bu takımda henüz oyuncu yok.');
                }

                final players = snapshot.data!.docs;
                return Column(
                  children: players.map((playerDoc) {
                    final playerData = playerDoc.data() as Map<String, dynamic>;
                    final playerId = playerDoc.id;
                    final playerName = playerData['fullName'] ?? 'İsimsiz Oyuncu';
                    final playerRole = playerData['role'] ?? 'Oyuncu';
                    final isCaptain = playerRole == 'Kaptan';

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerProfileScreen(playerId: playerId),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(8),
                          border: isCaptain
                              ? Border.all(color: Colors.tealAccent[400]!, width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isCaptain
                                  ? Colors.tealAccent[400]
                                  : Colors.grey[600],
                              child: Icon(
                                isCaptain ? Icons.star : Icons.person,
                                color: isCaptain ? Colors.black : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playerName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isCaptain ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    playerRole,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

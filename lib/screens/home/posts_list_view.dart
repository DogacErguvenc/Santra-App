import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:halisaharakip_app/screens/home/post_detail_screen.dart';
import 'package:halisaharakip_app/screens/home/team_profile_screen.dart';
import 'package:intl/intl.dart';

class PostsListView extends StatefulWidget {
  const PostsListView({super.key});

  @override
  State<PostsListView> createState() => _PostsListViewState();
}

class _PostsListViewState extends State<PostsListView> {
  String? _selectedLevelFilter;
  String? _selectedDistrictFilter;
  DateTime? _selectedDateFilter;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _districts = [
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateFilter ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDateFilter) {
      setState(() {
        _selectedDateFilter = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedLevelFilter = null;
      _selectedDistrictFilter = null;
      _selectedDateFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Query postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'Aktif')
        .where('adminApproved', isEqualTo: true);

    if (_searchController.text.isNotEmpty) {
      String searchQuery = _searchController.text.toLowerCase();
      postsQuery = postsQuery
          .where('pitchName_lowercase', isGreaterThanOrEqualTo: searchQuery)
          .where('pitchName_lowercase',
              isLessThanOrEqualTo: '$searchQuery\uf8ff')
          .orderBy('pitchName_lowercase');
    } else {
      postsQuery = postsQuery.orderBy('matchTimestamp', descending: false);
    }

    if (_selectedLevelFilter != null) {
      postsQuery =
          postsQuery.where('gameLevel', isEqualTo: _selectedLevelFilter);
    }
    if (_selectedDistrictFilter != null) {
      postsQuery =
          postsQuery.where('district', isEqualTo: _selectedDistrictFilter);
    }
    if (_selectedDateFilter != null) {
      DateTime startOfDay = DateTime(_selectedDateFilter!.year,
          _selectedDateFilter!.month, _selectedDateFilter!.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      postsQuery = postsQuery
          .where('matchTimestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('matchTimestamp', isLessThan: endOfDay);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
          child: ExpansionTile(
            title: const Text('Filtrele & Ara'),
            leading: const Icon(Icons.filter_list),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Halısaha Adına Göre Ara',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _searchController.clear()),
                        )
                      : null,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9çÇğĞıİöÖşŞüÜ ]'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: ['Başlangıç', 'Orta', 'İleri Düzey'].map((level) {
                  return FilterChip(
                    label: Text(level),
                    selected: _selectedLevelFilter == level,
                    onSelected: (bool selected) => setState(
                        () => _selectedLevelFilter = selected ? level : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: _selectedDistrictFilter,
                decoration: const InputDecoration(labelText: 'İlçe Seç'),
                items: _districts
                    .map((String district) => DropdownMenuItem<String>(
                        value: district, child: Text(district)))
                    .toList(),
                onChanged: (String? newValue) =>
                    setState(() => _selectedDistrictFilter = newValue),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDateFilter == null
                        ? 'Tarih Seç'
                        : DateFormat('dd/MM/yyyy')
                            .format(_selectedDateFilter!)),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Filtreleri Temizle',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: postsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(
                    child: Text('İlanlar getirilirken bir sorun oluştu.'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Bu kriterlere uygun aktif bir maç ilanı yok.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                        textAlign: TextAlign.center),
                  ),
                );
              }
              final posts = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index].data() as Map<String, dynamic>;
                  final postId = posts[index].id;
                  final matchDate =
                      (post['matchTimestamp'] as Timestamp).toDate();
                  final formattedDate =
                      DateFormat('dd MMMM, HH:mm', 'tr_TR').format(matchDate);
                  final logoURL = post['teamLogoURL'];

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TeamProfileScreen(
                                teamId: post['teamId'] ?? '',
                                teamName: post['teamName'] ?? 'İsimsiz Takım',
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundImage: logoURL != null
                              ? CachedNetworkImageProvider(logoURL)
                              : null,
                          child: logoURL == null
                              ? const Icon(Icons.shield_outlined,
                                  color: Colors.grey)
                              : null,
                        ),
                      ),
                      title: Text(
                        post['pitchName'] ?? 'Saha Adı Belirtilmemiş',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TeamProfileScreen(
                                    teamId: post['teamId'] ?? '',
                                    teamName:
                                        post['teamName'] ?? 'İsimsiz Takım',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              post['teamName'] ?? 'İsimsiz Takım',
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(formattedDate),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                PostDetailScreen(postId: postId)));
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

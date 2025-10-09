import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class AdminPostsApprovalScreen extends StatefulWidget {
  const AdminPostsApprovalScreen({super.key});

  @override
  State<AdminPostsApprovalScreen> createState() => _AdminPostsApprovalScreenState();
}

class _AdminPostsApprovalScreenState extends State<AdminPostsApprovalScreen> {
  bool _isLoading = false;

  Future<void> _approvePost(String postId, Map<String, dynamic> postData) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'status': 'Aktif',
        'adminApproved': true,
        'approvedAt': Timestamp.now(),
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        showSnackBar(context, 'İlan başarıyla onaylandı!');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'İlan onaylanırken hata oluştu: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectPost(String postId) async {
    if (_isLoading) return;
    
    final TextEditingController reasonController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı Reddet'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bu ilanı neden reddediyorsunuz? Sebep yazmanız zorunludur.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reddetme Sebebi',
                  border: OutlineInputBorder(),
                  hintText: 'Örn: Halı saha adı hatalı, eksik bilgi...',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Reddetme sebebi zorunludur';
                  }
                  if (value.trim().length < 10) {
                    return 'En az 10 karakter girmelisiniz';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
                _performReject(postId, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
  }

  Future<void> _performReject(String postId, String reason) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'status': 'Reddedildi',
        'adminApproved': false,
        'rejectedAt': Timestamp.now(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
        'rejectionReason': reason,
      });

      if (mounted) {
        showSnackBar(context, 'İlan reddedildi!');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'İlan reddedilirken hata oluştu: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditPostDialog(String postId, Map<String, dynamic> postData) {
    final _pitchNameController = TextEditingController(text: postData['pitchName'] ?? '');
    final _notesController = TextEditingController(text: postData['notes'] ?? '');
    final _phoneController = TextEditingController(text: postData['contactInfo']?['phone'] ?? '');
    final _socialMediaController = TextEditingController(text: postData['contactInfo']?['socialMedia'] ?? '');
    final _otherContactController = TextEditingController(text: postData['contactInfo']?['other'] ?? '');
    String _selectedSocialPlatform = postData['contactInfo']?['socialMediaPlatform'] ?? 'Instagram';
    
    String _selectedGameLevel = postData['gameLevel'] ?? 'Orta';
    String _selectedDistrict = postData['district'] ?? 'Kadıköy';
    
    final List<String> _districts = [
      'Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar', 'Bahçelievler',
      'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş', 'Beykoz', 'Beylikdüzü',
      'Beyoğlu', 'Büyükçekmece', 'Çatalca', 'Çekmeköy', 'Esenler', 'Esenyurt',
      'Eyüpsultan', 'Fatih', 'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane',
      'Kartal', 'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer',
      'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli', 'Tuzla',
      'Ümraniye', 'Üsküdar', 'Zeytinburnu'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('İlanı Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _pitchNameController,
                  decoration: const InputDecoration(
                    labelText: 'Halı Saha Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDistrict,
                  decoration: const InputDecoration(
                    labelText: 'İlçe',
                    border: OutlineInputBorder(),
                  ),
                  items: _districts.map<DropdownMenuItem<String>>((String value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value))
                  ).toList(),
                  onChanged: (String? newValue) {
                    setDialogState(() => _selectedDistrict = newValue!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGameLevel,
                  decoration: const InputDecoration(
                    labelText: 'Oyun Seviyesi',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Başlangıç', 'Orta', 'İleri'].map<DropdownMenuItem<String>>((String value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value))
                  ).toList(),
                  onChanged: (String? newValue) {
                    setDialogState(() => _selectedGameLevel = newValue!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notlar',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _socialMediaController,
                        decoration: const InputDecoration(
                          labelText: 'Sosyal Medya',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        value: _selectedSocialPlatform,
                        decoration: const InputDecoration(
                          labelText: 'Platform',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          'Instagram', 'Twitter/X', 'Facebook', 'TikTok', 'LinkedIn', 'Diğer'
                        ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setDialogState(() => _selectedSocialPlatform = v ?? 'Instagram'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otherContactController,
                  decoration: const InputDecoration(
                    labelText: 'Diğer İletişim',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_pitchNameController.text.trim().isEmpty) {
                  showSnackBar(context, 'Halı saha adı boş olamaz!', isError: true);
                  return;
                }
                
                try {
                  await FirebaseFirestore.instance.collection('posts').doc(postId).update({
                    'pitchName': _pitchNameController.text.trim(),
                    'pitchName_lowercase': _pitchNameController.text.trim().toLowerCase(),
                    'district': _selectedDistrict,
                    'gameLevel': _selectedGameLevel,
                    'notes': _notesController.text.trim(),
                    'contactInfo': {
                      'phone': _phoneController.text.trim(),
                      'socialMedia': _socialMediaController.text.trim(),
                      'socialMediaPlatform': _selectedSocialPlatform,
                      'other': _otherContactController.text.trim(),
                    },
                    'editedBy': FirebaseAuth.instance.currentUser?.uid,
                    'editedAt': Timestamp.now(),
                  });
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    showSnackBar(context, 'İlan başarıyla düzenlendi!');
                  }
                } catch (e) {
                  if (mounted) {
                    showSnackBar(context, 'İlan düzenlenirken hata oluştu: $e', isError: true);
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç İlanları Onayı'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('status', isEqualTo: 'Beklemede')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('İlanlar getirilirken bir hata oluştu.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('Onay bekleyen ilan bulunmuyor.'));
                }

                final posts = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
                    final postId = posts[index].id;
                    final matchDate = (post['matchTimestamp'] as Timestamp).toDate();
                    final formattedDate = DateFormat('dd MMMM, HH:mm', 'tr_TR').format(matchDate);
                    final logoURL = post['teamLogoURL'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (logoURL != null)
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(logoURL),
                                  )
                                else
                                  const CircleAvatar(
                                    radius: 20,
                                    child: Icon(Icons.group),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post['teamName'] ?? 'İsimsiz Takım',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Beklemede',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    post['pitchName'] ?? 'Saha adı belirtilmemiş',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_city, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  post['district'] ?? 'İlçe belirtilmemiş',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.sports_soccer, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  post['gameLevel'] ?? 'Seviye belirtilmemiş',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            if (post['notes'] != null && post['notes'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                post['notes'],
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showEditPostDialog(postId, post),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Düzenle'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(color: Colors.blue),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approvePost(postId, post),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Onayla'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _rejectPost(postId),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Reddet'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

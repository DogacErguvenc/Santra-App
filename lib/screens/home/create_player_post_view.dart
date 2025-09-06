import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';

class CreatePlayerPostView extends StatefulWidget {
  const CreatePlayerPostView({super.key});

  @override
  State<CreatePlayerPostView> createState() => _CreatePlayerPostViewState();
}

class _CreatePlayerPostViewState extends State<CreatePlayerPostView> {
  final _positionController = TextEditingController();
  final _experienceController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _socialMediaController = TextEditingController();
  final _otherContactController = TextEditingController();

  bool _isLoading = false;
  String _selectedGameLevel = 'Orta';
  String _selectedDistrict = 'Kadıköy';
  String _selectedPosition = 'Orta Saha';
  bool _contactConsent = false;

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

  final List<String> _positions = [
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

  @override
  void dispose() {
    _positionController.dispose();
    _experienceController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _socialMediaController.dispose();
    _otherContactController.dispose();
    super.dispose();
  }

  Future<void> _createPlayerPost() async {
    if (_isLoading) return;

    if (!_contactConsent) {
      showSnackBar(context,
          'İlan yayınlamak için iletişim bilgilerinizin paylaşılmasını onaylamanız gerekmektedir.',
          isError: true);
      return;
    }
    if (_phoneController.text.trim().isEmpty &&
        _socialMediaController.text.trim().isEmpty &&
        _otherContactController.text.trim().isEmpty) {
      showSnackBar(context,
          'Lütfen en az bir iletişim yöntemi girin (Telefon, Sosyal Medya vb.).',
          isError: true);
      return;
    }

    if (_positionController.text.trim().isEmpty ||
        _experienceController.text.trim().isEmpty) {
      showSnackBar(context,
          'Lütfen pozisyon ve deneyim bilgilerini eksiksiz girin.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();
      
      // Kullanıcının takımı olup olmadığını kontrol et
      if (userData?['teamId'] != null) {
        if (mounted)
          showSnackBar(context, 'Takım arama ilanı vermek için takımsız olmalısınız.',
              isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Kullanıcının zaten aktif bir oyuncu ilanı olup olmadığını kontrol et
      final existingPostsQuery = await FirebaseFirestore.instance
          .collection('player_posts')
          .where('playerId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'Aktif')
          .get();
      
      if (existingPostsQuery.docs.isNotEmpty) {
        if (mounted)
          showSnackBar(context, 'Zaten aktif bir oyuncu ilanınız bulunmaktadır. Yeni ilan açmak için mevcut ilanınızı silin.',
              isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final fullName = userData?['fullName'] ?? 'İsimsiz Oyuncu';
      final profileImageURL = userData?['profileImageURL'];

      await FirebaseFirestore.instance.collection('player_posts').add({
        'playerId': currentUser.uid,
        'playerName': fullName,
        'playerImageURL': profileImageURL,
        'position': _positionController.text.trim(),
        'experience': _experienceController.text.trim(),
        'district': _selectedDistrict,
        'gameLevel': _selectedGameLevel,
        'notes': _notesController.text.trim(),
        'status': 'Aktif',
        'createdAt': Timestamp.now(),
        'contactInfo': {
          'phone': _phoneController.text.trim(),
          'socialMedia': _socialMediaController.text.trim(),
          'other': _otherContactController.text.trim(),
        },
      });

      if (mounted) {
        showSnackBar(context, 'Oyuncu ilanı başarıyla oluşturuldu!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'İlan oluşturulurken bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oyuncu İlanı Oluştur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu ilan sadece takımsız oyuncular tarafından oluşturulabilir.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _positionController,
              decoration: const InputDecoration(
                  labelText: 'Pozisyon',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sports_soccer_outlined)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9çÇğĞıİöÖşŞüÜ ]'))
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedPosition,
              decoration: const InputDecoration(
                  labelText: 'Tercih Edilen Pozisyon', border: OutlineInputBorder()),
              items: _positions
                  .map<DropdownMenuItem<String>>((String value) =>
                      DropdownMenuItem<String>(
                          value: value, child: Text(value)))
                  .toList(),
              onChanged: (String? newValue) =>
                  setState(() => _selectedPosition = newValue!),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _experienceController,
              decoration: const InputDecoration(
                  labelText: 'Deneyim (örn: 5 yıl, amatör lig)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work_outline)),
              maxLines: 2,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9çÇğĞıİöÖşŞüÜ .,:!()-]'))
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedDistrict,
              decoration: const InputDecoration(
                  labelText: 'İlçe', border: OutlineInputBorder()),
              items: _districts
                  .map<DropdownMenuItem<String>>((String value) =>
                      DropdownMenuItem<String>(
                          value: value, child: Text(value)))
                  .toList(),
              onChanged: (String? newValue) =>
                  setState(() => _selectedDistrict = newValue!),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedGameLevel,
              decoration: const InputDecoration(
                  labelText: 'Oyun Seviyesi', border: OutlineInputBorder()),
              items: <String>['Başlangıç', 'Orta', 'İleri Düzey']
                  .map<DropdownMenuItem<String>>((String value) =>
                      DropdownMenuItem<String>(
                          value: value, child: Text(value)))
                  .toList(),
              onChanged: (String? newValue) =>
                  setState(() => _selectedGameLevel = newValue!),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                  labelText: 'Kendiniz hakkında notlar (örn: Fair-play önemli, hafta sonları müsait)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined)),
              maxLines: 3,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9çÇğĞıİöÖşŞüÜ .,:!()-]'))
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('İletişim Bilgileri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                  labelText: 'Telefon Numarası (İsteğe Bağlı)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _socialMediaController,
              decoration: const InputDecoration(
                  labelText: 'Sosyal Medya (örn: @kullaniciadi)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _otherContactController,
              decoration: const InputDecoration(
                  labelText: 'Diğer (örn: Discord)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.chat_bubble_outline)),
            ),
            const SizedBox(height: 10),
            Text(
                'Not: Takım kaptanları bu bilgilerden en az birini görerek sizinle iletişime geçecektir.',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text(
                  "İletişim bilgilerimin takım kaptanlarıyla paylaşılmasını onaylıyorum.",
                  style: TextStyle(fontSize: 12)),
              value: _contactConsent,
              onChanged: (newValue) {
                setState(() {
                  _contactConsent = newValue ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      onPressed: _createPlayerPost,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Oyuncu İlanını Yayınla',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

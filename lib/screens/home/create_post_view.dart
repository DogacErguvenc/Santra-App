import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _pitchNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _socialMediaController = TextEditingController();
  final _otherContactController = TextEditingController();

  bool _isLoading = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedGameLevel = 'Orta';
  String _selectedDistrict = 'Kadıköy';
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

  @override
  void dispose() {
    _pitchNameController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _socialMediaController.dispose();
    _otherContactController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _createPost() async {
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

    if (_pitchNameController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      showSnackBar(context,
          'Lütfen halı saha adı, tarih ve saat bilgilerini eksiksiz girin.',
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
      final teamId = userDoc.data()?['teamId'];
      if (teamId == null) {
        if (mounted)
          showSnackBar(context, 'İlan vermek için bir takımınız olmalı.',
              isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .get();
      final teamData = teamDoc.data() ?? {};
      final teamName = teamData['teamName'] ?? 'İsimsiz Takım';
      final teamLogoURL = teamData['logoURL'];

      final matchDateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
          _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      final pitchName = _pitchNameController.text.trim();

      await FirebaseFirestore.instance.collection('posts').add({
        'captainId': currentUser.uid,
        'teamId': teamId,
        'teamName': teamName,
        'teamLogoURL': teamLogoURL,
        'pitchName': pitchName,
        'pitchName_lowercase': pitchName.toLowerCase(),
        'district': _selectedDistrict,
        'notes': _notesController.text.trim(),
        'gameLevel': _selectedGameLevel,
        'matchTimestamp': Timestamp.fromDate(matchDateTime),
        'status': 'Aktif',
        'createdAt': Timestamp.now(),
        'contactInfo': {
          'phone': _phoneController.text.trim(),
          'socialMedia': _socialMediaController.text.trim(),
          'other': _otherContactController.text.trim(),
        },
      });

      if (mounted) {
        showSnackBar(context, 'İlan başarıyla oluşturuldu!');
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
      appBar: AppBar(title: const Text('Yeni Maç İlanı Oluştur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pitchNameController,
              decoration: const InputDecoration(
                  labelText: 'Halı Saha Adı',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9çÇğĞıİöÖşŞüÜ ]'))
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
            Row(
              children: [
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: () => _selectDate(context),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_selectedDate == null
                            ? 'Tarih Seç'
                            : DateFormat('dd/MM/yyyy')
                                .format(_selectedDate!)))),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: () => _selectTime(context),
                        icon: const Icon(Icons.access_time),
                        label: Text(_selectedTime == null
                            ? 'Saat Seç'
                            : _selectedTime!.format(context)))),
              ],
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
                  labelText: 'Maç Notları (örn: Fair-play önemli)',
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
                'Not: Rakip olmak isteyen diğer takım kaptanları bu bilgilerden en az birini görerek sizinle iletişime geçecektir.',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text(
                  "İletişim bilgilerimin diğer takım kaptanlarıyla paylaşılmasını onaylıyorum.",
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
                      onPressed: _createPost,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text('İlanı Yayınla',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

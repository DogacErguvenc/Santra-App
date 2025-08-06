import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halisaharakip_app/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class EditPostScreen extends StatefulWidget {
  final DocumentSnapshot post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _pitchNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _socialMediaController = TextEditingController();
  final _otherContactController = TextEditingController();

  bool _isLoading = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedGameLevel;
  String? _selectedDistrict;
  bool _contactConsent = true;

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
    final postData = widget.post.data() as Map<String, dynamic>;

    _pitchNameController.text = postData['pitchName'] ?? '';
    _notesController.text = postData['notes'] ?? '';
    _selectedGameLevel = postData['gameLevel'];
    _selectedDistrict = postData['district'];

    if (postData['matchTimestamp'] != null) {
      final timestamp = (postData['matchTimestamp'] as Timestamp).toDate();
      _selectedDate = timestamp;
      _selectedTime = TimeOfDay.fromDateTime(timestamp);
    }

    final contactInfo = postData['contactInfo'] as Map<String, dynamic>?;
    if (contactInfo != null) {
      _phoneController.text = contactInfo['phone'] ?? '';
      _socialMediaController.text = contactInfo['socialMedia'] ?? '';
      _otherContactController.text = contactInfo['other'] ?? '';
    }
  }

  @override
  void dispose() {
    _pitchNameController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _socialMediaController.dispose();
    _otherContactController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final matchDateTime = DateTime(_selectedDate!.year, _selectedDate!.month,
          _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      final pitchName = _pitchNameController.text.trim();

      await widget.post.reference.update({
        'pitchName': pitchName,
        'pitchName_lowercase': pitchName.toLowerCase(),
        'district': _selectedDistrict,
        'notes': _notesController.text.trim(),
        'gameLevel': _selectedGameLevel,
        'matchTimestamp': Timestamp.fromDate(matchDateTime),
        'contactInfo': {
          'phone': _phoneController.text.trim(),
          'socialMedia': _socialMediaController.text.trim(),
          'other': _otherContactController.text.trim(),
        },
      });

      if (mounted) {
        showSnackBar(context, 'İlan başarıyla güncellendi!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'İlan güncellenirken bir hata oluştu: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlanı Düzenle')),
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
              items: _districts
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedDistrict = value),
              decoration: const InputDecoration(
                  labelText: 'İlçe', border: OutlineInputBorder()),
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
                  setState(() => _selectedGameLevel = newValue),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                  labelText: 'Maç Notları',
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
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _updatePost,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Değişiklikleri Kaydet',
                        style: TextStyle(fontSize: 16)),
                  ),
          ],
        ),
      ),
    );
  }
}

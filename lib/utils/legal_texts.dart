class LegalTexts {
  // Gizlilik Politikası (KVKK/GDPR uyumlu, bilgilendirme amaçlı)
  static const String privacyPolicy = """
Gizlilik Politikası

Son Güncelleme: 08 Ekim 2025

Bu Gizlilik Politikası, Santra mobil uygulamasını kullanırken kişisel verilerinizin 6698 sayılı KVKK ve AB Genel Veri Koruma Tüzüğü (GDPR) başta olmak üzere yürürlükteki mevzuata uygun olarak nasıl işlendiğini açıklar.

1) Veri Sorumlusu ve İletişim
Veri Sorumlusu: Santra Uygulaması (HDE Software)
E‑posta: santraappdev@gmail.com
Adres: İstanbul, Türkiye

2) İşlenen Kişisel Veriler
- Kimlik/İletişim: Ad, Soyad, E‑posta
- Hesap Verileri: Profil fotoğrafı (opsiyonel), takım/rol bilgisi, ilanlar, maç kayıtları
- Teknik Veriler: Cihaz tanımlayıcısı (deviceId), FCM bildirimi için token, oturum/log kayıtları, uygulama sürümü
- Kullanım Verileri: İlan görüntüleme/etkileşim, bildirim okuma/işlem bilgisi

3) İşleme Amaçları
- Üyelik oluşturma ve hesabın yönetimi
- Uygulama fonksiyonlarının sunulması (ilan oluşturma, meydan okuma, maç ve bildirim süreçleri)
- Güvenliğin sağlanması, kötüye kullanımın önlenmesi (banlı cihaz takibi)
- Performans ve kullanıcı deneyiminin geliştirilmesi, hata ayıklama
- Yasal yükümlülüklerin yerine getirilmesi, taleplerin yanıtlanması

4) Hukuki Sebepler (KVKK m.5/2; GDPR m.6)
- Sözleşmenin kurulması/ifası (üyelik ve temel fonksiyonlar)
- Meşru menfaat (güvenlik, dolandırıcılık önleme, performans)
- Hukuki yükümlülük (muhasebe, kayıt saklama talepleri vb.)
- Açık rıza (zorunlu olmayan bildirim tercihleriniz, profil fotoğrafı gibi opsiyoneller)

5) Veri Toplama Yöntemi
Veriler, uygulama içi formlar, Firebase SDK’ları ve uygulama günlükleri aracılığıyla otomatik/yarı otomatik yollarla toplanır.

6) Veri Paylaşımı ve Aktarım
- Hizmet sağlayıcılar: Google Firebase (Auth, Firestore, Cloud Functions, Messaging, Storage) – veri barındırma, kimlik doğrulama, bildirim ve saklama hizmetleri
- Hukuki zorunluluklar: İdari/Adli mercilerin talepleri
Yurt dışına aktarım: Firebase altyapısı gereği verileriniz AB/ABD dahil yurt dışındaki sunuculara aktarılabilir. Aktarımlarda sözleşmesel güvenceler ve uygun teknik/idari önlemler uygulanır.

7) Saklama Süreleri
- Hesap verileri: Hesap silinene kadar; yasal uyuşmazlık halinde zamanaşımı süresi boyunca
- Bildirim/işlem logları: Meşru menfaat ve güvenlik amaçları doğrultusunda makul sürelerle
- Yedekler: Operasyonel gereklilikler kapsamında sınırlı süre

8) Veri Sahibi Hakları (KVKK m.11; GDPR m.15‑22)
Verilerinize erişme, düzeltme, silme, işlemeyi kısıtlama, itiraz etme, taşınabilirlik ve rızayı geri çekme haklarına sahipsiniz. Talepleriniz için destek@santraapp.com adresine başvurabilirsiniz.

9) Güvenlik Önlemleri
Uygulama; erişim kontrolü, şifrelenmiş iletişim (TLS), güvenlik kuralları (Firestore Rules), App Check/Play Integrity doğrulaması ve rol/izin yönetimi uygular.

10) Çerezler ve Benzer Teknolojiler
Uygulama içinde SDK seviyesinde analitik/performans verileri işlenebilir. Bildirimler için cihaz FCM token’ı kullanılır.

11) Değişiklikler
Bu politika güncellenebilir. Güncel metin uygulama içinden erişilebilir durumda tutulur.

12) İletişim
Sorularınız için: santraappdev@gmail.com
""";

  // Kullanım Koşulları (hizmet şartları)
  static const String termsOfService = """
Kullanım Koşulları

Son Güncelleme: 08 Ekim 2025

1) Taraflar ve Kabul
Santra uygulamasını kullanarak bu Koşulları ve Gizlilik Politikası’nı kabul etmiş olursunuz. Koşulları kabul etmiyorsanız uygulamayı kullanmayınız.

2) Hizmetin Kapsamı
Santra; takımların/oyuncuların ilan oluşturmasını, meydan okumayı, maç ayarlamasını ve sonuç/istatistik takibini kolaylaştırır. Uygulama; saha kiralama, hakemlik veya fiziksel etkinlik organizasyonu yapmaz.

3) Üyelik ve Yaş Sınırı
Hesap açmak için 13+ yaş gereklidir. 18 yaş altı kullanıcılar, ilgili mevzuat gereği veli/vasi onayı ile uygulamayı kullanmalıdır.

4) Kullanıcı Yükümlülükleri
- Hesap bilgilerinin gizliliğinden siz sorumlusunuz.
- Yanıltıcı/gerçeğe aykırı bilgi (ör. yanlış skor) paylaşmayın.
- Hakaret, tehdit, nefret söylemi, spam, reklam ve hukuka aykırı içerik yasaktır.
- Üçüncü kişilerin haklarını (kişilik, fikri haklar, marka vb.) ihlal etmeyin.

5) İlan ve Maç Süreçleri
Kaptan rolündeki kullanıcılar ilan oluşturabilir. Meydan okumalar ve maç akışı uygulama içi kurallara tabidir. Uyuşmazlık/itiraz hallerinde nihai takdir yetkisi Santra’dadır.

6) Ücretlendirme
Uygulamanın mevcut sürümü temel fonksiyonları ücretsiz sunar. İleride sunulabilecek ücretli özellikler ayrıca duyurulur.

7) Fesih ve Askıya Alma
Koşullara aykırılık, dolandırıcılık veya kötüye kullanım tespitinde hesabınız askıya alınabilir/sonlandırılabilir; banlı cihaz listesi uygulanabilir.

8) Sorumluluk Reddi
Uygulama bir aracı platformdur. Maç/etkinlik sırasında doğrudan/dolaylı ortaya çıkabilecek yaralanma, hasar, anlaşmazlık ve diğer zararlardan sorumlu değiliz. Kullanıcılar spor faaliyetlerinin risklerini kabul eder.

9) Sorumluluğun Sınırı
Mevzuatın izin verdiği azami ölçüde; dolaylı/kazara meydana gelen zararlar, kâr/itibar kaybı ve veri kaybından sorumlu değiliz. Uygulama “olduğu gibi” sağlanır; kesintisiz ve hatasız çalışma taahhüdü yoktur.

10) Fikri Mülkiyet
Uygulama üzerindeki tüm telif, marka ve tasarım hakları saklıdır. İçeriklerin izinsiz kopyalanması, dağıtımı veya türev çalışma oluşturulması yasaktır.

11) Üçüncü Taraf Hizmetler
Firebase ve benzeri hizmet sağlayıcıların koşulları ayrıca geçerlidir. Bu sağlayıcıların değişikliklerinden sorumlu değiliz.

12) Değişiklikler
Koşullar güncellenebilir. Güncel metin uygulama içinde yayımlandığı andan itibaren geçerlidir.

13) Uyuşmazlık Çözümü ve Yetkili Mahkeme
Türk Hukuku uygulanır. İstanbul Merkez (Çağlayan) Adliyesi Mahkemeleri ve İcra Daireleri yetkilidir.

14) İletişim
Sorularınız ve bildirimler için: santraappdev@gmail.com
""";
}

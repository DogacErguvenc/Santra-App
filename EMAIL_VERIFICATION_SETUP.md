# E-posta Doğrulama Sistemi Kurulum Talimatları

## Firebase Console Ayarları

### 1. Authentication > Templates > Email verification

Firebase Console'da aşağıdaki ayarları yapın:

1. **Firebase Console** > **Authentication** > **Templates** > **Email verification** bölümüne gidin
2. **Customize** butonuna tıklayın
3. Aşağıdaki şablonu kullanın:

#### E-posta Konusu:

```
Halisaha Rakip - E-posta Adresinizi Doğrulayın
```

#### E-posta İçeriği:

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>E-posta Doğrulama</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 600px;
        margin: 0 auto;
        padding: 20px;
      }
      .header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 30px;
        text-align: center;
        border-radius: 10px 10px 0 0;
      }
      .content {
        background: #f9f9f9;
        padding: 30px;
        border-radius: 0 0 10px 10px;
      }
      .button {
        display: inline-block;
        background: #667eea;
        color: white;
        padding: 15px 30px;
        text-decoration: none;
        border-radius: 5px;
        margin: 20px 0;
        font-weight: bold;
      }
      .footer {
        text-align: center;
        margin-top: 30px;
        color: #666;
        font-size: 14px;
      }
    </style>
  </head>
  <body>
    <div class="header">
      <h1>⚽ Halisaha Rakip</h1>
      <p>E-posta Adresinizi Doğrulayın</p>
    </div>

    <div class="content">
      <h2>Merhaba!</h2>

      <p>
        Halisaha Rakip uygulamasına kayıt olduğunuz için teşekkür ederiz.
        Hesabınızı aktifleştirmek için aşağıdaki butona tıklayarak e-posta
        adresinizi doğrulayın:
      </p>

      <div style="text-align: center;">
        <a href="{{LINK}}" class="button">E-posta Adresimi Doğrula</a>
      </div>

      <p>
        <strong>Önemli:</strong> Bu bağlantı 24 saat geçerlidir. Eğer butona
        tıklayamıyorsanız, aşağıdaki bağlantıyı tarayıcınıza
        kopyalayabilirsiniz:
      </p>

      <p
        style="word-break: break-all; background: #eee; padding: 10px; border-radius: 5px;"
      >
        {{LINK}}
      </p>

      <p>Eğer bu e-postayı siz talep etmediyseniz, lütfen dikkate almayın.</p>

      <p>
        İyi oyunlar!<br />
        <strong>Halisaha Rakip Ekibi</strong>
      </p>
    </div>

    <div class="footer">
      <p>Bu e-posta Halisaha Rakip uygulaması tarafından gönderilmiştir.</p>
      <p>© 2024 Halisaha Rakip. Tüm hakları saklıdır.</p>
    </div>
  </body>
</html>
```

### 2. Sender Name ve Reply-to Address

- **Sender name:** `Halisaha Rakip`
- **Reply-to address:** `noreply@halisaharakipapp.firebaseapp.com` (veya kendi domain'iniz)

### 3. Action URL

- **Action URL:** `https://halisaharakipapp.firebaseapp.com/__/auth/action`

## Güvenlik Ayarları

### 1. Authorized Domains

Firebase Console > Authentication > Settings > Authorized domains bölümünde:

- `halisaharakipapp.firebaseapp.com`
- `halisaharakipapp.web.app`
- Kendi domain'inizi ekleyin (varsa)

### 2. Email Link Settings

Firebase Console > Authentication > Settings > Email link settings:

- **Action URL:** `https://halisaharakipapp.firebaseapp.com/__/auth/action`
- **Continue URL:** `https://halisaharakipapp.firebaseapp.com`

## Test Etme

1. Uygulamayı çalıştırın
2. Yeni bir hesap oluşturun
3. E-posta doğrulama ekranının görüntülendiğini kontrol edin
4. E-postanızı kontrol edin ve doğrulama bağlantısına tıklayın
5. Uygulamada "E-postamı Doğruladım" butonuna tıklayın
6. Ana sayfaya yönlendirildiğinizi kontrol edin

## Sorun Giderme

### E-posta gelmiyor

- Spam klasörünü kontrol edin
- Firebase Console'da e-posta şablonunun doğru ayarlandığından emin olun
- Geliştirici konsolunda hata mesajlarını kontrol edin

### Doğrulama çalışmıyor

- Firebase Console'da Authorized domains ayarlarını kontrol edin
- Action URL'in doğru olduğundan emin olun
- Uygulama loglarını kontrol edin

## Özellikler

✅ **E-posta doğrulama zorunluluğu** - Doğrulanmamış e-postalar ile giriş engellenir
✅ **Otomatik e-posta gönderimi** - Kayıt sonrası otomatik doğrulama e-postası
✅ **Yeniden gönderme** - 60 saniye bekleme süresi ile tekrar gönderme
✅ **Firestore senkronizasyonu** - Doğrulama durumu Firestore'da güncellenir
✅ **Kullanıcı dostu arayüz** - Modern ve anlaşılır doğrulama ekranı
✅ **Güvenlik** - Sahte e-posta kullanımı engellenir

const { onCall } = require("firebase-functions/v2/https"); 
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const admin = require("firebase-admin");

const projectId = "halisaharakipapp";
admin.initializeApp({ projectId: projectId });

// --- YENİ MAÇ İPTAL FONKSİYONU ---
exports.cancelMatch = onCall(async (request) => {
  const userId = request.auth.uid;
  if (!userId) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu işlemi yapmak için giriş yapmalısınız.');
  }

  const matchId = request.data.matchId;
  if (!matchId) {
    throw new functions.https.HttpsError('invalid-argument', 'Maç ID\'si gönderilmedi.');
  }

  console.log(`Kullanıcı ${userId}, maç ${matchId} için iptal isteği gönderdi.`);

  const firestore = getFirestore();
  const matchRef = firestore.collection('matches').doc(matchId);
  const matchDoc = await matchRef.get();

  if (!matchDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'İptal edilecek maç bulunamadı.');
  }

  const matchData = matchDoc.data();
  const userDoc = await firestore.collection('users').doc(userId).get();
  const userTeamId = userDoc.data().teamId;

  // Güvenlik: Sadece maça katılan takımların kaptanları iptal edebilir.
  if (userTeamId !== matchData.homeTeamId && userTeamId !== matchData.awayTeamId) {
    throw new functions.https.HttpsError('permission-denied', 'Bu maçı iptal etme yetkiniz yok.');
  }

  // Zaman Kontrolü: Maça 72 saatten az mı kaldı?
  const matchTimestamp = matchData.matchTimestamp.toMillis();
  const nowTimestamp = Date.now();
  const hoursDifference = (matchTimestamp - nowTimestamp) / 1000 / 60 / 60;

  if (hoursDifference < 72) {
    throw new functions.https.HttpsError('failed-precondition', 'Maçın başlamasına 72 saatten az kaldığı için iptal edilemez.');
  }

  // İşlemleri başlat
  try {
    const batch = firestore.batch();
    
    // 1. Maçı sil
    batch.delete(matchRef);

    // 2. Orijinal ilanı tekrar 'Aktif' yap
    const postId = matchData.postId;
    if (postId) {
      const postRef = firestore.collection('posts').doc(postId);
      batch.update(postRef, { status: 'Aktif' });

      // 3. O ilana ait eski challenge'ları temizle
      const challengesSnapshot = await postRef.collection('challenges').get();
      challengesSnapshot.forEach(doc => batch.delete(doc.ref));
    }
    
    await batch.commit();
    console.log(`Maç ${matchId} başarıyla iptal edildi.`);
    
    // 4. Diğer kaptana bildirim gönder
    const otherCaptainId = (userId === matchData.homeCaptainId) ? matchData.awayCaptainId : matchData.homeCaptainId;
    const otherCaptainDoc = await firestore.collection('users').doc(otherCaptainId).get();
    if(otherCaptainDoc.exists && otherCaptainDoc.data().fcmTokens) {
        const tokens = otherCaptainDoc.data().fcmTokens;
        if(tokens.length > 0) {
            const message = {
                notification: { title: "Maç İptal Edildi", body: `${userDoc.data().fullName} adlı kullanıcı, aranızdaki maçı iptal etti.`},
                data: { "cancelledPostId": postId }, // Tıklayınca ana sayfaya veya ilana gidebilir
                tokens: tokens,
            };
            await getMessaging().sendEachForMulticast(message);
        }
    }

    return { success: true, message: 'Maç başarıyla iptal edildi.' };

  } catch(error) {
    console.error("Maç iptal edilirken hata oluştu:", error);
    throw new functions.https.HttpsError('internal', 'İşlem sırasında bir sunucu hatası oluştu.');
  }
});


exports.toggleUserBanStatus = onCall(async (request) => {
  if (request.auth.token.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Bu işlemi yapmak için admin yetkisine sahip olmalısınız.');
  }

  const userIdToToggle = request.data.userId;
  const newBanStatus = request.data.banStatus;
  if (!userIdToToggle) {
    throw new functions.https.HttpsError('invalid-argument', 'Kullanıcı ID\'si gönderilmedi.');
  }

  try {
    console.log(`Kullanıcı ${userIdToToggle} için ban durumu ${newBanStatus} olarak ayarlanıyor.`);
    
    const userDocRef = getFirestore().collection('users').doc(userIdToToggle);
    const userDoc = await userDocRef.get();
    const deviceId = userDoc.data()?.deviceId;

    const promises = [
      admin.auth().updateUser(userIdToToggle, { disabled: newBanStatus }),
      userDocRef.update({ isBanned: newBanStatus })
    ];

    if (deviceId) {
      const bannedDeviceRef = getFirestore().collection('bannedDevices').doc(deviceId);
      if (newBanStatus) {
        console.log(`Cihaz ${deviceId} kara listeye ekleniyor.`);
        promises.push(bannedDeviceRef.set({ bannedAt: new Date(), bannedUserId: userIdToToggle }));
      } else {
        console.log(`Cihaz ${deviceId} kara listeden kaldırılıyor.`);
        promises.push(bannedDeviceRef.delete());
      }
    }

    await Promise.all(promises);

    console.log("İşlem başarıyla tamamlandı.");
    return { success: true, message: `Kullanıcı başarıyla ${newBanStatus ? 'banlandı' : 'banı kaldırıldı'}.` };

  } catch (error) {
    console.error("Banlama işlemi sırasında hata oluştu:", error);
    throw new functions.https.HttpsError('internal', 'İşlem sırasında bir sunucu hatası oluştu.');
  }
});

exports.sendChallengeNotification = onDocumentCreated("posts/{postId}/challenges/{challengeId}", async (event) => {
  console.log("Fonksiyon yeni bir meydan okuma ile tetiklendi. Event ID:", event.id);
  const challengeData = event.data.data();
  if (!challengeData) { console.log("Meydan okuma dokümanında veri bulunamadı."); return; }
  const challengingTeamName = challengeData.challengerTeamName;
  const postId = event.params.postId;
  try {
    const postDoc = await getFirestore().collection("posts").doc(postId).get();
    if (!postDoc.exists) { console.log("İlan dokümanı bulunamadı:", postId); return; }
    const postCaptainId = postDoc.data().captainId;
    const captainUserDoc = await getFirestore().collection("users").doc(postCaptainId).get();
    if (!captainUserDoc.exists) { console.log("Kaptan kullanıcı dokümanı bulunamadı:", postCaptainId); return; }
    const fcmTokens = captainUserDoc.data().fcmTokens;
    if (!fcmTokens || fcmTokens.length === 0) { console.log("Kaptanın bildirim alacak bir cihazı (FCM token) bulunamadı."); return; }
    const message = {
      notification: { title: "Yeni Bir Meydan Okuman Var!", body: `${challengingTeamName} takımı, ilanına meydan okudu!` },
      data: { "postId": postId },
      tokens: fcmTokens,
    };
    await getMessaging().sendEachForMulticast(message);
  } catch (error) { console.error("Bildirim fonksiyonunda genel bir hata oluştu:", error); }
});

exports.sendChallengeAcceptedNotification = onDocumentCreated("matches/{matchId}", async (event) => {
  console.log("Maç oluşturuldu, kabul bildirimi gönderiliyor. Maç ID:", event.params.matchId);
  const matchData = event.data.data();
  if (!matchData) { console.log("Maç dokümanında veri bulunamadı."); return; }
  const challengerCaptainId = matchData.challengerId;
  const homeTeamName = matchData.homeTeamName;
  if (!challengerCaptainId) { console.log("Bu maç bir meydan okuma sonucu oluşmamış, bildirim gönderilmiyor."); return; }
  try {
    const challengerUserDoc = await getFirestore().collection("users").doc(challengerCaptainId).get();
    if (!challengerUserDoc.exists) { console.log("Meydan okuyan kaptan kullanıcı dokümanı bulunamadı:", challengerCaptainId); return; }
    const fcmTokens = challengerUserDoc.data().fcmTokens;
    if (!fcmTokens || fcmTokens.length === 0) { console.log("Meydan okuyan kaptanın bildirim alacak bir cihazı (FCM token) bulunamadı."); return; }
    const message = {
      notification: { title: "Meydan Okuman Kabul Edildi!", body: `${homeTeamName} takımı, meydan okumanı kabul etti. Maç ayarlandı!` },
      data: { "matchId": event.params.matchId },
      tokens: fcmTokens,
    };
    await getMessaging().sendEachForMulticast(message);
  } catch (error) { console.error("Kabul bildirim fonksiyonunda hata oluştu:", error); }
});

exports.sendScoreDisputedNotification = onDocumentCreated("matches/{matchId}/disputes/{disputeId}", async (event) => {
    console.log("Skora itiraz edildi, bildirim gönderiliyor. Maç ID:", event.params.matchId);
    const disputeData = event.data.data();
    if (!disputeData) { console.log("İtiraz dokümanında veri yok."); return; }
    const matchId = event.params.matchId;
    const disputingTeamName = disputeData.disputingTeamName;
    try {
        const matchDoc = await getFirestore().collection("matches").doc(matchId).get();
        if (!matchDoc.exists) { console.log("Maç dokümanı bulunamadı:", matchId); return; }
        const scoreReporterId = matchDoc.data().scoreReporterId;
        if (!scoreReporterId) { console.log("Skoru giren kaptan ID'si maçta kayıtlı değil."); return; }
        const reporterUserDoc = await getFirestore().collection("users").doc(scoreReporterId).get();
        if (!reporterUserDoc.exists) { console.log("Skoru giren kaptan bulunamadı:", scoreReporterId); return; }
        const fcmTokens = reporterUserDoc.data().fcmTokens;
        if (!fcmTokens || fcmTokens.length === 0) { console.log("Skoru giren kaptanın FCM token'ı yok."); return; }
        const message = {
            notification: { title: "Girdiğin Skora İtiraz Edildi!", body: `${disputingTeamName} takımı, girdiğin maç skoruna itiraz etti.`},
            data: { "matchId": matchId },
            tokens: fcmTokens,
        };
        await getMessaging().sendEachForMulticast(message);
    } catch (error) {
        console.error("İtiraz bildirim fonksiyonunda hata oluştu:", error);
    }
});

exports.autoConfirmScores = onSchedule("every 12 hours", async (event) => {
  console.log("Zamanlanmış fonksiyon çalıştırıldı: Otomatik skor onayı kontrol ediliyor.");
  const now = admin.firestore.Timestamp.now();
  const twoDaysAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - (48 * 60 * 60 * 1000));
  const querySnapshot = await getFirestore().collection("matches").where("status", "==", "Sonuç Girildi").where("scoreEnteredAt", "<=", twoDaysAgo).get();
  if (querySnapshot.empty) { console.log("Otomatik onaylanacak maç bulunamadı."); return null; }
  for (const doc of querySnapshot.docs) {
    try {
      console.log(`Maç otomatik onaylanıyor: ${doc.id}`);
      await doc.ref.update({ status: "Onaylandı", confirmedAt: now, confirmedBy: "auto-confirm-system" });
      const matchData = doc.data();
      const homeCaptainId = matchData.homeCaptainId;
      const awayCaptainId = matchData.awayCaptainId;
      if (homeCaptainId && awayCaptainId) {
        const homeCaptainDoc = await getFirestore().collection("users").doc(homeCaptainId).get();
        const awayCaptainDoc = await getFirestore().collection("users").doc(awayCaptainId).get();
        const tokens = [];
        if (homeCaptainDoc.exists && homeCaptainDoc.data().fcmTokens) { tokens.push(...homeCaptainDoc.data().fcmTokens); }
        if (awayCaptainDoc.exists && awayCaptainDoc.data().fcmTokens) { tokens.push(...awayCaptainDoc.data().fcmTokens); }
        if (tokens.length > 0) {
          const message = {
            notification: { title: "Maç Sonucu Onaylandı", body: "Beklemedeki maç sonucu sistem tarafından otomatik olarak onaylandı." },
            data: { "matchId": doc.id },
            tokens: tokens,
          };
          await getMessaging().sendEachForMulticast(message);
          console.log(`Otomatik onay bildirimi gönderildi. Maç ID: ${doc.id}`);
        }
      }
    } catch (error) {
      console.error(`Maç ${doc.id} onaylanırken veya bildirim gönderilirken hata oluştu:`, error);
    }
  }
  console.log(`${querySnapshot.size} adet maçın onay süreci tamamlandı.`);
  return null;
});

exports.updateTeamStatsOnMatchComplete = onDocumentUpdated("matches/{matchId}", async (event) => {
  const data = event.data.after.data();
  const previousData = event.data.before.data();
  if (data.status !== 'Onaylandı' || previousData.status === 'Onaylandı') { return null; }
  const homeTeamId = data.homeTeamId; const awayTeamId = data.awayTeamId; const homeScore = data.homeScore; const awayScore = data.awayScore;
  if (homeTeamId == null || awayTeamId == null || homeScore == null || awayScore == null) { return null; }
  const homeTeamRef = getFirestore().collection('teams').doc(homeTeamId); const awayTeamRef = getFirestore().collection('teams').doc(awayTeamId);
  const batch = getFirestore().batch(); const increment = FieldValue.increment(1);
  if (homeScore > awayScore) {
    batch.update(homeTeamRef, { wins: increment, matchesPlayed: increment }); batch.update(awayTeamRef, { losses: increment, matchesPlayed: increment });
  } else if (awayScore > homeScore) {
    batch.update(awayTeamRef, { wins: increment, matchesPlayed: increment }); batch.update(homeTeamRef, { losses: increment, matchesPlayed: increment });
  } else {
    batch.update(homeTeamRef, { draws: increment, matchesPlayed: increment }); batch.update(awayTeamRef, { draws: increment, matchesPlayed: increment });
  }
  await batch.commit();
  return null;
});

exports.calculateTeamPoints = onDocumentUpdated("teams/{teamId}", async (event) => {
  const data = event.data.after.data(); const previousData = event.data.before.data();
  const wins = data.wins ?? 0; const draws = data.draws ?? 0;
  const prevWins = previousData.wins ?? 0; const prevDraws = previousData.draws ?? 0;
  if (wins === prevWins && draws === prevDraws) { return null; }
  const newPoints = (wins * 3) + (draws * 1);
  return event.data.after.ref.update({ points: newPoints });
});
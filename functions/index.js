const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ─── RESET NOTIFIKACIJA U PONOĆ (UTC 00:00) ───────────────────────────────────
exports.resetDailyNotificationCount = functions.pubsub
  .schedule("0 0 * * *")
  .timeZone("UTC")
  .onRun(async (context) => {
    console.log("Pokrećem reset dnevnih notifikacija...");

    const snapshot = await db.collection("subscriptions").get();

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        daily_notification_count: 0,
        last_notification_reset: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    console.log(`Reset završen za ${snapshot.size} firmi.`);
    return null;
  });

// ─── PROVJERA ISTEKA PRETPLATE (svaki dan u 01:00 UTC) ───────────────────────
exports.checkSubscriptionExpiry = functions.pubsub
  .schedule("0 1 * * *")
  .timeZone("UTC")
  .onRun(async (context) => {
    console.log("Provjera isteka pretplata...");

    const now = admin.firestore.Timestamp.now();
    const snapshot = await db.collection("subscriptions").get();

    const batch = db.batch();
    let updated = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const status = data.status;
      const endDate = data.end_date;
      const gracePeriodEnd = data.grace_period_end;

      // Aktivan → Grace Period
      if (status === "active" && endDate && endDate.toMillis() < now.toMillis()) {
        const gracePeriodEndDate = new Date();
        gracePeriodEndDate.setDate(gracePeriodEndDate.getDate() + 7);

        batch.update(doc.ref, {
          status: "grace_period",
          grace_period_end: admin.firestore.Timestamp.fromDate(gracePeriodEndDate),
        });
        updated++;
        console.log(`Firma ${data.company_id} ušla u grace period.`);
      }

      // Grace Period → Expired
      if (
        status === "grace_period" &&
        gracePeriodEnd &&
        gracePeriodEnd.toMillis() < now.toMillis()
      ) {
        batch.update(doc.ref, {
          status: "expired",
          tier: "free",
        });
        updated++;
        console.log(`Firma ${data.company_id} — pretplata istekla, downgrade na Free.`);

        // Soft Lock poslednjeg radnika
        await applySoftLock(data.company_id);
      }
    }

    await batch.commit();
    console.log(`Ažurirano ${updated} pretplata.`);
    return null;
  });

// ─── SOFT LOCK — zaključaj poslednje dodate radnike ──────────────────────────
async function applySoftLock(companyId) {
  const FREE_WORKER_LIMIT = 5;

  const workersSnap = await db
    .collection("users")
    .where("current_company_id", "==", companyId)
    .where("active_status", "==", true)
    .orderBy("created_at", "desc")
    .get();

  if (workersSnap.size <= FREE_WORKER_LIMIT) return;

  const toBlock = workersSnap.docs.slice(0, workersSnap.size - FREE_WORKER_LIMIT);
  const batch = db.batch();
  toBlock.forEach((doc) => {
    batch.update(doc.ref, { soft_locked: true });
  });
  await batch.commit();

  console.log(
    `Soft Lock: ${toBlock.length} radnika zaključano za firmu ${companyId}.`
  );
}

// ─── FCM NOTIFIKACIJA (okidač na novi shift) ──────────────────────────────────
exports.onShiftCreated = functions.firestore
  .document("shifts/{shiftId}")
  .onCreate(async (snap, context) => {
    const shift = snap.data();

    if (!shift.notification_sent) return null;

    // Dohvati FCM token radnika
    const userDoc = await db.collection("users").doc(shift.worker_id).get();
    if (!userDoc.exists) return null;

    const fcmToken = userDoc.data().fcm_token;
    if (!fcmToken) return null;

    // Formatiraj vreme
    const startTime = shift.start_time.toDate();
    const hours = startTime.getHours().toString().padStart(2, "0");
    const minutes = startTime.getMinutes().toString().padStart(2, "0");
    const timeStr = `${hours}:${minutes}`;

    const date = startTime.toLocaleDateString("sr-Latn", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
    });

    // Pošalji notifikaciju sa 60s debounce
    await new Promise((resolve) => setTimeout(resolve, 60000));

    // Provjeri da li je smena i dalje aktivna
    const shiftCheck = await snap.ref.get();
    if (!shiftCheck.exists) return null;

    const message = {
      token: fcmToken,
      notification: {
        title: "Nova smena je dodata",
        body: `${date} u ${timeStr}`,
      },
      data: {
        type: "shift",
        shift_id: context.params.shiftId,
        company_id: shift.company_id,
      },
      android: {
        notification: {
          channelId: "shiftio_main",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`FCM poslat radniku ${shift.worker_id}`);

      // Povećaj daily_notification_count
      const subSnap = await db
        .collection("subscriptions")
        .where("company_id", "==", shift.company_id)
        .limit(1)
        .get();

      if (!subSnap.empty) {
        await subSnap.docs[0].ref.update({
          daily_notification_count:
            admin.firestore.FieldValue.increment(1),
        });
      }
    } catch (error) {
      console.error("FCM greška:", error);
    }

    return null;
  });

// ─── WEBHOOK: RevenueCat → Firestore sync ────────────────────────────────────
exports.revenueCatWebhook = functions.https.onRequest(async (req, res) => {
  // Provjeri shared secret
  const authHeader = req.headers.authorization;
  const expectedSecret = functions.config().revenuecat?.webhook_secret;

  if (expectedSecret && authHeader !== `Bearer ${expectedSecret}`) {
    console.error("Neovlašten RevenueCat webhook poziv.");
    res.status(401).send("Unauthorized");
    return;
  }

  const event = req.body;
  const eventType = event.event?.type;
  const appUserId = event.event?.app_user_id;
  const productId = event.event?.product_id ?? "";

  if (!appUserId) {
    res.status(400).send("Missing app_user_id");
    return;
  }

  console.log(`RevenueCat event: ${eventType} za korisnika ${appUserId}`);

  // Pronađi company_id admina
  const userDoc = await db.collection("users").doc(appUserId).get();
  if (!userDoc.exists) {
    res.status(404).send("User not found");
    return;
  }

  const companyId = userDoc.data().current_company_id;
  if (!companyId) {
    res.status(400).send("No company");
    return;
  }

  // Odredi tier i cycle iz product ID-a
  let tier = "free";
  let cycle = "monthly";

  if (productId.includes("standard")) tier = "standard";
  if (productId.includes("pro")) tier = "pro";
  if (productId.includes("yearly")) cycle = "yearly";

  const subSnap = await db
    .collection("subscriptions")
    .where("company_id", "==", companyId)
    .limit(1)
    .get();

  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE": {
      const endDate = new Date();
      if (cycle === "yearly") {
        endDate.setFullYear(endDate.getFullYear() + 1);
      } else {
        endDate.setMonth(endDate.getMonth() + 1);
      }

      const updateData = {
        tier,
        cycle,
        status: "active",
        end_date: admin.firestore.Timestamp.fromDate(endDate),
        grace_period_end: null,
      };

      if (subSnap.empty) {
        await db.collection("subscriptions").add({
          company_id: companyId,
          daily_notification_count: 0,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          ...updateData,
        });
      } else {
        await subSnap.docs[0].ref.update(updateData);
      }
      break;
    }

    case "CANCELLATION":
    case "EXPIRATION":
      if (!subSnap.empty) {
        await subSnap.docs[0].ref.update({ status: "past_due" });
      }
      break;

    case "BILLING_ISSUE":
      if (!subSnap.empty) {
        await subSnap.docs[0].ref.update({ status: "past_due" });
      }
      break;

    default:
      console.log(`Nepoznat event tip: ${eventType}`);
  }

  res.status(200).send("OK");
});
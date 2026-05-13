# FCM push obavijesti za narudžbe (iOS)

Backend šalje **topic** poruke na FCM topic iz konfiguracije (zadano `mozzart_purchase_orders`, env `MOZZART_FCM_TOPIC`). iOS aplikacija mora biti pretplaćena na isti topic nakon prijave.

## Firebase konzola

1. U istom Firebase projektu koji koristi `gcloud-api` (npr. alias `fcm_barion` u `PROJECTS_JSON`) dodaj **iOS aplikaciju** s točnim **Bundle ID**-jem.
2. Preuzmi `GoogleService-Info.plist` i dodaj ga u Xcode projekt.
3. **Apple Push Notifications**: u Firebase Project Settings → Cloud Messaging → **Apple app configuration** učitaj **APNs Authentication Key** (.p8) ili APNs certifikat (preporuka: .p8 key).

## iOS aplikacija (Swift, sažetak)

1. Dodaj ovisnosti: **Firebase/Messaging** (i osnovni Firebase).
2. U `AppDelegate` ili `@main` app lifecycle: `FirebaseApp.configure()`.
3. Zatraži dozvolu za notifikacije (`UNUserNotificationCenter`), registriraj za remote notifications.
4. Implementiraj `MessagingDelegate` i `application(_:didReceiveRegistrationToken:)` ako trebaš token za debug.
5. **Pretplata na topic** (nakon uspješnog logina u Mozzart backend / kad imaš session):

   ```swift
   Messaging.messaging().subscribe(toTopic: "mozzart_purchase_orders") { error in
       // log / retry
   }
   ```

   Topic string mora točno odgovarati vrijednosti u produkcijskom `.env` (`MOZZART_FCM_TOPIC`).

6. Obradi dolazne poruke:
   - **Foreground**: `MessagingDelegate` → `messaging(_:didReceiveMessage:)`.
   - **Background / tap**: `userNotificationCenter(_:didReceive:withCompletionHandler:)` i UNNotificationResponse.

## FS Ordino (Flutter app u ovom repou)

Ovo pokriva isti checklist kao Swift sažetak iznad, preko **FlutterFire** (`firebase_core`, `firebase_messaging`):

| Zahtjev (iz checklista) | U implementaciji |
|-------------------------|------------------|
| Firebase + Messaging | `pubspec.yaml`, `Firebase.initializeApp()` u `lib/main.dart` |
| `GoogleService-Info.plist` u bundleu | `ios/Runner/GoogleService-Info.plist` + uključen u Xcode **Copy Bundle Resources** |
| APNs u Firebase konzoli | Ručno u projektu (nije u kodu); bez .p8 u konzoli iOS **ne** prima FCM |
| Pretplata na topic nakon auth | `subscribeMozzartPurchaseOrdersTopic()` iz `session_scope.dart` nakon login/restore |
| Točan topic | `kMozzartPurchaseOrdersFcmTopic` u `lib/src/push/purchase_order_fcm.dart` = `mozzart_purchase_orders` (kao `MOZZART_FCM_TOPIC`) |
| Foreground prikaz | `setForegroundNotificationPresentationOptions` u `main.dart` |
| Push capability / APNs entitlement | `ios/Runner/DebugProfile.entitlements` (`development`), `Release.entitlements` (`production`) |
| Background remote | `UIBackgroundModes` → `remote-notification` u `Info.plist` |
| Method swizzling (FCM plugin) | `FirebaseAppDelegateProxyEnabled` = true u `Info.plist` |
| iOS: APNs token kasni | Prije `subscribeToTopic` čeka se `getAPNSToken()` (do ~10 s); zatim `getToken()` |
| Osvježenje FCM tokena | `installMozzartFcmTokenRefreshHandler()` u `main.dart` — ponovna pretplata ako je korisnik već uspješno pretplaćen |
| Odjava | `unsubscribeMozzartPurchaseOrdersTopic()` pri logoutu |
| Background handler (data / terminated) | `firebaseMessagingBackgroundHandler` u `lib/src/push/firebase_background.dart`, registriran u `main.dart` |

**Debug:** na fizičkom iPhoneu (ne simulator) u Xcode konzoli filtriraj `purchase_order_fcm` — trebaju se pojaviti poruke poput `getToken ok`, `subscribed topic`, ili upozorenja ako je APNs token null / dozvola odbijena.

## Payload koji šalje backend

`notification.title` / `notification.body` (prikaz u trayu), plus `data` (sve vrijednosti su stringovi):

| `data["type"]`              | Značenje              | Ostala polja                          |
|----------------------------|------------------------|----------------------------------------|
| `purchase_order_sent`      | Email poslan dobavljaču | `purchase_order_id`, `supplier_name` |
| `purchase_order_confirmed` | Dobavljač potvrdio     | `purchase_order_id`, `supplier_name` |

Prema `purchase_order_id` otvori detalj narudžbe u aplikaciji.

## Operativno

- U `gcloud` `.env` u `CALLER_TOKENS_JSON` mora postojati ključ **`mozzart`** s Bearer tokenom koji se podudara s `MOZZART_GCLOUD_CALLER_TOKEN` u Mozzart `.env`.
- `MOZZART_FCM_ENABLED=true` u Mozzart okruženju; Celery worker mora raditi jer se slanje radi asinkrono.

## Ako Android prima push, a iOS ne

1. **Firebase → isti projekt** kao backend (`fcm_barion`): `GoogleService-Info.plist` na iOS mora biti iz tog projekta.
2. **Cloud Messaging → Apple**: obavezno učitaj **APNs Authentication Key (.p8)** (ili certifikat). Bez toga FCM ne isporučuje na iOS.
3. **Topic** točno `mozzart_purchase_orders` (ili vrijednost iz `MOZZART_FCM_TOPIC`).
4. **Fizički uređaj**; u foregroundu implementiraj `UNUserNotificationCenterDelegate` (`userNotificationCenter(_:willPresent:...)`).
5. Interni `gcloud-api` za poruke s `notification` postavlja APNs (`apns-priority`, `apns-push-type: alert`, `sound: default`) radi pouzdanijeg prikaza na iOS 13+.

## Test

- Iz kontejnera `mozzart` (s ispravnim tokenom): `curl -X POST http://gcloud-api:8080/fcm/send` s `topic`, `project_alias`, `notification` i `data` (vidi `/opt/stacks/gcloud/README.md`).
- Na fizičkom iPhoneu: development certifikat / sandbox APNs preko Firebase-a.

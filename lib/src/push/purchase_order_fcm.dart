import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';

/// Same default topic as Django `MOZZART_FCM_TOPIC` (see `app/config/settings.py`).
const String kMozzartPurchaseOrdersFcmTopic = 'mozzart_purchase_orders';

/// Subscribe after successful auth so topic pushes from gcloud-api reach the device.
Future<void> subscribeMozzartPurchaseOrdersTopic() async {
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    await messaging.subscribeToTopic(kMozzartPurchaseOrdersFcmTopic);
  } catch (e, st) {
    developer.log(
      'FCM subscribe failed',
      error: e,
      stackTrace: st,
      name: 'purchase_order_fcm',
    );
  }
}

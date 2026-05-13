import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Same default topic as Django `MOZZART_FCM_TOPIC` (see `app/config/settings.py`).
const String kMozzartPurchaseOrdersFcmTopic = 'mozzart_purchase_orders';

/// True after [subscribeMozzartPurchaseOrdersTopic] runs; false after [unsubscribeMozzartPurchaseOrdersTopic].
/// Used so [installMozzartFcmTokenRefreshHandler] does not subscribe before login.
bool _mozzartTopicDesired = false;

/// Call once from [main] after [Firebase.initializeApp] so APNs/FCM token refresh re-applies topic subscription.
void installMozzartFcmTokenRefreshHandler() {
  FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
    if (!_mozzartTopicDesired) return;
    developer.log(
      'FCM token refresh; re-subscribing topic',
      name: 'purchase_order_fcm',
    );
    unawaited(_subscribeMozzartPurchaseOrdersTopicBody());
  });
}

/// Subscribe after successful auth so topic pushes from gcloud-api reach the device.
Future<void> subscribeMozzartPurchaseOrdersTopic() async {
  await _subscribeMozzartPurchaseOrdersTopicBody();
}

/// Leave topic on logout so a refreshed token does not keep receiving staff pushes.
Future<void> unsubscribeMozzartPurchaseOrdersTopic() async {
  _mozzartTopicDesired = false;
  try {
    await FirebaseMessaging.instance
        .unsubscribeFromTopic(kMozzartPurchaseOrdersFcmTopic);
  } catch (e, st) {
    developer.log(
      'FCM unsubscribe failed',
      error: e,
      stackTrace: st,
      name: 'purchase_order_fcm',
    );
  }
}

Future<void> _subscribeMozzartPurchaseOrdersTopicBody() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      developer.log(
        'FCM: notifications denied in system settings',
        name: 'purchase_order_fcm',
      );
      return;
    }
    if (status == AuthorizationStatus.notDetermined) {
      developer.log(
        'FCM: permission still not determined after request',
        name: 'purchase_order_fcm',
      );
      return;
    }

    // iOS: topic + FCM need APNs device token; it can arrive shortly after permission.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      String? apns;
      for (var i = 0; i < 40; i++) {
        apns = await messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (apns == null || apns.isEmpty) {
        developer.log(
          'FCM: APNs token still null after wait; subscribe may not deliver on iOS',
          name: 'purchase_order_fcm',
        );
      }
    }

    final token = await messaging.getToken();
    developer.log(
      'FCM: getToken ok (len=${token?.length ?? 0})',
      name: 'purchase_order_fcm',
    );

    await messaging.subscribeToTopic(kMozzartPurchaseOrdersFcmTopic);
    _mozzartTopicDesired = true;
    developer.log(
      'FCM: subscribed topic $kMozzartPurchaseOrdersFcmTopic',
      name: 'purchase_order_fcm',
    );
  } catch (e, st) {
    _mozzartTopicDesired = false;
    developer.log(
      'FCM subscribe failed',
      error: e,
      stackTrace: st,
      name: 'purchase_order_fcm',
    );
  }
}

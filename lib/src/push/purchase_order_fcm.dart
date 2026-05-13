import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Same default topic as Django `MOZZART_FCM_TOPIC` (see `app/config/settings.py`).
const String kMozzartPurchaseOrdersFcmTopic = 'mozzart_purchase_orders';

/// True after a successful [subscribeToTopic]; false after [unsubscribeMozzartPurchaseOrdersTopic].
bool _mozzartTopicDesired = false;

/// One delayed retry per app launch if APNs token is late (common on cold start).
bool _scheduledIosApnsRetry = false;

/// Call once from [main] after [Firebase.initializeApp] so FCM token refresh re-applies topic subscription.
void installMozzartFcmTokenRefreshHandler() {
  FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
    if (!_mozzartTopicDesired) return;
    developer.log(
      'FCM token refresh; re-subscribing topic',
      name: 'purchase_order_fcm',
    );
    unawaited(_subscribeMozzartPurchaseOrdersTopicBody(isRetry: false));
  });
}

/// Subscribe after successful auth so topic pushes from gcloud-api reach the device.
Future<void> subscribeMozzartPurchaseOrdersTopic() async {
  await _subscribeMozzartPurchaseOrdersTopicBody(isRetry: false);
}

/// Leave topic on logout so a refreshed token does not keep receiving staff pushes.
Future<void> unsubscribeMozzartPurchaseOrdersTopic() async {
  _mozzartTopicDesired = false;
  _scheduledIosApnsRetry = false;
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

Future<void> _subscribeMozzartPurchaseOrdersTopicBody({required bool isRetry}) async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    developer.log(
      'FCM: notification authorizationStatus=$status',
      name: 'purchase_order_fcm',
    );

    if (status == AuthorizationStatus.denied) {
      developer.log(
        'FCM: notifications denied in system settings',
        name: 'purchase_order_fcm',
      );
      return;
    }
    // Do not bail on notDetermined: some OS / timing edge cases still obtain a token later.
    if (status == AuthorizationStatus.notDetermined) {
      developer.log(
        'FCM: permission notDetermined after request; continuing to try token/topic',
        name: 'purchase_order_fcm',
      );
    }

    // iOS: topic + FCM need APNs device token; it can arrive shortly after permission.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _waitForApnsToken(messaging);
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

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !isRetry &&
        !_scheduledIosApnsRetry) {
      final apns = await messaging.getAPNSToken();
      if (apns == null || apns.isEmpty) {
        _scheduledIosApnsRetry = true;
        developer.log(
          'FCM: scheduling delayed topic retry (APNs was null after subscribe)',
          name: 'purchase_order_fcm',
        );
        unawaited(_delayedIosTopicSubscribeRetry());
      }
    }
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

Future<void> _waitForApnsToken(FirebaseMessaging messaging) async {
  String? apns;
  for (var i = 0; i < 40; i++) {
    apns = await messaging.getAPNSToken();
    if (apns != null && apns.isNotEmpty) break;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  if (apns == null || apns.isEmpty) {
    developer.log(
      'FCM: APNs token still null after wait; subscribe may not deliver until delayed retry',
      name: 'purchase_order_fcm',
    );
  } else {
    developer.log(
      'FCM: APNs token received (len=${apns.length})',
      name: 'purchase_order_fcm',
    );
  }
}

Future<void> _delayedIosTopicSubscribeRetry() async {
  await Future<void>.delayed(const Duration(seconds: 8));
  if (!_mozzartTopicDesired) {
    developer.log(
      'FCM: delayed retry skipped (no longer subscribed / logged out)',
      name: 'purchase_order_fcm',
    );
    return;
  }
  try {
    final messaging = FirebaseMessaging.instance;
    await _waitForApnsToken(messaging);
    await messaging.getToken();
    await messaging.subscribeToTopic(kMozzartPurchaseOrdersFcmTopic);
    _mozzartTopicDesired = true;
    developer.log(
      'FCM: delayed retry finished; topic $kMozzartPurchaseOrdersFcmTopic',
      name: 'purchase_order_fcm',
    );
  } catch (e, st) {
    developer.log(
      'FCM delayed topic retry failed',
      error: e,
      stackTrace: st,
      name: 'purchase_order_fcm',
    );
  }
}

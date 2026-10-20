import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../state/runs.dart';
import '../state/settings.dart';

/// Account + sync. Runs are stored under users/{uid}/runs/{startMillis};
/// the phone keeps a local copy so the app works offline.
class Cloud extends ChangeNotifier {
  bool ready = false, busy = false;
  String? error;
  User? user;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
      ready = true;
      user = FirebaseAuth.instance.currentUser;
      FirebaseAuth.instance.authStateChanges().listen((u) {
        user = u;
        notifyListeners();
      });
      runStore.onChange = _push;
      if (user != null) unawaited(syncAll());
    } catch (e) {
      ready = false;
      error = '$e';
      debugPrint('Firebase init failed: $e');
    }
    notifyListeners();
  }

  Future<String?> signIn() async {
    if (!ready) return 'الخدمة غير متاحة الحين';
    busy = true;
    error = null;
    notifyListeners();
    try {
      final acc = await GoogleSignIn.instance.authenticate();
      final idToken = acc.authentication.idToken;
      final cred = GoogleAuthProvider.credential(idToken: idToken);
      final res = await FirebaseAuth.instance.signInWithCredential(cred);
      user = res.user;
      if (settings.name.isEmpty && (user?.displayName ?? '').isNotEmpty) {
        await settings.setName(user!.displayName!.split(' ').first);
      }
      await _db.collection('users').doc(user!.uid).set({
        'name': settings.name,
        'goalKm': settings.goalKm,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await syncAll();
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      return 'تعذّر الدخول بقوقل (${e.code.name})';
    } catch (e) {
      return 'تعذّر الدخول: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    user = null;
    notifyListeners();
  }

  CollectionReference<Map<String, dynamic>> _runs(String uid) => _db.collection('users').doc(uid).collection('runs');

  /// Two-way merge: upload local runs the server lacks, download the rest.
  Future<void> syncAll() async {
    final u = user;
    if (u == null) return;
    busy = true;
    notifyListeners();
    try {
      final snap = await _runs(u.uid).get();
      final remote = {for (final d in snap.docs) d.id: d.data()};
      final local = {for (final r in runStore.runs) _id(r): r};
      final batch = _db.batch();
      var writes = 0;
      for (final e in local.entries) {
        if (!remote.containsKey(e.key)) {
          batch.set(_runs(u.uid).doc(e.key), toCloud(e.value));
          writes++;
        }
      }
      if (writes > 0) await batch.commit();
      final missing = remote.entries.where((e) => !local.containsKey(e.key)).map((e) => fromCloud(e.value)).toList();
      if (missing.isNotEmpty) await runStore.addAll(missing);
      error = null;
    } catch (e) {
      error = 'تعذّرت المزامنة';
      debugPrint('sync failed: $e');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Called by the run store on every local change.
  Future<void> _push(RunChange kind, Run r) async {
    final u = user;
    if (u == null) return;
    try {
      final doc = _runs(u.uid).doc(_id(r));
      if (kind == RunChange.removed) {
        await doc.delete();
      } else {
        await doc.set(toCloud(r));
      }
    } catch (e) {
      debugPrint('push failed: $e');
    }
  }

  static String _id(Run r) => '${r.start.millisecondsSinceEpoch}';
}

/// Firestore has no nested arrays, so the path is stored flat: [lat, lng, lat, lng, …].
Map<String, dynamic> toCloud(Run r) => {
      'start': r.start.millisecondsSinceEpoch,
      'secs': r.secs,
      'meters': r.meters,
      'path': [for (final p in r.path) ...p.map((v) => double.parse(v.toStringAsFixed(6)))],
      'splits': r.splits,
      'name': r.name,
      'flag': r.flag,
      'points': r.points,
      'savedAt': FieldValue.serverTimestamp(),
    };

Run fromCloud(Map<String, dynamic> j) {
  final flat = ((j['path'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList();
  return Run(
    start: DateTime.fromMillisecondsSinceEpoch(j['start'] as int),
    secs: j['secs'] as int,
    meters: (j['meters'] as num).toDouble(),
    path: [for (var i = 0; i + 1 < flat.length; i += 2) [flat[i], flat[i + 1]]],
    splits: ((j['splits'] as List?) ?? const []).map((e) => e as int).toList(),
    name: j['name'] as String?,
    flag: j['flag'] as String?,
  );
}

/// Web OAuth client (type 3) from google-services.json, used to mint the ID token.
const _webClientId = '427085259383-eijfpe028f5vfgsnplg6tihlgff58hs0.apps.googleusercontent.com';

final cloud = Cloud();

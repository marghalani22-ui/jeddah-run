import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/runs.dart';
import '../state/settings.dart';

/// Public card other runners see: name, @username and this week's numbers.
class Profile {
  Profile(this.uid, Map<String, dynamic> d)
      : name = (d['name'] as String?)?.trim().isNotEmpty == true ? d['name'] as String : 'عدّاء',
        code = d['code'] as String? ?? '',
        weekKm = (d['weekKm'] as num?)?.toDouble() ?? 0,
        totalKm = (d['totalKm'] as num?)?.toDouble() ?? 0,
        streak = (d['streak'] as num?)?.toInt() ?? 0;

  final String uid, name, code;
  final double weekKm, totalKm;
  final int streak;
}

enum FriendState { pendingIn, pendingOut, friends }

class Friendship {
  Friendship(this.id, Map<String, dynamic> d, String me)
      : other = (d['members'] as List).cast<String>().firstWhere((m) => m != me, orElse: () => me),
        state = d['status'] == 'accepted'
            ? FriendState.friends
            : (d['requester'] == me ? FriendState.pendingOut : FriendState.pendingIn);

  final String id, other;
  final FriendState state;
}

class ChatInfo {
  ChatInfo(this.id, Map<String, dynamic> d)
      : lastText = d['lastText'] as String? ?? '',
        lastFrom = d['lastFrom'] as String? ?? '',
        lastAt = (d['lastAt'] as Timestamp?)?.toDate();

  final String id, lastText, lastFrom;
  final DateTime? lastAt;
}

class Message {
  Message(this.id, Map<String, dynamic> d)
      : from = d['from'] as String? ?? '',
        text = d['text'] as String? ?? '',
        at = (d['at'] as Timestamp?)?.toDate() ?? DateTime.now();

  final String id, from, text;
  final DateTime at;
}

final _usernameRe = RegExp(r'^[a-z0-9_]{3,16}$');

String pairId(String a, String b) => (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

/// Friends, requests, chats and the public profile. Lives on Firestore:
///   profiles/{uid}, usernames/{name}, friendships/{pair}, chats/{pair}/messages/{id}
class Social extends ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get me => FirebaseAuth.instance.currentUser?.uid;

  Profile? mine;
  List<Friendship> friendships = [];
  Map<String, ChatInfo> chats = {};
  final Map<String, Profile> profiles = {};
  Map<String, int> _lastRead = {};
  Set<String> blocked = {};

  StreamSubscription? _subF, _subC, _subP;
  String? _bound;

  int get requestsIn => friendships.where((f) => f.state == FriendState.pendingIn).length;

  int get unread => chats.values.where((c) => _isUnread(c)).length;

  bool _isUnread(ChatInfo c) =>
      c.lastAt != null && c.lastFrom != me && c.lastAt!.millisecondsSinceEpoch > (_lastRead[c.id] ?? 0);

  bool isUnread(String chatId) => chats[chatId] != null && _isUnread(chats[chatId]!);

  /// Start or stop listening when the signed-in user changes.
  Future<void> bind() async {
    final uid = me;
    if (uid == _bound) return;
    await _subF?.cancel();
    await _subC?.cancel();
    await _subP?.cancel();
    _bound = uid;
    friendships = [];
    chats = {};
    mine = null;
    if (uid == null) {
      notifyListeners();
      return;
    }
    try {
      final u = await _db.collection('users').doc(uid).get();
      blocked = ((u.data()?['blocked'] as List?) ?? const []).cast<String>().toSet();
    } catch (_) {}
    try {
      final sp = await SharedPreferences.getInstance();
      _lastRead = (jsonDecode(sp.getString('lastRead') ?? '{}') as Map).map((k, v) => MapEntry(k as String, v as int));
    } catch (_) {}
    _subP = _db.collection('profiles').doc(uid).snapshots().listen((s) {
      mine = s.exists ? Profile(uid, s.data()!) : null;
      notifyListeners();
    }, onError: (e) => debugPrint('profile: $e'));
    _subF = _db.collection('friendships').where('members', arrayContains: uid).snapshots().listen((s) {
      final all = s.docs.map((d) => Friendship(d.id, d.data(), uid)).toList();
      // Anything from a blocked runner is dropped silently.
      for (final f in all.where((f) => blocked.contains(f.other))) {
        remove(f).catchError((_) {});
      }
      friendships = all.where((f) => !blocked.contains(f.other)).toList();
      for (final f in friendships) {
        _loadProfile(f.other);
      }
      notifyListeners();
    }, onError: (e) => debugPrint('friendships: $e'));
    _subC = _db.collection('chats').where('members', arrayContains: uid).snapshots().listen((s) {
      chats = {for (final d in s.docs) d.id: ChatInfo(d.id, d.data())};
      notifyListeners();
    }, onError: (e) => debugPrint('chats: $e'));
    await publishStats();
  }

  Future<void> _loadProfile(String uid, {bool force = false}) async {
    if (profiles.containsKey(uid) && !force) return;
    try {
      final s = await _db.collection('profiles').doc(uid).get();
      if (s.exists) {
        profiles[uid] = Profile(uid, s.data()!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('load profile: $e');
    }
  }

  Future<void> refreshProfiles() async {
    await Future.wait(friendships.map((f) => _loadProfile(f.other, force: true)));
  }

  /// Writes this week's numbers to the public profile so friends can compare.
  Future<void> publishStats() async {
    final uid = me;
    if (uid == null) return;
    try {
      await _db.collection('profiles').doc(uid).set({
        'name': settings.name,
        'weekKm': double.parse(runStore.weekKm.toStringAsFixed(2)),
        'totalKm': double.parse(runStore.totalKm.toStringAsFixed(1)),
        'streak': runStore.streak,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('publish stats: $e');
    }
  }

  /// Claims a unique @username. Returns an error message or null.
  Future<String?> setUsername(String raw) async {
    final uid = me;
    if (uid == null) return 'سجّل دخول أول';
    final name = raw.trim().toLowerCase().replaceAll('@', '');
    if (!_usernameRe.hasMatch(name)) return 'من 3 إلى 16 حرف إنجليزي أو رقم أو _';
    final old = mine?.code ?? '';
    if (name == old) return null;
    try {
      await _db.runTransaction((tx) async {
        final ref = _db.collection('usernames').doc(name);
        final taken = await tx.get(ref);
        if (taken.exists && taken.data()?['uid'] != uid) throw 'taken';
        tx.set(ref, {'uid': uid});
        if (old.isNotEmpty) tx.delete(_db.collection('usernames').doc(old));
        tx.set(_db.collection('profiles').doc(uid), {'code': name, 'name': settings.name}, SetOptions(merge: true));
      });
      return null;
    } catch (e) {
      return e == 'taken' ? 'الاسم محجوز، جرّب غيره' : 'تعذّر الحفظ، جرّب مرة ثانية';
    }
  }

  /// Sends a friend request to @username (or accepts theirs if they already asked).
  Future<String> addFriend(String raw) async {
    final uid = me;
    if (uid == null) return 'سجّل دخول أول';
    final name = raw.trim().toLowerCase().replaceAll('@', '');
    if (name.isEmpty) return 'اكتب اسم المستخدم';
    try {
      final u = await _db.collection('usernames').doc(name).get();
      final other = u.data()?['uid'] as String?;
      if (other == null) return 'ما لقينا أحد بهذا الاسم';
      if (other == uid) return 'هذا اسمك أنت';
      if (blocked.contains(other)) return 'هذا الشخص محظور عندك، فك الحظر أول من ملفي';
      final id = pairId(uid, other);
      Friendship? existing;
      for (final f in friendships) {
        if (f.id == id) existing = f;
      }
      if (existing != null) {
        switch (existing.state) {
          case FriendState.friends:
            return 'أنتم أصحاب من قبل';
          case FriendState.pendingOut:
            return 'أرسلت له طلب، ننتظر موافقته';
          case FriendState.pendingIn:
            await accept(existing);
            return 'صرتوا أصحاب';
        }
      }
      await _db.collection('friendships').doc(id).set({
        'members': [uid, other],
        'requester': uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _loadProfile(other);
      return 'انرسل الطلب';
    } catch (e) {
      debugPrint('add friend: $e');
      return 'تعذّر الإرسال، جرّب مرة ثانية';
    }
  }

  Future<void> accept(Friendship f) =>
      _db.collection('friendships').doc(f.id).update({'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()});

  Future<void> remove(Friendship f) => _db.collection('friendships').doc(f.id).delete();

  /// Block: ends the friendship (so the chat closes) and remembers the uid on our private doc.
  Future<void> block(String other) async {
    final uid = me;
    if (uid == null) return;
    blocked.add(other);
    friendships.removeWhere((f) => f.other == other);
    notifyListeners();
    await _db.collection('users').doc(uid).set({'blocked': FieldValue.arrayUnion([other])}, SetOptions(merge: true));
    await _db.collection('friendships').doc(pairId(uid, other)).delete().catchError((_) {});
  }

  Future<void> unblock(String other) async {
    final uid = me;
    if (uid == null) return;
    blocked.remove(other);
    notifyListeners();
    await _db.collection('users').doc(uid).set({'blocked': FieldValue.arrayRemove([other])}, SetOptions(merge: true));
  }

  /// Report goes to reports/ for review; only the reporter can write it, nobody can read it from the app.
  Future<bool> report(String other, String reason, {String? note}) async {
    final uid = me;
    if (uid == null) return false;
    try {
      await _db.collection('reports').add({
        'from': uid,
        'about': other,
        'chat': pairId(uid, other),
        'reason': reason,
        'note': (note ?? '').trim(),
        'at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('report: $e');
      return false;
    }
  }

  Stream<List<Message>> messages(String chatId) => _db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('at', descending: true)
      .limit(150)
      .snapshots()
      .map((s) => s.docs.map((d) => Message(d.id, d.data())).toList());

  Future<void> send(String otherUid, String text) async {
    final uid = me;
    final t = text.trim();
    if (uid == null || t.isEmpty) return;
    final id = pairId(uid, otherUid);
    final chat = _db.collection('chats').doc(id);
    final batch = _db.batch();
    batch.set(chat.collection('messages').doc(), {'from': uid, 'text': t, 'at': FieldValue.serverTimestamp()});
    batch.set(chat, {
      'members': [uid, otherUid],
      'lastText': t.length > 80 ? '${t.substring(0, 80)}…' : t,
      'lastFrom': uid,
      'lastAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> markRead(String chatId) async {
    _lastRead[chatId] = DateTime.now().millisecondsSinceEpoch;
    // May be called from build/dispose; notify after the current frame work.
    Future.microtask(notifyListeners);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('lastRead', jsonEncode(_lastRead));
    } catch (_) {}
  }
}

final social = Social();

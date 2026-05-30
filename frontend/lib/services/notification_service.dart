import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String fromUid;
  final String fromUsername;
  final String oglasId;
  final String title;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromUsername,
    required this.oglasId,
    required this.title,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      type: d['type'] as String? ?? '',
      fromUid: d['fromUid'] as String? ?? '',
      fromUsername: d['fromUsername'] as String? ?? '',
      oglasId: d['oglasId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> notificationsStream(String uid) {
    return _inbox(uid).limit(50).snapshots().map((snap) {
      final list = snap.docs.map((d) => AppNotification.fromDoc(d)).toList();
      list.sort((a, b) {
        final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Stream<int> unreadCountStream(String uid) {
    return _inbox(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead(String uid, String notificationId) async {
    await _inbox(uid).doc(notificationId).update({'read': true});
  }

  /// Fan-out in-app obvestila vsem sledilcem z vklopljenimi obvestili.
  Future<void> notifyFollowersOfNewListing({
    required String authorUid,
    required String authorUsername,
    required String oglasId,
    required String title,
  }) async {
    final followersSnap = await _db
        .collection('users')
        .doc(authorUid)
        .collection('followers')
        .where('notifyOnNewListing', isEqualTo: true)
        .get();

    if (followersSnap.docs.isEmpty) return;

    var batch = _db.batch();
    var ops = 0;

    for (final followerDoc in followersSnap.docs) {
      final followerUid = followerDoc.id;
      if (followerUid == authorUid) continue;

      final notifRef = _inbox(followerUid).doc();
      batch.set(notifRef, {
        'type': 'new_listing',
        'fromUid': authorUid,
        'fromUsername': authorUsername,
        'oglasId': oglasId,
        'title': title,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ops++;
      if (ops >= 450) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }
}

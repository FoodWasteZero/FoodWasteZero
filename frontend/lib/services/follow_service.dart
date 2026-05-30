import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _followingRef(
      String followerUid, String targetUid) {
    return _db
        .collection('users')
        .doc(followerUid)
        .collection('following')
        .doc(targetUid);
  }

  DocumentReference<Map<String, dynamic>> _followersRef(
      String targetUid, String followerUid) {
    return _db
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(followerUid);
  }

  Stream<bool> isFollowingStream(String followerUid, String targetUid) {
    return _followingRef(followerUid, targetUid).snapshots().map((s) => s.exists);
  }

  Future<({bool following, bool notify})> getFollowState(
      String followerUid, String targetUid) async {
    final snap = await _followingRef(followerUid, targetUid).get();
    if (!snap.exists) return (following: false, notify: false);
    final data = snap.data();
    return (
      following: true,
      notify: data?['notifyOnNewListing'] as bool? ?? false,
    );
  }

  Future<void> follow({
    required String followerUid,
    required String targetUid,
    required String targetUsername,
    bool notifyOnNewListing = false,
  }) async {
    final payload = {
      'targetUid': targetUid,
      'targetUsername': targetUsername,
      'notifyOnNewListing': notifyOnNewListing,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.set(_followingRef(followerUid, targetUid), payload);
    batch.set(_followersRef(targetUid, followerUid), {
      'followerUid': followerUid,
      'notifyOnNewListing': notifyOnNewListing,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> unfollow({
    required String followerUid,
    required String targetUid,
  }) async {
    final batch = _db.batch();
    batch.delete(_followingRef(followerUid, targetUid));
    batch.delete(_followersRef(targetUid, followerUid));
    await batch.commit();
  }

  Future<void> setNotifyOnNewListing({
    required String followerUid,
    required String targetUid,
    required bool notify,
  }) async {
    final batch = _db.batch();
    batch.update(_followingRef(followerUid, targetUid), {
      'notifyOnNewListing': notify,
    });
    batch.update(_followersRef(targetUid, followerUid), {
      'notifyOnNewListing': notify,
    });
    await batch.commit();
  }
}

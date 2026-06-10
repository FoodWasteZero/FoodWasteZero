import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../common/auth_helpers.dart';
import '../common/theme.dart';
import '../screens/auth_screen.dart';
import '../services/follow_service.dart';
import '../services/ui_state_service.dart';
import '../widgets/user_listings_view.dart';

class PublisherProfileScreen extends StatefulWidget {
  final String targetUid;

  const PublisherProfileScreen({super.key, required this.targetUid});

  @override
  State<PublisherProfileScreen> createState() => _PublisherProfileScreenState();
}

class _PublisherProfileScreenState extends State<PublisherProfileScreen> {
  bool _following = false;
  bool _notify = false;
  bool _followLoading = false;

  String _displayName(Map<String, dynamic>? data) {
    if (data == null) return 'Uporabnik';
    if (data['userType'] == 'davatelj') {
      return data['organizationName'] as String? ??
          data['ime'] as String? ??
          'Organizacija';
    }
    final first = data['firstName'] as String? ?? '';
    final sur = data['surname'] as String? ?? '';
    final combined = '$first $sur'.trim();
    if (combined.isNotEmpty) return combined;
    return data['ime'] as String? ?? 'Uporabnik';
  }

  Future<void> _loadFollowState() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || isAppGuest(me)) return;
    final state = await FollowService.instance
        .getFollowState(me.uid, widget.targetUid);
    if (mounted) {
      setState(() {
        _following = state.following;
        _notify = state.notify;
      });
    }
  }

  Future<void> _toggleFollow(String targetUsername) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || isAppGuest(me)) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    if (me.uid == widget.targetUid) return;

    setState(() => _followLoading = true);
    try {
      if (_following) {
        await FollowService.instance.unfollow(
          followerUid: me.uid,
          targetUid: widget.targetUid,
        );
        if (mounted) setState(() {
          _following = false;
          _notify = false;
        });
      } else {
        await FollowService.instance.follow(
          followerUid: me.uid,
          targetUid: widget.targetUid,
          targetUsername: targetUsername,
          notifyOnNewListing: false,
        );
        if (mounted) setState(() => _following = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _setNotify(bool value) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || isAppGuest(me)) return;
    setState(() => _followLoading = true);
    try {
      await FollowService.instance.setNotifyOnNewListing(
        followerUid: me.uid,
        targetUid: widget.targetUid,
        notify: value,
      );
      if (mounted) setState(() => _notify = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final me = FirebaseAuth.instance.currentUser;
    final isOwner = me != null && me.uid == widget.targetUid;
    final isGuest = isAppGuest(me);

    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: c.textDark),
                  ),
                  Expanded(
                    child: Text('Profil',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: c.textDark)),
                  ),
                ],
              ),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.targetUid)
                  .snapshots(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting &&
                    !userSnap.hasData) {
                  return Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(color: kGreenMid)),
                  );
                }

                final data =
                    userSnap.data?.data() as Map<String, dynamic>?;
                final isDavatelj = data?['userType'] == 'davatelj';
                final name = _displayName(data);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: kGreenPale,
                              shape: BoxShape.circle,
                              border: Border.all(color: kGreenMid, width: 2),
                            ),
                            child: Icon(
                              isDavatelj
                                  ? Icons.store_rounded
                                  : Icons.person_rounded,
                              color: kGreenMid,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(name,
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: c.textDark)),
                                    ),
                                    if (isDavatelj) ...[
                                      SizedBox(width: 6),
                                      Icon(Icons.verified_rounded,
                                          color: Color(0xFF029624), size: 22),
                                    ],
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  isDavatelj ? 'Organizacija' : 'Uporabnik',
                                  style: TextStyle(
                                      fontSize: 13, color: c.textLight),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!isOwner && !isGuest) ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _following
                                  ? OutlinedButton.icon(
                                      onPressed: _followLoading ? null : () => _toggleFollow(name),
                                      icon: const Icon(Icons.person_remove_outlined, size: 16),
                                      label: const Text('Ne sledi več',
                                          style: TextStyle(fontWeight: FontWeight.w700)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: kTextMid,
                                        side: BorderSide(color: kBorder),
                                        shape: RoundedRectangleBorder(borderRadius: kRadius8),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _followLoading ? null : () => _toggleFollow(name),
                                      icon: _followLoading
                                          ? const SizedBox(width: 14, height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                                      label: const Text('Sledi',
                                          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kGreenDark,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: kRadius8),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shadowColor: kGreenMid.withOpacity(0.4),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        if (_following) ...[
                          SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: kRadius12,
                              border: Border.all(
                                  color: const Color(0x0F000000)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Obveščaj me ob novih oglasih',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: c.textDark),
                                  ),
                                ),
                                Switch(
                                  value: _notify,
                                  onChanged: _followLoading
                                      ? null
                                      : _setNotify,
                                  activeColor: kGreenMid,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
            Divider(height: 1),
            Expanded(
              child: UserListingsView(
                profileUid: widget.targetUid,
                isOwner: false,
                onAuthorTap: () {
                  final me = FirebaseAuth.instance.currentUser;
                  if (me != null && me.uid == widget.targetUid) {
                    UIStateService.instance.requestMineTab();
                    Navigator.popUntil(context, (r) => r.isFirst);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
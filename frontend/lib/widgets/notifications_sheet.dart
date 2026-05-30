import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../cards/food_detail_sheet.dart';
import '../common/auth_helpers.dart';
import '../common/oglas_mapper.dart';
import '../common/theme.dart';
import '../screens/auth_screen.dart';
import '../services/notification_service.dart';

void showNotificationsSheet(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;
  if (isAppGuest(user)) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    return;
  }
  if (user == null) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: kRadiusFull,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Obvestila',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: kTextDark)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: NotificationService.instance
                    .notificationsStream(user.uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: kGreenMid));
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 48, color: kTextLight),
                            SizedBox(height: 12),
                            Text('Ni novih obvestil', style: kHeading2),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final n = items[i];
                      return _NotificationTile(
                        notification: n,
                        uid: user.uid,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String uid;

  const _NotificationTile({
    required this.notification,
    required this.uid,
  });

  Future<void> _open(BuildContext context) async {
    await NotificationService.instance.markRead(uid, notification.id);
    if (!context.mounted) return;

    final doc = await FirebaseFirestore.instance
        .collection('oglasi')
        .doc(notification.oglasId)
        .get();
    if (!context.mounted) return;
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oglas ni več na voljo.')),
      );
      return;
    }
    final oglas = docToFoodOglas(doc);
    Navigator.pop(context);
    await FoodDetailSheet.show(context, oglas);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: unread ? kGreenPale.withOpacity(0.5) : kCard,
        borderRadius: kRadius12,
        child: InkWell(
          borderRadius: kRadius12,
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kGreenMid.withOpacity(0.12),
                    borderRadius: kRadius8,
                  ),
                  child: const Icon(Icons.campaign_rounded,
                      color: kGreenMid, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.fromUsername.isNotEmpty
                            ? notification.fromUsername
                            : 'Nov oglas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.title,
                        style: const TextStyle(fontSize: 13, color: kTextMid),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: kGreenMid,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zvonec z opcijskim badge za neprebrana obvestila.
class NotificationBellButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool lightStyle;

  const NotificationBellButton({
    super.key,
    required this.onTap,
    this.lightStyle = true,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final showBadge = uid != null && !isAppGuest(user);

    Widget bell = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: lightStyle
            ? Colors.white.withOpacity(0.18)
            : kGreenPale,
        borderRadius: kRadius12,
        border: Border.all(
          color: lightStyle
              ? Colors.white.withOpacity(0.25)
              : kGreenMid.withOpacity(0.2),
        ),
      ),
      child: Icon(
        Icons.notifications_outlined,
        color: lightStyle ? Colors.white : kGreenMid,
        size: 20,
      ),
    );

    if (!showBadge) {
      return GestureDetector(onTap: onTap, child: bell);
    }

    return GestureDetector(
      onTap: onTap,
      child: StreamBuilder<int>(
        stream: NotificationService.instance.unreadCountStream(uid!),
        builder: (context, snap) {
          final count = snap.data ?? 0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              bell,
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../common/oglas_mapper.dart';
import '../common/theme.dart';
import '../models/models.dart';
import '../cards/food_card.dart';
import '../cards/food_detail_sheet.dart';

/// Seznam oglasov za profilUid – lastniški (Moje objave) ali javni način.
class UserListingsView extends StatelessWidget {
  final String profileUid;
  final bool isOwner;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onAdd;
  final void Function(DocumentSnapshot doc)? onEdit;
  final void Function(String docId)? onDelete;

  const UserListingsView({
    super.key,
    required this.profileUid,
    this.isOwner = false,
    this.onAuthorTap,
    this.onAdd,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('oglasi')
          .where('uid', isEqualTo: profileUid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Center(
              child: CircularProgressIndicator(color: kGreenMid));
        }
        if (snap.hasError) {
          return _StreamError(message: snap.error.toString(), isOwner: isOwner);
        }

        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        sortOglasDocsNewestFirst(docs);

        if (docs.isEmpty) {
          return _EmptyState(isOwner: isOwner, onAdd: onAdd);
        }

        if (isOwner) {
          return _OwnerList(
            docs: docs,
            onAdd: onAdd,
            onEdit: onEdit,
            onDelete: onDelete,
            onAuthorTap: onAuthorTap,
          );
        }

        return _PublicList(
          docs: docs,
          onAuthorTap: onAuthorTap,
        );
      },
    );
  }
}

class _OwnerList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final VoidCallback? onAdd;
  final void Function(DocumentSnapshot doc)? onEdit;
  final void Function(String docId)? onDelete;
  final VoidCallback? onAuthorTap;

  const _OwnerList({
    required this.docs,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final moji = docs.map(docToFoodOglas).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF2E7D32),
          title: Text('Moje objave',
              style: TextStyle(
                  color: c.card, fontWeight: FontWeight.w800)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: Icon(Icons.add, size: 16),
                label: Text('Dodaj objavo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.card,
                  foregroundColor: kGreenMid,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  shape: RoundedRectangleBorder(borderRadius: kRadius8),
                ),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _OwnerOglasCard(
                oglas: moji[i],
                doc: docs[i],
                onTap: () => FoodDetailSheet.show(context, moji[i]),
                onEdit: onEdit != null ? () => onEdit!(docs[i]) : null,
                onDelete:
                    onDelete != null ? () => onDelete!(docs[i].id) : null,
                onAuthorTap: onAuthorTap,
              ),
              childCount: moji.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final VoidCallback? onAuthorTap;

  const _PublicList({required this.docs, this.onAuthorTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final aktivni = <QueryDocumentSnapshot>[];
    final arhiv = <QueryDocumentSnapshot>[];

    for (final d in docs) {
      final s = (d.data() as Map)['status'] as String? ?? '';
      if (s == 'prevzeto') {
        arhiv.add(d);
      } else {
        aktivni.add(d);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (aktivni.isNotEmpty) ...[
          _SectionTitle('Aktivni oglasi'),
          SizedBox(height: 8),
          ...aktivni.map((doc) {
            final oglas = docToFoodOglas(doc);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FoodCard(
                oglas: oglas,
                onTap: () => FoodDetailSheet.show(context, oglas),
                onAuthorTap: onAuthorTap,
              ),
            );
          }),
        ],
        if (arhiv.isNotEmpty) ...[
          SizedBox(height: 16),
          _SectionTitle('Arhiv'),
          SizedBox(height: 8),
          ...arhiv.map((doc) {
            final oglas = docToFoodOglas(doc);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FoodCard(
                oglas: oglas,
                onTap: () => FoodDetailSheet.show(context, oglas),
                onAuthorTap: onAuthorTap,
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              color: kGreenMid, borderRadius: kRadiusFull),
        ),
        SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: c.textDark)),
      ],
    );
  }
}

class _OwnerOglasCard extends StatelessWidget {
  final FoodOglas oglas;
  final QueryDocumentSnapshot doc;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAuthorTap;

  const _OwnerOglasCard({
    required this.oglas,
    required this.doc,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          FoodCard(oglas: oglas, onTap: onTap, onAuthorTap: onAuthorTap),
          if (onEdit != null || onDelete != null)
            Positioned(
              top: 8,
              right: 8,
              child: Row(children: [
                if (onEdit != null)
                  _ActionChip(
                    icon: Icons.edit_rounded,
                    color: kGreenMid,
                    onTap: onEdit!,
                    tooltip: 'Uredi',
                  ),
                if (onEdit != null && onDelete != null)
                  SizedBox(width: 6),
                if (onDelete != null)
                  _ActionChip(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    onTap: onDelete!,
                    tooltip: 'Izbriši',
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionChip({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: kRadius8,
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _StreamError extends StatelessWidget {
  final String message;
  final bool isOwner;
  const _StreamError({required this.message, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (isOwner) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Color(0xFF2E7D32),
            title: Text('Moje objave',
                style: TextStyle(
                    color: c.card, fontWeight: FontWeight.w800)),
          ),
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: kOrange),
                    SizedBox(height: 12),
                    Text('Napaka pri nalaganju', style: kHeading2),
                    SizedBox(height: 8),
                    Text(message, style: kBody, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: kOrange),
            SizedBox(height: 12),
            Text('Napaka pri nalaganju', style: kHeading2),
            SizedBox(height: 8),
            Text(message, style: kBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isOwner;
  final VoidCallback? onAdd;
  const _EmptyState({required this.isOwner, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (!isOwner) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: kGreenMid),
              SizedBox(height: 12),
              Text('Ni objavljenih oglasov', style: kHeading2),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Color(0xFF2E7D32),
          title: Text('Moje objave',
              style: TextStyle(
                  color: c.card, fontWeight: FontWeight.w800)),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                        color: kGreenPale, shape: BoxShape.circle),
                    child: Icon(Icons.inbox_outlined,
                        size: 48, color: kGreenMid),
                  ),
                  SizedBox(height: 18),
                  Text('Moje objave', style: kHeading2),
                  SizedBox(height: 8),
                  Text('Še niste objavili nobenega oglasa.',
                      style: kBody, textAlign: TextAlign.center),
                  SizedBox(height: 28),
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                        ),
                        borderRadius: kRadiusFull,
                        boxShadow: [
                          BoxShadow(
                              color: kGreenMid.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              color: c.card, size: 20),
                          SizedBox(width: 8),
                          Text('Dodaj prvi oglas',
                              style: TextStyle(
                                  color: c.card,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

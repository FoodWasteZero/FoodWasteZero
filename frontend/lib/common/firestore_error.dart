import 'package:cloud_firestore/cloud_firestore.dart';

/// Človeku berljivo sporočilo za napake Firestore (npr. permission-denied).
String firestoreErrorMessage(Object? error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Dostop zavrnjen (permission-denied).\n\n'
            '1) Firestore → Rules → Publish (allow read: if true za oglasi)\n'
            '2) Authentication → Anonymous → Enable\n'
            '3) Project ID na zaslonu = Project ID v Console\n'
            '4) Izbriši staro vrstico match /{document=**} če jo imaš';
      case 'failed-precondition':
        return 'Manjkajoč indeks (${error.message ?? error.code}).\n'
            'Odpri povezavo iz konzole ali posodobi aplikacijo.';
      case 'unavailable':
        return 'Firestore trenutno ni dosegljiv. Preveri internetno povezavo.';
      default:
        return '${error.code}\n${error.message ?? ''}';
    }
  }
  return error.toString();
}

int createdAtMillis(Map<String, dynamic> data) {
  final ts = data['createdAt'];
  if (ts is Timestamp) return ts.millisecondsSinceEpoch;
  return 0;
}

void sortDocsByCreatedAt(List<QueryDocumentSnapshot> docs) {
  docs.sort((a, b) {
    final ma = createdAtMillis(a.data() as Map<String, dynamic>);
    final mb = createdAtMillis(b.data() as Map<String, dynamic>);
    return mb.compareTo(ma);
  });
}

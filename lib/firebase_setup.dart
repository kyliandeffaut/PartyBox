import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// `flutter run --dart-define=USE_EMULATORS=true` pour viser les émulateurs locaux
/// (Auth 9099, Firestore 8080) au lieu de la prod.
const bool useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// Hôte des émulateurs. Par défaut : `localhost` sur le web, `10.0.2.2` sur l'émulateur Android.
/// Sur un vrai téléphone : `--dart-define=EMULATOR_HOST=<IP du PC>`.
const String _emulatorHostOverride = String.fromEnvironment('EMULATOR_HOST');

/// Durée de vie d'un lobby avant nettoyage.
const Duration lobbyLifetime = Duration(hours: 24);

/// À appeler juste après `Firebase.initializeApp`, avant tout accès à Firestore.
Future<void> configureEmulators() async {
  if (!useEmulators) return;
  final host = _emulatorHostOverride.isNotEmpty
      ? _emulatorHostOverride
      : (kIsWeb ? 'localhost' : '10.0.2.2');
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  debugPrint('Firebase : émulateurs sur $host (Auth 9099, Firestore 8080)');
}

Future<String>? _signInFuture;

/// Garantit un utilisateur connecté (Auth anonyme) et renvoie son uid.
/// Sur le web, attend d'abord la restauration de la session existante.
Future<String> ensureSignedIn() {
  return _signInFuture ??= _signIn().whenComplete(() => _signInFuture = null);
}

Future<String> _signIn() async {
  final auth = FirebaseAuth.instance;
  final existing = auth.currentUser ?? await auth.authStateChanges().first;
  if (existing != null) return existing.uid;
  final cred = await auth.signInAnonymously();
  return cred.user!.uid;
}

/// uid de l'utilisateur connecté, ou null s'il ne l'est pas encore.
String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

/// Clé du document `lobbyNames/{clé}` : nom sans espaces autour, en minuscules, encodé
/// (un id de document ne peut pas contenir de `/`).
String lobbyNameKey(String lobbyName) =>
    Uri.encodeComponent(lobbyName.trim().toLowerCase());

/// Date d'expiration d'un lobby créé maintenant.
Timestamp newLobbyExpireAt() =>
    Timestamp.fromDate(DateTime.now().add(lobbyLifetime));

/// Supprime tous les messages d'un lobby, par lots (limite de 500 écritures par batch).
Future<void> deleteLobbyMessages(DocumentReference lobbyRef) async {
  while (true) {
    final snap = await lobbyRef.collection('messages').limit(400).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final m in snap.docs) {
      batch.delete(m.reference);
    }
    await batch.commit();
    if (snap.docs.length < 400) return;
  }
}

/// Supprime un lobby, ses messages et son entrée `lobbyNames` (si elle pointe encore dessus).
/// Utilisé par le dernier joueur qui part et par le nettoyage des lobbys expirés.
Future<void> deleteLobbyCompletely(
  DocumentReference lobbyRef,
  Map<String, dynamic> data,
) async {
  await deleteLobbyMessages(lobbyRef);
  final batch = FirebaseFirestore.instance.batch();
  final nameKey = data['nameKey'];
  if (nameKey is String && nameKey.isNotEmpty) {
    final nameRef = FirebaseFirestore.instance
        .collection('lobbyNames')
        .doc(nameKey);
    final nameDoc = await nameRef.get();
    if (nameDoc.exists && nameDoc.data()?['lobbyId'] == lobbyRef.id) {
      batch.delete(nameRef);
    }
  }
  batch.delete(lobbyRef);
  await batch.commit();
}

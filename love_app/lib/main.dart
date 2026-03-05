import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'features/couple_game/state/couple_game_controller.dart';
import 'features/couple_game/ui/screens/home_game_screen.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';

const bool kUseFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);
const String kFirebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

bool _envBool(String key, {bool defaultValue = false}) {
  final raw = dotenv.env[key]?.trim().toLowerCase();
  if (raw == null || raw.isEmpty) return defaultValue;
  return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseInitError;
  var useFirebaseEmulators = kUseFirebaseEmulators;
  var firebaseEmulatorHost = kFirebaseEmulatorHost;

  try {
    await dotenv.load(fileName: '.env');
    useFirebaseEmulators = useFirebaseEmulators || _envBool('USE_FIREBASE_EMULATORS');
    final hostFromEnv = dotenv.env['FIREBASE_EMULATOR_HOST']?.trim();
    if (hostFromEnv != null && hostFromEnv.isNotEmpty) {
      firebaseEmulatorHost = hostFromEnv;
    }
  } catch (e) {
    debugPrint('dotenv load failed: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (useFirebaseEmulators) {
      debugPrint(
        'Firebase emulators ENABLED -> host=$firebaseEmulatorHost',
      );
      FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(
        firebaseEmulatorHost,
        8080,
      );
      FirebaseStorage.instance.useStorageEmulator(firebaseEmulatorHost, 9199);
    } else {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.deviceCheck,
        );
      } catch (e) {
        debugPrint('Firebase App Check activation failed: $e');
      }
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.initialize();
  } catch (e) {
    firebaseInitError = e.toString();
    debugPrint('Firebase initialization error: $e');
  }

  runApp(MyApp(firebaseInitError: firebaseInitError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.firebaseInitError});

  final String? firebaseInitError;

  @override
  Widget build(BuildContext context) {
    final firebaseReady = Firebase.apps.isNotEmpty;

    return MaterialApp(
      title: 'Love Messages',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: firebaseReady
          ? const AuthGate()
          : FirebaseRequiredScreen(errorMessage: firebaseInitError),
    );
  }
}

class FirebaseRequiredScreen extends StatelessWidget {
  const FirebaseRequiredScreen({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.pink, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Love Messages',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Firebase n\'est pas initialisé. Vérifie firebase_options.dart et la config Android.',
                textAlign: TextAlign.center,
              ),
              if ((errorMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Détail: $errorMessage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          unawaited(PushNotificationService.instance.clearUserTokenBinding());
          return const AuthScreen();
        }

        unawaited(PushNotificationService.instance.registerUserToken(user.uid));
        return HomeRouter(user: user);
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isRegisterMode = false;
  bool _loading = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String _normalizeUsername(String value) {
    final lower = value.trim().toLowerCase().replaceAll(' ', '_');
    return lower.replaceAll(RegExp(r'[^a-z0-9_.-]'), '');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _normalizeUsername(_usernameController.text);
    final password = _passwordController.text.trim();
    final email = '$username@loveapp.local';

    setState(() {
      _loading = true;
    });

    try {
      if (_isRegisterMode) {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        try {
          await _firestore.runTransaction((tx) async {
            final usernameRef = _firestore
                .collection('usernames')
                .doc(username);
            final usernameSnap = await tx.get(usernameRef);
            if (usernameSnap.exists) {
              throw Exception('Ce pseudo est déjà utilisé.');
            }

            tx.set(usernameRef, {
              'uid': cred.user!.uid,
              'createdAt': FieldValue.serverTimestamp(),
            });

            tx.set(_firestore.collection('users').doc(cred.user!.uid), {
              'username': username,
              'usernameLower': username,
              'createdAt': FieldValue.serverTimestamp(),
              'lastSeenAt': FieldValue.serverTimestamp(),
              'activePairId': null,
            });
          });
        } catch (e) {
          await cred.user?.delete();
          rethrow;
        }
      } else {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        await _firestore.collection('users').doc(cred.user!.uid).set({
          'username': username,
          'usernameLower': username,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'activePairId': null,
        }, SetOptions(merge: true));

        await _firestore.collection('usernames').doc(username).set({
          'uid': cred.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth erreur: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.favorite, size: 80, color: Colors.pink),
                  const SizedBox(height: 20),
                  const Text(
                    'Love Messages',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRegisterMode ? 'Créer un compte' : 'Se connecter',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom d\'utilisateur',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      final normalized = _normalizeUsername(value ?? '');
                      if (normalized.length < 3) {
                        return 'Pseudo minimum 3 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 6) {
                        return 'Mot de passe minimum 6 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isRegisterMode ? 'Créer le compte' : 'Connexion',
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _isRegisterMode = !_isRegisterMode;
                            });
                          },
                    child: Text(
                      _isRegisterMode
                          ? 'Déjà un compte ? Se connecter'
                          : 'Pas de compte ? S\'inscrire',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return const Scaffold(
            body: Center(child: Text('Profil introuvable. Reconnecte-toi.')),
          );
        }

        final myUsername = (data['username'] as String?) ?? 'unknown';
        final activePairId = data['activePairId'] as String?;

        if (activePairId == null || activePairId.isEmpty) {
          return PairingScreen(myUid: user.uid, myUsername: myUsername);
        }

        return MainMenuScreen(
          myUid: user.uid,
          myUsername: myUsername,
          pairId: activePairId,
        );
      },
    );
  }
}

class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.myUid,
    required this.myUsername,
  });

  final String myUid;
  final String myUsername;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];
  bool _searching = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> _searchUsers() async {
    final prefix = _searchController.text.trim().toLowerCase();
    if (prefix.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() {
      _searching = true;
    });

    final query = await _firestore
        .collection('users')
        .orderBy('usernameLower')
        .startAt([prefix])
        .endAt(['$prefix\uf8ff'])
        .limit(10)
        .get();

    if (!mounted) return;

    setState(() {
      _results = query.docs.where((doc) => doc.id != widget.myUid).toList();
      _searching = false;
    });
  }

  Future<void> _sendRequest(Map<String, dynamic> targetUser) async {
    final targetUid = targetUser['uid'] as String;
    final targetUsername = targetUser['username'] as String? ?? 'unknown';

    final requestId = '${widget.myUid}_$targetUid';
    await _firestore.collection('pairRequests').doc(requestId).set({
      'fromUid': widget.myUid,
      'fromUsername': widget.myUsername,
      'toUid': targetUid,
      'toUsername': targetUsername,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Demande envoyée à @$targetUsername')),
    );
  }

  Future<void> _acceptRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final fromUid = data['fromUid'] as String;
    final fromUsername = data['fromUsername'] as String? ?? 'unknown';

    final sorted = [fromUid, widget.myUid]..sort();
    final pairId = '${sorted[0]}__${sorted[1]}';

    await _firestore.runTransaction((tx) async {
      final meRef = _firestore.collection('users').doc(widget.myUid);
      final otherRef = _firestore.collection('users').doc(fromUid);
      final pairRef = _firestore.collection('pairs').doc(pairId);

      final meSnap = await tx.get(meRef);
      final otherSnap = await tx.get(otherRef);

      final mePair = meSnap.data()?['activePairId'] as String?;
      final otherPair = otherSnap.data()?['activePairId'] as String?;

      if ((mePair ?? '').isNotEmpty || (otherPair ?? '').isNotEmpty) {
        throw Exception('Un utilisateur est déjà en couple actif.');
      }

      tx.set(pairRef, {
        'members': [widget.myUid, fromUid],
        'memberUsernames': {
          widget.myUid: widget.myUsername,
          fromUid: fromUsername,
        },
        'compatibilityScore': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.update(meRef, {'activePairId': pairId});
      tx.update(otherRef, {'activePairId': pairId});
      tx.update(doc.reference, {
        'status': 'accepted',
        'pairId': pairId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _declineRequest(
    DocumentReference<Map<String, dynamic>> requestRef,
  ) {
    return requestRef.update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final incomingStream = _firestore
        .collection('pairRequests')
        .where('toUid', isEqualTo: widget.myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.myUsername}'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Trouver ta moitié par pseudo 💕',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un pseudo',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchUsers(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _searchUsers,
                  child: const Text('Chercher'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_searching) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: [
                  ..._results.map((doc) {
                    final data = doc.data();
                    final username = data['username'] as String? ?? 'unknown';

                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text('@$username'),
                      trailing: ElevatedButton(
                        onPressed: () =>
                            _sendRequest({'uid': doc.id, 'username': username}),
                        child: const Text('Inviter'),
                      ),
                    );
                  }),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Demandes reçues',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: incomingStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: LinearProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const ListTile(
                          title: Text('Aucune demande reçue.'),
                        );
                      }

                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          final fromUsername =
                              data['fromUsername'] as String? ?? 'unknown';

                          return ListTile(
                            title: Text('@$fromUsername veut se connecter'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _acceptRequest(doc),
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _declineRequest(doc.reference),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    super.key,
    required this.myUid,
    required this.myUsername,
    required this.pairId,
  });

  final String myUid;
  final String myUsername;
  final String pairId;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  CoupleGameController? _coupleGameController;
  String? _controllerPairId;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> _leavePair() async {
    await _firestore.collection('users').doc(widget.myUid).update({
      'activePairId': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final pairStream = _firestore
        .collection('pairs')
        .doc(widget.pairId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: pairStream,
      builder: (context, pairSnapshot) {
        if (pairSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pairData = pairSnapshot.data?.data();
        if (pairData == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Pair introuvable'),
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: ElevatedButton(
                onPressed: _leavePair,
                child: const Text('Revenir à la recherche'),
              ),
            ),
          );
        }

        final members = (pairData['members'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .toList();
        final partnerUid = members.firstWhere(
          (uid) => uid != widget.myUid,
          orElse: () => '',
        );

        final usernames =
            (pairData['memberUsernames'] as Map<String, dynamic>? ?? {}).map(
              (key, value) => MapEntry(key, '$value'),
            );
        final partnerName = usernames[partnerUid] ?? 'partner';

        if (_controllerPairId != widget.pairId && partnerUid.isNotEmpty) {
          _coupleGameController?.dispose();
          _coupleGameController = CoupleGameController.online(
            firestore: _firestore,
            pairId: widget.pairId,
            currentUid: widget.myUid,
            partnerUid: partnerUid,
          )..load();
          _controllerPairId = widget.pairId;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.myUsername} & $partnerName'),
            centerTitle: true,
            backgroundColor: Colors.pink,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chatter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          myUid: widget.myUid,
                          myUsername: widget.myUsername,
                          pairId: widget.pairId,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Text('💑', style: TextStyle(fontSize: 20)),
                  label: const Text('Nous deux'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _coupleGameController == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HomeGameScreen(
                                controller: _coupleGameController!,
                                yourName: widget.myUsername,
                                partnerName: partnerName,
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _coupleGameController?.dispose();
    super.dispose();
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.myUid,
    required this.myUsername,
    required this.pairId,
  });

  final String myUid;
  final String myUsername;
  final String pairId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  Future<void> _sendMessage(String text) async {
    final sanitized = text.trim();
    if (sanitized.isEmpty) return;

    try {
      await _firestore
          .collection('pairs')
          .doc(widget.pairId)
          .collection('messages')
          .add({
            'senderUid': widget.myUid,
            'senderUsername': widget.myUsername,
            'type': 'text',
            'text': sanitized,
            'imageUrl': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur envoi message: $e')));
    }
  }

  Future<void> _sendImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload image en cours...')));

      final msgRef = _firestore
          .collection('pairs')
          .doc(widget.pairId)
          .collection('messages')
          .doc();

      final storageRef = _storage.ref().child(
        'pairs/${widget.pairId}/chat/${msgRef.id}.jpg',
      );

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      await msgRef.set({
        'senderUid': widget.myUid,
        'senderUsername': widget.myUsername,
        'type': 'image',
        'text': '',
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image envoyée')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur envoi image: $e')));
    }
  }

  Future<void> _leavePair() async {
    await _firestore.collection('users').doc(widget.myUid).update({
      'activePairId': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final pairStream = _firestore
        .collection('pairs')
        .doc(widget.pairId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: pairStream,
      builder: (context, pairSnapshot) {
        if (pairSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pairData = pairSnapshot.data?.data();
        if (pairData == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Pair introuvable'),
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: ElevatedButton(
                onPressed: _leavePair,
                child: const Text('Revenir à la recherche'),
              ),
            ),
          );
        }

        final members = (pairData['members'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .toList();
        final partnerUid = members.firstWhere(
          (uid) => uid != widget.myUid,
          orElse: () => '',
        );

        final usernames =
            (pairData['memberUsernames'] as Map<String, dynamic>? ?? {}).map(
              (key, value) => MapEntry(key, '$value'),
            );
        final partnerName = usernames[partnerUid] ?? 'partner';

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.myUsername} & $partnerName'),
            centerTitle: true,
            backgroundColor: Colors.pink,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore
                      .collection('pairs')
                      .doc(widget.pairId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}'));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Aucun message pour le moment.'),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final message = Message(
                          senderUid: data['senderUid'] as String? ?? '',
                          senderName: data['senderUsername'] as String? ?? '',
                          type: data['type'] as String? ?? 'text',
                          content: data['text'] as String? ?? '',
                          imageUrl: data['imageUrl'] as String?,
                          timestamp: data['createdAt'] is Timestamp
                              ? (data['createdAt'] as Timestamp).toDate()
                              : DateTime.now(),
                        );

                        return MessageBubble(
                          message: message,
                          isYou: message.senderUid == widget.myUid,
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      color: Colors.pink,
                      onPressed: _sendImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.pink),
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.pink,
                      onPressed: () => _sendMessage(_messageController.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isYou});

  final Message message;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isYou
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.senderName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
            ),
            if (message.type == 'image' &&
                message.imageUrl != null &&
                message.imageUrl!.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 260),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
              ),
            if (message.type == 'text' && message.content.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isYou ? Colors.pink : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isYou ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Message {
  const Message({
    required this.senderUid,
    required this.senderName,
    required this.type,
    required this.content,
    required this.timestamp,
    this.imageUrl,
  });

  final String senderUid;
  final String senderName;
  final String type;
  final String content;
  final DateTime timestamp;
  final String? imageUrl;
}

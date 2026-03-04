import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Love Messages',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => ChatScreen(
              yourName: args['yourName']!,
              partnerName: args['partnerName']!,
            ),
          );
        }
        return null;
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TextEditingController _yourNameController = TextEditingController();
  final TextEditingController _partnerNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkNames();
  }

  Future<void> _checkNames() async {
    final prefs = await SharedPreferences.getInstance();
    final yourName = prefs.getString('yourName');
    final partnerName = prefs.getString('partnerName');

    if (yourName != null && partnerName != null && mounted) {
      Navigator.of(context).pushReplacementNamed('/chat',
          arguments: {'yourName': yourName, 'partnerName': partnerName});
    }
  }

  Future<void> _saveNames() async {
    if (_yourNameController.text.isEmpty ||
        _partnerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both names')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yourName', _yourNameController.text);
    await prefs.setString('partnerName', _partnerNameController.text);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/chat', arguments: {
        'yourName': _yourNameController.text,
        'partnerName': _partnerNameController.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, size: 80, color: Colors.pink),
                const SizedBox(height: 24),
                const Text(
                  'Love Messages',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _yourNameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _partnerNameController,
                  decoration: InputDecoration(
                    labelText: "Your Partner's Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.favorite),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saveNames,
                  icon: const Icon(Icons.check),
                  label: const Text('Start Chatting'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _yourNameController.dispose();
    _partnerNameController.dispose();
    super.dispose();
  }
}

class ChatScreen extends StatefulWidget {
  final String yourName;
  final String partnerName;

  const ChatScreen({
    super.key,
    required this.yourName,
    required this.partnerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  late FirebaseFirestore _firestore;
  late FirebaseStorage _storage;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _storage = FirebaseStorage.instance;
    _initializeConversation();
  }

  void _initializeConversation() {
    // Create a unique conversation ID based on names (sorted to ensure consistency)
    final names = [widget.yourName, widget.partnerName];
    names.sort();
    _conversationId = names.join('_').toLowerCase();
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _conversationId == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add({
        'sender': widget.yourName,
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': null,
      });
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _sendImage() async {
    final XFile? image =
        await _imagePicker.pickImage(source: ImageSource.gallery);

    if (image == null || _conversationId == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image...')),
      );

      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final ref = _storage
          .ref()
          .child('conversations')
          .child(_conversationId!)
          .child(fileName);

      await ref.putFile(File(image.path));
      final imageUrl = await ref.getDownloadURL();

      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add({
        'sender': widget.yourName,
        'content': '',
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.yourName} & ${widget.partnerName}'),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.pink,
        elevation: 0,
      ),
      body: _conversationId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('conversations')
                        .doc(_conversationId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final messages = snapshot.data?.docs ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text('Send your first message!'),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final messageData = messages[index].data()
                              as Map<String, dynamic>;
                          final message = Message(
                            sender: messageData['sender'] ?? '',
                            content: messageData['content'] ?? '',
                            timestamp: messageData['timestamp'] != null
                                ? (messageData['timestamp'] as Timestamp)
                                    .toDate()
                                : DateTime.now(),
                            imageUrl: messageData['imageUrl'],
                          );
                          final isYou = message.sender == widget.yourName;

                          return MessageBubble(
                            message: message,
                            isYou: isYou,
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) {
                            _sendMessage(text);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.pink,
                        onPressed: () {
                          _sendMessage(_messageController.text);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isYou;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isYou,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment:
              isYou ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
              ),
            if (message.content.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  final String sender;
  final String content;
  final DateTime timestamp;
  final String? imageUrl;

  Message({
    required this.sender,
    required this.content,
    required this.timestamp,
    this.imageUrl,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Love Messages',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => ChatScreen(
              yourName: args['yourName']!,
              partnerName: args['partnerName']!,
            ),
          );
        }
        return null;
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TextEditingController _yourNameController = TextEditingController();
  final TextEditingController _partnerNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkNames();
  }

  Future<void> _checkNames() async {
    final prefs = await SharedPreferences.getInstance();
    final yourName = prefs.getString('yourName');
    final partnerName = prefs.getString('partnerName');

    if (yourName != null && partnerName != null && mounted) {
      Navigator.of(context).pushReplacementNamed('/chat',
          arguments: {'yourName': yourName, 'partnerName': partnerName});
    }
  }

  Future<void> _saveNames() async {
    if (_yourNameController.text.isEmpty ||
        _partnerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both names')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yourName', _yourNameController.text);
    await prefs.setString('partnerName', _partnerNameController.text);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/chat', arguments: {
        'yourName': _yourNameController.text,
        'partnerName': _partnerNameController.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, size: 80, color: Colors.pink),
                const SizedBox(height: 24),
                const Text(
                  'Love Messages',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _yourNameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _partnerNameController,
                  decoration: InputDecoration(
                    labelText: "Your Partner's Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.favorite),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saveNames,
                  icon: const Icon(Icons.check),
                  label: const Text('Start Chatting'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _yourNameController.dispose();
    _partnerNameController.dispose();
    super.dispose();
  }
}

class ChatScreen extends StatefulWidget {
  final String yourName;
  final String partnerName;

  const ChatScreen({
    super.key,
    required this.yourName,
    required this.partnerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  List<Message> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getStringList('messages') ?? [];

    setState(() {
      _messages = messagesJson
          .map((json) => Message.fromJson(jsonDecode(json)))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson =
        _messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('messages', messagesJson);
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    final message = Message(
      sender: widget.yourName,
      content: text,
      timestamp: DateTime.now(),
      imageUrl: null,
    );

    setState(() {
      _messages.add(message);
    });

    await _saveMessages();
    _messageController.clear();
  }

  Future<void> _sendImage() async {
    final XFile? image =
        await _imagePicker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final File newImage = File('${appDir.path}/$fileName');
      await File(image.path).copy(newImage.path);

      final message = Message(
        sender: widget.yourName,
        content: '',
        timestamp: DateTime.now(),
        imageUrl: newImage.path,
      );

      setState(() {
        _messages.add(message);
      });

      await _saveMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.yourName} & ${widget.partnerName}'),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.pink,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text('Send your first message!'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                _messages[_messages.length - 1 - index];
                            final isYou = message.sender == widget.yourName;

                            return MessageBubble(
                              message: message,
                              isYou: isYou,
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) {
                            _sendMessage(text);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.pink,
                        onPressed: () {
                          _sendMessage(_messageController.text);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isYou;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isYou,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment:
              isYou ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(message.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (message.content.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  final String sender;
  final String content;
  final DateTime timestamp;
  final String? imageUrl;

  Message({
    required this.sender,
    required this.content,
    required this.timestamp,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      sender: json['sender'] as String,
      content: json['content'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

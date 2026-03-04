import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/couple_game_controller.dart';
import '../widgets/couple_card.dart';
import '../widgets/couple_game_scaffold.dart';
import 'reveal_screen.dart';

class AnswerScreen extends StatefulWidget {
  const AnswerScreen({
    super.key,
    required this.controller,
    required this.yourName,
    required this.partnerName,
  });

  final CoupleGameController controller;
  final String yourName;
  final String partnerName;

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends State<AnswerScreen> {
  final TextEditingController _answerController = TextEditingController();

  final List<String> _quickAnswers = [
    'Trop mignon 🥰',
    'Impossible de choisir 😅',
    'Toi évidemment 💘',
    'Surprise totale 🎉',
  ];

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    if (_answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écris une réponse pour continuer.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await widget.controller.submitMyAnswer(_answerController.text);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RevealScreen(
          controller: widget.controller,
          yourName: widget.yourName,
          partnerName: widget.partnerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CoupleGameScaffold(
      title: 'Ta réponse 💬',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoupleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.controller.todayQuestion.questionText,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _answerController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Écris ta réponse ici ✍️',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAnswers
                        .map(
                          (item) => ActionChip(
                            label: Text(item),
                            onPressed: () {
                              _answerController.text = item;
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: const Icon(Icons.send),
              label: const Text('Envoyer anonymement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }
}

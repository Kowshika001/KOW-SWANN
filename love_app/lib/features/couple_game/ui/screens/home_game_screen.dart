import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/couple_game_controller.dart';
import '../widgets/couple_card.dart';
import '../widgets/couple_game_scaffold.dart';
import 'answer_screen.dart';
import 'history_screen.dart';
import 'reveal_screen.dart';

class HomeGameScreen extends StatefulWidget {
  const HomeGameScreen({
    super.key,
    required this.controller,
    required this.yourName,
    required this.partnerName,
  });

  final CoupleGameController controller;
  final String yourName;
  final String partnerName;

  @override
  State<HomeGameScreen> createState() => _HomeGameScreenState();
}

class _HomeGameScreenState extends State<HomeGameScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.isLoading) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return CoupleGameScaffold(
          title: 'Nous Deux 💑',
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Historique',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistoryScreen(
                      controller: widget.controller,
                      yourName: widget.yourName,
                      partnerName: widget.partnerName,
                    ),
                  ),
                );
              },
            ),
          ],
          body: widget.controller.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CoupleCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Score compatibilité 💖',
                              style: GoogleFonts.nunito(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.controller.score} points',
                              style: GoogleFonts.pacifico(
                                fontSize: 30,
                                color: Colors.pink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      CoupleCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question du jour 💬',
                              style: GoogleFonts.nunito(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.controller.getCategoryLabel(
                                widget.controller.todayQuestion.category,
                              ),
                              style: GoogleFonts.nunito(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.controller.todayQuestion.questionText,
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      CoupleCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.controller.hasAnsweredToday
                                  ? 'Tu as déjà répondu aujourd\'hui ✅'
                                  : 'Prêt(e) à répondre ? ✍️',
                              style: GoogleFonts.nunito(fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (widget.controller.hasAnsweredToday) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => RevealScreen(
                                          controller: widget.controller,
                                          yourName: widget.yourName,
                                          partnerName: widget.partnerName,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AnswerScreen(
                                          controller: widget.controller,
                                          yourName: widget.yourName,
                                          partnerName: widget.partnerName,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(
                                  widget.controller.hasAnsweredToday
                                      ? Icons.auto_awesome
                                      : Icons.edit,
                                ),
                                label: Text(
                                  widget.controller.hasAnsweredToday
                                      ? 'Voir la révélation'
                                      : 'Répondre',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

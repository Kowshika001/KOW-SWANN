import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/couple_game_controller.dart';
import '../widgets/couple_card.dart';
import '../widgets/couple_game_scaffold.dart';

class RevealScreen extends StatefulWidget {
  const RevealScreen({
    super.key,
    required this.controller,
    required this.yourName,
    required this.partnerName,
  });

  final CoupleGameController controller;
  final String yourName;
  final String partnerName;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.controller.todayAnswer;

    return CoupleGameScaffold(
      title: 'Révélation 💖',
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 18,
              gravity: 0.2,
            ),
          ),
          if (answer == null)
            const Center(
              child: Text(
                'Aucune réponse pour aujourd\'hui.',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 42,
                    child: AnimatedTextKit(
                      repeatForever: true,
                      animatedTexts: [
                        TypewriterAnimatedText(
                          'Vous êtes trop chou 💑',
                          textStyle: GoogleFonts.pacifico(
                            color: Colors.white,
                            fontSize: 28,
                          ),
                          speed: const Duration(milliseconds: 85),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  CoupleCard(
                    child: Text(
                      widget.controller.todayQuestion.questionText,
                      style: GoogleFonts.nunito(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CoupleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.yourName} 💬',
                                  style: GoogleFonts.nunito(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  answer.myAnswer,
                                  style: GoogleFonts.nunito(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CoupleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.partnerName} 💬',
                                  style: GoogleFonts.nunito(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  answer.partnerAnswer,
                                  style: GoogleFonts.nunito(fontSize: 16),
                                ),
                                if (answer.partnerAnswer ==
                                    CoupleGameController
                                        .waitingPartnerText) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.controller.randomPromptForPartner(),
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  CoupleCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Compatibilité actuelle',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.controller.score} pts ✨',
                          style: GoogleFonts.pacifico(
                            fontSize: 24,
                            color: Colors.pink,
                          ),
                        ),
                      ],
                    ),
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
    _confettiController.dispose();
    super.dispose();
  }
}

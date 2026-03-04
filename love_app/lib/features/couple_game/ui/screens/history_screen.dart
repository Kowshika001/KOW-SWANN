import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../state/couple_game_controller.dart';
import '../widgets/couple_card.dart';
import '../widgets/couple_game_scaffold.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.controller,
    required this.yourName,
    required this.partnerName,
  });

  final CoupleGameController controller;
  final String yourName;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final history = controller.answers;

    return CoupleGameScaffold(
      title: 'Historique 💕',
      body: history.isEmpty
          ? Center(
              child: Text(
                'Aucun quiz joué pour le moment.',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final question = controller.findQuestionById(item.questionId);

                return CoupleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(item.date),
                        style: GoogleFonts.nunito(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        question?.questionText ?? 'Question inconnue',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$yourName: ${item.myAnswer}',
                        style: GoogleFonts.nunito(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$partnerName: ${item.partnerAnswer}',
                        style: GoogleFonts.nunito(fontSize: 15),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

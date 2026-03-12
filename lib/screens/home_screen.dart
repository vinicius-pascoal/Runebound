import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../game/phase_model.dart';
import '../game/score_service.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleController;
  final List<_StarParticle> _stars = [];
  Map<int, int> _bestScores = {};

  @override
  void initState() {
    super.initState();
    _generateStars();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _loadScores();
  }

  void _generateStars() {
    final rng = Random();
    for (int i = 0; i < 60; i++) {
      _stars.add(
        _StarParticle(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          radius: rng.nextDouble() * 2 + 0.5,
          opacity: rng.nextDouble() * 0.6 + 0.1,
          phase: rng.nextDouble() * 2 * pi,
        ),
      );
    }
  }

  Future<void> _loadScores() async {
    final scores = await ScoreService.getAllBestScores(kPhases.length);
    if (mounted) setState(() => _bestScores = scores);
  }

  void _openPhaseSelect() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PhaseSelectSheet(
        bestScores: _bestScores,
        onPhaseSelected: (phase) {
          Navigator.pop(context);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, animation, __) => GameScreen(phase: phase),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ).then((_) => _loadScores());
        },
      ),
    );
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [Color(0xFF1A1240), Color(0xFF0B0D1A), Color(0xFF05060D)],
          ),
        ),
        child: Stack(
          children: [
            // Estrelas animadas.
            AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                painter: _StarfieldPainter(
                  stars: _stars,
                  progress: _particleController.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            // Anel mágico central.
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C4DFF).withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Conteúdo principal.
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        Text(
                              '✦',
                              style: TextStyle(
                                fontSize: 72,
                                color: const Color(0xFF7C4DFF).withOpacity(0.9),
                                shadows: const [
                                  Shadow(
                                    color: Color(0xFF7C4DFF),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(0.92, 0.92),
                              end: const Offset(1.08, 1.08),
                              duration: 2200.ms,
                              curve: Curves.easeInOut,
                            ),
                        const SizedBox(height: 24),
                        const Text(
                              'RUNEBOUND',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: Colors.white,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 700.ms)
                            .slideY(begin: 0.2, end: 0),
                        const SizedBox(height: 12),
                        Text(
                          'Combine runas ancestrais e invoque\ncascatas arcanas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.6),
                            height: 1.5,
                          ),
                        ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
                        const Spacer(flex: 2),
                        FilledButton(
                              onPressed: _openPhaseSelect,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF7C4DFF),
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              child: const Text('SELECIONAR FASE'),
                            )
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 500.ms)
                            .slideY(begin: 0.3, end: 0),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => _openPhaseSelect(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text(
                            'Continuar Último Progresso',
                            style: TextStyle(fontSize: 14),
                          ),
                        ).animate().fadeIn(delay: 800.ms, duration: 500.ms),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Sheet de seleção de fase ───────────────────────────────────────
class _PhaseSelectSheet extends StatelessWidget {
  const _PhaseSelectSheet({
    required this.bestScores,
    required this.onPhaseSelected,
  });

  final Map<int, int> bestScores;
  final void Function(Phase) onPhaseSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1020),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecionar Fase',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                itemCount: kPhases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final phase = kPhases[i];
                  final best = bestScores[phase.id] ?? 0;
                  final completed = best >= phase.targetScore;
                  return _PhaseTile(
                        phase: phase,
                        bestScore: best,
                        completed: completed,
                        onTap: () => onPhaseSelected(phase),
                      )
                      .animate()
                      .fadeIn(delay: (i * 80).ms, duration: 350.ms)
                      .slideX(begin: 0.12, end: 0);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PhaseTile extends StatelessWidget {
  const _PhaseTile({
    required this.phase,
    required this.bestScore,
    required this.completed,
    required this.onTap,
  });

  final Phase phase;
  final int bestScore;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = phase.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.18), color.withOpacity(0.06)],
          ),
          border: Border.all(
            color: completed ? color.withOpacity(0.6) : color.withOpacity(0.22),
            width: completed ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.18),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Center(
                child: Text(
                  phase.icon,
                  style: TextStyle(
                    fontSize: 26,
                    color: color,
                    shadows: [Shadow(color: color, blurRadius: 12)],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Fase ${phase.id}  ·  ${phase.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (completed)
                        Icon(
                          Icons.check_circle_rounded,
                          color: color,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phase.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Tag(label: '${phase.moves} movimentos', color: color),
                      const SizedBox(width: 8),
                      _Tag(label: 'Meta: ${phase.targetScore}', color: color),
                      const Spacer(),
                      if (bestScore > 0)
                        Text(
                          'Recorde: $bestScore',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Fundo estrelado ────────────────────────────────────────────────────────
class _StarParticle {
  const _StarParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.phase,
  });

  final double x, y, radius, opacity, phase;
}

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter({required this.stars, required this.progress});

  final List<_StarParticle> stars;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      final twinkle = (sin(progress * 2 * pi + s.phase) + 1) / 2;
      paint.color = Colors.white.withOpacity(s.opacity * (0.4 + 0.6 * twinkle));
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.progress != progress;
}

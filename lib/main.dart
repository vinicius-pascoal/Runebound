import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const RuneboundApp());
}

class RuneboundApp extends StatelessWidget {
  const RuneboundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runebound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090B16),
      ),
      home: const RuneboundPage(),
    );
  }
}

class RuneboundPage extends StatefulWidget {
  const RuneboundPage({super.key});

  @override
  State<RuneboundPage> createState() => _RuneboundPageState();
}

class _RuneboundPageState extends State<RuneboundPage> {
  static const int rows = 8;
  static const int cols = 8;
  static const int runeTypes = 6;

  final Random _random = Random();

  late List<List<int>> _board;
  Point<int>? _selected;
  bool _isBusy = false;
  int _score = 0;
  int _bestCombo = 0;

  Set<String> _clearingCells = <String>{};

  final List<Color> _runeColors = const [
    Color(0xFF8B5CF6), // violeta
    Color(0xFF06B6D4), // ciano
    Color(0xFFF59E0B), // dourado
    Color(0xFF10B981), // esmeralda
    Color(0xFFEF4444), // rubi
    Color(0xFFEAB308), // luz
  ];

  final List<String> _runeSymbols = const ['✦', '☽', '✶', '⬡', '✷', '✹'];

  @override
  void initState() {
    super.initState();
    _board = _createBoard();
  }

  List<List<int>> _createBoard() {
    final board = List.generate(rows, (_) => List.filled(cols, 0));

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        board[row][col] = _randomRuneForPosition(board, row, col);
      }
    }

    return board;
  }

  int _randomRuneForPosition(List<List<int>> board, int row, int col) {
    final options = List<int>.generate(runeTypes, (index) => index)
      ..shuffle(_random);

    for (final value in options) {
      final createsHorizontalMatch =
          col >= 2 &&
          board[row][col - 1] == value &&
          board[row][col - 2] == value;

      final createsVerticalMatch =
          row >= 2 &&
          board[row - 1][col] == value &&
          board[row - 2][col] == value;

      if (!createsHorizontalMatch && !createsVerticalMatch) {
        return value;
      }
    }

    return _random.nextInt(runeTypes);
  }

  void _restartGame() {
    setState(() {
      _board = _createBoard();
      _selected = null;
      _isBusy = false;
      _score = 0;
      _bestCombo = 0;
      _clearingCells = <String>{};
    });
  }

  String _cellKey(int row, int col) => '$row:$col';

  bool _isAdjacent(Point<int> a, Point<int> b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs() == 1;
  }

  void _swap(Point<int> a, Point<int> b) {
    final temp = _board[a.x][a.y];
    _board[a.x][a.y] = _board[b.x][b.y];
    _board[b.x][b.y] = temp;
  }

  Set<Point<int>> _findMatches() {
    final matches = <Point<int>>{};

    // Horizontal
    for (int row = 0; row < rows; row++) {
      int streak = 1;

      for (int col = 1; col <= cols; col++) {
        final sameAsPrevious =
            col < cols &&
            _board[row][col] != -1 &&
            _board[row][col] == _board[row][col - 1];

        if (sameAsPrevious) {
          streak++;
        } else {
          if (_board[row][col - 1] != -1 && streak >= 3) {
            for (int i = 0; i < streak; i++) {
              matches.add(Point(row, col - 1 - i));
            }
          }
          streak = 1;
        }
      }
    }

    // Vertical
    for (int col = 0; col < cols; col++) {
      int streak = 1;

      for (int row = 1; row <= rows; row++) {
        final sameAsPrevious =
            row < rows &&
            _board[row][col] != -1 &&
            _board[row][col] == _board[row - 1][col];

        if (sameAsPrevious) {
          streak++;
        } else {
          if (_board[row - 1][col] != -1 && streak >= 3) {
            for (int i = 0; i < streak; i++) {
              matches.add(Point(row - 1 - i, col));
            }
          }
          streak = 1;
        }
      }
    }

    return matches;
  }

  void _collapseBoard() {
    for (int col = 0; col < cols; col++) {
      final survivors = <int>[];

      for (int row = rows - 1; row >= 0; row--) {
        if (_board[row][col] != -1) {
          survivors.add(_board[row][col]);
        }
      }

      int writeRow = rows - 1;

      for (final value in survivors) {
        _board[writeRow][col] = value;
        writeRow--;
      }

      while (writeRow >= 0) {
        _board[writeRow][col] = _random.nextInt(runeTypes);
        writeRow--;
      }
    }
  }

  Future<void> _resolveBoard() async {
    int chain = 0;

    while (true) {
      final matches = _findMatches();
      if (matches.isEmpty) {
        break;
      }

      chain++;
      if (chain > _bestCombo) {
        _bestCombo = chain;
      }

      if (!mounted) return;
      setState(() {
        _clearingCells = matches.map((p) => _cellKey(p.x, p.y)).toSet();
        _score += matches.length * 20 * chain;
      });

      await Future.delayed(const Duration(milliseconds: 220));

      for (final point in matches) {
        _board[point.x][point.y] = -1;
      }

      _collapseBoard();

      if (!mounted) return;
      setState(() {
        _clearingCells = <String>{};
      });

      await Future.delayed(const Duration(milliseconds: 180));
    }
  }

  Future<void> _attemptSwap(Point<int> a, Point<int> b) async {
    setState(() {
      _isBusy = true;
      _selected = null;
      _swap(a, b);
    });

    await Future.delayed(const Duration(milliseconds: 140));

    final hasMatch = _findMatches().isNotEmpty;

    if (!hasMatch) {
      if (!mounted) return;
      setState(() {
        _swap(a, b);
      });

      await Future.delayed(const Duration(milliseconds: 140));

      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
      return;
    }

    await _resolveBoard();

    if (!mounted) return;
    setState(() {
      _isBusy = false;
    });
  }

  Future<void> _onTileTap(int row, int col) async {
    if (_isBusy) return;

    final tapped = Point(row, col);

    if (_selected == null) {
      setState(() {
        _selected = tapped;
      });
      return;
    }

    if (_selected == tapped) {
      setState(() {
        _selected = null;
      });
      return;
    }

    if (!_isAdjacent(_selected!, tapped)) {
      setState(() {
        _selected = tapped;
      });
      return;
    }

    await _attemptSwap(_selected!, tapped);
  }

  Color _tileBaseColor(int rune) => _runeColors[rune];

  String _tileSymbol(int rune) => _runeSymbols[rune];

  Widget _buildTile(int row, int col) {
    final value = _board[row][col];
    final isSelected = _selected == Point(row, col);
    final isClearing = _clearingCells.contains(_cellKey(row, col));
    final color = _tileBaseColor(value);

    return GestureDetector(
      onTap: () => _onTileTap(row, col),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: isClearing
            ? 0.84
            : isSelected
            ? 1.05
            : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isSelected ? 20 : 16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(isClearing ? 0.45 : 0.82),
                color.withOpacity(isClearing ? 0.18 : 0.46),
              ],
            ),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.95)
                  : Colors.white.withOpacity(0.10),
              width: isSelected ? 2.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isSelected ? 0.38 : 0.18),
                blurRadius: isClearing ? 22 : (isSelected ? 16 : 8),
                spreadRadius: isClearing ? 1 : 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isSelected ? 20 : 16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  _tileSymbol(value),
                  style: TextStyle(
                    fontSize: isSelected ? 30 : 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: color.withOpacity(0.85), blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comboLabel = _bestCombo <= 1 ? '-' : 'x$_bestCombo';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.35,
            colors: [Color(0xFF1A1532), Color(0xFF0B0D1A), Color(0xFF05060D)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Runebound',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Combine runas ancestrais e invoque cascatas arcanas.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _isBusy ? null : _restartGame,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Novo jogo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _buildStatCard(
                          title: 'Pontuacao',
                          value: '$_score',
                          icon: Icons.auto_awesome_rounded,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          title: 'Melhor combo',
                          value: comboLabel,
                          icon: Icons.bolt_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rows * cols,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemBuilder: (context, index) {
                            final row = index ~/ cols;
                            final col = index % cols;
                            return _buildTile(row, col);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isBusy
                          ? 'As energias arcanas estao se reorganizando...'
                          : 'Toque em uma runa e depois em uma adjacente para trocar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

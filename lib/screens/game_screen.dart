import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../game/phase_model.dart';
import '../game/score_service.dart';
import '../game/particle_burst.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de célula animada
// ─────────────────────────────────────────────────────────────────────────────
class _RuneCell {
  _RuneCell({required this.value, required this.key});
  int value;
  final UniqueKey key;
}

// ─────────────────────────────────────────────────────────────────────────────
// GameScreen
// ─────────────────────────────────────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  /// Construtor para modo campanha (fase normal)
  const GameScreen({super.key, required this.phase}) : infiniteMode = null;

  /// Construtor para modo infinito
  const GameScreen.infinite({
    super.key,
    required InfiniteMode this.infiniteMode,
  }) : phase = null;

  final Phase? phase;
  final InfiniteMode? infiniteMode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late Phase? _phase;
  late InfiniteMode? _infiniteMode;

  bool get _isInfinite => _infiniteMode != null;

  late List<List<_RuneCell>> _board;
  late List<List<double>> _fallOffset; // pixels de offset vertical por célula

  final Random _random = Random();

  Point<int>? _selected;
  bool _isBusy = false;
  int _score = 0;
  int _bestCombo = 0;
  int _movesLeft = 0; // campanha: movimentos restantes
  int _movesUsed = 0; // infinito: movimentos realizados
  int _bestScore = 0;
  bool _gameOver = false;
  bool _victory = false;
  bool _infiniteEnded = false; // infinito: jogador encerrou manualmente

  // Células em animação de clearance e seu tamanho de match (3, 4 ou 5+)
  Map<String, int> _clearingCells = {}; // key -> matchSize
  Set<String> _particleCells = {}; // células com partícula ativa

  int get _rows => _isInfinite ? _infiniteMode!.rows : _phase!.rows;
  int get _cols => _isInfinite ? _infiniteMode!.cols : _phase!.cols;
  int get _runeTypes =>
      _isInfinite ? _infiniteMode!.runeTypes : _phase!.runeTypes;
  Color get _accentColor =>
      _isInfinite ? _infiniteMode!.accentColor : _phase!.accentColor;

  final List<Color> _runeColors = const [
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFFEAB308),
  ];

  final List<String> _runeSymbols = const ['✦', '☽', '✶', '⬡', '✷', '✹'];

  // ── Animações de troca ────────────────────────────────────────────────────
  Point<int>? _swapA, _swapB;
  Animation<Offset>? _animA, _animB;
  AnimationController? _swapController;

  @override
  void initState() {
    super.initState();
    _phase = widget.phase;
    _infiniteMode = widget.infiniteMode;
    _movesLeft = _isInfinite ? 0 : _phase!.moves;
    _initBoard();
    _loadBestScore();
  }

  Future<void> _loadBestScore() async {
    final int best;
    if (_isInfinite) {
      best = await ScoreService.getInfiniteBestScore(_infiniteMode!.id);
    } else {
      best = await ScoreService.getBestScore(_phase!.id);
    }
    if (mounted) setState(() => _bestScore = best);
  }

  void _initBoard() {
    // Constrói em variável local para que _randomSafe possa referenciar
    // linhas já preenchidas sem depender de _board (que é `late`).
    final board = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => _RuneCell(value: 0, key: UniqueKey())),
    );
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        board[r][c] = _RuneCell(
          value: _randomSafe(board, r, c),
          key: UniqueKey(),
        );
      }
    }
    _board = board;
    _fallOffset = List.generate(_rows, (_) => List.filled(_cols, 0));
  }

  int _randomSafe(List<List<_RuneCell>> board, int row, int col) {
    final opts = List.generate(_runeTypes, (i) => i)..shuffle(_random);
    for (final v in opts) {
      bool hOk =
          !(col >= 2 &&
              board[row][col - 1].value == v &&
              board[row][col - 2].value == v);
      bool vOk =
          !(row >= 2 &&
              board[row - 1][col].value == v &&
              board[row - 2][col].value == v);
      if (hOk && vOk) return v;
    }
    return _random.nextInt(_runeTypes);
  }

  String _key(int r, int c) => '$r:$c';

  bool _isAdj(Point<int> a, Point<int> b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs() == 1;

  // ── Encontrar matches retornando também o tamanho de cada grupo ───────────
  Map<String, int> _findMatchesWithSize() {
    final result = <String, int>{};

    // Horizontal
    for (int r = 0; r < _rows; r++) {
      int start = 0;
      while (start < _cols) {
        int end = start;
        while (end + 1 < _cols &&
            _board[r][end + 1].value == _board[r][start].value &&
            _board[r][start].value != -1) {
          end++;
        }
        final len = end - start + 1;
        if (len >= 3) {
          for (int c = start; c <= end; c++) {
            final k = _key(r, c);
            result[k] = max(result[k] ?? 0, len);
          }
        }
        start = end + 1;
      }
    }

    // Vertical
    for (int c = 0; c < _cols; c++) {
      int start = 0;
      while (start < _rows) {
        int end = start;
        while (end + 1 < _rows &&
            _board[end + 1][c].value == _board[start][c].value &&
            _board[start][c].value != -1) {
          end++;
        }
        final len = end - start + 1;
        if (len >= 3) {
          for (int r = start; r <= end; r++) {
            final k = _key(r, c);
            result[k] = max(result[k] ?? 0, len);
          }
        }
        start = end + 1;
      }
    }

    return result;
  }

  // ── Colapso com animação de queda ─────────────────────────────────────────
  Future<void> _collapseWithFallAnimation() async {
    const double tileSize = 56;

    for (int col = 0; col < _cols; col++) {
      // Coleta sobreviventes de cima para baixo com a linha de origem.
      final survivors = <(int, _RuneCell)>[];
      int holes = 0;
      for (int row = 0; row < _rows; row++) {
        if (_board[row][col].value != -1) {
          survivors.add((row, _board[row][col]));
        } else {
          holes++;
        }
      }

      // Nenhum buraco: coluna intacta, nada a fazer.
      if (holes == 0) continue;

      // Novas runas preenchem as linhas do topo.
      final newCells = List.generate(
        holes,
        (_) => _RuneCell(value: _random.nextInt(_runeTypes), key: UniqueKey()),
      );
      for (int i = 0; i < holes; i++) {
        _fallOffset[i][col] = -(tileSize * holes);
        _board[i][col] = newCells[i];
      }

      // Sobreviventes descem para as linhas abaixo das novas.
      for (int i = 0; i < survivors.length; i++) {
        final newRow = holes + i;
        final (originalRow, cell) = survivors[i];
        final drop = newRow - originalRow; // > 0 quando a peça cai
        _fallOffset[newRow][col] = drop > 0 ? -(tileSize * drop) : 0;
        _board[newRow][col] = cell;
      }
    }

    setState(() {}); // exibe células na posição deslocada

    // Anima para posição zero
    await Future.delayed(const Duration(milliseconds: 40));

    setState(() {
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          _fallOffset[r][c] = 0;
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 320));
  }

  // ── Swap com animação deslizante ─────────────────────────────────────────
  Future<void> _doSwapAnimation(Point<int> a, Point<int> b) async {
    _swapController?.dispose();
    _swapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    final dx = (b.y - a.y).toDouble();
    final dy = (b.x - a.x).toDouble();

    _swapA = a;
    _swapB = b;
    _animA = Tween<Offset>(begin: Offset.zero, end: Offset(dx, dy)).animate(
      CurvedAnimation(parent: _swapController!, curve: Curves.easeInOut),
    );
    _animB = Tween<Offset>(begin: Offset.zero, end: Offset(-dx, -dy)).animate(
      CurvedAnimation(parent: _swapController!, curve: Curves.easeInOut),
    );

    _swapController!.addListener(() => setState(() {}));
    await _swapController!.forward();

    _swapA = null;
    _swapB = null;
    _animA = null;
    _animB = null;

    // Troca real na estrutura
    final tmp = _board[a.x][a.y];
    _board[a.x][a.y] = _board[b.x][b.y];
    _board[b.x][b.y] = tmp;
  }

  Future<void> _doReverseSwap(Point<int> a, Point<int> b) async {
    await _doSwapAnimation(b, a);
  }

  // ── Lógica principal ──────────────────────────────────────────────────────
  Future<void> _resolveBoard(int chain) async {
    var matches = _findMatchesWithSize();
    if (matches.isEmpty) return;

    int iterChain = chain;

    while (matches.isNotEmpty) {
      iterChain++;
      if (iterChain > _bestCombo) _bestCombo = iterChain;

      // Pontuação: 4=dobro, 5+=triplo
      int points = 0;
      for (final entry in matches.entries) {
        final sz = entry.value;
        final multiplier = sz >= 5 ? 3 : (sz == 4 ? 2 : 1);
        points += 20 * multiplier * iterChain;
      }
      _score += points;

      // Partículas nas células grandes
      final bigCells = <String>{};
      for (final entry in matches.entries) {
        if (entry.value >= 4) bigCells.add(entry.key);
      }

      setState(() {
        _clearingCells = Map.from(matches);
        _particleCells = bigCells;
      });

      await Future.delayed(const Duration(milliseconds: 260));

      // Remove
      for (final k in matches.keys) {
        final parts = k.split(':');
        final r = int.parse(parts[0]);
        final c = int.parse(parts[1]);
        _board[r][c].value = -1;
      }

      if (!mounted) return;
      setState(() {
        _clearingCells = {};
        _particleCells = {};
      });

      await _collapseWithFallAnimation();

      if (!mounted) return;
      matches = _findMatchesWithSize();
    }
  }

  Future<void> _attemptSwap(Point<int> a, Point<int> b) async {
    if (!_isInfinite && _movesLeft <= 0) return;
    setState(() {
      _isBusy = true;
      _selected = null;
    });

    await _doSwapAnimation(a, b);

    final matches = _findMatchesWithSize();

    if (matches.isEmpty) {
      await _doReverseSwap(a, b);
      setState(() {
        _board[a.x][a.y].value = _board[a.x][a.y].value; // sem mudança real
        _isBusy = false;
      });
      return;
    }

    if (!_isInfinite) setState(() => _movesLeft--);
    await _resolveBoard(0);

    if (!mounted) return;
    if (_isInfinite) {
      setState(() => _movesUsed++);
      await ScoreService.saveInfiniteBestScore(_infiniteMode!.id, _score);
      final newBest = await ScoreService.getInfiniteBestScore(
        _infiniteMode!.id,
      );
      if (!mounted) return;
      setState(() {
        _bestScore = newBest;
        _isBusy = false;
      });
    } else {
      await ScoreService.saveBestScore(_phase!.id, _score);
      final newBest = await ScoreService.getBestScore(_phase!.id);
      if (!mounted) return;
      setState(() {
        _bestScore = newBest;
        _isBusy = false;
      });
      _checkEndConditions();
    }
  }

  void _checkEndConditions() {
    if (_isInfinite) return;
    if (_score >= _phase!.targetScore) {
      setState(() => _victory = true);
    } else if (_movesLeft <= 0) {
      setState(() => _gameOver = true);
    }
  }

  /// Encerra o modo infinito manualmente (botão do jogador)
  Future<void> _endInfiniteGame() async {
    await ScoreService.saveInfiniteBestScore(_infiniteMode!.id, _score);
    final newBest = await ScoreService.getInfiniteBestScore(_infiniteMode!.id);
    if (!mounted) return;
    setState(() {
      _bestScore = newBest;
      _infiniteEnded = true;
    });
  }

  Future<void> _onTileTap(int row, int col) async {
    if (_isBusy || _gameOver || _victory || _infiniteEnded) return;

    final tapped = Point(row, col);

    if (_selected == null) {
      setState(() => _selected = tapped);
      return;
    }

    if (_selected == tapped) {
      setState(() => _selected = null);
      return;
    }

    if (!_isAdj(_selected!, tapped)) {
      setState(() => _selected = tapped);
      return;
    }

    await _attemptSwap(_selected!, tapped);
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _bestCombo = 0;
      _movesLeft = _isInfinite ? 0 : _phase!.moves;
      _movesUsed = 0;
      _gameOver = false;
      _victory = false;
      _infiniteEnded = false;
      _selected = null;
      _isBusy = false;
      _clearingCells = {};
      _particleCells = {};
      _initBoard();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _swapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 10),
                        _buildStats(),
                        const SizedBox(height: 10),
                        _buildProgressBar(),
                        const SizedBox(height: 10),
                        _buildBoard(),
                        const SizedBox(height: 10),
                        _buildStatusText(),
                      ],
                    ),
                  ),
                ),
              ),
              if (_gameOver || _victory) _buildOverlay(),
              if (_infiniteEnded) _buildInfiniteOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = _isInfinite ? _infiniteMode!.name : _phase!.name;
    final subtitle = _isInfinite ? 'Modo Infinito' : 'Fase ${_phase!.id}';
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white70,
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (_isInfinite)
          FilledButton.tonalIcon(
            onPressed: (_isBusy || _infiniteEnded) ? null : _endInfiniteGame,
            icon: const Icon(Icons.flag_rounded, size: 16),
            label: const Text('Encerrar'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          )
        else
          FilledButton.tonalIcon(
            onPressed: _isBusy ? null : _restartGame,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Novo'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
      ],
    );
  }

  Widget _buildStats() {
    final movesValue = _isInfinite ? '$_movesUsed' : '$_movesLeft';
    final movesLabel = _isInfinite ? 'Jogadas' : 'Movimentos';
    final movesColor = _isInfinite
        ? _accentColor
        : (_movesLeft <= 5 ? const Color(0xFFEF4444) : const Color(0xFF06B6D4));

    return Row(
      children: [
        _StatChip(
          icon: Icons.auto_awesome_rounded,
          label: 'Pontos',
          value: '$_score',
          color: const Color(0xFF8B5CF6),
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.bolt_rounded,
          label: 'Combo',
          value: _bestCombo <= 1 ? '-' : 'x$_bestCombo',
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: _isInfinite
              ? Icons.all_inclusive_rounded
              : Icons.touch_app_rounded,
          label: movesLabel,
          value: movesValue,
          color: movesColor,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.emoji_events_rounded,
          label: 'Recorde',
          value: '$_bestScore',
          color: const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    // No modo infinito não existe barra de progresso de meta
    if (_isInfinite) return const SizedBox.shrink();

    final progress = (_score / _phase!.targetScore).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Meta: ${_phase!.targetScore} pts',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: _phase!.accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            builder: (_, val, __) => LinearProgressIndicator(
              value: val,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_phase!.accentColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard() {
    final tileGap = 6.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30),
          ],
        ),
        child: AspectRatio(
          aspectRatio: _cols / _rows,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Cada célula tem padding EdgeInsets.all(tileGap/2) em todos os
              // lados, portanto o espaço total consumido pelos gaps é
              // tileGap * _cols (e não _cols-1). O cálculo abaixo é correto.
              final cellW = (constraints.maxWidth - tileGap * _cols) / _cols;
              final cellH = (constraints.maxHeight - tileGap * _rows) / _rows;
              final cellSize = min(cellW, cellH);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _rows,
                  (row) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _cols,
                      (col) => Padding(
                        padding: EdgeInsets.all(tileGap / 2),
                        child: SizedBox(
                          width: cellSize,
                          height: cellSize,
                          child: _buildTile(row, col, cellSize),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTile(int row, int col, double size) {
    final cell = _board[row][col];
    if (cell.value == -1) return const SizedBox();
    final key = _key(row, col);
    final isSelected = _selected == Point(row, col);
    final matchSize = _clearingCells[key] ?? 0;
    final isClearing = matchSize > 0;
    final hasParticle = _particleCells.contains(key);
    final color = _runeColors[cell.value % _runeColors.length];

    // Calcula offset de swap
    double swapDx = 0, swapDy = 0;
    if (_swapA != null && _animA != null) {
      if (_swapA == Point(row, col)) {
        swapDx = _animA!.value.dx * size;
        swapDy = _animA!.value.dy * size;
      } else if (_swapB == Point(row, col)) {
        swapDx = _animB!.value.dx * size;
        swapDy = _animB!.value.dy * size;
      }
    }

    final fallY = _fallOffset[row][col];

    Widget tile = GestureDetector(
      onTap: () => _onTileTap(row, col),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: isClearing ? 0.78 : (isSelected ? 1.08 : 1.0),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(isClearing ? 0.3 : 0.85),
                color.withOpacity(isClearing ? 0.1 : 0.45),
              ],
            ),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.95)
                  : (matchSize >= 4
                        ? Colors.white.withOpacity(0.7)
                        : Colors.white.withOpacity(0.10)),
              width: isSelected || matchSize >= 4 ? 2.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(
                  isSelected ? 0.45 : (matchSize >= 4 ? 0.55 : 0.18),
                ),
                blurRadius: matchSize >= 5
                    ? 30
                    : (matchSize == 4 ? 20 : (isSelected ? 16 : 8)),
                spreadRadius: matchSize >= 4 ? 2 : 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Brilho superior
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(matchSize >= 4 ? 0.28 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Símbolo
              Center(
                child: Text(
                  _runeSymbols[cell.value % _runeSymbols.length],
                  style: TextStyle(
                    fontSize: matchSize >= 4 ? size * 0.52 : size * 0.44,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: color.withOpacity(0.9),
                        blurRadius: matchSize >= 4 ? 20 : 10,
                      ),
                    ],
                  ),
                ),
              ),
              // Badge de match 4/5
              if (matchSize >= 4)
                Positioned(
                  top: 2,
                  right: 4,
                  child: Text(
                    matchSize >= 5 ? '✦✦' : '✦',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              // Partículas
              if (hasParticle)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ParticleBurst(
                      color: color,
                      count: matchSize >= 5 ? 18 : 10,
                      size: size,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Aplica animação de queda (TweenAnimationBuilder para smooth)
    if (fallY != 0) {
      tile = TweenAnimationBuilder<double>(
        key: ValueKey('fall_${cell.key}'),
        tween: Tween(begin: fallY, end: 0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (_, val, child) =>
            Transform.translate(offset: Offset(0, val), child: child),
        child: tile,
      );
    }

    // Aplica animação de swap
    if (swapDx != 0 || swapDy != 0) {
      tile = Transform.translate(offset: Offset(swapDx, swapDy), child: tile);
    }

    return tile;
  }

  Widget _buildStatusText() {
    String text;
    if (_infiniteEnded) {
      text = '✦ Jogo encerrado! Veja sua pontuação final.';
    } else if (_victory) {
      text = '✦ Vitória! Runas dominadas!';
    } else if (_gameOver) {
      text = '☽ Movimentos esgotados. Tente novamente!';
    } else if (_isBusy) {
      text = 'As energias arcanas se reorganizam...';
    } else {
      text = 'Toque em uma runa e depois em uma adjacente para trocar.';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
      ),
    );
  }

  Widget _buildOverlay() {
    final isVictory = _victory;
    final color = isVictory ? const Color(0xFF8B5CF6) : const Color(0xFFEF4444);
    final icon = isVictory ? '✦' : '☽';
    final title = isVictory ? 'Vitória!' : 'Falhou!';
    final subtitle = isVictory
        ? 'Você dominou as runas arcanas!'
        : 'Seus movimentos se esgotaram.';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1020),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.2), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                      icon,
                      style: TextStyle(
                        fontSize: 52,
                        color: color,
                        shadows: [Shadow(color: color, blurRadius: 20)],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                      duration: 1200.ms,
                    ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                _ScoreRow(label: 'Pontuação', value: '$_score', color: color),
                const SizedBox(height: 6),
                _ScoreRow(
                  label: 'Recorde',
                  value: '$_bestScore',
                  color: const Color(0xFF10B981),
                ),
                if (_bestCombo > 1) ...[
                  const SizedBox(height: 6),
                  _ScoreRow(
                    label: 'Melhor Combo',
                    value: 'x$_bestCombo',
                    color: const Color(0xFFF59E0B),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          foregroundColor: Colors.white70,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Menu'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _restartGame,
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Jogar Novamente'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfiniteOverlay() {
    final color = _infiniteMode!.accentColor;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1020),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.2), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                      _infiniteMode!.icon,
                      style: TextStyle(
                        fontSize: 52,
                        color: color,
                        shadows: [Shadow(color: color, blurRadius: 20)],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                      duration: 1200.ms,
                    ),
                const SizedBox(height: 16),
                const Text(
                  'Sessão Encerrada',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Você realizou $_movesUsed jogada${_movesUsed == 1 ? '' : 's'}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                _ScoreRow(label: 'Pontuação', value: '$_score', color: color),
                const SizedBox(height: 6),
                _ScoreRow(
                  label: 'Recorde',
                  value: '$_bestScore',
                  color: const Color(0xFF10B981),
                ),
                if (_bestCombo > 1) ...[
                  const SizedBox(height: 6),
                  _ScoreRow(
                    label: 'Melhor Combo',
                    value: 'x$_bestCombo',
                    color: const Color(0xFFF59E0B),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          foregroundColor: Colors.white70,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Menu'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _restartGame,
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Jogar Novamente'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

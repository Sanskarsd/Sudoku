import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/database/local_database.dart';
import '../../../../data/repositories/sudoku_repository.dart';
import '../../../sudoku/domain/engine/sudoku_generator.dart';
import '../../../sudoku/domain/engine/difficulty_evaluator.dart';
import '../../../sudoku/domain/models/sudoku_config.dart';
import '../../../sudoku/domain/models/sudoku_puzzle.dart';
import '../../../settings/game_settings.dart';

Map<String, Object?> _generate(Map<String, Object?> args) {
  final config = SudokuConfig.fromMode(SudokuMode.values[args['mode']! as int]);
  final puzzle = const SudokuGenerator(maxAttempts: 12).generatePuzzle(
      config, SudokuDifficulty.values[args['difficulty']! as int],
      randomSeed: args['seed']! as int);
  return {
    'mode': config.mode.index,
    'difficulty': puzzle.difficulty.index,
    'seed': puzzle.seed,
    'solution': puzzle.solution,
    'initial': puzzle.initialBoard,
    'score': puzzle.score,
    'technique': puzzle.hardestTechnique
  };
}

class GameLaunch {
  const GameLaunch(this.puzzle, this.dailyDate);
  final SudokuPuzzle puzzle;
  final String dailyDate;
}

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.puzzle, this.dailyDate})
      : _saved = null;
  const GameScreen.restore(this._saved, {super.key})
      : puzzle = null,
        dailyDate = null;
  final SudokuPuzzle? puzzle;
  final Map<String, Object?>? _saved;
  final String? dailyDate;
  static Future<SudokuPuzzle> createPuzzle(
    SudokuConfig c,
    SudokuDifficulty d, {
    int? seed,
  }) async {
    final data = await compute(_generate, {
      'mode': c.mode.index,
      'difficulty': d.index,
      'seed': seed ?? DateTime.now().microsecondsSinceEpoch & 0x7fffffff
    });
    return _decodePuzzle(data);
  }

  static SudokuPuzzle _decodePuzzle(Map<String, Object?> m) {
    final c = SudokuConfig.fromMode(SudokuMode.values[m['mode']! as int]);
    return SudokuPuzzle(
        config: c,
        solution: (m['solution'] as List)
            .map((r) => (r as List).cast<int>())
            .toList(),
        initialBoard:
            (m['initial'] as List).map((r) => (r as List).cast<int>()).toList(),
        difficulty: SudokuDifficulty.values[m['difficulty']! as int],
        seed: m['seed']! as int,
        score: m['score']! as int,
        hardestTechnique: m['technique']! as String);
  }

  static Future<Map<String, Object?>?> loadLatest() =>
      SudokuRepository(LocalDatabase.instance).latest();
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  late SudokuConfig config;
  late List<List<int>> initial, solution, board;
  late List<List<Set<int>>> notes;
  late SudokuDifficulty difficulty;
  int? selected;
  int mistakes = 0, hints = 0, elapsed = 0;
  bool noteMode = false,
      paused = false,
      finished = false,
      gameOver = false,
      lifecycleActive = true;
  int? gameId;
  String? dailyDate;
  int? puzzleSeed;
  final undoStack = <List<List<int>>>[];
  final redoStack = <List<List<int>>>[];
  final undoNotesStack = <List<List<Set<int>>>>[];
  final redoNotesStack = <List<List<Set<int>>>>[];
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _save(completed: finished);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    lifecycleActive = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _save();
    }
    if (mounted) setState(() {});
  }

  void _init() {
    final saved = widget._saved;
    if (saved != null) {
      config = SudokuConfig.fromMode(SudokuMode.values[saved['mode']! as int]);
      difficulty = SudokuDifficulty.values[saved['difficulty']! as int];
      initial = (saved['initial'] as List)
          .map((r) => (r as List).cast<int>())
          .toList();
      solution = (saved['solution'] as List)
          .map((r) => (r as List).cast<int>())
          .toList();
      board =
          (saved['board'] as List).map((r) => (r as List).cast<int>()).toList();
      elapsed = saved['elapsed']! as int;
      mistakes = saved['mistakes']! as int;
      hints = saved['hints']! as int;
      finished = saved['finished']! as bool;
      gameOver = saved['gameOver'] as bool? ?? false;
      gameId = saved['_gameId'] as int?;
      dailyDate = saved['dailyDate'] as String?;
      puzzleSeed = saved['seed'] as int?;
      notes = List.generate(
          config.size,
          (r) => List.generate(
              config.size,
              (c) => ((saved['notes'] as List?)?[r] as List?)?[c] is List
                  ? (((saved['notes'] as List)[r] as List)[c] as List)
                      .cast<int>()
                      .toSet()
                  : <int>{}));
    } else {
      final p = widget.puzzle!;
      config = p.config;
      difficulty = p.difficulty;
      initial = p.initialBoard.map(List<int>.of).toList();
      solution = p.solution.map(List<int>.of).toList();
      board = p.newCurrentBoard();
      dailyDate = widget.dailyDate;
      puzzleSeed = p.seed;
      notes = List.generate(
          config.size, (_) => List.generate(config.size, (_) => <int>{}));
    }
    if (!finished && ref.read(gameSettingsProvider).timerEnabled) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !paused && lifecycleActive && !finished) {
          setState(() => elapsed++);
        }
      });
    }
  }

  List<List<int>> _copy() => board.map(List<int>.of).toList();
  List<List<Set<int>>> _copyNotes() => notes
      .map((row) => row.map((cell) => Set<int>.of(cell)).toList())
      .toList();
  void _recordUndo() {
    undoStack.add(_copy());
    undoNotesStack.add(_copyNotes());
    redoStack.clear();
    redoNotesStack.clear();
  }

  Map<String, Object?> _serialize() => {
        'mode': config.mode.index,
        'difficulty': difficulty.index,
        'initial': initial,
        'solution': solution,
        'board': board,
        'notes': notes.map((r) => r.map((s) => s.toList()).toList()).toList(),
        'elapsed': elapsed,
        'mistakes': mistakes,
        'hints': hints,
        'finished': finished,
        'gameOver': gameOver,
        'dailyDate': dailyDate,
        'seed': puzzleSeed,
      };
  Future<void> _save({bool completed = false}) async {
    try {
      gameId = await SudokuRepository(LocalDatabase.instance)
          .save(_serialize(), id: gameId, completed: completed);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    _save(completed: finished);
    super.dispose();
  }

  void _enter(int value) {
    if (selected == null || paused || finished) return;
    final r = selected! ~/ config.size, c = selected! % config.size;
    if (initial[r][c] != 0) return;
    setState(() {
      if (noteMode) {
        if (board[r][c] != 0) return;
        _recordUndo();
        if (notes[r][c].contains(value)) {
          notes[r][c].remove(value);
        } else {
          notes[r][c].add(value);
        }
        return;
      }
      _recordUndo();
      board[r][c] = value;
      notes[r][c].clear();
      if (ref.read(gameSettingsProvider).automaticNotes) {
        for (var i = 0; i < config.size; i++) {
          notes[r][i].remove(value);
          notes[i][c].remove(value);
        }
        if (config.hasBoxes) {
          final rowStart = r ~/ config.boxRows * config.boxRows;
          final columnStart = c ~/ config.boxColumns * config.boxColumns;
          for (var row = rowStart; row < rowStart + config.boxRows; row++) {
            for (var column = columnStart;
                column < columnStart + config.boxColumns;
                column++) {
              notes[row][column].remove(value);
            }
          }
        }
      }
      if (value != solution[r][c]) mistakes++;
      final limit = ref.read(gameSettingsProvider).mistakeLimit;
      if (limit != null && mistakes >= limit) {
        gameOver = true;
        finished = true;
        timer?.cancel();
      } else if (_isComplete()) {
        finished = true;
        timer?.cancel();
      }
    });
    if (gameOver) {
      _save(completed: true);
      _showGameOver();
    } else if (finished) {
      _completeGame();
    }
  }

  Future<void> _completeGame() async {
    await _save();
    final id = gameId;
    if (id != null) {
      await SudokuRepository(LocalDatabase.instance).recordCompletion(
        gameId: id,
        seconds: elapsed,
        mode: config.mode.index,
        difficulty: difficulty.index,
        hints: hints,
        mistakes: mistakes,
        dailyDate: dailyDate,
        payload: _serialize(),
      );
    }
    await _showWin();
  }

  Future<void> _showGameOver() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game over'),
        content: Text('You reached the $mistakes mistake limit.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'))
        ],
      ),
    );
  }

  bool _isComplete() =>
      board.every((r) => r.every((v) => v != 0)) && _matches();
  bool _matches() {
    for (var r = 0; r < config.size; r++) {
      for (var c = 0; c < config.size; c++) {
        if (board[r][c] != solution[r][c]) return false;
      }
    }
    return true;
  }

  void _undo() {
    if (undoStack.isEmpty) return;
    setState(() {
      redoStack.add(_copy());
      redoNotesStack.add(_copyNotes());
      board = undoStack.removeLast();
      notes = undoNotesStack.removeLast();
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;
    setState(() {
      undoStack.add(_copy());
      undoNotesStack.add(_copyNotes());
      board = redoStack.removeLast();
      notes = redoNotesStack.removeLast();
    });
  }

  void _clear() {
    if (selected == null) return;
    final r = selected! ~/ config.size, c = selected! % config.size;
    if (initial[r][c] != 0) return;
    setState(() {
      _recordUndo();
      board[r][c] = 0;
      notes[r][c].clear();
    });
  }

  void _hint() {
    if (selected == null) return;
    if (paused || finished) return;
    var r = selected! ~/ config.size, c = selected! % config.size;
    if (initial[r][c] != 0) return;
    final evaluation = DifficultyEvaluator(config).evaluate(board);
    final deductions =
        evaluation.techniques.where((step) => step.placement != null).toList();
    var explanation = 'The value matches the saved solution.';
    var value = solution[r][c];
    if (deductions.isNotEmpty) {
      final deduction = deductions.first;
      final placement = deduction.placement!;
      r = placement.$1;
      c = placement.$2;
      value = placement.$3;
      explanation = 'Logical hint: ${deduction.technique.label}.';
    }
    setState(() {
      hints++;
      _recordUndo();
      board[r][c] = value;
      notes[r][c].clear();
      if (_isComplete()) {
        finished = true;
        timer?.cancel();
      }
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(explanation)));
    if (finished) _completeGame();
  }

  Future<void> _showWin() async {
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Puzzle complete!'),
                content: Text(
                    'Solved in ${_time()} with $mistakes mistakes and $hints hints.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'))
                ]));
  }

  String _time() =>
      '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(config.label), actions: [
        IconButton(
            tooltip: paused ? 'Resume' : 'Pause',
            onPressed: () => setState(() => paused = !paused),
            icon: Icon(paused ? Icons.play_arrow : Icons.pause)),
        IconButton(
            tooltip: 'Save game',
            onPressed: _save,
            icon: const Icon(Icons.save_outlined))
      ]),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final boardWidth = constraints.maxWidth - 32;
        final boardHeight = constraints.maxHeight * .55;
        final side = boardWidth < boardHeight ? boardWidth : boardHeight;
        return Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(difficulty.name.toUpperCase(),
                                style: Theme.of(context).textTheme.labelLarge),
                            Text(
                                ref.watch(gameSettingsProvider).timerEnabled
                                    ? _time()
                                    : 'Timer off',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('Mistakes $mistakes')
                          ])),
                  SizedBox(
                      width: side,
                      height: side,
                      child: paused
                          ? const Center(child: Text('Game paused'))
                          : _board()),
                  Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                                tooltip: 'Undo',
                                onPressed: undoStack.isEmpty ? null : _undo,
                                icon: const Icon(Icons.undo)),
                            IconButton(
                                tooltip: 'Redo',
                                onPressed: redoStack.isEmpty ? null : _redo,
                                icon: const Icon(Icons.redo)),
                            IconButton(
                                tooltip: 'Clear cell',
                                onPressed: _clear,
                                icon: const Icon(Icons.backspace_outlined)),
                            FilterChip(
                                label: const Text('Notes'),
                                selected: noteMode,
                                onSelected: (v) =>
                                    setState(() => noteMode = v)),
                            IconButton(
                                tooltip: 'Hint',
                                onPressed: _hint,
                                icon: const Icon(Icons.lightbulb_outline))
                          ])),
                  const Spacer(),
                  _keypad(context),
                  const SizedBox(height: 12)
                ])));
      })));
  Widget _board() => Column(
      children: List.generate(
          config.size,
          (r) => Expanded(
              child: Row(
                  children: List.generate(
                      config.size, (c) => Expanded(child: _cell(r, c)))))));
  Widget _cell(int r, int c) {
    final value = board[r][c],
        isFixed = initial[r][c] != 0,
        sel = selected == r * config.size + c,
        peer = _isPeer(r, c),
        match = selected != null &&
            value != 0 &&
            value == board[selected! ~/ config.size][selected! % config.size];
    final conflict = _hasConflict(r, c);
    final wrong = value != 0 && !isFixed && value != solution[r][c];
    final showMistakes = ref.watch(gameSettingsProvider).highlightMistakes;
    final thick = config.hasBoxes &&
        ((r % config.boxRows == config.boxRows - 1 && r < config.size - 1) ||
            (c % config.boxColumns == config.boxColumns - 1 &&
                c < config.size - 1));
    return InkWell(
        onTap: () => setState(() => selected = r * config.size + c),
        child: Container(
            decoration: BoxDecoration(
                color: sel
                    ? Theme.of(context).colorScheme.primaryContainer
                    : showMistakes && (wrong || conflict)
                        ? Theme.of(context).colorScheme.errorContainer
                        : match
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : peer
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                : null,
                border: Border(
                    right: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: thick ? 2 : 0.5),
                    bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: thick ? 2 : 0.5))),
            alignment: Alignment.center,
            child: value == 0
                ? (notes[r][c].isEmpty
                    ? null
                    : Wrap(
                        alignment: WrapAlignment.center,
                        children: notes[r][c]
                            .map((n) => Text('$n ',
                                style: Theme.of(context).textTheme.labelSmall))
                            .toList()))
                : Text('$value',
                    style: TextStyle(
                        fontWeight:
                            isFixed ? FontWeight.bold : FontWeight.normal,
                        color:
                            wrong ? Theme.of(context).colorScheme.error : null,
                        fontSize: 22))));
  }

  bool _isPeer(int row, int column) {
    if (selected == null) return false;
    final selectedRow = selected! ~/ config.size;
    final selectedColumn = selected! % config.size;
    if (row == selectedRow || column == selectedColumn) return true;
    return config.hasBoxes &&
        row ~/ config.boxRows == selectedRow ~/ config.boxRows &&
        column ~/ config.boxColumns == selectedColumn ~/ config.boxColumns;
  }

  bool _hasConflict(int row, int column) {
    final value = board[row][column];
    if (value == 0) return false;
    for (var i = 0; i < config.size; i++) {
      if (i != column && board[row][i] == value) return true;
      if (i != row && board[i][column] == value) return true;
    }
    if (config.hasBoxes) {
      final rowStart = row ~/ config.boxRows * config.boxRows;
      final columnStart = column ~/ config.boxColumns * config.boxColumns;
      for (var r = rowStart; r < rowStart + config.boxRows; r++) {
        for (var c = columnStart; c < columnStart + config.boxColumns; c++) {
          if ((r != row || c != column) && board[r][c] == value) return true;
        }
      }
    }
    return false;
  }

  Widget _keypad(BuildContext context) {
    final digits = config.digits;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: digits
                .map((n) => SizedBox(
                    width: config.size == 9 ? 38 : 52,
                    height: 48,
                    child: FilledButton.tonal(
                        onPressed: () => _enter(n),
                        child:
                            Text('$n', style: const TextStyle(fontSize: 19)))))
                .toList()));
  }
}

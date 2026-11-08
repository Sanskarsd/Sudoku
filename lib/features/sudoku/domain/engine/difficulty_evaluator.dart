import '../models/sudoku_config.dart';
import 'sudoku_solver.dart';

enum SudokuTechnique {
  nakedSingle('Naked single', 1, 1),
  hiddenSingle('Hidden single', 1, 2),
  nakedPair('Naked pair', 2, 5),
  hiddenPair('Hidden pair', 2, 6),
  pointing('Pointing pair / triple', 3, 8),
  boxLine('Box-line reduction', 3, 8),
  nakedTriple('Naked triple', 4, 10),
  hiddenTriple('Hidden triple', 4, 12),
  xWing('X-Wing', 5, 18),
  swordfish('Swordfish', 6, 24),
  nakedQuad('Naked quad', 6, 20),
  hiddenQuad('Hidden quad', 6, 22);

  const SudokuTechnique(this.label, this.rank, this.weight);
  final String label;
  final int rank;
  final int weight;
}

class TechniqueStep {
  const TechniqueStep(
      {required this.technique, required this.eliminations, this.placement});
  final SudokuTechnique technique;
  final int eliminations;
  final (int, int, int)? placement;
}

class DifficultyResult {
  const DifficultyResult({
    required this.solved,
    required this.supported,
    required this.score,
    required this.steps,
    required this.techniques,
    required this.hardestTechnique,
    required this.eliminations,
    this.classification,
    this.failureReason,
  });

  final bool solved;
  final bool supported;
  final int score;
  final int steps;
  final List<TechniqueStep> techniques;
  final String hardestTechnique;
  final int eliminations;
  final SudokuDifficulty? classification;
  final String? failureReason;
  List<String> get techniqueNames =>
      techniques.map((s) => s.technique.label).toList(growable: false);
}

class DifficultyThresholds {
  const DifficultyThresholds({
    this.easyMaxRank = 1,
    this.mediumMaxRank = 3,
    this.hardMaxRank = 5,
    this.scoreWeights = const {},
    this.mediumScoreFraction = .30,
    this.hardScoreFraction = .60,
    this.expertScoreFraction = .80,
  });

  final int easyMaxRank;
  final int mediumMaxRank;
  final int hardMaxRank;
  final Map<SudokuTechnique, int> scoreWeights;
  final double mediumScoreFraction;
  final double hardScoreFraction;
  final double expertScoreFraction;

  int weightFor(SudokuTechnique technique) =>
      scoreWeights[technique] ?? technique.weight;

  SudokuDifficulty? classify({
    required int rank,
    required int score,
    required int boardSize,
  }) {
    final techniqueLevel = rank <= easyMaxRank
        ? 0
        : rank <= mediumMaxRank
            ? 1
            : rank <= hardMaxRank
                ? 2
                : rank <= SudokuTechnique.swordfish.rank
                    ? 3
                    : -1;
    if (techniqueLevel < 0) return null;

    // Total logical work distinguishes long, multi-step puzzles that use the
    // same basic technique set. This is based on recorded placements and
    // candidate eliminations, never on the number of clues.
    final cells = boardSize * boardSize;
    final scoreLevel = score >= (cells * expertScoreFraction).ceil()
        ? 3
        : score >= (cells * hardScoreFraction).ceil()
            ? 2
            : score >= (cells * mediumScoreFraction).ceil()
                ? 1
                : 0;
    return SudokuDifficulty
        .values[techniqueLevel > scoreLevel ? techniqueLevel : scoreLevel];
  }
}

class DifficultyEvaluator {
  const DifficultyEvaluator(this.config,
      {this.thresholds = const DifficultyThresholds()});
  final SudokuConfig config;
  final DifficultyThresholds thresholds;

  DifficultyResult evaluate(List<List<int>> puzzle) {
    final solver = SudokuSolver(config);
    if (!solver.isValid(puzzle)) {
      return _failure('Puzzle has conflicting clues.');
    }
    final board = puzzle.map(List<int>.of).toList();
    final candidates = List.generate(
        config.size,
        (r) => List.generate(
            config.size,
            (c) => board[r][c] == 0
                ? solver.candidates(board, r, c).toSet()
                : <int>{}));
    final units = _units();
    final steps = <TechniqueStep>[];
    var score = 0;
    var eliminationCount = 0;
    final safetyLimit = config.size * config.size * config.size * 8;

    for (var turn = 0; turn < safetyLimit; turn++) {
      if (_hasContradiction(board, candidates, units)) {
        return _failure('Candidate deductions produced a contradiction.', steps,
            score, eliminationCount);
      }
      final single = _findSingle(board, candidates, units);
      if (single != null) {
        final (r, c, digit, technique) = single;
        if (!_place(board, candidates, units, r, c, digit)) {
          return _failure('Logical deduction produced a contradiction.', steps,
              score, eliminationCount);
        }
        steps.add(TechniqueStep(
            technique: technique, eliminations: 0, placement: (r, c, digit)));
        score += thresholds.weightFor(technique);
        continue;
      }

      final reduction = _findNakedSubset(candidates, units, 2) ??
          _findHiddenSubset(candidates, units, 2);
      if (reduction != null) {
        final (technique, removals) = reduction;
        if (removals > 0) {
          steps
              .add(TechniqueStep(technique: technique, eliminations: removals));
          eliminationCount += removals;
          score += thresholds.weightFor(technique) * removals;
          continue;
        }
      }
      final intersections = _findPointingOrBoxLine(candidates);
      if (intersections != null && intersections.$2 > 0) {
        steps.add(TechniqueStep(
            technique: intersections.$1, eliminations: intersections.$2));
        eliminationCount += intersections.$2;
        score += thresholds.weightFor(intersections.$1) * intersections.$2;
        continue;
      }
      final largerSubset = _findNakedSubset(candidates, units, 3) ??
          _findHiddenSubset(candidates, units, 3);
      if (largerSubset != null && largerSubset.$2 > 0) {
        steps.add(TechniqueStep(
            technique: largerSubset.$1, eliminations: largerSubset.$2));
        eliminationCount += largerSubset.$2;
        score += thresholds.weightFor(largerSubset.$1) * largerSubset.$2;
        continue;
      }
      final quad = _findNakedSubset(candidates, units, 4) ??
          _findHiddenSubset(candidates, units, 4);
      if (quad != null && quad.$2 > 0) {
        steps.add(TechniqueStep(technique: quad.$1, eliminations: quad.$2));
        eliminationCount += quad.$2;
        score += thresholds.weightFor(quad.$1) * quad.$2;
        continue;
      }
      final fish = _findFish(candidates, 2) ?? _findFish(candidates, 3);
      if (fish != null && fish.$2 > 0) {
        steps.add(TechniqueStep(technique: fish.$1, eliminations: fish.$2));
        eliminationCount += fish.$2;
        score += thresholds.weightFor(fish.$1) * fish.$2;
        continue;
      }
      break;
    }

    final solved = board.every((row) => row.every((v) => v != 0));
    final hardest = steps.isEmpty
        ? null
        : steps
            .map((s) => s.technique)
            .reduce((a, b) => a.rank >= b.rank ? a : b);
    final mini = config.mode == SudokuMode.mini;
    final classification = !solved || mini
        ? null
        : thresholds.classify(
            rank: hardest?.rank ?? 1,
            score: score,
            boardSize: config.size,
          );
    return DifficultyResult(
      solved: solved,
      supported: solved,
      score: score,
      steps: steps.length,
      techniques: List.unmodifiable(steps),
      hardestTechnique:
          hardest?.label ?? (solved ? 'Given values only' : 'Unsupported'),
      eliminations: eliminationCount,
      classification: classification,
      failureReason: solved
          ? null
          : 'Puzzle requires a technique outside the supported logical solver.',
    );
  }

  bool _hasContradiction(List<List<int>> board, List<List<Set<int>>> candidates,
      List<List<(int, int)>> units) {
    for (var r = 0; r < config.size; r++) {
      for (var c = 0; c < config.size; c++) {
        if (board[r][c] == 0 && candidates[r][c].isEmpty) return true;
      }
    }
    for (final unit in units) {
      for (final digit in config.digits) {
        final alreadyPlaced = unit.any((p) => board[p.$1][p.$2] == digit);
        if (!alreadyPlaced &&
            !unit.any((p) => candidates[p.$1][p.$2].contains(digit))) {
          return true;
        }
      }
    }
    return false;
  }

  DifficultyResult _failure(String reason,
          [List<TechniqueStep> steps = const [],
          int score = 0,
          int eliminations = 0]) =>
      DifficultyResult(
        solved: false,
        supported: false,
        score: score,
        steps: steps.length,
        techniques: List.unmodifiable(steps),
        hardestTechnique: 'Invalid',
        eliminations: eliminations,
        failureReason: reason,
      );

  List<List<(int, int)>> _units() {
    final units = <List<(int, int)>>[];
    for (var i = 0; i < config.size; i++) {
      units.add(List.generate(config.size, (c) => (i, c)));
      units.add(List.generate(config.size, (r) => (r, i)));
    }
    if (config.hasBoxes) {
      for (var br = 0; br < config.size ~/ config.boxRows; br++) {
        for (var bc = 0; bc < config.size ~/ config.boxColumns; bc++) {
          units.add([
            for (var r = br * config.boxRows;
                r < (br + 1) * config.boxRows;
                r++)
              for (var c = bc * config.boxColumns;
                  c < (bc + 1) * config.boxColumns;
                  c++)
                (r, c)
          ]);
        }
      }
    }
    return units;
  }

  (int, int, int, SudokuTechnique)? _findSingle(List<List<int>> board,
      List<List<Set<int>>> candidates, List<List<(int, int)>> units) {
    for (var r = 0; r < config.size; r++) {
      for (var c = 0; c < config.size; c++) {
        if (board[r][c] == 0 && candidates[r][c].length == 1) {
          return (r, c, candidates[r][c].single, SudokuTechnique.nakedSingle);
        }
      }
    }
    for (final unit in units) {
      for (final digit in config.digits) {
        final cells =
            unit.where((p) => candidates[p.$1][p.$2].contains(digit)).toList();
        if (cells.length == 1) {
          return (
            cells.single.$1,
            cells.single.$2,
            digit,
            SudokuTechnique.hiddenSingle
          );
        }
      }
    }
    return null;
  }

  bool _place(List<List<int>> board, List<List<Set<int>>> candidates,
      List<List<(int, int)>> units, int r, int c, int digit) {
    if (!candidates[r][c].contains(digit)) return false;
    board[r][c] = digit;
    candidates[r][c].clear();
    for (final unit in units) {
      if (!unit.contains((r, c))) continue;
      for (final p in unit) {
        if (p != (r, c)) candidates[p.$1][p.$2].remove(digit);
      }
    }
    return true;
  }

  (SudokuTechnique, int)? _findNakedSubset(
      List<List<Set<int>>> c, List<List<(int, int)>> units, int size) {
    for (final unit in units) {
      final cells = unit
          .where(
              (p) => c[p.$1][p.$2].isNotEmpty && c[p.$1][p.$2].length <= size)
          .toList();
      for (final chosen in _combinations(cells, size)) {
        final union = <int>{for (final p in chosen) ...c[p.$1][p.$2]};
        if (union.length != size) continue;
        final overlapsAnotherSubset = unit.any((p) =>
            !chosen.contains(p) &&
            c[p.$1][p.$2].isNotEmpty &&
            c[p.$1][p.$2].difference(union).isEmpty);
        if (overlapsAnotherSubset) continue;
        var removed = 0;
        for (final p in unit) {
          if (!chosen.contains(p)) {
            final before = c[p.$1][p.$2].length;
            c[p.$1][p.$2].removeAll(union);
            removed += before - c[p.$1][p.$2].length;
          }
        }
        if (removed > 0) {
          return (
            switch (size) {
              2 => SudokuTechnique.nakedPair,
              3 => SudokuTechnique.nakedTriple,
              _ => SudokuTechnique.nakedQuad,
            },
            removed
          );
        }
      }
    }
    return null;
  }

  (SudokuTechnique, int)? _findHiddenSubset(
      List<List<Set<int>>> c, List<List<(int, int)>> units, int size) {
    for (final unit in units) {
      for (final digits in _combinations(config.digits, size)) {
        if (digits
            .any((digit) => !unit.any((p) => c[p.$1][p.$2].contains(digit)))) {
          continue;
        }
        final cells =
            unit.where((p) => digits.any(c[p.$1][p.$2].contains)).toList();
        if (cells.length != size) continue;
        var removed = 0;
        for (final p in cells) {
          final before = c[p.$1][p.$2].length;
          c[p.$1][p.$2].retainAll(digits.toSet());
          removed += before - c[p.$1][p.$2].length;
        }
        if (removed > 0) {
          return (
            size == 2
                ? SudokuTechnique.hiddenPair
                : size == 3
                    ? SudokuTechnique.hiddenTriple
                    : SudokuTechnique.hiddenQuad,
            removed
          );
        }
      }
    }
    return null;
  }

  (SudokuTechnique, int)? _findPointingOrBoxLine(List<List<Set<int>>> c) {
    if (!config.hasBoxes) return null;
    final brCount = config.size ~/ config.boxRows,
        bcCount = config.size ~/ config.boxColumns;
    for (var br = 0; br < brCount; br++) {
      for (var bc = 0; bc < bcCount; bc++) {
        final cells = <(int, int)>[];
        for (var r = br * config.boxRows; r < (br + 1) * config.boxRows; r++) {
          for (var col = bc * config.boxColumns;
              col < (bc + 1) * config.boxColumns;
              col++) {
            cells.add((r, col));
          }
        }
        for (final digit in config.digits) {
          final spots =
              cells.where((p) => c[p.$1][p.$2].contains(digit)).toList();
          if (spots.length < 2) continue;
          if (spots.every((p) => p.$1 == spots.first.$1)) {
            var removed = 0;
            for (var col = 0; col < config.size; col++) {
              if (col < bc * config.boxColumns ||
                  col >= (bc + 1) * config.boxColumns) {
                if (c[spots.first.$1][col].remove(digit)) removed++;
              }
            }
            if (removed > 0) return (SudokuTechnique.pointing, removed);
          }
          if (spots.every((p) => p.$2 == spots.first.$2)) {
            var removed = 0;
            for (var r = 0; r < config.size; r++) {
              if (r < br * config.boxRows || r >= (br + 1) * config.boxRows) {
                if (c[r][spots.first.$2].remove(digit)) removed++;
              }
            }
            if (removed > 0) return (SudokuTechnique.pointing, removed);
          }
        }
      }
    }
    for (var axis = 0; axis < 2; axis++) {
      for (var index = 0; index < config.size; index++) {
        for (final digit in config.digits) {
          final spots = <(int, int)>[];
          for (var i = 0; i < config.size; i++) {
            final p = axis == 0 ? (index, i) : (i, index);
            if (c[p.$1][p.$2].contains(digit)) spots.add(p);
          }
          if (spots.length < 2) continue;
          final box = axis == 0
              ? spots.map((p) => p.$2 ~/ config.boxColumns).toSet()
              : spots.map((p) => p.$1 ~/ config.boxRows).toSet();
          if (box.length != 1) continue;
          var removed = 0;
          for (var r = 0; r < config.size; r++) {
            for (var col = 0; col < config.size; col++) {
              final onLine = axis == 0 ? r == index : col == index;
              final inBox = axis == 0
                  ? col ~/ config.boxColumns == box.first
                  : r ~/ config.boxRows == box.first;
              if (!onLine && inBox && c[r][col].remove(digit)) removed++;
            }
          }
          if (removed > 0) return (SudokuTechnique.boxLine, removed);
        }
      }
    }
    return null;
  }

  (SudokuTechnique, int)? _findFish(List<List<Set<int>>> c, int size) {
    // Fish patterns apply to any boxed row/column Sudoku large enough to
    // contain the pattern, including Compact 6×6.
    if (!config.hasBoxes || config.size < size * 2) return null;
    for (var transposed = 0; transposed < 2; transposed++) {
      for (final digit in config.digits) {
        final eligible = <int, List<int>>{};
        for (var major = 0; major < config.size; major++) {
          final minor = <int>[];
          for (var i = 0; i < config.size; i++) {
            final r = transposed == 0 ? major : i,
                col = transposed == 0 ? i : major;
            if (c[r][col].contains(digit)) minor.add(i);
          }
          if (minor.length >= 2 && minor.length <= size) {
            eligible[major] = minor;
          }
        }
        for (final majors in _combinations(eligible.keys.toList(), size)) {
          final cover = {for (final major in majors) ...eligible[major]!};
          if (cover.length != size) continue;
          var removed = 0;
          for (var major = 0; major < config.size; major++) {
            if (majors.contains(major)) continue;
            for (final minor in cover) {
              final r = transposed == 0 ? major : minor,
                  col = transposed == 0 ? minor : major;
              if (c[r][col].remove(digit)) removed++;
            }
          }
          if (removed > 0) {
            return (
              size == 2 ? SudokuTechnique.xWing : SudokuTechnique.swordfish,
              removed
            );
          }
        }
      }
    }
    return null;
  }

  List<List<T>> _combinations<T>(List<T> input, int size) {
    final results = <List<T>>[];
    void walk(int start, List<T> current) {
      if (current.length == size) {
        results.add(List.of(current));
        return;
      }
      for (var i = start; i <= input.length - (size - current.length); i++) {
        current.add(input[i]);
        walk(i + 1, current);
        current.removeLast();
      }
    }

    walk(0, []);
    return results;
  }
}

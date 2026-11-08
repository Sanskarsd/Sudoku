import 'dart:math';

import '../models/sudoku_config.dart';
import '../models/sudoku_puzzle.dart';
import 'difficulty_evaluator.dart';
import 'sudoku_solver.dart';

class PuzzleGenerationException implements Exception {
  const PuzzleGenerationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SudokuGenerator {
  const SudokuGenerator({
    this.maxAttempts = 8,
    this.maxRemovals = 81,
    this.thresholds = const DifficultyThresholds(),
  });
  final int maxAttempts;
  final int maxRemovals;
  final DifficultyThresholds thresholds;

  SudokuPuzzle generatePuzzle(
    SudokuConfig config,
    SudokuDifficulty requestedDifficulty, {
    int? randomSeed,
  }) {
    final seed = randomSeed ?? Random.secure().nextInt(0x7fffffff);
    final random = Random(seed);
    final solver = SudokuSolver(config);
    final evaluator = DifficultyEvaluator(config, thresholds: thresholds);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final solutionBoard = List.generate(
        config.size,
        (_) => List.filled(config.size, 0),
      );
      if (!solver.solve(solutionBoard, random: random)) continue;
      final solution = solutionBoard.map(List<int>.of).toList();
      final initial = solution.map(List<int>.of).toList();
      final cells = <(int, int)>[];
      for (var r = 0; r < config.size; r++) {
        for (var c = 0; c < config.size; c++) {
          cells.add((r, c));
        }
      }
      cells.shuffle(random);
      final clueFloor = _minimumClues(config, requestedDifficulty);
      var removed = 0;
      for (final (r, c) in cells) {
        if (initial.expand((row) => row).where((v) => v != 0).length <=
                clueFloor ||
            removed >= maxRemovals) {
          break;
        }
        final saved = initial[r][c];
        initial[r][c] = 0;
        if (solver.countSolutions(initial, limit: 2) == 1) {
          removed++;
          final result = evaluator.evaluate(initial);
          if (_matches(config, requestedDifficulty, result)) {
            if (_verify(config, solver, initial, solution)) {
              return SudokuPuzzle(
                config: config,
                solution: solution,
                initialBoard: initial,
                difficulty: requestedDifficulty,
                seed: seed ^ attempt,
                score: result.score,
                hardestTechnique: result.hardestTechnique,
              );
            }
          }
        } else {
          initial[r][c] = saved;
        }
      }
      // Test the bounded candidate at its final clue level as well.
      final result = evaluator.evaluate(initial);
      if (_matches(config, requestedDifficulty, result) &&
          _verify(config, solver, initial, solution)) {
        return SudokuPuzzle(
          config: config,
          solution: solution,
          initialBoard: initial,
          difficulty: requestedDifficulty,
          seed: seed ^ attempt,
          score: result.score,
          hardestTechnique: result.hardestTechnique,
        );
      }
    }
    throw PuzzleGenerationException(
      'Could not generate a verified ${requestedDifficulty.name} ${config.label} in $maxAttempts attempts. Try again or choose another difficulty.',
    );
  }

  int _minimumClues(SudokuConfig config, SudokuDifficulty difficulty) {
    if (config.mode == SudokuMode.mini) return 6;
    final total = config.size * config.size;
    final fraction = switch (difficulty) {
      SudokuDifficulty.easy => .58,
      SudokuDifficulty.medium => .40,
      SudokuDifficulty.hard => .30,
      SudokuDifficulty.expert => .22,
    };
    final theoreticalFloor =
        config.mode == SudokuMode.classic ? 17 : config.size;
    return max(theoreticalFloor, (total * fraction).round());
  }

  bool _matches(
    SudokuConfig config,
    SudokuDifficulty requested,
    DifficultyResult result,
  ) {
    if (config.mode == SudokuMode.mini) {
      return result.solved && requested == SudokuDifficulty.easy;
    }
    return result.solved && result.classification == requested;
  }

  bool _verify(
    SudokuConfig config,
    SudokuSolver solver,
    List<List<int>> initial,
    List<List<int>> solution,
  ) {
    if (initial.length != config.size ||
        initial.any((r) => r.length != config.size) ||
        !solver.isValid(initial) ||
        !solver.isValid(solution) ||
        solution.any((r) => r.contains(0)) ||
        solver.countSolutions(initial, limit: 2) != 1) {
      return false;
    }
    for (var r = 0; r < config.size; r++) {
      for (var c = 0; c < config.size; c++) {
        if (initial[r][c] != 0 && initial[r][c] != solution[r][c]) return false;
      }
    }
    return true;
  }
}

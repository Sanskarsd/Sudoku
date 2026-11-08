import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_master/features/sudoku/domain/engine/sudoku_generator.dart';
import 'package:sudoku_master/features/sudoku/domain/engine/difficulty_evaluator.dart';
import 'package:sudoku_master/features/sudoku/domain/engine/sudoku_solver.dart';
import 'package:sudoku_master/features/sudoku/domain/models/sudoku_config.dart';

void main() {
  group('SudokuSolver', () {
    for (final config in [
      SudokuConfig.mini,
      SudokuConfig.compact,
      SudokuConfig.classic
    ]) {
      test('${config.label} builds a complete valid board reproducibly', () {
        final solver = SudokuSolver(config);
        final a =
            List.generate(config.size, (_) => List.filled(config.size, 0));
        final b =
            List.generate(config.size, (_) => List.filled(config.size, 0));
        expect(solver.solve(a, random: Random(42)), isTrue);
        expect(solver.solve(b, random: Random(42)), isTrue);
        expect(solver.isValid(a), isTrue);
        expect(a, b);
        expect(a.expand((r) => r).every((v) => v >= 1 && v <= config.size),
            isTrue);
      });
    }

    test('Mini board uses Latin constraints and no box rule', () {
      const solver = SudokuSolver(SudokuConfig.mini);
      expect(
          solver.isValid([
            [1, 2, 3],
            [2, 3, 1],
            [3, 1, 2]
          ]),
          isTrue);
      expect(
          solver.isValid([
            [1, 2, 3],
            [2, 1, 3],
            [3, 3, 1]
          ]),
          isFalse);
    });

    test('Compact and Classic reject duplicate values inside a subgrid', () {
      final compact = List.generate(6, (_) => List.filled(6, 0));
      compact[0][0] = 1;
      compact[1][1] = 1;
      expect(
          const SudokuSolver(SudokuConfig.compact).isValid(compact), isFalse);

      final classic = List.generate(9, (_) => List.filled(9, 0));
      classic[0][0] = 1;
      classic[1][1] = 1;
      expect(
          const SudokuSolver(SudokuConfig.classic).isValid(classic), isFalse);
    });

    test('solution counting stops at limit and leaves caller unchanged', () {
      const solver = SudokuSolver(SudokuConfig.mini);
      final puzzle = [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0]
      ];
      final before = puzzle.map(List<int>.of).toList();
      expect(solver.countSolutions(puzzle, limit: 2), 2);
      expect(puzzle, before);
    });

    test('difficulty evaluator distinguishes logical solving from search', () {
      const evaluator = DifficultyEvaluator(SudokuConfig.classic);
      final solved = [
        [1, 2, 3, 4, 5, 6, 7, 8, 9],
        [4, 5, 6, 7, 8, 9, 1, 2, 3],
        [7, 8, 9, 1, 2, 3, 4, 5, 6],
        [2, 3, 4, 5, 6, 7, 8, 9, 1],
        [5, 6, 7, 8, 9, 1, 2, 3, 4],
        [8, 9, 1, 2, 3, 4, 5, 6, 7],
        [3, 4, 5, 6, 7, 8, 9, 1, 2],
        [6, 7, 8, 9, 1, 2, 3, 4, 5],
        [9, 1, 2, 3, 4, 5, 6, 7, 8],
      ];
      final easy = evaluator.evaluate(solved);
      expect(easy.solved, isTrue);
      expect(easy.supported, isTrue);
      expect(easy.classification, SudokuDifficulty.easy);

      final unsupported =
          evaluator.evaluate(List.generate(9, (_) => List.filled(9, 0)));
      expect(unsupported.solved, isFalse);
      expect(unsupported.supported, isFalse);
      expect(unsupported.classification, isNull);
      expect(unsupported.failureReason, isNotNull);
    });

    test('generation returns unique puzzle with preserved clues', () {
      const generator = SudokuGenerator(maxAttempts: 12);
      final puzzle = generator.generatePuzzle(
          SudokuConfig.mini, SudokuDifficulty.easy,
          randomSeed: 7);
      final solver = SudokuSolver(puzzle.config);
      expect(solver.countSolutions(puzzle.initialBoard), 1);
      for (var r = 0; r < puzzle.config.size; r++) {
        for (var c = 0; c < puzzle.config.size; c++) {
          if (puzzle.initialBoard[r][c] != 0) {
            expect(puzzle.initialBoard[r][c], puzzle.solution[r][c]);
          }
        }
      }
    });

    test('same seed recreates the same puzzle and respects retry bounds', () {
      const generator = SudokuGenerator(maxAttempts: 12);
      final first = generator.generatePuzzle(
          SudokuConfig.mini, SudokuDifficulty.easy,
          randomSeed: 20261030);
      final second = generator.generatePuzzle(
          SudokuConfig.mini, SudokuDifficulty.easy,
          randomSeed: 20261030);
      expect(first.solution, second.solution);
      expect(first.initialBoard, second.initialBoard);
      expect(
        () => const SudokuGenerator(maxAttempts: 0).generatePuzzle(
            SudokuConfig.mini, SudokuDifficulty.easy,
            randomSeed: 4),
        throwsA(isA<PuzzleGenerationException>()),
      );
    });

    for (final config in [SudokuConfig.compact, SudokuConfig.classic]) {
      test('${config.label} generated puzzle is unique and clue-safe', () {
        final puzzle = const SudokuGenerator(maxAttempts: 12).generatePuzzle(
          config,
          SudokuDifficulty.easy,
          randomSeed: 31 + config.size,
        );
        final solver = SudokuSolver(config);
        expect(solver.countSolutions(puzzle.initialBoard, limit: 2), 1);
        for (var r = 0; r < config.size; r++) {
          for (var c = 0; c < config.size; c++) {
            if (puzzle.initialBoard[r][c] != 0) {
              expect(puzzle.initialBoard[r][c], puzzle.solution[r][c]);
            }
          }
        }
      });

      for (final difficulty in [
        SudokuDifficulty.medium,
        SudokuDifficulty.hard,
        SudokuDifficulty.expert,
      ]) {
        test(
            '${config.label} generates verified ${difficulty.name} puzzles '
            'for multiple seeds', () {
          const generator = SudokuGenerator(maxAttempts: 12);
          final solver = SudokuSolver(config);
          for (final seed in [23, 91]) {
            final puzzle = generator.generatePuzzle(
              config,
              difficulty,
              randomSeed: seed,
            );
            final evaluated =
                DifficultyEvaluator(config).evaluate(puzzle.initialBoard);

            expect(solver.isValid(puzzle.solution), isTrue,
                reason: '${config.label}, ${difficulty.name}, seed $seed');
            expect(
                puzzle.solution
                    .expand((row) => row)
                    .every((value) => value >= 1 && value <= config.size),
                isTrue);
            expect(solver.isValid(puzzle.initialBoard), isTrue);
            expect(solver.countSolutions(puzzle.initialBoard, limit: 2), 1);
            expect(evaluated.solved, isTrue);
            expect(evaluated.supported, isTrue);
            expect(evaluated.classification, difficulty);
            for (var r = 0; r < config.size; r++) {
              for (var c = 0; c < config.size; c++) {
                final clue = puzzle.initialBoard[r][c];
                if (clue != 0) expect(clue, puzzle.solution[r][c]);
              }
            }
          }
        });
      }
    }
  });
}

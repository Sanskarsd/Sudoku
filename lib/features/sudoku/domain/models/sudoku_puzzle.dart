import 'sudoku_config.dart';

class SudokuPuzzle {
  SudokuPuzzle({
    required this.config,
    required List<List<int>> solution,
    required List<List<int>> initialBoard,
    required this.difficulty,
    required this.seed,
    required this.score,
    required this.hardestTechnique,
  })  : solution = _freeze(solution),
        initialBoard = _freeze(initialBoard);
  final SudokuConfig config;
  final List<List<int>> solution;
  final List<List<int>> initialBoard;
  final SudokuDifficulty difficulty;
  final int seed;
  final int score;
  final String hardestTechnique;
  static List<List<int>> _freeze(List<List<int>> b) =>
      List.unmodifiable(b.map(List<int>.unmodifiable));
  List<List<int>> newCurrentBoard() =>
      initialBoard.map((r) => List<int>.of(r)).toList();
}

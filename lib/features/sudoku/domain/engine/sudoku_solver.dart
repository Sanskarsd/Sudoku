import 'dart:math';

import '../models/sudoku_config.dart';

class SudokuSolver {
  const SudokuSolver(this.config);
  final SudokuConfig config;

  bool isValid(List<List<int>> board) {
    if (board.length != config.size ||
        board.any((r) => r.length != config.size)) {
      return false;
    }
    for (var r = 0; r < config.size; r++) {
      for (var c = 0; c < config.size; c++) {
        final v = board[r][c];
        if (v < 0 || v > config.size) return false;
        if (v != 0 && !isAllowed(board, r, c, v, ignoreCell: true)) {
          return false;
        }
      }
    }
    return true;
  }

  bool isAllowed(
    List<List<int>> b,
    int row,
    int col,
    int value, {
    bool ignoreCell = false,
  }) {
    if (value < 1 || value > config.size) return false;
    for (var i = 0; i < config.size; i++) {
      if (i != col && b[row][i] == value) return false;
      if (i != row && b[i][col] == value) return false;
    }
    if (config.hasBoxes) {
      final rs = row ~/ config.boxRows * config.boxRows;
      final cs = col ~/ config.boxColumns * config.boxColumns;
      for (var r = rs; r < rs + config.boxRows; r++) {
        for (var c = cs; c < cs + config.boxColumns; c++) {
          if ((r != row || c != col) && b[r][c] == value) return false;
        }
      }
    }
    return true;
  }

  List<int> candidates(List<List<int>> b, int r, int c) =>
      config.digits.where((v) => isAllowed(b, r, c, v)).toList();

  bool solve(List<List<int>> board, {Random? random}) {
    if (!isValid(board)) return false;
    final cell = _bestCell(board, random: random);
    if (cell == null) return true;
    final (r, c, options) = cell;
    if (random != null) options.shuffle(random);
    for (final value in options) {
      board[r][c] = value;
      if (solve(board, random: random)) return true;
      board[r][c] = 0;
    }
    return false;
  }

  int countSolutions(List<List<int>> board, {int limit = 2}) {
    if (limit < 1 || !isValid(board)) return 0;
    final work = board.map(List<int>.of).toList();
    var count = 0;
    void search() {
      if (count >= limit) return;
      final cell = _bestCell(work);
      if (cell == null) {
        count++;
        return;
      }
      final (r, c, options) = cell;
      for (final v in options) {
        work[r][c] = v;
        search();
        work[r][c] = 0;
        if (count >= limit) return;
      }
    }

    search();
    return count;
  }

  (int, int, List<int>)? _bestCell(List<List<int>> b, {Random? random}) {
    (int, int, List<int>)? best;
    var equallyConstrainedCells = 0;
    for (var r = 0; r < config.size; r++) {
      for (var c = 0; c < config.size; c++) {
        if (b[r][c] != 0) continue;
        final opts = candidates(b, r, c);
        if (opts.isEmpty) return (r, c, opts);
        if (best == null || opts.length < best.$3.length) {
          best = (r, c, opts);
          equallyConstrainedCells = 1;
        } else if (opts.length == best.$3.length && random != null) {
          equallyConstrainedCells++;
          if (random.nextInt(equallyConstrainedCells) == 0) {
            best = (r, c, opts);
          }
        }
        if (opts.length == 1) return best;
      }
    }
    return best;
  }
}

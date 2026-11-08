enum SudokuMode { mini, compact, classic }

enum SudokuDifficulty { easy, medium, hard, expert }

class SudokuConfig {
  const SudokuConfig._(this.mode, this.size, this.boxRows, this.boxColumns);
  static const mini = SudokuConfig._(SudokuMode.mini, 3, 0, 0);
  static const compact = SudokuConfig._(SudokuMode.compact, 6, 2, 3);
  static const classic = SudokuConfig._(SudokuMode.classic, 9, 3, 3);

  final SudokuMode mode;
  final int size;
  final int boxRows;
  final int boxColumns;
  bool get hasBoxes => boxRows > 0;
  List<int> get digits => List.generate(size, (i) => i + 1);
  String get label => switch (mode) {
        SudokuMode.mini => 'Mini Sudoku',
        SudokuMode.compact => 'Compact Sudoku',
        SudokuMode.classic => 'Classic Sudoku',
      };
  static SudokuConfig fromMode(SudokuMode mode) => switch (mode) {
        SudokuMode.mini => mini,
        SudokuMode.compact => compact,
        SudokuMode.classic => classic,
      };
}

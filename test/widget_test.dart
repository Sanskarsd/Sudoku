import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_master/app/app.dart';

void main() {
  testWidgets('home screen shows game setup and simplified mini rules',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SudokuMasterApp()));
    expect(find.text('Sudoku Master'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your board'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Compact'), findsOneWidget);
    expect(find.text('Mini'), findsOneWidget);
    await tester.tap(find.text('Mini'));
    await tester.pumpAndSettle();
    expect(find.textContaining('difficulty range is intentionally limited'),
        findsOneWidget);
  });
}

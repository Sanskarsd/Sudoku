import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/home/new_game_screen.dart';
import '../features/home/saved_games_screen.dart';
import '../features/daily_challenge/daily_challenge_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/statistics/statistics_screen.dart';
import '../features/sudoku/domain/models/sudoku_puzzle.dart';
import '../features/sudoku/presentation/screens/game_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
        path: '/new-game', builder: (context, state) => const NewGameScreen()),
    GoRoute(
        path: '/daily',
        builder: (context, state) => const DailyChallengeScreen()),
    GoRoute(
        path: '/game',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is SudokuPuzzle) {
            return GameScreen(puzzle: extra);
          }
          if (extra is GameLaunch) {
            return GameScreen(puzzle: extra.puzzle, dailyDate: extra.dailyDate);
          }
          if (extra is Map<String, Object?>) {
            return GameScreen.restore(extra);
          }
          return const Scaffold(
              body: Center(child: Text('Game data was not provided.')));
        }),
    GoRoute(
        path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
        path: '/statistics',
        builder: (context, state) => const StatisticsScreen()),
    GoRoute(
        path: '/saved-games',
        builder: (context, state) => const SavedGamesScreen()),
  ],
);

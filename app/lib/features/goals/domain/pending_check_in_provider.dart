import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Check-in requests currently in flight, keyed `goalId|yyyy-MM-dd`.
///
/// Kept separate from `checkInProvider` rather than widening its state, so the
/// existing read sites are untouched. Two jobs:
///   1. the duplicate-tap guard in `CheckInNotifier.setCheckIn`
///   2. driving the spinner in `CheckInButton`
final pendingCheckInProvider =
    NotifierProvider<PendingCheckInNotifier, Set<String>>(PendingCheckInNotifier.new);

String pendingCheckInKey(String goalId, DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$goalId|${date.year}-$m-$d';
}

class PendingCheckInNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool isPending(String key) => state.contains(key);

  /// Marks [key] in flight. Returns false if it already was, which is the
  /// signal to drop a duplicate request.
  bool begin(String key) {
    if (state.contains(key)) return false;
    state = {...state, key};
    return true;
  }

  void end(String key) {
    if (!state.contains(key)) return;
    state = {...state}..remove(key);
  }
}

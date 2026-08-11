/// Pluralization helpers for user-facing copy.
///
/// This lived privately inside status_style.dart, which is why a dozen other
/// call sites re-invented it or skipped it entirely and shipped "1 weeks",
/// "1 days" and "1 members". Everything that puts a number next to a noun
/// should come through here.

/// `plural(1, 'week')` → "week"; `plural(2, 'week')` → "weeks".
/// Pass [pluralForm] for irregulars: `plural(n, 'is', 'are')`.
String plural(int n, String singular, [String? pluralForm]) =>
    n == 1 ? singular : (pluralForm ?? '${singular}s');

/// `count(1, 'week')` → "1 week"; `count(3, 'check-in')` → "3 check-ins".
String count(int n, String singular, [String? pluralForm]) =>
    '$n ${plural(n, singular, pluralForm)}';

/// A streak length as a compound adjective: "4-week streak", "1-week streak".
///
/// Hyphenated on purpose — "4 week streak" reads as three separate nouns, and
/// the codebase previously spelled it both ways on the same screen.
String weekStreakLabel(int weeks) => '$weeks-week streak';

/// Short form for tight spaces: "4 wk".
String weekStreakShort(int weeks) => '$weeks wk';

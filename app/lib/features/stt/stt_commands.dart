/// Things a cashier can SAY to control the listening, rather than reaching for the screen —
/// pure Dart, no Flutter, so the rules are tested directly.
library;

/// The phrases that end a listening run.
///
/// Deliberately two words, and deliberately not just "selesai": a stop phrase has to be something
/// nobody says by accident while reading an order out. A till that stops listening because a word
/// drifted past is worse than one that needs the phrase said twice.
const List<String> kStopPhrases = [
  'pesanan selesai',
  'pesanan sudah selesai',
  'order selesai',
];

/// Matches a phrase however the recognizer punctuated or spaced it: "Pesanan, selesai" and
/// "pesanan  selesai" are the same instruction.
final List<RegExp> _stopPatterns = [
  for (final phrase in kStopPhrases)
    RegExp(phrase.split(' ').join(r'[^a-z0-9]+'), caseSensitive: false),
];

/// What is left of a spoken line once a stop phrase is removed, and whether one was there.
///
/// The phrase is taken OUT because "ayam bakar dua pesanan selesai" is an order followed by an
/// instruction: the order must still be recorded, without the instruction stuck on the end of the
/// item name.
({String text, bool stop}) readStopPhrase(String utterance) {
  for (final pattern in _stopPatterns) {
    final m = pattern.firstMatch(utterance);
    if (m == null) continue;
    final rest = utterance.substring(0, m.start) + utterance.substring(m.end);
    return (text: rest.replaceAll(RegExp(r'\s+'), ' ').trim(), stop: true);
  }
  return (text: utterance, stop: false);
}

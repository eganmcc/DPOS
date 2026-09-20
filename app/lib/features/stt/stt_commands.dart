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

/// The words the stop phrase is made of. Nothing is sold under these names, so a line consisting
/// only of them is an instruction that got chopped up, not an order.
const Set<String> kCommandWords = {'pesanan', 'sudah', 'selesai', 'order'};

List<String> _words(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// A whole utterance that is nothing but command words, including "selesai".
///
/// This exists because of what the device did on 20 Sep: the recognizer split "pesanan selesai"
/// across two results, so neither half matched the two-word phrase — the run kept going and
/// "selesai" was staged as an item, reported as "tidak ada di katalog". Matching a bare "selesai"
/// does risk stopping when a cashier says it to a customer; being unable to stop, and billing a
/// word as an item, is the worse failure.
bool isStopCommand(String utterance) {
  final w = _words(utterance);
  return w.isNotEmpty && w.every(kCommandWords.contains) && w.contains('selesai');
}

/// Drops command words from the END of a line.
///
/// The other half of the same split: "air mineral tiga pesanan" | "selesai" leaves the first line
/// carrying a word that is not part of any item's name, which would mangle both the name and the
/// quantity behind it.
String stripTrailingCommandWords(String utterance) {
  final w = _words(utterance);
  var end = w.length;
  while (end > 0 && kCommandWords.contains(w[end - 1])) {
    end--;
  }
  return end == w.length ? utterance : w.sublist(0, end).join(' ');
}

/// What is left of a spoken line once a stop phrase is removed, and whether one was there.
///
/// The phrase is taken OUT because "ayam bakar dua pesanan selesai" is an order followed by an
/// instruction: the order must still be recorded, without the instruction stuck on the end of the
/// item name.
({String text, bool stop}) readStopPhrase(String utterance) {
  // A line that is ONLY command words is the instruction arriving on its own.
  if (isStopCommand(utterance)) return (text: '', stop: true);
  for (final pattern in _stopPatterns) {
    final m = pattern.firstMatch(utterance);
    if (m == null) continue;
    final rest = utterance.substring(0, m.start) + utterance.substring(m.end);
    return (text: rest.replaceAll(RegExp(r'\s+'), ' ').trim(), stop: true);
  }
  return (text: utterance, stop: false);
}

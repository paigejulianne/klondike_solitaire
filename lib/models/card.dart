import 'dart:math';

enum Suit { spades, hearts, diamonds, clubs }

extension SuitX on Suit {
  bool get isRed => this == Suit.hearts || this == Suit.diamonds;

  String get symbol {
    switch (this) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }
}

/// A single playing card. Rank runs 1 (Ace) through 13 (King).
class PlayingCard {
  final Suit suit;
  final int rank;
  bool faceUp;

  PlayingCard({required this.suit, required this.rank, this.faceUp = false});

  bool get isRed => suit.isRed;

  String get rankLabel {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '$rank';
    }
  }

  /// Stable identity independent of faceUp state - there is exactly one
  /// card of each suit/rank combination in a standard deck.
  String get id => '${suit.name}_$rank';

  PlayingCard copy() => PlayingCard(suit: suit, rank: rank, faceUp: faceUp);

  /// Packs the card into a single int for the auto-save payload.
  int toCode() => suit.index * 100 + rank * 2 + (faceUp ? 1 : 0);

  @override
  String toString() => '$rankLabel${suit.symbol}${faceUp ? "" : "(down)"}';
}

extension PlayingCardCodec on PlayingCard {
  /// Inverse of [PlayingCard.toCode]. Throws on out-of-range input so a
  /// corrupt save is rejected rather than producing an impossible deck.
  static PlayingCard fromCode(int code) {
    final suitIndex = code ~/ 100;
    final rest = code % 100;
    final rank = rest ~/ 2;
    if (suitIndex < 0 || suitIndex >= Suit.values.length) {
      throw ArgumentError('bad suit in card code $code');
    }
    if (rank < 1 || rank > 13) {
      throw ArgumentError('bad rank in card code $code');
    }
    return PlayingCard(
      suit: Suit.values[suitIndex],
      rank: rank,
      faceUp: rest.isOdd,
    );
  }
}

List<PlayingCard> createShuffledDeck([int? seed]) {
  final deck = <PlayingCard>[
    for (final suit in Suit.values)
      for (var rank = 1; rank <= 13; rank++) PlayingCard(suit: suit, rank: rank),
  ];
  deck.shuffle(seed == null ? Random() : Random(seed));
  return deck;
}

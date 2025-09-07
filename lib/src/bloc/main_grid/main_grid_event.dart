import 'package:equatable/equatable.dart';
import '../../data/card_entity.dart';

abstract class MainGridEvent extends Equatable {
  const MainGridEvent();

  @override
  List<Object?> get props => [];
}

// Event to load initial cards
class LoadCards extends MainGridEvent {
  final bool refresh;

  const LoadCards({this.refresh = false});

  @override
  List<Object?> get props => [refresh];
}

// Event to load more cards (pagination)
class LoadMoreCards extends MainGridEvent {
  const LoadMoreCards();
}

// Event when card is added
class CardAdded extends MainGridEvent {
  final CardEntity card;

  const CardAdded(this.card);

  @override
  List<Object?> get props => [card];
}

// Event when card is deleted
class CardDeleted extends MainGridEvent {
  final int cardId;

  const CardDeleted(this.cardId);

  @override
  List<Object?> get props => [cardId];
}

// Event for searching cards
class SearchCards extends MainGridEvent {
  final String query;

  const SearchCards(this.query);

  @override
  List<Object?> get props => [query];
}

// Event when search query changes
class SearchQueryChanged extends MainGridEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

// Event to clear search and show all cards
class ClearSearch extends MainGridEvent {
  const ClearSearch();
}

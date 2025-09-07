import 'package:equatable/equatable.dart';
import '../../data/card_entity.dart';

abstract class MainGridState extends Equatable {
  const MainGridState();

  @override
  List<Object?> get props => [];
}

class MainGridInitial extends MainGridState {
  const MainGridInitial();
}

class MainGridLoading extends MainGridState {
  final bool isFirstLoad;

  const MainGridLoading({this.isFirstLoad = true});

  @override
  List<Object?> get props => [isFirstLoad];
}

class MainGridLoaded extends MainGridState {
  final List<CardEntity> cards;
  final bool hasReachedMax;
  final String? searchQuery;
  final bool isSearchResult;

  const MainGridLoaded({
    required this.cards,
    this.hasReachedMax = false,
    this.searchQuery,
    this.isSearchResult = false,
  });

  @override
  List<Object?> get props => [
    cards,
    hasReachedMax,
    searchQuery,
    isSearchResult,
  ];

  MainGridLoaded copyWith({
    List<CardEntity>? cards,
    bool? hasReachedMax,
    String? searchQuery,
    bool? isSearchResult,
  }) {
    return MainGridLoaded(
      cards: cards ?? this.cards,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchResult: isSearchResult ?? this.isSearchResult,
    );
  }
}

class MainGridError extends MainGridState {
  final String message;

  const MainGridError(this.message);

  @override
  List<Object?> get props => [message];
}

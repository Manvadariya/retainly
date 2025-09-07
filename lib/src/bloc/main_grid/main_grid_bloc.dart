import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../data/repository/card_repository.dart';
import 'main_grid_event.dart';
import 'main_grid_state.dart';

class MainGridBloc extends Bloc<MainGridEvent, MainGridState> {
  final CardRepository _cardRepository;
  static const int _pageSize = 20;
  MainGridBloc({required CardRepository cardRepository})
    : _cardRepository = cardRepository,
      super(const MainGridInitial()) {
    on<LoadCards>(_onLoadCards);
    on<LoadMoreCards>(_onLoadMoreCards);
    on<CardAdded>(_onCardAdded);
    on<CardDeleted>(_onCardDeleted);
    on<SearchCards>(_onSearchCards);
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<ClearSearch>(_onClearSearch);
  }

  @override
  Future<void> close() {
    return super.close();
  }

  Future<void> _onLoadCards(
    LoadCards event,
    Emitter<MainGridState> emit,
  ) async {
    try {
      emit(MainGridLoading(isFirstLoad: true));
      final cards = await _cardRepository.getAllCards(limit: _pageSize);
      final hasReachedMax = cards.length < _pageSize;

      emit(MainGridLoaded(cards: cards, hasReachedMax: hasReachedMax));
    } catch (e) {
      emit(MainGridError('Failed to load cards: ${e.toString()}'));
    }
  }

  Future<void> _onLoadMoreCards(
    LoadMoreCards event,
    Emitter<MainGridState> emit,
  ) async {
    if (state is! MainGridLoaded) return;
    final currentState = state as MainGridLoaded;

    // Don't load more if already reached max or is showing search results
    if (currentState.hasReachedMax || currentState.isSearchResult) return;

    try {
      // Show loading state but keep current cards
      // Could add a "loadingMore" flag to state if needed for UI

      final moreCards = await _cardRepository.getAllCards(
        offset: currentState.cards.length,
        limit: _pageSize,
      );

      final hasReachedMax = moreCards.length < _pageSize;

      emit(
        currentState.copyWith(
          cards: [...currentState.cards, ...moreCards],
          hasReachedMax: hasReachedMax,
        ),
      );
    } catch (e) {
      // Keep current cards but show error
      emit(MainGridError('Failed to load more cards: ${e.toString()}'));
    }
  }

  Future<void> _onCardAdded(
    CardAdded event,
    Emitter<MainGridState> emit,
  ) async {
    if (state is! MainGridLoaded) return;
    final currentState = state as MainGridLoaded;

    // If showing search results, don't update unless card matches search
    if (currentState.isSearchResult && currentState.searchQuery != null) {
      final query = currentState.searchQuery!.toLowerCase();
      final content = event.card.content.toLowerCase();
      final body = event.card.body?.toLowerCase() ?? '';

      if (content.contains(query) || body.contains(query)) {
        emit(currentState.copyWith(cards: [event.card, ...currentState.cards]));
      }
    } else {
      // For normal view, add card to the top
      emit(currentState.copyWith(cards: [event.card, ...currentState.cards]));
    }
  }

  Future<void> _onCardDeleted(
    CardDeleted event,
    Emitter<MainGridState> emit,
  ) async {
    if (state is! MainGridLoaded) return;
    final currentState = state as MainGridLoaded;

    try {
      await _cardRepository.deleteCard(event.cardId);

      final updatedCards = currentState.cards
          .where((card) => card.id != event.cardId)
          .toList();

      emit(currentState.copyWith(cards: updatedCards));
    } catch (e) {
      emit(MainGridError('Failed to delete card: ${e.toString()}'));
    }
  }

  Future<void> _onSearchCards(
    SearchCards event,
    Emitter<MainGridState> emit,
  ) async {
    try {
      emit(MainGridLoading(isFirstLoad: false));

      final searchResults = await _cardRepository.searchCards(event.query);

      emit(
        MainGridLoaded(
          cards: searchResults,
          hasReachedMax: true, // No pagination for search results
          searchQuery: event.query,
          isSearchResult: true,
        ),
      );
    } catch (e) {
      emit(MainGridError('Search failed: ${e.toString()}'));
    }
  }

  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<MainGridState> emit,
  ) async {
    try {
      emit(MainGridLoading(isFirstLoad: false));

      final cards = await _cardRepository.getAllCards(limit: _pageSize);
      final hasReachedMax = cards.length < _pageSize;

      emit(
        MainGridLoaded(
          cards: cards,
          hasReachedMax: hasReachedMax,
          searchQuery: null,
          isSearchResult: false,
        ),
      );
    } catch (e) {
      emit(MainGridError('Failed to load cards: ${e.toString()}'));
    }
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<MainGridState> emit,
  ) async {
    final query = event.query.trim();

    // If query is empty, clear search
    if (query.isEmpty) {
      add(const ClearSearch());
      return;
    }

    // Only perform search if query is at least 2 characters
    if (query.length >= 2) {
      try {
        // Show loading state but maintain previous cards if available
        if (state is MainGridLoaded) {
          emit(
            (state as MainGridLoaded).copyWith(
              searchQuery: query,
              isSearchResult: true,
            ),
          );
        } else {
          emit(MainGridLoading(isFirstLoad: false));
        }

        final searchResults = await _cardRepository.searchCards(query);

        if (state is MainGridLoaded) {
          emit(
            (state as MainGridLoaded).copyWith(
              cards: searchResults,
              hasReachedMax: true, // No pagination for search results
              searchQuery: query,
              isSearchResult: true,
            ),
          );
        } else {
          emit(
            MainGridLoaded(
              cards: searchResults,
              hasReachedMax: true,
              searchQuery: query,
              isSearchResult: true,
            ),
          );
        }
      } catch (e) {
        // Don't emit error state for live search - just keep current state
        if (state is! MainGridLoaded) {
          // If we don't have any cards to show, we must show an error
          emit(MainGridError('Search failed: ${e.toString()}'));
        }
        print('Search query changed error: ${e.toString()}');
      }
    }
  }
}

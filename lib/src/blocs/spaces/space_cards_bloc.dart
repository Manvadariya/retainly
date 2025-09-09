import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/card_entity.dart';
import '../../data/repository/card_repository.dart';

// Events
abstract class SpaceCardsEvent extends Equatable {
  const SpaceCardsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSpaceCards extends SpaceCardsEvent {
  final int spaceId;
  final int offset;
  final int limit;

  const LoadSpaceCards(this.spaceId, {this.offset = 0, this.limit = 40});

  @override
  List<Object> get props => [spaceId, offset, limit];
}

class MoveCardToSpace extends SpaceCardsEvent {
  final int cardId;
  final int? targetSpaceId;

  const MoveCardToSpace(this.cardId, this.targetSpaceId);

  @override
  List<Object?> get props => [cardId, targetSpaceId];
}

class AddCardToSpace extends SpaceCardsEvent {
  final CardEntity card;
  final int spaceId;

  const AddCardToSpace(this.card, this.spaceId);

  @override
  List<Object> get props => [card, spaceId];
}

// States
abstract class SpaceCardsState extends Equatable {
  const SpaceCardsState();

  @override
  List<Object?> get props => [];
}

class SpaceCardsLoading extends SpaceCardsState {
  const SpaceCardsLoading();
}

class SpaceCardsLoaded extends SpaceCardsState {
  final List<CardEntity> cards;
  final int spaceId;
  final bool hasMore;
  final int offset;

  const SpaceCardsLoaded({
    required this.cards,
    required this.spaceId,
    this.hasMore = false,
    this.offset = 0,
  });

  @override
  List<Object> get props => [cards, spaceId, hasMore, offset];
}

class SpaceCardsError extends SpaceCardsState {
  final String message;

  const SpaceCardsError(this.message);

  @override
  List<Object> get props => [message];
}

// Bloc
class SpaceCardsBloc extends Bloc<SpaceCardsEvent, SpaceCardsState> {
  final CardRepository _cardRepository;
  final int pageSize = 40;

  SpaceCardsBloc({required CardRepository cardRepository})
    : _cardRepository = cardRepository,
      super(const SpaceCardsLoading()) {
    on<LoadSpaceCards>(_onLoadSpaceCards);
    on<MoveCardToSpace>(_onMoveCardToSpace);
    on<AddCardToSpace>(_onAddCardToSpace);
  }

  Future<void> _onLoadSpaceCards(
    LoadSpaceCards event,
    Emitter<SpaceCardsState> emit,
  ) async {
    print('SpaceCardsBloc: Loading cards for space ID: ${event.spaceId}');
    if (event.offset == 0) {
      // First load or refresh
      emit(const SpaceCardsLoading());
    }

    try {
      // Load cards for this space
      final cards = await _cardRepository.getCardsBySpaceId(
        event.spaceId,
        offset: event.offset,
        limit: event.limit,
      );

      print(
        'SpaceCardsBloc: Loaded ${cards.length} cards for space ID: ${event.spaceId}',
      );

      // Log image cards
      final imageCards = cards.where((card) => card.type == 'image').toList();
      print('SpaceCardsBloc: Found ${imageCards.length} image cards');
      for (final card in imageCards) {
        print(
          'SpaceCardsBloc: Image card ID: ${card.id}, path: ${card.imagePath}',
        );
      }

      // If we got a full page, there might be more
      final hasMore = cards.length == event.limit;

      // Add to existing list for pagination, or use as initial list
      if (event.offset > 0 && state is SpaceCardsLoaded) {
        final currentState = state as SpaceCardsLoaded;
        final updatedCards = [...currentState.cards, ...cards];
        emit(
          SpaceCardsLoaded(
            cards: updatedCards,
            spaceId: event.spaceId,
            hasMore: hasMore,
            offset: event.offset + cards.length,
          ),
        );
      } else {
        emit(
          SpaceCardsLoaded(
            cards: cards,
            spaceId: event.spaceId,
            hasMore: hasMore,
            offset: cards.length,
          ),
        );
      }
    } catch (e) {
      emit(SpaceCardsError(e.toString()));
    }
  }

  Future<void> _onMoveCardToSpace(
    MoveCardToSpace event,
    Emitter<SpaceCardsState> emit,
  ) async {
    try {
      await _cardRepository.moveCardToSpace(event.cardId, event.targetSpaceId);

      // If this is a move from the current space, refresh the list
      if (state is SpaceCardsLoaded) {
        final currentState = state as SpaceCardsLoaded;
        if (event.targetSpaceId != currentState.spaceId) {
          // The card was moved out, reload cards for the current space
          add(LoadSpaceCards(currentState.spaceId));
        }
      }
    } catch (e) {
      emit(SpaceCardsError(e.toString()));
    }
  }

  Future<void> _onAddCardToSpace(
    AddCardToSpace event,
    Emitter<SpaceCardsState> emit,
  ) async {
    try {
      await _cardRepository.addCardToSpace(event.card, event.spaceId);

      // If this card was added to the current space, refresh the list
      if (state is SpaceCardsLoaded) {
        final currentState = state as SpaceCardsLoaded;
        if (event.spaceId == currentState.spaceId) {
          // The card was added to this space, reload cards
          add(LoadSpaceCards(currentState.spaceId));
        }
      }
    } catch (e) {
      emit(SpaceCardsError(e.toString()));
    }
  }
}

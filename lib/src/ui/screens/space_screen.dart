import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/spaces/space_cards_bloc.dart';
import '../../data/card_entity.dart';
import '../../data/repository/card_repository.dart';
import '../../data/space_entity.dart';
import '../widgets/card_grid.dart';
import '../widgets/card/add_text_card_to_space_modal.dart';
import '../widgets/card/add_link_card_to_space_modal.dart';

class SpaceScreen extends StatefulWidget {
  final SpaceEntity space;

  const SpaceScreen({super.key, required this.space});

  @override
  State<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends State<SpaceScreen> {
  late SpaceCardsBloc _spaceCardsBloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _spaceCardsBloc = SpaceCardsBloc(
      cardRepository: context.read<CardRepository>(),
    );
    _spaceCardsBloc.add(LoadSpaceCards(widget.space.id!));

    // Set up scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _spaceCardsBloc.close();
    super.dispose();
  }

  void _onScroll() {
    // Load more when reaching the bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final state = _spaceCardsBloc.state;
      if (state is SpaceCardsLoaded && state.hasMore) {
        _spaceCardsBloc.add(
          LoadSpaceCards(widget.space.id!, offset: state.offset),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _spaceCardsBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.space.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddCardOptions(context),
              tooltip: 'Add Card',
            ),
          ],
        ),
        body: BlocBuilder<SpaceCardsBloc, SpaceCardsState>(
          builder: (context, state) {
            if (state is SpaceCardsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is SpaceCardsLoaded) {
              return state.cards.isEmpty
                  ? _buildEmptyState()
                  : _buildCardsList(state.cards);
            } else if (state is SpaceCardsError) {
              return Center(child: Text('Error: ${state.message}'));
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No cards in this space',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add cards to this space by creating new ones\nor moving them from the global view',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Card'),
            onPressed: () => _showAddCardOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsList(List<CardEntity> cards) {
    return RefreshIndicator(
      onRefresh: () async {
        _spaceCardsBloc.add(LoadSpaceCards(widget.space.id!));
      },
      child: CardGrid(
        cards: cards,
        scrollController: _scrollController,
        onCardSelected: (card) {
          // Navigate to card detail/edit screen
          if (card.id != null) {
            Navigator.pushNamed(
              context,
              '/cardDetail',
              arguments: card.id,
            ).then((_) {
              // Refresh cards when returning from detail screen
              _spaceCardsBloc.add(LoadSpaceCards(widget.space.id!));
            });
          }
        },
        onCardLongPress: (card) {
          // Show move card options
          _showCardOptions(context, card);
        },
      ),
    );
  }

  void _showAddCardOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Add to Space',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // Text card option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF303030),
                  child: Icon(Icons.text_fields, color: Colors.white),
                ),
                title: const Text(
                  'Text Note',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Create a text note',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        // Use MultiBlocProvider to provide repositories and blocs
                        RepositoryProvider<CardRepository>.value(
                          value: context.read<CardRepository>(),
                          child: AddTextCardToSpaceModal(
                            spaceId: widget.space.id!,
                          ),
                        ),
                  );
                  if (result == true) {
                    // Refresh cards in this space
                    _spaceCardsBloc.add(LoadSpaceCards(widget.space.id!));
                  }
                },
              ),
              // Link card option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF303030),
                  child: Icon(Icons.link, color: Colors.white),
                ),
                title: const Text(
                  'Link',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Add a link card',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        RepositoryProvider<CardRepository>.value(
                          value: context.read<CardRepository>(),
                          child: AddLinkCardToSpaceModal(
                            spaceId: widget.space.id!,
                          ),
                        ),
                  );
                  if (result == true) {
                    _spaceCardsBloc.add(LoadSpaceCards(widget.space.id!));
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showCardOptions(BuildContext context, CardEntity card) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove from Space'),
                subtitle: const Text('Move to global view'),
                onTap: () {
                  Navigator.pop(context);
                  _spaceCardsBloc.add(MoveCardToSpace(card.id!, null));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Card'),
                subtitle: const Text('Remove completely'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement delete card functionality
                  // This should use the card repository's delete method
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

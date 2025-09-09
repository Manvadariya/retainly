import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/spaces/spaces_bloc.dart';
import '../../data/space_entity.dart';
import '../../ui/screens/space_screen.dart';

class SpacesPanel extends StatelessWidget {
  const SpacesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpacesBloc, SpacesState>(
      builder: (context, state) {
        if (state is SpacesLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is SpacesLoaded) {
          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: state.spaces.isEmpty
                    ? _buildEmptyState(context)
                    : _buildSpacesList(context, state.spaces),
              ),
            ],
          );
        } else if (state is SpacesError) {
          return Center(child: Text('Error: ${state.message}'));
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Spaces',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSpaceDialog(context),
            tooltip: 'Create New Space',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No spaces yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create spaces to organize your cards',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Space'),
            onPressed: () => _showAddSpaceDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacesList(BuildContext context, List<SpaceEntity> spaces) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: spaces.length,
      itemBuilder: (context, index) {
        final space = spaces[index];
        return _buildSpaceListItem(context, space);
      },
    );
  }

  Widget _buildSpaceListItem(BuildContext context, SpaceEntity space) {
    final cardCount = space.cardCount ?? 0;
    final formatter = DateFormat.yMMMd();
    final dateCreated = formatter.format(
      DateTime.fromMillisecondsSinceEpoch(space.createdAt),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _navigateToSpace(context, space),
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        space.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showEditSpaceDialog(context, space);
                            break;
                          case 'delete':
                            _showDeleteSpaceDialog(context, space);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$cardCount ${cardCount == 1 ? 'card' : 'cards'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Created $dateCreated',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSpace(BuildContext context, SpaceEntity space) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SpaceScreen(space: space)));
  }

  void _showAddSpaceDialog(BuildContext context) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Space'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Space Name',
            labelText: 'Name',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                context.read<SpacesBloc>().add(AddSpace(name));
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditSpaceDialog(BuildContext context, SpaceEntity space) {
    final textController = TextEditingController(text: space.name);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Space'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Space Name',
            labelText: 'Name',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                context.read<SpacesBloc>().add(
                  UpdateSpace(space.copyWith(name: name)),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSpaceDialog(BuildContext context, SpaceEntity space) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Space'),
        content: Text(
          'Are you sure you want to delete "${space.name}"? '
          'Cards in this space will remain in your collection but will be moved to the global view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SpacesBloc>().add(DeleteSpace(space.id!));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

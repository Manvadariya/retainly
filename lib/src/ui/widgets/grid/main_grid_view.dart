import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../bloc/main_grid/main_grid_bloc.dart';
import '../../../bloc/main_grid/main_grid_event.dart';
import '../../../bloc/main_grid/main_grid_state.dart';
import '../../../data/card_entity.dart';
import '../../../ui/theme/app_theme.dart';
// Use the new implementation to fix setState during build issues
import 'card_tile_new.dart';

class MainGridView extends StatefulWidget {
  const MainGridView({super.key});

  @override
  State<MainGridView> createState() => _MainGridViewState();
}

class _MainGridViewState extends State<MainGridView> {
  final _scrollController = ScrollController();
  bool _isBottomLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isNearBottom && !_isBottomLoading) {
      setState(() => _isBottomLoading = true);
      context.read<MainGridBloc>().add(const LoadMoreCards());
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isBottomLoading = false);
      });
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // Load more when reached 80% of the scroll
    return currentScroll >= (maxScroll * 0.8);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainGridBloc, MainGridState>(
      builder: (context, state) {
        if (state is MainGridInitial) {
          // Trigger loading when first built
          context.read<MainGridBloc>().add(const LoadCards());
          return _buildLoadingView();
        } else if (state is MainGridLoading && state.isFirstLoad) {
          return _buildLoadingView();
        } else if (state is MainGridError) {
          return _buildErrorView(state.message);
        } else if (state is MainGridLoaded) {
          return _buildGridView(state);
        }

        // Fallback for any other state
        return _buildLoadingView();
      },
    );
  }

  Widget _buildLoadingView() {
    // Calculate columns based on screen width (3 columns for tablets, 4 for large screens)
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 4
        : width > 600
        ? 3
        : 2;

    return Container(
      color: AppTheme.surfaceColor,
      child: CustomScrollView(
        slivers: [
          // Shimmer header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Shimmer.fromColors(
                baseColor: AppTheme.cardColor,
                highlightColor: AppTheme.cardColor.withOpacity(0.5),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          // Shimmer grid of loading cards
          SliverPadding(
            padding: const EdgeInsets.all(12.0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.7,
                mainAxisSpacing: 12.0,
                crossAxisSpacing: 12.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Shimmer.fromColors(
                    baseColor: AppTheme.cardColor,
                    highlightColor: AppTheme.cardColor.withOpacity(0.5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                childCount:
                    crossAxisCount * 4, // Show 4 rows of shimmering cards
              ),
            ),
          ),

          // Add loading indicator at bottom
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your cards...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom padding for navigation
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Container(
      color: AppTheme.surfaceColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated error icon with a subtle bounce effect
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.errorColor,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Error',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppTheme.errorColor),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  // Add a small haptic feedback if available
                  HapticFeedback.mediumImpact();
                  context.read<MainGridBloc>().add(const LoadCards());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(MainGridLoaded state) {
    final cards = state.cards;
    // Calculate columns based on screen width (3 columns for tablets, 4 for large screens)
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 4
        : width > 600
        ? 3
        : 2;

    if (cards.isEmpty) {
      return _buildEmptyView(state.isSearchResult);
    }

    return Container(
      color: AppTheme.surfaceColor,
      child: RefreshIndicator(
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.surfaceVariantColor,
        onRefresh: () async {
          context.read<MainGridBloc>().add(const LoadCards(refresh: true));
          // Wait for refresh to complete
          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          slivers: [
            // Search indicator if showing search results
            if (state.isSearchResult && state.searchQuery != null)
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.surfaceVariantColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Results for "${state.searchQuery}"',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 18,
                        ),
                        onPressed: () => context.read<MainGridBloc>().add(
                          const ClearSearch(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Grid of cards with improved spacing
            SliverPadding(
              padding: const EdgeInsets.all(12.0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.7, // Card aspect ratio (more vertical)
                  mainAxisSpacing: 12.0,
                  crossAxisSpacing: 12.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCardItem(cards[index]),
                  childCount: cards.length,
                ),
              ),
            ),

            // Shimmer loading indicator for pagination
            if (!state.hasReachedMax && cards.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[700]!,
                      child: Column(
                        children: [
                          Container(
                            width: 160,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 120,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom padding to ensure cards are above bottom navigation bar
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isSearchResult) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: Column(
            key: ValueKey<bool>(isSearchResult),
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                child: isSearchResult
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search_off,
                          color: AppTheme.primaryColor,
                          size: 64,
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          color: AppTheme.primaryColor,
                          size: 64,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              Text(
                isSearchResult ? 'No results found' : 'No media cards yet.',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 12),

              Text(
                isSearchResult
                    ? 'Try a different search term'
                    : 'Tap + to create one.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              if (isSearchResult) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.onPrimaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () =>
                      context.read<MainGridBloc>().add(const ClearSearch()),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Search'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem(CardEntity card) {
    return CardTile(
      card: card,
      onTap: () {
        if (card.id != null) {
          Navigator.pushNamed(context, '/cardDetail', arguments: card.id).then((
            result,
          ) {
            if (result == true) {
              // Refresh the grid if card was deleted
              context.read<MainGridBloc>().add(const LoadCards(refresh: true));
            }
          });
        }
      },
      onDelete: () {
        _showDeleteConfirmation(card);
      },
    );
  }

  void _showDeleteConfirmation(CardEntity card) {
    // Get the bloc reference before the dialog
    final mainGridBloc = BlocProvider.of<MainGridBloc>(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: mainGridBloc,
          child: Builder(
            builder: (builderContext) {
              // Ensure we have a proper Material widget ancestor
              return Material(
                type: MaterialType.transparency,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: AppTheme.surfaceVariantColor,
                  title: const Text(
                    'Delete Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  content: Text(
                    'Are you sure you want to delete "${card.content}"?',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('CANCEL'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (card.id != null) {
                          // Use the builderContext which has access to the provided bloc
                          builderContext.read<MainGridBloc>().add(
                            CardDeleted(card.id!),
                          );
                        }
                        Navigator.of(dialogContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('DELETE'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

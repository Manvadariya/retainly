import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../../bloc/main_grid/main_grid_bloc.dart';
import '../../bloc/main_grid/main_grid_event.dart';
import '../../data/repository/card_repository.dart';
import '../../data/repository/space_repository.dart';
import '../widgets/grid/main_grid_view.dart';
import '../widgets/tabs/spaces_tab.dart';
import '../widgets/card/add_text_card_modal.dart';
import '../widgets/card/add_image_card_modal.dart';
import '../widgets/card/add_link_card_modal.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MainGridBloc _mainGridBloc;
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  Timer? _searchDebounceTimer;

  // Define the navigation items
  final List<_NavItem> _navItems = const [
    _NavItem(label: 'Everything', icon: Icons.grid_view_rounded),
    _NavItem(label: 'Spaces', icon: Icons.folder_rounded),
    _NavItem(label: 'Serendipity', icon: Icons.auto_awesome),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize BLoC with repository
    _mainGridBloc = MainGridBloc(cardRepository: CardRepository());

    // Setup search controller listener
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _mainGridBloc.close(); // Clean up the BLoC when screen is disposed
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous debounce timer
    _searchDebounceTimer?.cancel();

    final query = _searchController.text;

    // Debounce search for 300ms to avoid excessive DB queries
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _mainGridBloc.add(SearchQueryChanged(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _mainGridBloc,
      child: Scaffold(
        backgroundColor:
            AppTheme.scaffoldBackgroundColor, // Material 3 dark theme
        appBar: _buildAppBar(),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNavBar(),
        floatingActionButton: AnimatedScale(
          scale: _searchController.text.isEmpty ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: FloatingActionButton.extended(
            onPressed: () {
              // Add haptic feedback
              HapticFeedback.mediumImpact();
              _addNewCard(context);
            },
            backgroundColor: AppTheme.primaryColor,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: const Icon(
                Icons.add,
                key: ValueKey('add-icon'),
                color: Colors.white,
              ),
            ),
            label: const Text('Create'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Switch between different tabs based on _selectedIndex
    switch (_selectedIndex) {
      case 0: // Everything (Main Grid)
        return const MainGridView();
      case 1: // Spaces
        return const SpacesTab();
      case 2: // Serendipity
        return const Center(
          child: Text(
            'Serendipity feature coming soon!',
            style: TextStyle(color: Colors.white70),
          ),
        );
      default:
        return const MainGridView();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surfaceVariantColor,
      elevation: 0,
      automaticallyImplyLeading:
          false, // This prevents the back button from appearing
      title: const Text(
        'Retainly',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      actions: [],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _buildSearchBar(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search cards...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _mainGridBloc.add(const ClearSearch());
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            FocusScope.of(context).unfocus();
          }
        },
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final isSelected = index == _selectedIndex;

              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedIndex = index);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _navItems[index].icon,
                        color: isSelected ? AppTheme.primaryColor : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _navItems[index].label,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _addNewCard(BuildContext context) async {
    final action = await showModalBottomSheet<_FabAction>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FabOptionsSheet(),
    );

    if (action == _FabAction.text) {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const AddTextCardModal(),
      );
      if (result == true) {
        _mainGridBloc.add(const LoadCards(refresh: true));
      }
    } else if (action == _FabAction.image) {
      // Ask for image source
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _ImageSourceSheet(),
      );
      if (source != null) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: source, imageQuality: 95);
        if (picked != null) {
          final file = File(picked.path);
          final result = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddImageCardModal(imageFile: file),
          );
          if (result == true) {
            _mainGridBloc.add(const LoadCards(refresh: true));
          }
        }
      }
    } else if (action == _FabAction.link) {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const AddLinkCardModal(),
      );
      if (result == true) {
        _mainGridBloc.add(const LoadCards(refresh: true));
      }
    }
  }
}

enum _FabAction { text, image, link }

class _FabOptionsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.dividerColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: const Center(
              child: Text(
                'Create New Card',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Card options
          _buildOptionItem(
            context,
            icon: Icons.text_snippet,
            title: 'Text Card',
            subtitle: 'Create a card with formatted text',
            action: _FabAction.text,
            color: Colors.blue,
          ),
          _buildOptionItem(
            context,
            icon: Icons.image,
            title: 'Image Card',
            subtitle: 'Upload an image with optional caption',
            action: _FabAction.image,
            color: Colors.green,
          ),
          _buildOptionItem(
            context,
            icon: Icons.link,
            title: 'Link Card',
            subtitle: 'Save a link with preview',
            action: _FabAction.link,
            color: Colors.purple,
          ),

          // Bottom padding
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required _FabAction action,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop(action);
          },
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.surfaceVariantColor,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.dividerColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: const Center(
              child: Text(
                'Select Image Source',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Source options with grid layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  context,
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  source: ImageSource.gallery,
                  color: Colors.blue,
                ),
                _buildSourceOption(
                  context,
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  source: ImageSource.camera,
                  color: Colors.green,
                ),
              ],
            ),
          ),

          // Bottom padding
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSourceOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ImageSource source,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(source);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariantColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for navigation items
class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem({required this.label, required this.icon});
}

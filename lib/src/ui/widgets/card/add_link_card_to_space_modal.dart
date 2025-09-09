import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repository/card_repository.dart';
import '../../../data/card_entity.dart';

class AddLinkCardToSpaceModal extends StatefulWidget {
  final String? initialUrl;
  final bool autofocusSave;
  final int spaceId;

  const AddLinkCardToSpaceModal({
    super.key,
    this.initialUrl,
    this.autofocusSave = false,
    required this.spaceId,
  });

  @override
  State<AddLinkCardToSpaceModal> createState() =>
      _AddLinkCardToSpaceModalState();
}

class _AddLinkCardToSpaceModalState extends State<AddLinkCardToSpaceModal> {
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaveEnabled = false;
  bool _isAnalyzing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();

    _urlController.addListener(_validateInput);
    _titleController.addListener(_validateInput);

    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      _analyzeLink();
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_validateInput);
    _titleController.removeListener(_validateInput);
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final hasUrl = _isValidUrl(_urlController.text.trim());
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final isValid = hasUrl && hasTitle;

    if (isValid != _isSaveEnabled) {
      setState(() {
        _isSaveEnabled = isValid;
      });
    }
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  Future<void> _analyzeLink() async {
    final url = _urlController.text.trim();
    if (!_isValidUrl(url)) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // This is a placeholder for the actual link analysis functionality
      // In a real implementation, we would fetch metadata from the URL
      // For now, we'll just set a title if none exists
      if (_titleController.text.isEmpty) {
        _titleController.text = 'Link to ${Uri.parse(url).host}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final cardRepository = context.read<CardRepository>();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final card = CardEntity(
        type: 'link',
        content: _titleController.text.trim(),
        body: _descriptionController.text.trim(),
        url: _urlController.text.trim(),
        spaceId: widget.spaceId,
        createdAt: now,
        updatedAt: now,
      );

      await cardRepository.addCard(card);
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildUrlForm(),
            _buildTitleForm(),
            _buildDescriptionForm(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF303030), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: Colors.white),
          const SizedBox(width: 16),
          const Text(
            'Add Link to Space',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'URL',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter URL...',
              hintStyle: const TextStyle(color: Colors.grey),
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF303030)),
              ),
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: _isAnalyzing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search, color: Colors.white70),
                      onPressed: () => _analyzeLink(),
                    ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a URL';
              }
              if (!_isValidUrl(value.trim())) {
                return 'Please enter a valid URL';
              }
              return null;
            },
            autofocus: widget.initialUrl == null,
            onFieldSubmitted: (_) => _analyzeLink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Title',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter link title...',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF303030)),
              ),
              contentPadding: EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
            autofocus: widget.initialUrl != null,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description (optional)',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter description...',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF303030)),
              ),
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF303030), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF303030),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: !_isSaveEnabled || _isLoading
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      HapticFeedback.mediumImpact();
                      _saveCard();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              disabledBackgroundColor: Colors.blueAccent.withOpacity(0.3),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

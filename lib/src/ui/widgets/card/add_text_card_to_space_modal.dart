import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repository/card_repository.dart';
import '../../../data/card_entity.dart';

class AddTextCardToSpaceModal extends StatefulWidget {
  final String? initialText;
  final bool autofocusSave;
  final int spaceId;

  const AddTextCardToSpaceModal({
    super.key,
    this.initialText,
    this.autofocusSave = false,
    required this.spaceId,
  });

  @override
  State<AddTextCardToSpaceModal> createState() =>
      _AddTextCardToSpaceModalState();
}

class _AddTextCardToSpaceModalState extends State<AddTextCardToSpaceModal> {
  late final TextEditingController _textController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaveEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    _textController.addListener(_validateInput);
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _isSaveEnabled = true;
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_validateInput);
    _textController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final isValid = _textController.text.trim().length >= 2;
    if (isValid != _isSaveEnabled) {
      setState(() {
        _isSaveEnabled = isValid;
      });
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
        type: 'text',
        content: _textController.text.trim().split('\n').first,
        body: _textController.text.trim(),
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
          children: [_buildHeader(), _buildTextForm(), _buildFooter()],
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
          const Icon(Icons.text_fields, color: Colors.white),
          const SizedBox(width: 16),
          const Text(
            'Add Text Note to Space',
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

  Widget _buildTextForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _textController,
            maxLines: 10,
            minLines: 5,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter your note...',
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

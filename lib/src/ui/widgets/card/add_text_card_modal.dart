import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/add_card/add_card_bloc.dart';
import '../../../bloc/add_card/add_card_event.dart';
import '../../../bloc/add_card/add_card_state.dart';
import '../../../data/repository/card_repository.dart';

class AddTextCardModal extends StatefulWidget {
  final String? initialText;
  final bool autofocusSave;
  const AddTextCardModal({
    super.key,
    this.initialText,
    this.autofocusSave = false,
  });

  @override
  State<AddTextCardModal> createState() => _AddTextCardModalState();
}

class _AddTextCardModalState extends State<AddTextCardModal> {
  late final TextEditingController _textController;
  final _formKey = GlobalKey<FormState>();
  final List<String> _tags = [];
  final _tagController = TextEditingController();
  bool _isSaveEnabled = false;

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
    _tagController.dispose();
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

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddCardBloc(cardRepository: CardRepository()),
      child: BlocConsumer<AddCardBloc, AddCardState>(
        listener: (context, state) {
          if (state is AddCardSuccess) {
            Navigator.of(context).pop(true);
          } else if (state is AddCardFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed: ${state.error}')));
          }
        },
        builder: (context, state) {
          return Material(
            // Use actual color instead of transparent for Material widget with TextField
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title bar with close button
                    Row(
                      children: [
                        const Text(
                          'New Text Card',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Note content input
                    TextFormField(
                      controller: _textController,
                      autofocus: true,
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFF262626),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Please enter at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Tags input
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tagController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add a tag (optional)',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: const Color(0xFF262626),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.grey,
                                ),
                                onPressed: _addTag,
                              ),
                            ),
                            onFieldSubmitted: (_) => _addTag(),
                          ),
                        ),
                      ],
                    ),

                    // Tags display
                    if (_tags.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        height: 32,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _tags.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: Chip(
                                backgroundColor: Colors.orangeAccent
                                    .withOpacity(0.3),
                                label: Text(
                                  _tags[index],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                deleteIconColor: Colors.white70,
                                onDeleted: () => _removeTag(_tags[index]),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Cancel button
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                          child: const Text('CANCEL'),
                        ),

                        const SizedBox(width: 16),

                        // Save button
                        ElevatedButton(
                          autofocus: widget.autofocusSave,
                          onPressed: _isSaveEnabled && state is! AddCardSaving
                              ? () {
                                  if (_formKey.currentState?.validate() ??
                                      false) {
                                    context.read<AddCardBloc>().add(
                                      AddTextCardRequested(
                                        content: _textController.text.trim(),
                                        tags: _tags,
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            disabledBackgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: state is AddCardSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('SAVE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

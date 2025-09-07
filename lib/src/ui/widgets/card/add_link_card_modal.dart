import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/add_card/add_card_bloc.dart';
import '../../../bloc/add_card/add_card_event.dart';
import '../../../bloc/add_card/add_card_state.dart';
import '../../../data/repository/card_repository.dart';

class AddLinkCardModal extends StatefulWidget {
  final String? initialUrl;
  final String? initialTitle;
  final bool autofocusSave;
  const AddLinkCardModal({
    super.key,
    this.initialUrl,
    this.initialTitle,
    this.autofocusSave = false,
  });

  @override
  State<AddLinkCardModal> createState() => _AddLinkCardModalState();
}

class _AddLinkCardModalState extends State<AddLinkCardModal> {
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  final _formKey = GlobalKey<FormState>();
  late final AddCardBloc _addCardBloc;

  bool _isUrlValid = false;
  bool _isFetching = false;
  String? _fetchError;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _addCardBloc = AddCardBloc(cardRepository: CardRepository());
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _urlController.addListener(_onUrlChanged);
    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      _isUrlValid = _isValidUrl(widget.initialUrl!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _titleController.dispose();
    _addCardBloc.close();
    super.dispose();
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    final isValid = _isValidUrl(url);

    if (isValid != _isUrlValid) {
      setState(() {
        _isUrlValid = isValid;
        _fetchError = null;
      });

      // Only fetch if URL is valid
      if (isValid) {
        // Debounce the fetch operation
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          _fetchTitle();
        });
      }
    }
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;

    // Simple URL validation using RegExp
    final RegExp urlRegExp = RegExp(
      r'^(https?:\/\/)?'
      r'(www\.)?'
      r'[-a-zA-Z0-9@:%._\+~#=]{1,256}'
      r'\.[a-zA-Z0-9()]{1,6}'
      r'([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
      multiLine: false,
    );

    return urlRegExp.hasMatch(url);
  }

  Future<void> _fetchTitle() async {
    if (!_isUrlValid || _isFetching) return;

    setState(() {
      _isFetching = true;
      _fetchError = null;
    });

    try {
      final url = _urlController.text.trim();
      // URL normalization - ensure it starts with http:// or https://
      String normalizedUrl = url;
      if (!normalizedUrl.startsWith('http://') &&
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }

      // Update the URL field with normalized URL
      if (normalizedUrl != url) {
        _urlController.text = normalizedUrl;
      }

      // Add event to fetch title
      _addCardBloc.add(FetchTitleRequested(url: normalizedUrl));
    } catch (e) {
      setState(() {
        _fetchError = 'Failed to fetch title: ${e.toString()}';
        _isFetching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _addCardBloc,
      child: BlocConsumer<AddCardBloc, AddCardState>(
        listener: (context, state) {
          if (state is TitleFetched) {
            _titleController.text = state.title;
            setState(() {
              _isFetching = false;
            });
          } else if (state is AddCardFailure) {
            setState(() {
              _fetchError = state.error;
              _isFetching = false;
            });
          } else if (state is AddCardSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link saved successfully')),
            );
            Navigator.of(context).pop(true);
          }
        },
        builder: (context, state) {
          return Material(
            // Don't use transparent color for Material widget when using TextField
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
                    // Title bar
                    Row(
                      children: [
                        const Text(
                          'New Link Card',
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

                    // URL input field
                    TextFormField(
                      controller: _urlController,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter URL (https://example.com)',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFF262626),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        suffixIcon: _isFetching
                            ? Container(
                                width: 24,
                                height: 24,
                                padding: const EdgeInsets.all(12),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  Icons.refresh,
                                  color: _isUrlValid
                                      ? Colors.orangeAccent
                                      : Colors.grey,
                                ),
                                onPressed: _isUrlValid && !_isFetching
                                    ? _fetchTitle
                                    : null,
                                tooltip: 'Fetch page title',
                              ),
                        errorText: _fetchError,
                        errorMaxLines: 2,
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
                    ),

                    const SizedBox(height: 16),

                    // Title input field
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFF262626),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                          child: const Text('CANCEL'),
                        ),

                        const SizedBox(width: 16),

                        ElevatedButton(
                          autofocus: widget.autofocusSave,
                          onPressed:
                              (_isUrlValid &&
                                  !_isFetching &&
                                  state is! AddCardSaving)
                              ? () {
                                  if (_formKey.currentState?.validate() ??
                                      false) {
                                    final url = _urlController.text.trim();
                                    final title = _titleController.text.trim();

                                    _addCardBloc.add(
                                      AddLinkCardRequested(
                                        url: url,
                                        title: title,
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
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

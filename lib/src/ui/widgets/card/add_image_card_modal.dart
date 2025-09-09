import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/add_card/add_card_bloc.dart';
import '../../../bloc/add_card/add_card_event.dart';
import '../../../bloc/add_card/add_card_state.dart';
import '../../../data/repository/card_repository.dart';

class AddImageCardModal extends StatefulWidget {
  final File? imageFile;
  final String? imagePath;
  final bool autofocusSave;
  const AddImageCardModal({
    super.key,
    this.imageFile,
    this.imagePath,
    this.autofocusSave = false,
  });

  @override
  State<AddImageCardModal> createState() => _AddImageCardModalState();
}

class _AddImageCardModalState extends State<AddImageCardModal> {
  final _captionController = TextEditingController();
  File? _fileToShow;
  bool _userInitiatedSave = false;

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  Future<void> _initializeImage() async {
    try {
      if (widget.imageFile != null) {
        print('AddImageCardModal: Using provided File object');
        _fileToShow = widget.imageFile;
      } else if (widget.imagePath != null) {
        print(
          'AddImageCardModal: Loading image from path: ${widget.imagePath}',
        );
        final file = File(widget.imagePath!);

        if (await file.exists()) {
          print(
            'AddImageCardModal: File exists, size: ${await file.length()} bytes',
          );
          setState(() {
            _fileToShow = file;
          });
        } else {
          print(
            'AddImageCardModal: Error - File does not exist at ${widget.imagePath}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image file not found or inaccessible'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        print('AddImageCardModal: No image source provided');
      }
    } catch (e) {
      print('AddImageCardModal: Error initializing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading image: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddCardBloc(cardRepository: CardRepository()),
      child: BlocConsumer<AddCardBloc, AddCardState>(
        listener: (context, state) {
          if (state is AddCardSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image saved successfully'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            // Only pop if the user initiated saving via the save button
            if (_userInitiatedSave) {
              Navigator.of(context).pop(true);
            }
          } else if (state is AddCardError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed: ${state.message}')));
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Image Preview',
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
                  const SizedBox(height: 12),
                  _fileToShow != null
                      ? AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Builder(
                              builder: (context) {
                                try {
                                  return Image.file(
                                    _fileToShow!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print(
                                        'AddImageCardModal: Error rendering image: $error',
                                      );
                                      return Container(
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.white54,
                                            size: 64,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                } catch (e) {
                                  print(
                                    'AddImageCardModal: Exception in image builder: $e',
                                  );
                                  return Container(
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: Icon(
                                        Icons.error_outline,
                                        color: Colors.redAccent,
                                        size: 64,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        )
                      // Show placeholder if no image
                      : AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.white54,
                                size: 64,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a caption (optional)',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: const Color(0xFF262626),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        autofocus: widget.autofocusSave,
                        onPressed: state is AddCardLoading
                            ? null
                            : () {
                                // Mark that user initiated this save
                                _userInitiatedSave = true;

                                context.read<AddCardBloc>().add(
                                  AddImageCardRequested(
                                    imagePath: _fileToShow?.path ?? '',
                                    caption:
                                        _captionController.text.trim().isEmpty
                                        ? null
                                        : _captionController.text.trim(),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: state is AddCardLoading
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
          );
        },
      ),
    );
  }
}

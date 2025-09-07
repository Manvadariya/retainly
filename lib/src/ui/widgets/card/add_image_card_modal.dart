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

  @override
  void initState() {
    super.initState();
    if (widget.imageFile != null) {
      _fileToShow = widget.imageFile;
    } else if (widget.imagePath != null) {
      _fileToShow = File(widget.imagePath!);
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
                  if (_fileToShow != null)
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_fileToShow!, fit: BoxFit.cover),
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
                        onPressed: state is AddCardSaving
                            ? null
                            : () {
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
          );
        },
      ),
    );
  }
}

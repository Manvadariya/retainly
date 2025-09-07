import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../../data/card_entity.dart';
import '../../data/repository/card_repository.dart';
import 'add_card_event.dart';
import 'add_card_state.dart';
import '../../utils/image_storage.dart';

class AddCardBloc extends Bloc<AddCardEvent, AddCardState> {
  final CardRepository cardRepository;

  AddCardBloc({required this.cardRepository}) : super(const AddCardIdle()) {
    on<AddTextCardRequested>(_onAddTextCardRequested);
    on<AddImageCardRequested>(_onAddImageCardRequested);
    on<AddLinkCardRequested>(_onAddLinkCardRequested);
    on<FetchTitleRequested>(_onFetchTitleRequested);
  }

  Future<void> _onAddTextCardRequested(
    AddTextCardRequested event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const AddCardSaving());

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final card = CardEntity(
        type: 'text',
        content: event
            .content, // Using content as both title and body for simple notes
        body: event.content,
        createdAt: now,
        updatedAt: now,
      );

      final cardId = await cardRepository.addCard(card);
      emit(AddCardSuccess(cardId));
    } catch (e) {
      emit(AddCardFailure(e.toString()));
    }
  }

  Future<void> _onAddImageCardRequested(
    AddImageCardRequested event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const AddCardSaving());

    try {
      // Persist image and thumbnail
      final storage = ImageStorage();
      final input = File(event.imagePath);
      final (original, thumbnail) = await storage.saveImageWithThumbnail(input);

      final now = DateTime.now().millisecondsSinceEpoch;
      final card = CardEntity(
        type: 'image',
        content: event.caption?.trim().isNotEmpty == true
            ? event.caption!.trim()
            : 'Image',
        body: null,
        imagePath: original.path, // store original path
        createdAt: now,
        updatedAt: now,
      );
      final cardId = await cardRepository.addCard(card);
      emit(AddCardSuccess(cardId));
    } catch (e) {
      emit(AddCardFailure(e.toString()));
    }
  }

  Future<void> _onAddLinkCardRequested(
    AddLinkCardRequested event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const AddCardSaving());

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final card = CardEntity(
        type: 'link',
        content: event.title.trim(),
        url: event.url.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final cardId = await cardRepository.addCard(card);
      emit(AddCardSuccess(cardId));
    } catch (e) {
      emit(AddCardFailure(e.toString()));
    }
  }

  Future<void> _onFetchTitleRequested(
    FetchTitleRequested event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const TitleFetching());

    try {
      // Normalize URL and ensure scheme
      String raw = event.url.trim();
      if (raw.isEmpty) {
        emit(const AddCardFailure('Empty URL'));
        return;
      }

      if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
        raw = 'https://$raw';
      }

      final uri = Uri.tryParse(raw);
      if (uri == null) {
        emit(const AddCardFailure('Invalid URL'));
        return;
      }

      final client = http.Client();
      http.Response response;
      try {
        response = await client
            .get(
              uri,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.9',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        client.close();
        emit(const AddCardFailure('Connection timed out while fetching title'));
        return;
      } on SocketException catch (e) {
        client.close();
        emit(AddCardFailure('Network error: ${e.message}'));
        return;
      } catch (e) {
        client.close();
        emit(AddCardFailure('Request failed: $e'));
        return;
      }
      client.close();

      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var titleElements = document.getElementsByTagName('title');

        if (titleElements.isNotEmpty) {
          String title = titleElements.first.text.trim();
          emit(TitleFetched(title));
        } else {
          // Try to find meta tag with og:title
          var metaTags = document.getElementsByTagName('meta');
          var ogTitle = metaTags.firstWhere(
            (element) => element.attributes['property'] == 'og:title',
            orElse: () => metaTags.firstWhere(
              (element) => element.attributes['name'] == 'title',
              orElse: () => document.createElement('meta'),
            ),
          );

          if (ogTitle.attributes.containsKey('content') &&
              ogTitle.attributes['content']!.isNotEmpty) {
            emit(TitleFetched(ogTitle.attributes['content']!));
          } else {
            // Fallback to URL without protocol and www
            String fallbackTitle = raw
                .replaceAll(RegExp(r'^https?://'), '')
                .replaceAll(RegExp(r'^www\.'), '');

            // If there's a path, just use the domain
            if (fallbackTitle.contains('/')) {
              fallbackTitle = fallbackTitle.split('/').first;
            }

            emit(TitleFetched(fallbackTitle));
          }
        }
      } else {
        emit(
          AddCardFailure('Could not load page: HTTP ${response.statusCode}'),
        );
      }
    } catch (e) {
      emit(AddCardFailure('Failed to fetch title: ${e.toString()}'));
    }
  }
}

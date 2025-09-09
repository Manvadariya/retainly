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
import '../../utils/url_utils.dart';

class AddCardBloc extends Bloc<AddCardEvent, AddCardState> {
  final CardRepository cardRepository;

  AddCardBloc({required this.cardRepository}) : super(const AddCardIdle()) {
    on<AddTextCardRequested>(_onAddTextCardRequested);
    on<AddImageCardRequested>(_onAddImageCardRequested);
    on<AddLinkCardRequested>(_onAddLinkCardRequested);
    on<FetchTitleRequested>(_onFetchTitleRequested);
    on<AddNewCard>(_onAddNewCard);
  }

  Future<void> _onAddTextCardRequested(
    AddTextCardRequested event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const AddCardLoading());

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final card = CardEntity(
        type: 'text',
        content: event
            .content, // Using content as both title and body for simple notes
        body: event.content,
        spaceId: event.spaceId, // Add to space if specified
        createdAt: now,
        updatedAt: now,
      );

      final cardId = await cardRepository.addCard(card);
      emit(AddCardSuccess(cardId));
    } catch (e) {
      emit(AddCardError(e.toString()));
    }
  }

  Future<void> _onAddImageCardRequested(
    AddImageCardRequested event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const AddCardLoading());

    try {
      print('AddCardBloc: Processing image from path: ${event.imagePath}');
      // Verify file exists and is readable
      final input = File(event.imagePath);
      if (!await input.exists()) {
        throw Exception(
          'Image file does not exist at path: ${event.imagePath}',
        );
      }

      final fileSize = await input.length();
      if (fileSize <= 0) {
        throw Exception('Image file is empty (0 bytes)');
      }

      print('AddCardBloc: File exists with size: $fileSize bytes');

      // Persist image and thumbnail
      final storage = ImageStorage();
      final (original, thumbnail) = await storage.saveImageWithThumbnail(input);

      final now = DateTime.now().millisecondsSinceEpoch;
      final card = CardEntity(
        type: 'image',
        content: event.caption?.trim().isNotEmpty == true
            ? event.caption!.trim()
            : 'Image',
        body: null,
        imagePath: original.path, // store original path
        spaceId: event.spaceId, // Add to space if specified
        createdAt: now,
        updatedAt: now,
      );
      print(
        'AddCardBloc: Created card entity with image path: ${original.path}',
      );

      final cardId = await cardRepository.addCard(card);
      print('AddCardBloc: Successfully saved card with ID: $cardId');

      emit(AddCardSuccess(cardId));
    } catch (e) {
      print('AddCardBloc: Error adding image card: $e');
      emit(AddCardError(e.toString()));
    }
  }

  Future<void> _onAddLinkCardRequested(
    AddLinkCardRequested event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const AddCardLoading());

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final card = CardEntity(
        type: 'link',
        content: event.title.trim(),
        url: event.url.trim(),
        spaceId: event.spaceId, // Add to space if specified
        createdAt: now,
        updatedAt: now,
      );

      final cardId = await cardRepository.addCard(card);
      emit(AddCardSuccess(cardId));
    } catch (e) {
      emit(AddCardError(e.toString()));
    }
  }

  Future<void> _onFetchTitleRequested(
    FetchTitleRequested event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const TitleFetching());

    try {
      // Use the URL utils class for URL normalization
      String raw = event.url.trim();
      if (raw.isEmpty) {
        emit(const AddCardError('Empty URL'));
        return;
      }

      // Enhanced URL normalization with UrlUtils
      String normalizedUrl = UrlUtils.normalizeUrl(raw);
      print('Normalized URL for fetching: $normalizedUrl');

      final uri = Uri.tryParse(normalizedUrl);
      if (uri == null) {
        emit(const AddCardError('Invalid URL'));
        return;
      }

      // Create a fallback title immediately (we'll use this if fetching fails)
      String fallbackTitle = uri.host;

      // If host includes www, remove it
      fallbackTitle = fallbackTitle.replaceAll(RegExp(r'^www\.'), '');

      final client = http.Client();
      http.Response? response;
      try {
        print('Attempting HTTP request to $uri');
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
            .timeout(const Duration(seconds: 5));

        print('Got response with status code: ${response.statusCode}');
      } on TimeoutException {
        client.close();
        print('Timeout fetching title from URL: $raw');
        emit(TitleFetched(fallbackTitle));
        return;
      } on SocketException catch (e) {
        client.close();
        print('Network error fetching title: ${e.message}');
        emit(TitleFetched(fallbackTitle));
        return;
      } catch (e) {
        client.close();
        print('Request failed fetching title: $e');
        emit(TitleFetched(fallbackTitle));
        return;
      }
      client.close();

      if (response.statusCode == 200) {
        try {
          var document = parser.parse(response.body);
          var titleElements = document.getElementsByTagName('title');

          if (titleElements.isNotEmpty) {
            String title = titleElements.first.text.trim();
            if (title.isNotEmpty) {
              print('Found title tag: $title');
              emit(TitleFetched(title));
              return;
            }
          }

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
            print('Found og:title: ${ogTitle.attributes['content']}');
            emit(TitleFetched(ogTitle.attributes['content']!));
            return;
          }
        } catch (e) {
          print('Error parsing HTML: $e');
        }
      }

      // If we got here, we need to use the fallback
      print('Using fallback title: $fallbackTitle');
      emit(TitleFetched(fallbackTitle));
    } catch (e) {
      print('Unexpected error in _onFetchTitleRequested: $e');
      // Don't fail completely, use domain name
      final domain = event.url
          .replaceAll(RegExp(r'^https?://'), '')
          .replaceAll(RegExp(r'^www\.'), '')
          .split('/')
          .first;
      emit(TitleFetched(domain));
    }
  }

  Future<void> _onAddNewCard(
    AddNewCard event,
    Emitter<AddCardState> emit,
  ) async {
    emit(const AddCardLoading());

    try {
      final cardId = await cardRepository.addCard(event.card);
      emit(AddCardSuccess(cardId));
    } catch (e) {
      emit(AddCardError(e.toString()));
    }
  }
}

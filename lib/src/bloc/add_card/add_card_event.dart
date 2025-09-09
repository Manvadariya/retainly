import 'package:equatable/equatable.dart';
import '../../data/card_entity.dart';

abstract class AddCardEvent extends Equatable {
  const AddCardEvent();

  @override
  List<Object?> get props => [];
}

class AddTextCardRequested extends AddCardEvent {
  final String content;
  final List<String> tags;
  final int? spaceId;

  const AddTextCardRequested({
    required this.content,
    this.tags = const [],
    this.spaceId,
  });

  @override
  List<Object?> get props => [content, tags, spaceId];
}

class AddImageCardRequested extends AddCardEvent {
  final String imagePath; // temp file path
  final String? caption;
  final int? spaceId;

  const AddImageCardRequested({
    required this.imagePath,
    this.caption,
    this.spaceId,
  });

  @override
  List<Object?> get props => [imagePath, caption ?? '', spaceId];
}

class AddLinkCardRequested extends AddCardEvent {
  final String url;
  final String title;
  final int? spaceId;

  const AddLinkCardRequested({
    required this.url,
    required this.title,
    this.spaceId,
  });

  @override
  List<Object?> get props => [url, title, spaceId];
}

class FetchTitleRequested extends AddCardEvent {
  final String url;

  const FetchTitleRequested({required this.url});

  @override
  List<Object> get props => [url];
}

// New event to directly add a CardEntity object
class AddNewCard extends AddCardEvent {
  final CardEntity card;

  const AddNewCard(this.card);

  @override
  List<Object?> get props => [card];
}

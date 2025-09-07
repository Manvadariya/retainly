import 'package:equatable/equatable.dart';

abstract class AddCardEvent extends Equatable {
  const AddCardEvent();

  @override
  List<Object> get props => [];
}

class AddTextCardRequested extends AddCardEvent {
  final String content;
  final List<String> tags;

  const AddTextCardRequested({required this.content, this.tags = const []});

  @override
  List<Object> get props => [content, tags];
}

class AddImageCardRequested extends AddCardEvent {
  final String imagePath; // temp file path
  final String? caption;

  const AddImageCardRequested({required this.imagePath, this.caption});

  @override
  List<Object> get props => [imagePath, caption ?? ''];
}

class AddLinkCardRequested extends AddCardEvent {
  final String url;
  final String title;

  const AddLinkCardRequested({required this.url, required this.title});

  @override
  List<Object> get props => [url, title];
}

class FetchTitleRequested extends AddCardEvent {
  final String url;

  const FetchTitleRequested({required this.url});

  @override
  List<Object> get props => [url];
}

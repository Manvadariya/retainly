import 'package:equatable/equatable.dart';

abstract class AddCardState extends Equatable {
  const AddCardState();

  @override
  List<Object> get props => [];
}

class AddCardIdle extends AddCardState {
  const AddCardIdle();
}

// Renamed from AddCardSaving to make it more explicit in modal files
class AddCardLoading extends AddCardState {
  const AddCardLoading();
}

class AddCardSuccess extends AddCardState {
  final int cardId;

  const AddCardSuccess(this.cardId);

  @override
  List<Object> get props => [cardId];
}

// Renamed from AddCardFailure to make it more explicit in modal files
class AddCardError extends AddCardState {
  final String message;

  const AddCardError(this.message);

  @override
  List<Object> get props => [message];
}

class TitleFetching extends AddCardState {
  const TitleFetching();
}

class TitleFetched extends AddCardState {
  final String title;

  const TitleFetched(this.title);

  @override
  List<Object> get props => [title];
}

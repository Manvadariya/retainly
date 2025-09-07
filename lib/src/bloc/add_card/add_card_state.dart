import 'package:equatable/equatable.dart';

abstract class AddCardState extends Equatable {
  const AddCardState();

  @override
  List<Object> get props => [];
}

class AddCardIdle extends AddCardState {
  const AddCardIdle();
}

class AddCardSaving extends AddCardState {
  const AddCardSaving();
}

class AddCardSuccess extends AddCardState {
  final int cardId;

  const AddCardSuccess(this.cardId);

  @override
  List<Object> get props => [cardId];
}

class AddCardFailure extends AddCardState {
  final String error;

  const AddCardFailure(this.error);

  @override
  List<Object> get props => [error];
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

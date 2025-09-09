import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/space_entity.dart';
import '../../data/repository/space_repository.dart';

// Events
abstract class SpacesEvent extends Equatable {
  const SpacesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSpaces extends SpacesEvent {
  const LoadSpaces();
}

class AddSpace extends SpacesEvent {
  final String name;

  const AddSpace(this.name);

  @override
  List<Object> get props => [name];
}

class UpdateSpace extends SpacesEvent {
  final SpaceEntity space;

  const UpdateSpace(this.space);

  @override
  List<Object> get props => [space];
}

class DeleteSpace extends SpacesEvent {
  final int id;

  const DeleteSpace(this.id);

  @override
  List<Object> get props => [id];
}

// States
abstract class SpacesState extends Equatable {
  const SpacesState();

  @override
  List<Object?> get props => [];
}

class SpacesLoading extends SpacesState {
  const SpacesLoading();
}

class SpacesLoaded extends SpacesState {
  final List<SpaceEntity> spaces;

  const SpacesLoaded(this.spaces);

  @override
  List<Object> get props => [spaces];
}

class SpacesError extends SpacesState {
  final String message;

  const SpacesError(this.message);

  @override
  List<Object> get props => [message];
}

// Bloc
class SpacesBloc extends Bloc<SpacesEvent, SpacesState> {
  final SpaceRepository _spaceRepository;

  SpacesBloc({required SpaceRepository spaceRepository})
    : _spaceRepository = spaceRepository,
      super(const SpacesLoading()) {
    on<LoadSpaces>(_onLoadSpaces);
    on<AddSpace>(_onAddSpace);
    on<UpdateSpace>(_onUpdateSpace);
    on<DeleteSpace>(_onDeleteSpace);
  }

  Future<void> _onLoadSpaces(
    LoadSpaces event,
    Emitter<SpacesState> emit,
  ) async {
    emit(const SpacesLoading());
    try {
      final spaces = await _spaceRepository.getAllSpaces();
      emit(SpacesLoaded(spaces));
    } catch (e) {
      emit(SpacesError(e.toString()));
    }
  }

  Future<void> _onAddSpace(AddSpace event, Emitter<SpacesState> emit) async {
    try {
      final currentState = state;
      if (currentState is SpacesLoaded) {
        // Create a new space
        final now = DateTime.now().millisecondsSinceEpoch;
        final space = SpaceEntity(name: event.name, createdAt: now);

        await _spaceRepository.createSpace(space);

        // Reload the spaces to get the updated list with card counts
        final spaces = await _spaceRepository.getAllSpaces();
        emit(SpacesLoaded(spaces));
      }
    } catch (e) {
      emit(SpacesError(e.toString()));
    }
  }

  Future<void> _onUpdateSpace(
    UpdateSpace event,
    Emitter<SpacesState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is SpacesLoaded) {
        await _spaceRepository.updateSpace(event.space);

        // Reload the spaces to get the updated list
        final spaces = await _spaceRepository.getAllSpaces();
        emit(SpacesLoaded(spaces));
      }
    } catch (e) {
      emit(SpacesError(e.toString()));
    }
  }

  Future<void> _onDeleteSpace(
    DeleteSpace event,
    Emitter<SpacesState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is SpacesLoaded) {
        await _spaceRepository.deleteSpace(event.id);

        // Reload the spaces to get the updated list
        final spaces = await _spaceRepository.getAllSpaces();
        emit(SpacesLoaded(spaces));
      }
    } catch (e) {
      emit(SpacesError(e.toString()));
    }
  }
}

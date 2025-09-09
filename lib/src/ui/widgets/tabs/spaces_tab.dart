import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/spaces/spaces_bloc.dart';
import '../../../data/repository/space_repository.dart';
import '../spaces_panel.dart';

class SpacesTab extends StatelessWidget {
  const SpacesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SpacesBloc>(
      create: (context) =>
          SpacesBloc(spaceRepository: context.read<SpaceRepository>())
            ..add(const LoadSpaces()),
      child: const SpacesPanel(),
    );
  }
}

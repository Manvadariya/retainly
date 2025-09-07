import 'package:flutter/material.dart';
import '../../data/card_entity.dart';
import '../../data/repository/card_repository.dart';

class CardListWidget extends StatefulWidget {
  const CardListWidget({super.key});

  @override
  CardListWidgetState createState() => CardListWidgetState();
}

class CardListWidgetState extends State<CardListWidget> {
  final _repository = CardRepository();
  List<CardEntity> _cards = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final cards = await _repository.getAllCards();

      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load cards: $e';
        _isLoading = false;
      });
    }
  }

  // Make _loadCards method public so it can be called from outside
  void refreshCards() {
    _loadCards();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadCards, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_cards.isEmpty) {
      return const Center(
        child: Text('No cards yet. Add a card using the + button.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _cards.length,
      itemBuilder: (context, index) {
        final card = _cards[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(card.content),
            subtitle: Text(card.body ?? 'No content'),
            trailing: Text(
              DateTime.fromMillisecondsSinceEpoch(
                card.createdAt,
              ).toString().split('.')[0],
            ),
          ),
        );
      },
    );
  }
}

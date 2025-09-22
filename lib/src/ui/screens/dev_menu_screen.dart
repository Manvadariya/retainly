import 'package:flutter/material.dart';
import '../widgets/youtube_details_tester.dart';
import 'youtube_data_viewer.dart';

/// Developer menu for testing features
class DevMenu extends StatelessWidget {
  const DevMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Options')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Testing Tools'),
          _MenuTile(
            title: 'YouTube Details Screen',
            subtitle: 'Test the YouTube metadata display',
            icon: Icons.play_circle_filled,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const YouTubeDetailsTester(),
                ),
              );
            },
          ),
          _MenuTile(
            title: 'YouTube Raw Data Viewer',
            subtitle: 'View API and scraped JSON data',
            icon: Icons.data_array,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const YouTubeDataViewer(),
                ),
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'Debug Information'),
          _MenuTile(
            title: 'App Version',
            subtitle: '1.0.0 (dev)',
            icon: Icons.info_outline,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

class TimezoneSelector extends StatelessWidget {
  const TimezoneSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public),
      title: Text(french ? 'Fuseau horaire' : 'Time zone'),
      subtitle: Text(value),
      trailing: const Icon(Icons.search),
      onTap: () async {
        final zones = tz.timeZoneDatabase.locations.keys.toList()..sort();
        final selected = await showSearch<String>(
          context: context,
          delegate: _TimezoneSearchDelegate(
            zones,
            label: french ? 'Rechercher un fuseau' : 'Search time zones',
          ),
        );
        if (selected != null) onChanged(selected);
      },
    );
  }
}

class _TimezoneSearchDelegate extends SearchDelegate<String> {
  _TimezoneSearchDelegate(this.zones, {required String label})
    : super(searchFieldLabel: label);

  final List<String> zones;

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: const BackButtonIcon(),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final normalized = query.toLowerCase().trim();
    final matches = normalized.isEmpty
        ? zones
        : zones
              .where((zone) => zone.toLowerCase().contains(normalized))
              .toList();
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(matches[index]),
        onTap: () => close(context, matches[index]),
      ),
    );
  }
}

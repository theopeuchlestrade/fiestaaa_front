import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';

PaymentProviderModel? eventPaymentProviderById(
  List<PaymentProviderModel> providers,
  int? id,
) {
  if (id == null) return null;
  for (final provider in providers) {
    if (provider.id == id) return provider;
  }
  return null;
}

String eventFeatureLabel(String feature, S l10n) {
  switch (feature) {
    case eventFeatureCarpools:
      return l10n.carpools;
    case eventFeaturePolls:
      return l10n.ephemeralPolls;
    case eventFeatureItems:
      return l10n.availableItems;
    case eventFeatureTicketing:
      return l10n.ticketing;
    case eventFeaturePlaylist:
      return l10n.sharedPlaylist;
    case eventFeaturePayment:
      return l10n.payment;
    case eventFeatureExpenses:
      return l10n.sharedExpenses;
  }
  return feature;
}

List<String> orderedEventFeatureOptions(S l10n) {
  final features = <String>[
    eventFeatureCarpools,
    eventFeaturePolls,
    eventFeatureItems,
    eventFeatureTicketing,
    eventFeaturePlaylist,
    eventFeaturePayment,
    eventFeatureExpenses,
  ];
  features.sort((left, right) {
    final leftLabel = eventFeatureLabel(left, l10n).toLowerCase();
    final rightLabel = eventFeatureLabel(right, l10n).toLowerCase();
    return leftLabel.compareTo(rightLabel);
  });
  return features;
}

String? validateEventPaymentLink({
  required S l10n,
  required bool enabled,
  required PaymentProviderModel? provider,
  required String? value,
  String missingProviderName = '',
}) {
  if (!enabled || provider == null) {
    return null;
  }
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return l10n.linkRequired;
  }
  final regExp = provider.compiledValidationRegex;
  if (!regExp.hasMatch(text)) {
    return l10n.linkFormatInvalid(
      provider.name.isEmpty ? missingProviderName : provider.name,
    );
  }
  return null;
}

String? validatePlaylistLink({
  required S l10n,
  required bool enabled,
  required String? provider,
  required String? value,
}) {
  if (!enabled) {
    return null;
  }
  final url = value?.trim() ?? '';
  if (provider == null) {
    return l10n.selectProvider;
  }
  if (url.isEmpty) {
    return l10n.playlistLinkRequired;
  }
  final regExp = switch (provider) {
    'spotify' => RegExp(r'^https?://open\.spotify\.com/.+$'),
    'apple_music' => RegExp(r'^https?://music\.apple\.com/.+$'),
    'deezer' => RegExp(r'^https?://(www\.)?deezer\.com/.+$'),
    _ => RegExp(r'^https?://.+$'),
  };
  if (!regExp.hasMatch(url)) {
    return l10n.invalidPlaylistUrl;
  }
  return null;
}

class EventPlaylistSection extends StatelessWidget {
  const EventPlaylistSection({
    super.key,
    required this.valueKeyPrefix,
    required this.enabled,
    required this.selectedProvider,
    required this.urlController,
    required this.onProviderChanged,
    required this.onUrlChanged,
  });

  final String valueKeyPrefix;
  final bool enabled;
  final String? selectedProvider;
  final TextEditingController urlController;
  final ValueChanged<String?> onProviderChanged;
  final VoidCallback onUrlChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final providerOptions = <MapEntry<String?, String>>[
      MapEntry(null, l10n.noPlaylist),
      const MapEntry('spotify', 'Spotify'),
      const MapEntry('apple_music', 'Apple Music'),
      const MapEntry('deezer', 'Deezer'),
    ];
    final providerItems = providerOptions
        .map(
          (option) => DropdownMenuItem<String?>(
            value: option.key,
            child: Text(option.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
    final selectedItems = providerOptions
        .map(
          (option) => Align(
            alignment: Alignment.centerLeft,
            child: Text(option.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();

    final urlField = TextFormField(
      key: ValueKey('${valueKeyPrefix}_playlist_link_field'),
      controller: urlController,
      decoration: InputDecoration(
        labelText: l10n.playlistLink,
        prefixIcon: const Icon(Icons.link),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      validator: (value) => validatePlaylistLink(
        l10n: l10n,
        enabled: enabled,
        provider: selectedProvider,
        value: value,
      ),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      enabled: selectedProvider != null,
      onChanged: (_) => onUrlChanged(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 420;
            final providerField = DropdownButtonFormField<String?>(
              key: ValueKey(
                '${valueKeyPrefix}_playlist_provider_field_$stacked',
              ),
              initialValue: selectedProvider,
              items: providerItems,
              selectedItemBuilder: (_) => selectedItems,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.provider,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                if (enabled && value == null) {
                  return l10n.selectProvider;
                }
                return null;
              },
              onChanged: onProviderChanged,
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [providerField, const SizedBox(height: 12), urlField],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: providerField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: urlField),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          l10n.playlistHelperText,
          style: TextStyle(color: Theme.of(context).fiestaaaMutedText),
        ),
      ],
    );
  }
}

part of '../pages/event_detail_page.dart';

extension _EventDetailSummarySections on _EventDetailPageState {
  Widget _buildFeatureActionsSection() {
    final l10n = S.of(context);
    final actions = <_EventDetailFeatureActionData>[
      if (_isFeatureEnabled(eventFeatureCarpools))
        _EventDetailFeatureActionData(
          icon: Icons.directions_car_filled_outlined,
          label: l10n.carpools,
          onPressed: _openCarpools,
        ),
      if (_isFeatureEnabled(eventFeaturePolls))
        _EventDetailFeatureActionData(
          icon: Icons.poll_outlined,
          label: l10n.ephemeralPolls,
          onPressed: _openPollsModal,
        ),
      if (_isFeatureEnabled(eventFeatureItems))
        _EventDetailFeatureActionData(
          icon: Icons.inventory_2_outlined,
          label: l10n.availableItems,
          onPressed: _openItemsModal,
        ),
      if (_isFeatureEnabled(eventFeatureExpenses))
        _EventDetailFeatureActionData(
          icon: Icons.receipt_long_outlined,
          label: l10n.sharedExpenses,
          onPressed: _openExpenses,
        ),
      if (_canShowPlaylistFeature)
        _EventDetailFeatureActionData(
          icon: Icons.playlist_add_check,
          label: l10n.sharedPlaylist,
          onPressed: _openPlaylistFromMenu,
        ),
      if (_canShowPaymentFeature)
        _EventDetailFeatureActionData(
          icon: Icons.payment,
          label: l10n.payment,
          onPressed: _openPaymentFromMenu,
        ),
      if (_canShowTicketingFeature)
        _EventDetailFeatureActionData(
          icon: _isOwner
              ? Icons.qr_code_scanner
              : Icons.confirmation_number_outlined,
          label: _isOwner ? l10n.ticketScanner : l10n.ticket,
          onPressed: _isOwner ? _openQRScanner : _openMyQRCode,
        ),
      _EventDetailFeatureActionData(
        icon: Icons.groups_2_outlined,
        label: l10n.participants,
        onPressed: _openInvitations,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 700;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: actions.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isCompact ? 2 : 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: isCompact ? 2.8 : 3.8,
                  ),
                  itemBuilder: (context, index) =>
                      _EventDetailFeatureActionButton(data: actions[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    if (!_currentEvent.hasCoordinates) {
      return _DetailTile(
        icon: Icons.place,
        label: S.of(context).address,
        value: _formatEventAddress(context, _currentEvent),
      );
    }

    final latitude = _currentEvent.latitude ?? 0;
    final longitude = _currentEvent.longitude ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openMap(latitude, longitude),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place, color: FiestaaaPalette.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).address,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).fiestaaaMutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatEventAddress(context, _currentEvent),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      S.of(context).openInMapsApp,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FiestaaaPalette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.open_in_new,
                color: Theme.of(context).fiestaaaMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final l10n = S.of(context);

    if (_currentEvent.paymentProviderId == null) {
      return _buildFeaturePanel(
        icon: Icons.payment,
        title: l10n.noPaymentConfigured,
        subtitle: null,
        accentColor: Theme.of(context).colorScheme.fiestaaaInfo,
        children: [
          if (_isOwner && !_isReadOnly)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openEditEvent,
                icon: const Icon(Icons.add_link),
                label: Text(l10n.add),
              ),
            ),
        ],
      );
    }

    if (_loadingPaymentProviders) {
      return _buildFeaturePanel(
        icon: Icons.payment,
        title: l10n.loadingPaymentInfo,
        subtitle: null,
        accentColor: Theme.of(context).colorScheme.fiestaaaInfo,
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        ],
      );
    }

    if (_providersById.isEmpty && _paymentProvidersError != null) {
      return _buildFeaturePanel(
        icon: Icons.error_outline,
        title: _paymentProvidersError!,
        subtitle: null,
        accentColor: Theme.of(context).colorScheme.error,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadPaymentProviders,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reloadPaymentProviders),
            ),
          ),
        ],
      );
    }

    final provider = _providersById[_currentEvent.paymentProviderId ?? -1];
    final providerName =
        provider?.name ?? 'Fournisseur #${_currentEvent.paymentProviderId}';
    final amount = _currentEvent.paymentRequestedAmount;
    final amountText = amount != null
        ? NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amount)
        : l10n.amountNotSpecified;
    final amountDescription = _currentEvent.paymentPerPerson
        ? l10n.contributionPerPerson(amountText)
        : l10n.targetAmount(amountText);
    final identifier = _currentEvent.paymentIdentifier?.trim();
    final paymentUri = _buildPaymentUri(provider);
    final linkLabel =
        paymentUri?.toString() ??
        (identifier == null || identifier.isEmpty
            ? l10n.notProvided
            : identifier);

    return _buildFeaturePanel(
      icon: Icons.payment,
      leading: _buildPaymentProviderLogo(provider, size: 24),
      title: providerName,
      subtitle: null,
      accentColor: Theme.of(context).colorScheme.fiestaaaInfo,
      children: [
        Text(
          amountDescription,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          linkLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: paymentUri == null
                ? null
                : () => _openPaymentLink(paymentUri),
            icon: const Icon(Icons.open_in_new),
            label: Text(
              paymentUri == null ? l10n.linkUnavailable : l10n.openPayment,
            ),
          ),
        ),
      ],
    );
  }

  Uri? _buildPaymentUri(PaymentProviderModel? provider) {
    final identifier = _currentEvent.paymentIdentifier?.trim();
    if (identifier == null || identifier.isEmpty) {
      return null;
    }
    final direct = tryParseSafeAbsoluteHttpUri(identifier);
    if (direct != null) {
      return direct;
    }
    if (provider == null) {
      return null;
    }
    final encoded = Uri.encodeComponent(identifier);
    final url = provider.urlTemplate.replaceAll('{identifier}', encoded);
    return tryParseSafeAbsoluteHttpUri(url);
  }
}

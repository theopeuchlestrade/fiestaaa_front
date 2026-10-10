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

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 800 &&
                MediaQuery.textScalerOf(context).scale(16) <= 24
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _EventDetailFeatureActionButton(data: action),
              ),
          ],
        );
      },
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
        ? NumberFormat.currency(
            locale: Intl.getCurrentLocale(),
            symbol: '€',
          ).format(amount)
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

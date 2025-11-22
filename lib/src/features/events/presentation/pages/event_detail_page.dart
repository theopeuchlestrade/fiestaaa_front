import 'dart:collection';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_edit_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_invitations_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    required this.session,
    this.onEventUpdated,
    this.onEventRemoved,
  });

  final EventModel event;
  final SessionData session;
  final VoidCallback? onEventUpdated;
  final ValueChanged<int>? onEventRemoved;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _eventsApi = EventsApi();
  final _invitationsApi = InvitationsApi();
  final _paymentProvidersApi = PaymentProvidersApi();
  late EventModel _currentEvent;
  List<EventItemModel>? _eventItems;
  bool _loadingItems = true;
  String? _itemsError;
  int? _reservingItemId;
  InvitationModel? _myInvitation;
  bool _loadingMyInvitation = false;
  bool _loadingPaymentProviders = true;
  String? _paymentProvidersError;
  Map<int, PaymentProviderModel> _providersById = {};

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _loadItems();
    _loadMyInvitation();
    _loadPaymentProviders();
  }

  @override
  void dispose() {
    _eventsApi.dispose();
    _invitationsApi.dispose();
    _paymentProvidersApi.dispose();
    super.dispose();
  }

  bool get _isOwner =>
      widget.session.email.toLowerCase() ==
      _currentEvent.ownerEmail.toLowerCase();

  Future<void> _loadItems() async {
    setState(() {
      _loadingItems = true;
      _itemsError = null;
    });
    try {
      final data = await _eventsApi.fetchEventItems(widget.event.id);
      if (!mounted) return;
      setState(() {
        _eventItems = data;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _itemsError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _itemsError = 'Impossible de charger les items.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingItems = false;
      });
    }
  }

  Future<void> _loadMyInvitation() async {
    if (_isOwner) {
      setState(() => _myInvitation = null);
      return;
    }
    setState(() {
      _loadingMyInvitation = true;
    });
    try {
      final mine =
          await _invitationsApi.fetchMyInvitations(widget.session.token);
      if (!mounted) return;
      InvitationModel? match;
      for (final inv in mine) {
        if (inv.eventId == _currentEvent.id) {
          match = inv;
          break;
        }
      }
      setState(() {
        _myInvitation = match;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myInvitation = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingMyInvitation = false;
      });
    }
  }

  Future<void> _loadPaymentProviders() async {
    setState(() {
      _loadingPaymentProviders = true;
      _paymentProvidersError = null;
    });
    try {
      final providers = await _paymentProvidersApi.fetchProviders();
      if (!mounted) return;
      setState(() {
        _providersById = {
          for (final provider in providers) provider.id: provider,
        };
        _loadingPaymentProviders = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentProvidersError = e.message;
        _loadingPaymentProviders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paymentProvidersError =
            'Impossible de charger les cagnottes disponibles';
        _loadingPaymentProviders = false;
      });
    }
  }

  Future<void> _respondInvitation(String status) async {
    try {
      await _invitationsApi.respondInvitation(
        token: widget.session.token,
        eventId: _currentEvent.id,
        status: status,
      );
      if (!mounted) return;
      _showSnack(
        status == 'Accepted' ? 'Invitation acceptée' : 'Invitation refusée',
      );
      if (status == 'Declined') {
        widget.onEventRemoved?.call(_currentEvent.id);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }
      await _loadMyInvitation();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Action impossible', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  Future<void> _reserveQuantity(
    EventItemModel item,
    int quantity,
  ) async {
    setState(() {
      _reservingItemId = item.itemId;
    });
    try {
      await _eventsApi.reserveEventItem(
        token: widget.session.token,
        eventId: _currentEvent.id,
        itemId: item.itemId,
        quantity: quantity,
      );
      if (!mounted) return;
      _showSnack('Merci pour votre contribution !');
      await _loadItems();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Erreur réseau, merci de réessayer.', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _reservingItemId = null;
      });
    }
  }

  Future<void> _openQuantityDialog(EventItemModel item) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Contribution pour ${item.name}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Promis : ${item.reservedQuantity}/${item.maxQuantity}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantité souhaitée',
                    helperText: 'Entrez 0 pour annuler votre contribution.',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Champ requis';
                    }
                    final parsed = int.tryParse(text);
                    if (parsed == null || parsed < 0) {
                      return 'Entrez un nombre positif';
                    }
                    if (parsed > item.maxQuantity) {
                      return 'Maximum ${item.maxQuantity} unités';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                final qty = int.parse(controller.text.trim());
                Navigator.of(context).pop(qty);
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      await _reserveQuantity(item, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentEvent.name),
        actions: [
          if (_isOwner)
            IconButton(
              onPressed: _openEditEvent,
              icon: const Icon(Icons.edit),
              tooltip: 'Modifier l’événement',
            ),
          if (_isOwner)
            IconButton(
              onPressed: _openInvitations,
              icon: const Icon(Icons.people_alt),
              tooltip: 'Gérer les invitations',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadItems,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!_isOwner)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _InvitationStatusCard(
                  invitation: _myInvitation,
                  loading: _loadingMyInvitation,
                  onRespond: _respondInvitation,
                ),
              ),
            _DetailTile(
              icon: Icons.event,
              label: 'Date & heure',
              value:
                  '${_currentEvent.formattedDate} à ${_currentEvent.formattedTime}',
            ),
            _DetailTile(
              icon: Icons.place,
              label: 'Adresse',
              value: _currentEvent.address,
            ),
            _DetailTile(
              icon: Icons.description,
              label: 'Description',
              value: _currentEvent.description,
            ),
            _buildPaymentSection(),
            const SizedBox(height: 16),
            Text(
              'Items disponibles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Choisissez ce que vous apportez. Les quantités sont partagées entre tous les participants.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            if (_loadingItems)
              const Center(child: CircularProgressIndicator())
            else if (_itemsError != null)
              Column(
                children: [
                  Text(_itemsError!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadItems,
                    child: const Text('Réessayer'),
                  ),
                ],
              )
            else
              _EventItemsList(
                items: _eventItems ?? const [],
                reservingItemId: _reservingItemId,
                onReserve: _openQuantityDialog,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    if (_currentEvent.paymentProviderId == null) {
      return const _DetailTile(
        icon: Icons.payment,
        label: 'Paiement',
        value: 'Aucune cagnotte renseignée',
      );
    }

    if (_loadingPaymentProviders) {
      return const _DetailTile(
        icon: Icons.payment,
        label: 'Paiement',
        value: 'Chargement des informations...',
      );
    }

    if (_providersById.isEmpty && _paymentProvidersError != null) {
      return _DetailTile(
        icon: Icons.payment,
        label: 'Paiement',
        value: _paymentProvidersError!,
      );
    }

    final provider =
        _providersById[_currentEvent.paymentProviderId ?? -1];
    final providerName = provider?.name ??
        'Fournisseur #${_currentEvent.paymentProviderId}';
    final amount = _currentEvent.paymentRequestedAmount;
    final amountText = amount != null
        ? NumberFormat.currency(locale: 'fr_FR', symbol: '€')
            .format(amount)
        : 'Montant non précisé';
    final identifier = _currentEvent.paymentIdentifier?.trim();
    final paymentUri = _buildPaymentUri(provider);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payment, color: Colors.deepOrange),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paiement',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        providerName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Montant visé : $amountText'),
            const SizedBox(height: 4),
            Text(
              'Identifiant : ${identifier == null || identifier.isEmpty ? 'non renseigné' : identifier}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: paymentUri == null
                        ? null
                        : () => _openPaymentLink(paymentUri),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      paymentUri == null
                          ? 'Lien indisponible'
                          : 'Ouvrir la cagnotte',
                    ),
                  ),
                ),
                if (_paymentProvidersError != null)
                  IconButton(
                    onPressed: _loadPaymentProviders,
                    tooltip: 'Recharger les cagnottes',
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Uri? _buildPaymentUri(PaymentProviderModel? provider) {
    final identifier = _currentEvent.paymentIdentifier?.trim();
    if (provider == null || identifier == null || identifier.isEmpty) {
      return null;
    }
    final encoded = Uri.encodeComponent(identifier);
    final url =
        provider.urlTemplate.replaceAll('{identifier}', encoded);
    return Uri.tryParse(url);
  }

  Future<void> _openPaymentLink(Uri uri) async {
    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        _showSnack('Impossible d\'ouvrir la cagnotte', isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible d\'ouvrir la cagnotte', isError: true);
    }
  }

  Future<void> _openEditEvent() async {
    final updated = await Navigator.of(context).push<EventModel>(
      MaterialPageRoute(
        builder: (_) => EventEditPage(
          session: widget.session,
          initialEvent: _currentEvent,
        ),
      ),
    );

    if (updated != null) {
      setState(() {
        _currentEvent = updated;
      });
      widget.onEventUpdated?.call();
      _showSnack('Événement mis à jour');
    }
  }

  Future<void> _openInvitations() async {
    if (!_isOwner) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventInvitationsPage(
          session: widget.session,
          eventId: _currentEvent.id,
        ),
      ),
    );
    await _loadItems();
  }
}

class _InvitationStatusCard extends StatelessWidget {
  const _InvitationStatusCard({
    required this.invitation,
    required this.loading,
    required this.onRespond,
  });

  final InvitationModel? invitation;
  final bool loading;
  final void Function(String status) onRespond;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (invitation == null) {
      return const SizedBox.shrink();
    }

    final waiting = invitation!.status == 'Waiting';
    final accepted = invitation!.status == 'Accepted';
    final background = waiting
        ? Colors.orange.shade50
        : accepted
            ? Colors.green.shade50
            : Colors.grey.shade200;
    final accent = waiting
        ? Colors.orange.shade800
        : accepted
            ? Colors.green.shade800
            : Colors.grey.shade700;
    final icon = waiting
        ? Icons.mark_email_unread
        : accepted
            ? Icons.check_circle
            : Icons.cancel_outlined;
    final statusLabel = waiting
        ? 'Invitation en attente'
        : accepted
            ? 'Participation confirmée'
            : 'Invitation refusée';

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 12),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (waiting) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onRespond('Declined'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onRespond('Accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accepter'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Confirmez votre présence pour apparaître comme participant.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else
              Text(
                accepted
                    ? 'Merci ! Vous êtes compté parmi les participants.'
                    : 'Vous avez décliné cette invitation.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventItemsList extends StatelessWidget {
  const _EventItemsList({
    required this.items,
    required this.reservingItemId,
    required this.onReserve,
  });

  final List<EventItemModel> items;
  final int? reservingItemId;
  final void Function(EventItemModel item) onReserve;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Aucun item n’a encore été ajouté pour cette soirée.',
      );
    }

    final grouped = LinkedHashMap<String, List<EventItemModel>>();
    for (final item in items) {
      grouped.putIfAbsent(item.typeName, () => []).add(item);
    }

    return Column(
      children: grouped.entries
          .map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...entry.value.map(
                  (item) => _EventItemTile(
                    item: item,
                    isLoading: reservingItemId == item.itemId,
                    onTap: () => onReserve(item),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _EventItemTile extends StatelessWidget {
  const _EventItemTile({
    required this.item,
    required this.isLoading,
    required this.onTap,
  });

  final EventItemModel item;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio =
        item.maxQuantity == 0 ? 0.0 : item.reservedQuantity / item.maxQuantity;
    final available = item.remaining;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${item.reservedQuantity}/${item.maxQuantity}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                available > 0 ? Colors.deepOrange : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              available > 0
                  ? '$available unité(s) encore disponibles.'
                  : 'Quota rempli – vous pouvez remplacer une contribution existante.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onTap,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  isLoading ? 'Envoi...' : 'Je contribue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.deepOrange),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

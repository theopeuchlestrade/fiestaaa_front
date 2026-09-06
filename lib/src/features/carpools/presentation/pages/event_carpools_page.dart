import 'package:fiestaaa_front/src/core/presentation/widgets/realtime_status_banner.dart';
import 'package:fiestaaa_front/src/core/refresh_queue.dart';
import 'package:flutter/material.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/carpools/data/carpools_api.dart';
import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
import 'package:fiestaaa_front/src/features/carpools/presentation/widgets/carpool_card.dart';
import 'package:fiestaaa_front/src/features/carpools/presentation/pages/carpool_create_page.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/quasi_fullscreen_modal.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:fiestaaa_front/src/core/realtime_client.dart';

class EventCarpoolsPage extends StatefulWidget {
  const EventCarpoolsPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.session,
    required this.isOwner,
    required this.hasAcceptedInvitation,
    required this.eventReadOnly,
    this.compactModal = false,
  });

  final int eventId;
  final String eventName;
  final DateTime eventDate;
  final SessionData session;
  final bool isOwner;
  final bool hasAcceptedInvitation;
  final bool eventReadOnly;
  final bool compactModal;

  @override
  State<EventCarpoolsPage> createState() => _EventCarpoolsPageState();
}

class _EventCarpoolsPageState extends State<EventCarpoolsPage> {
  final _refreshQueue = RefreshQueue();
  int _scopeGeneration = 0;

  final _carpoolsApi = CarpoolsApi();
  List<CarpoolModel>? _carpools;
  bool _loading = true;
  String? _error;
  int? _joiningCarpoolId;
  int? _leavingCarpoolId;
  int? _editingCarpoolId;
  RealtimeClient? _realtime;
  String? _sortBy; // New: Current sort option

  bool get _canInteract =>
      !widget.eventReadOnly && (widget.isOwner || widget.hasAcceptedInvitation);

  @override
  void initState() {
    super.initState();
    _loadCarpools();
    _setupRealtime();
  }

  @override
  void didUpdateWidget(covariant EventCarpoolsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.session.token != widget.session.token) {
      _scopeGeneration++;
      _carpools = null;
      _realtime?.dispose();
      _setupRealtime();
      _loadCarpools();
    }
  }

  @override
  void dispose() {
    _refreshQueue.dispose();
    _realtime?.dispose();
    _carpoolsApi.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    _realtime = RealtimeClient(
      token: widget.session.token,
      eventId: widget.eventId,
    );
    _realtime!.connect();
    _realtime!.stream.listen((event) {
      if (!mounted) return;
      if ([
        'realtime.ready',
        'carpool_created',
        'carpool_updated',
        'carpool_deleted',
        'carpool_joined',
        'carpool_left',
      ].contains(event['type'])) {
        _loadCarpools();
      }
    });
  }

  Future<void> _loadCarpools() =>
      _refreshQueue.run('_loadCarpools', () => _loadCarpoolsOnce());

  Future<void> _loadCarpoolsOnce() async {
    if (!mounted) return;
    final requestScope = (
      _scopeGeneration,
      widget.session.token,
      widget.eventId,
    );
    setState(() {
      _loading = _carpools == null;
      _error = null;
    });
    try {
      final data = await _carpoolsApi.fetchEventCarpools(
        token: widget.session.token,
        eventId: widget.eventId,
        sortBy: _sortBy,
      );
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() => _carpools = data);
    } catch (e) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted &&
          requestScope ==
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openCarpoolCreatePage({CarpoolModel? existing}) async {
    if (!_canInteract) {
      _showSnack(S.of(context).acceptInvitationToPropose, isError: true);
      return;
    }
    setState(() => _editingCarpoolId = existing?.carpoolId);
    final result = await showQuasiFullscreenModal<Object>(
      context: context,
      heightFactor: 0.9,
      fitContent: true,
      builder: (context) => FiestaaaPageLayout(
        child: CarpoolCreatePage(
          existingCarpool: existing,
          eventId: widget.eventId,
          eventDate: widget.eventDate,
          session: widget.session,
        ),
      ),
    );
    setState(() => _editingCarpoolId = null);
    if (result == null) return;

    if (existing != null) {
      if (result is CarpoolPatchPayload) {
        await _updateCarpool(existing.carpoolId, result);
      } else if (result is CarpoolPayload) {
        final payload = result;
        final patchPayload = CarpoolPatchPayload(
          origin: payload.origin,
          departAt: payload.departAt,
          seatsTotal: payload.seatsTotal,
          notes: payload.notes,
        );
        await _updateCarpool(existing.carpoolId, patchPayload);
      }
    } else {
      if (result is CarpoolPayload) {
        await _createCarpool(result);
      }
    }
  }

  Future<void> _createCarpool(CarpoolPayload payload) async {
    setState(() => _editingCarpoolId = -1);
    try {
      await _carpoolsApi.createCarpool(
        token: widget.session.token,
        eventId: widget.eventId,
        payload: payload,
      );
      if (!mounted) return;
      _showSnack(S.of(context).carpoolCreatedSuccess);
      await _loadCarpools();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _editingCarpoolId = null);
      }
    }
  }

  Future<void> _updateCarpool(
    int carpoolId,
    CarpoolPatchPayload payload,
  ) async {
    setState(() => _editingCarpoolId = carpoolId);
    try {
      await _carpoolsApi.updateCarpool(
        token: widget.session.token,
        carpoolId: carpoolId,
        payload: payload,
      );
      if (!mounted) return;
      _showSnack(S.of(context).carpoolUpdated);
      await _loadCarpools();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _editingCarpoolId = null);
      }
    }
  }

  Future<void> _deleteCarpool(CarpoolModel carpool) async {
    final l10n = S.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCarpool),
        content: Text(
          carpool.passengers.isNotEmpty
              ? l10n.deleteCarpoolWithPassengersConfirm
              : l10n.deleteCarpoolConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _carpoolsApi.deleteCarpool(
        token: widget.session.token,
        carpoolId: carpool.carpoolId,
      );
      if (!mounted) return;
      _showSnack(S.of(context).carpoolDeleted);
      await _loadCarpools();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _joinCarpool(int carpoolId) async {
    if (!_canInteract) {
      _showSnack(S.of(context).acceptInvitationToJoin, isError: true);
      return;
    }
    setState(() => _joiningCarpoolId = carpoolId);
    try {
      await _carpoolsApi.joinCarpool(
        token: widget.session.token,
        carpoolId: carpoolId,
      );
      if (!mounted) return;
      _showSnack(S.of(context).joinedCarpool);
      await _loadCarpools();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _joiningCarpoolId = null);
      }
    }
  }

  Future<void> _leaveCarpool(int carpoolId) async {
    final l10n = S.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveCarpool),
        content: Text(l10n.leaveCarpoolConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _leavingCarpoolId = carpoolId);
    try {
      await _carpoolsApi.leaveCarpool(
        token: widget.session.token,
        carpoolId: carpoolId,
      );
      if (!mounted) return;
      _showSnack(S.of(context).leftCarpool);
      await _loadCarpools();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _leavingCarpoolId = null);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.error : null,
      ),
    );
  }

  bool get _userIsInAnyCarpool {
    if (_carpools == null) return false;
    final carpools = _carpools!;
    final userHandleLower = widget.session.handle?.toLowerCase();
    if (userHandleLower == null) return false;

    for (final carpool in carpools) {
      if (carpool.driverHandle?.toLowerCase() == userHandleLower) {
        return true;
      }
      if (carpool.passengers.any(
        (p) => p.handle?.toLowerCase() == userHandleLower,
      )) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final userIsInAnyCarpool = _userIsInAnyCarpool;
    final canCreateCarpool = _canInteract && !userIsInAnyCarpool;

    final content = RefreshIndicator(
      onRefresh: _loadCarpools,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: widget.compactModal,
        padding: EdgeInsets.zero,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FiestaaaPageHeader(
                  title: l10n.carpools,
                  subtitle: l10n.carpoolsSubtitle,
                ),
              ),
              const SizedBox(width: 8),
              _buildSortMenu(l10n),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (!_canInteract) ...[
            _buildWarningBanner(l10n),
            const SizedBox(height: 16),
          ],
          if (_canInteract) ...[
            _buildCreateSection(l10n, canCreateCarpool),
            const SizedBox(height: 24),
          ],
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _buildErrorSection(l10n)
          else if (_carpools == null || _carpools!.isEmpty)
            _buildEmptyState(l10n)
          else
            _buildCarpoolsGrid(l10n),
        ],
      ),
    );

    final realtimeContent = RealtimeStatusBanner(
      stream: _realtime?.stream,
      child: content,
    );
    if (widget.compactModal) return realtimeContent;

    return Scaffold(body: FiestaaaPageLayout(child: realtimeContent));
  }

  Widget _buildWarningBanner(S l10n) {
    final message = widget.eventReadOnly
        ? l10n.eventFinishedReadOnly
        : l10n.acceptInvitationForCarpool;
    final warningStyle = Theme.of(
      context,
    ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.warning);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningStyle.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warningStyle.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: warningStyle.foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: warningStyle.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSection(S l10n, bool canCreate) {
    final userIsInAnyCarpool = _userIsInAnyCarpool;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, color: FiestaaaPalette.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.proposeCarpool,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              userIsInAnyCarpool
                  ? l10n.alreadyInCarpoolForEvent
                  : l10n.proposeACarpoolDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).fiestaaaMutedText,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canCreate ? () => _openCarpoolCreatePage() : null,
                icon: _editingCarpoolId == -1
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  userIsInAnyCarpool
                      ? l10n.alreadyInCarpool
                      : l10n.proposeCarpool,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection(S l10n) {
    final danger = Theme.of(context).colorScheme.fiestaaaDanger;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: danger),
        const SizedBox(height: 12),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: danger),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadCarpools,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.retry),
        ),
      ],
    );
  }

  Widget _buildEmptyState(S l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: theme.fiestaaaMutedText,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCarpoolsAvailable,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _canInteract ? l10n.beFirstToPropose : l10n.acceptInvitationToJoin,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.fiestaaaMutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarpoolsGrid(S l10n) {
    final theme = Theme.of(context);
    final userHandle = widget.session.handle?.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.carpoolsCount(_carpools!.length),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.fiestaaaMutedText,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;

            // Mobile: 1 column, Tablet: 2, Desktop: 3
            int crossAxisCount = 1;
            if (screenWidth >= 1100) {
              crossAxisCount = 3;
            } else if (screenWidth >= 700) {
              crossAxisCount = 2;
            }

            final spacing = 16.0;
            // Calculate width for each item to fit the count
            // Total width = (count * itemWidth) + ((count - 1) * spacing)
            // itemWidth = (Total width - ((count - 1) * spacing)) / count
            final itemWidth =
                (screenWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _carpools!.map((carpool) {
                final isDriver =
                    userHandle != null &&
                    carpool.driverHandle?.toLowerCase() == userHandle;
                final isPassenger =
                    userHandle != null &&
                    carpool.passengers.any(
                      (p) => p.handle?.toLowerCase() == userHandle,
                    );
                final isDriverOfAnother = _carpools!.any(
                  (c) =>
                      c.driverHandle?.toLowerCase() == userHandle &&
                      c.carpoolId != carpool.carpoolId,
                );
                final isPassengerInAnother = _carpools!.any(
                  (c) =>
                      c.carpoolId != carpool.carpoolId &&
                      c.passengers.any(
                        (p) => p.handle?.toLowerCase() == userHandle,
                      ),
                );

                final canJoin =
                    _canInteract &&
                    !isDriver &&
                    !isPassenger &&
                    !isDriverOfAnother &&
                    !isPassengerInAnother &&
                    !carpool.isFull;
                final canLeave = isPassenger;
                final canEdit = isDriver;
                final canDelete = isDriver;

                String? unavailableReason;
                if (!_canInteract) {
                  unavailableReason = l10n.acceptInvitationToJoinCarpool;
                } else if (isDriver) {
                  unavailableReason = l10n.youAreTheDriver;
                } else if (isPassenger) {
                  unavailableReason = l10n.alreadyPassenger;
                } else if (isDriverOfAnother) {
                  unavailableReason = l10n.driverOfAnotherCarpool;
                } else if (isPassengerInAnother) {
                  unavailableReason = l10n.passengerInAnotherCarpool;
                } else if (carpool.isFull) {
                  unavailableReason = l10n.carpoolFull;
                }

                return SizedBox(
                  width: itemWidth,
                  child: CarpoolCard(
                    carpool: carpool,
                    isDriver: isDriver,
                    isPassenger: isPassenger,
                    unavailableReason: unavailableReason,
                    isJoining: _joiningCarpoolId == carpool.carpoolId,
                    isLeaving: _leavingCarpoolId == carpool.carpoolId,
                    onJoin: canJoin
                        ? () => _joinCarpool(carpool.carpoolId)
                        : null,
                    onLeave: canLeave
                        ? () => _leaveCarpool(carpool.carpoolId)
                        : null,
                    onEdit: canEdit
                        ? () => _openCarpoolCreatePage(existing: carpool)
                        : null,
                    onDelete: canDelete ? () => _deleteCarpool(carpool) : null,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSortMenu(S l10n) {
    final theme = Theme.of(context);
    final isActive = _sortBy != null;

    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? FiestaaaPalette.primary.withValues(alpha: 0.12)
            : theme.fiestaaaMutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: FiestaaaPalette.primary.withValues(alpha: 0.3))
            : Border.all(color: theme.fiestaaaSoftBorder),
      ),
      child: PopupMenuButton<String?>(
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort,
              color: isActive ? FiestaaaPalette.primary : theme.iconTheme.color,
              size: 20,
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: FiestaaaPalette.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        tooltip: l10n.sortBy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (value) {
          setState(() {
            _sortBy = value;
          });
          _loadCarpools();
        },
        itemBuilder: (context) => [
          _buildSortMenuItem(
            value: null,
            label: l10n.sortDefault,
            icon: Icons.reorder,
            isSelected: _sortBy == null,
          ),
          const PopupMenuDivider(),
          _buildSortMenuItem(
            value: 'departure_asc',
            label: l10n.sortByDepartureAsc,
            icon: Icons.arrow_upward,
            isSelected: _sortBy == 'departure_asc',
          ),
          _buildSortMenuItem(
            value: 'departure_desc',
            label: l10n.sortByDepartureDesc,
            icon: Icons.arrow_downward,
            isSelected: _sortBy == 'departure_desc',
          ),
          const PopupMenuDivider(),
          _buildSortMenuItem(
            value: 'available_seats_desc',
            label: l10n.sortByAvailableSeats,
            icon: Icons.event_seat,
            isSelected: _sortBy == 'available_seats_desc',
          ),
          _buildSortMenuItem(
            value: 'seats_desc',
            label: l10n.sortByTotalSeats,
            icon: Icons.airline_seat_recline_normal,
            isSelected: _sortBy == 'seats_desc',
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String?> _buildSortMenuItem({
    required String? value,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return PopupMenuItem<String?>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? FiestaaaPalette.primary
                : Theme.of(context).fiestaaaMutedText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? FiestaaaPalette.primary : null,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check, size: 18, color: FiestaaaPalette.primary),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:fiestaaa_front/src/features/carpools/data/carpools_api.dart';
import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final carpool = {
    'carpool_id': 5,
    'event_id': 7,
    'driver_id': 11,
    'driver_handle': 'alice',
    'origin': 'Paris',
    'depart_at': '2030-01-01T10:00:00Z',
    'seats_total': 4,
    'seats_taken': 1,
    'created_at': '2029-12-01T10:00:00Z',
    'updated_at': '2029-12-01T10:00:00Z',
    'passengers': <Object>[],
  };

  test('carpool API covers list and mutation workflows', () async {
    final requests = <http.Request>[];
    final api = CarpoolsApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode([carpool]), 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/carpools')) {
          return http.Response(jsonEncode(carpool), 201);
        }
        if (request.method == 'PATCH') {
          return http.Response(jsonEncode(carpool), 200);
        }
        return http.Response('{}', 200);
      }),
    );

    final listed = await api.fetchEventCarpools(
      token: 'token',
      eventId: 7,
      sortBy: 'departure',
    );
    final created = await api.createCarpool(
      token: 'token',
      eventId: 7,
      payload: CarpoolPayload(
        origin: 'Paris',
        departAt: DateTime.utc(2030),
        seatsTotal: 4,
      ),
    );
    final updated = await api.updateCarpool(
      token: 'token',
      carpoolId: 5,
      payload: CarpoolPatchPayload(seatsTotal: 5),
    );
    await api.joinCarpool(token: 'token', carpoolId: 5);
    await api.leaveCarpool(token: 'token', carpoolId: 5);
    await api.deleteCarpool(token: 'token', carpoolId: 5);

    expect(listed.single.driverHandle, 'alice');
    expect(created.seatsAvailable, 3);
    expect(updated.carpoolId, 5);
    expect(requests, hasLength(6));
    expect(requests.first.url.queryParameters['sort'], 'departure');
  });
}

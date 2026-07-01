import 'package:fiestaaa_front/src/core/feature_controller.dart';
import 'package:fiestaaa_front/src/features/friends/data/friends_api.dart';
import 'package:fiestaaa_front/src/features/friends/domain/friend_model.dart';

class FriendsController extends FeatureController {
  FriendsController({required this.token, FriendsApi? api})
    : api = api ?? FriendsApi();

  final String token;
  final FriendsApi api;
  List<FriendModel> friends = const [];
  List<FriendRequestModel> requests = const [];

  @override
  Future<void> load() async {
    final values = await Future.wait([
      api.fetchFriends(token),
      api.fetchRequests(token),
    ]);
    friends = values[0] as List<FriendModel>;
    requests = values[1] as List<FriendRequestModel>;
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}

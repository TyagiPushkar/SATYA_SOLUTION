import 'package:flutter_riverpod/flutter_riverpod.dart';
class HomeState {
}
class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return HomeState();
  }
  void getHomeData() {
    // Fetch home data her
  }
}
final homeProvider = NotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});

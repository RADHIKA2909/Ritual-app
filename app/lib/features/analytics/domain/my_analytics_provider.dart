import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// Not autoDispose so we can invalidate it from socket listeners
final myAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await ApiClient.instance.get('/users/me/analytics');
  return response.data as Map<String, dynamic>;
});

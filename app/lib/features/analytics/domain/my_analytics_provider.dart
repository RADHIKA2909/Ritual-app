import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final myAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await ApiClient.instance.get('/users/me/analytics');
  return response.data as Map<String, dynamic>;
});

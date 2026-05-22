import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final analyticsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, groupId) async {
  final response = await ApiClient.instance.get('/groups/$groupId/analytics');
  return response.data as Map<String, dynamic>;
});

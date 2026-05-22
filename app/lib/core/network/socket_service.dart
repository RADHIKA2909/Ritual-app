import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _activeUserId;
  String? _activeGroupId;

  String get _baseUrl {
    if (kIsWeb) return const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5001');
    if (Platform.isAndroid) return 'http://10.0.2.2:5001';
    return 'http://localhost:5001';
  }

  void initSocket() {
    if (_socket != null) return;

    _socket = IO.io(_baseUrl, IO.OptionBuilder()
      .setTransports(['websocket']) // for Flutter or Web
      .disableAutoConnect()  // disable auto-connection
      .build()
    );

    _socket?.onConnect((_) {
      print('Socket connected');
      // Re-join rooms automatically upon connection (or re-connection)
      if (_activeUserId != null) {
        _socket?.emit('join_user', _activeUserId);
      }
      if (_activeGroupId != null) {
        _socket?.emit('join_group', _activeGroupId);
      }
    });

    _socket?.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket?.connect();
  }

  void joinGroup(String groupId) {
    _activeGroupId = groupId;
    if (_socket?.connected == true) {
      _socket?.emit('join_group', groupId);
    }
  }

  void leaveGroup(String groupId) {
    if (_activeGroupId == groupId) {
      _activeGroupId = null;
    }
    _socket?.emit('leave_group', groupId);
  }

  void joinUserRoom(String userId) {
    _activeUserId = userId;
    if (_socket?.connected == true) {
      _socket?.emit('join_user', userId);
    }
  }

  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event, [dynamic callback]) {
    if (callback != null) {
      _socket?.off(event, callback);
    } else {
      _socket?.off(event);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}

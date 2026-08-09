import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _activeUserId;
  String? _activeGroupId;

  // Same backend as ApiClient — override at build time with
  // flutter build web --dart-define=BACKEND_URL=https://your-api.com
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://ritual-backend.fly.dev',
  );

  void initSocket() {
    if (_socket != null) return;

    _socket = IO.io(_baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
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

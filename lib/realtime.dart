part of appwrite;

class RTSub {
  final Stream stream;
  final Function close;

  RTSub({required this.stream, required this.close});
}

class Realtime extends Service {
  late WebSocketChannel websok;
  Map<String, String>? headers = {};

  String? endPoint;
  String? project;
  String? lastUrl;
  late Map<String, List<StreamController>> channels;
  Map<String, dynamic>? lastMessage;

  Realtime(Client client) : super(client);



  _closeConnection() {
    websok.sink.close.call();
  }

  createSocket() {
    //close existing connection
    if (endPoint == null) return;
    if (channels.keys.length < 1) {
      _closeConnection();
      return;
    }
    var uri = Uri.parse(endPoint!);
    uri = Uri(
        host: uri.host,
        scheme: uri.scheme,
        queryParameters: {
          "project": project,
          "channels[]": channels.keys,
        },
        path: uri.path + "/realtime");
    if (lastUrl == uri.toString() && websok.closeCode == null) {
      return;
    }
    lastUrl = uri.toString();
    print('subscription: $lastUrl');
    websok = WebSocketChannel.connect(uri, headers: headers);
    websok.stream.listen((event) {
      print(event);
      final data = jsonDecode(event);
      lastMessage = data;
      if (data['channels'] != null) {
        List<String> received = List<String>.from(data['channels']);
        received.forEach((channel) {
          if (channels[channel] != null) {
            channels[channel]!.forEach((stream) {
              stream.sink.add(event);
            });
          }
        });
      }
    });
  }
}

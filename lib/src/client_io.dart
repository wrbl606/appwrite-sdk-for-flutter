import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'client_mixin.dart';
import 'client_base.dart';
import 'cookie_manager.dart';
import 'enums.dart';
import 'exception.dart';
import 'interceptor.dart';
import 'response.dart';
import 'package:flutter/foundation.dart';

ClientBase createClient({
  required String endPoint,
  required bool selfSigned,
}) =>
    ClientIO(
      endPoint: endPoint,
      selfSigned: selfSigned,
    );

class ClientIO extends ClientBase with ClientMixin {
  String _endPoint;
  Map<String, String>? _headers;
  @override
  late Map<String, String> config;
  bool selfSigned;
  bool _initialized = false;
  String? _endPointRealtime;
  late http.Client _httpClient;
  late HttpClient _nativeClient;
  late CookieJar _cookieJar;
  final List<Interceptor> _interceptors = [];

  bool get initialized => _initialized;
  CookieJar get cookieJar => _cookieJar;
  @override
  String? get endPointRealtime => _endPointRealtime;

  ClientIO({
    String endPoint = 'https://appwrite.io/v1',
    this.selfSigned = false,
  }) : _endPoint = endPoint {
    _nativeClient = HttpClient()
      ..badCertificateCallback =
          ((X509Certificate cert, String host, int port) => selfSigned);
    _httpClient = IOClient(_nativeClient);
    _endPointRealtime = endPoint
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    _headers = {
      'content-type': 'application/json',
      'x-sdk-version': 'appwrite:flutter:5.0.0',
      'X-Appwrite-Response-Format' : '0.14.0',
    };

    config = {};

    assert(_endPoint.startsWith(RegExp("http://|https://")),
        "endPoint $_endPoint must start with 'http'");
    init();
  }

  @override
  String get endPoint => _endPoint;

  Future<Directory> _getCookiePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    final Directory dir = Directory('$path/cookies');
    await dir.create();
    return dir;
  }

     /// Your project ID
    @override
    ClientIO setProject(value) {
        config['project'] = value;
        addHeader('X-Appwrite-Project', value);
        return this;
    }
     /// Your secret JSON Web Token
    @override
    ClientIO setJWT(value) {
        config['jWT'] = value;
        addHeader('X-Appwrite-JWT', value);
        return this;
    }
    @override
    ClientIO setLocale(value) {
        config['locale'] = value;
        addHeader('X-Appwrite-Locale', value);
        return this;
    }

  @override
  ClientIO setSelfSigned({bool status = true}) {
    selfSigned = status;
    _nativeClient.badCertificateCallback =
        ((X509Certificate cert, String host, int port) => status);
    return this;
  }

  @override
  ClientIO setEndpoint(String endPoint) {
    _endPoint = endPoint;
    _endPointRealtime = endPoint
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return this;
  }

  @override
  ClientIO setEndPointRealtime(String endPoint) {
    _endPointRealtime = endPoint;
    return this;
  }

  @override
  ClientIO addHeader(String key, String value) {
    _headers![key] = value;

    return this;
  }

  Future init() async {
    // if web skip cookie implementation and origin header as those are automatically handled by browsers
    final Directory cookieDir = await _getCookiePath();
    _cookieJar = PersistCookieJar(storage: FileStorage(cookieDir.path));
    _interceptors.add(CookieManager(_cookieJar));
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    addHeader('Origin',
        'appwrite-${Platform.operatingSystem}://${packageInfo.packageName}');

    //creating custom user agent
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    var device = '';
    try {
      if (Platform.isAndroid) {
        final andinfo = await deviceInfoPlugin.androidInfo;
        device =
            '(Linux; U; Android ${andinfo.version.release}; ${andinfo.brand} ${andinfo.model})';
      }
      if (Platform.isIOS) {
        final iosinfo = await deviceInfoPlugin.iosInfo;
        device = '${iosinfo.utsname.machine} iOS/${iosinfo.systemVersion}';
      }
      if (Platform.isLinux) {
        final lininfo = await deviceInfoPlugin.linuxInfo;
        device = '(Linux; U; ${lininfo.id} ${lininfo.version})';
      }
      if (Platform.isWindows) {
        final wininfo = await deviceInfoPlugin.windowsInfo;
        device =
            '(Windows NT; ${wininfo.computerName})'; //can't seem to get much info here
      }
      if (Platform.isMacOS) {
        final macinfo = await deviceInfoPlugin.macOsInfo;
        device = '(Macintosh; ${macinfo.model})';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
      device = Platform.operatingSystem;
    }
    addHeader(
        'user-agent', '${packageInfo.packageName}/${packageInfo.version} $device');

    _initialized = true;
  }

  Future<http.BaseRequest> _interceptRequest(http.BaseRequest request) async {
    final body = (request is http.Request) ? request.body : '';
    for (final i in _interceptors) {
      request = await i.onRequest(request);
    }

    if (request is http.Request) {
      assert(
        body == request.body,
        'Interceptors should not transform the body of the request'
        'Use Request converter instead',
      );
    }
    return request;
  }

  Future<http.Response> _interceptResponse(http.Response response) async {
    final body = response.body;
    for (final i in _interceptors) {
      response = await i.onResponse(response);
    }

    assert(
      body == response.body,
      'Interceptors should not transform the body of the response',
    );
    return response;
  }

  @override
  Future webAuth(Uri url) {
    return FlutterWebAuth.authenticate(
      url: url.toString(),
      callbackUrlScheme: "appwrite-callback-" + config['project']!,
    ).then((value) async {
      Uri url = Uri.parse(value);
      final key = url.queryParameters['key'];
      final secret = url.queryParameters['secret'];
      if (key == null || secret == null) {
        throw AppwriteException(
            "Invalid OAuth2 Response. Key and Secret not available.", 500);
      }
      Cookie cookie = Cookie(key, secret);
      cookie.domain = Uri.parse(_endPoint).host;
      cookie.httpOnly = true;
      cookie.path = '/';
      List<Cookie> cookies = [cookie];
      await init();
      _cookieJar.saveFromResponse(Uri.parse(_endPoint), cookies);
    });
  }

  @override
  Future<Response> call(
    HttpMethod method, {
    String path = '',
    Map<String, String> headers = const {},
    Map<String, dynamic> params = const {},
    ResponseType? responseType,
  }) async {
    if (!_initialized) {
      await init();
    }

    late http.Response res;
    http.BaseRequest request = prepareRequest(
      method,
      uri: Uri.parse(_endPoint + path),
      headers: {..._headers!, ...headers},
      params: params,
    );

    try {
      request = await _interceptRequest(request);
      final streamedResponse = await _httpClient.send(request);
      res = await toResponse(streamedResponse);
      res = await _interceptResponse(res);

      return prepareResponse(
        res,
        responseType: responseType,
      );
    } catch (e) {
      if (e is AppwriteException) {
        rethrow;
      }
      throw AppwriteException(e.toString());
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'xml_parser.dart';

String removeTrailing(String pattern, String from) {
  int i = from.length;
  while (from.startsWith(pattern, i - pattern.length)) i -= pattern.length;
  return from.substring(0, i);
}

String trimLeading(String pattern, String from) {
  int i = 0;
  while (from.startsWith(pattern, i)) i += pattern.length;
  return from.substring(i);
}

String htmlEncode(String text) {
  Map<String, String> mapping = Map.from(
      {"&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': '&quot;'});
  mapping.forEach((key, value) {
    text = text.replaceAll(key, value);
  });
  return text;
}

class Device {
  final DeviceInfo info;

  Device(this.info);

  String get controlURL {
    final base = removeTrailing("/", info.URLBase);
    final s = info.serviceList
        .firstWhere((element) => element['serviceId'].contains("AVTransport"));
    if (s != null) {
      final controlURL = trimLeading("/", s["controlURL"]);
      return base + '/' + controlURL;
    }
    throw Exception("not found controlURL");
  }

  Future<String> request(String action, List<int> data) {
    final controlURL = this.controlURL;
    final Map<String, Object> headers = Map.from({
      'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
      'Content-Type': 'text/xml',
    });
    return Http.post(Uri.parse(controlURL), headers, data);
  }

  Future<String> setUrl(String url) {
    final data = XmlText.setPlayURLXml(url);
    return request('SetAVTransportURI', Utf8Encoder().convert(data));
  }

  Future<String> play() {
    final data = XmlText.playActionXml();
    return request('Play', Utf8Encoder().convert(data));
  }

  Future<String> pause() {
    final data = XmlText.pauseActionXml();
    return request('Pause', Utf8Encoder().convert(data));
  }

  Future<String> stop() {
    final data = XmlText.stopActionXml();
    return request('Stop', Utf8Encoder().convert(data));
  }

  Future<String> seek(String sk) {
    final data = XmlText.seekToXml(sk);
    return request('Seek', Utf8Encoder().convert(data));
  }

  Future<String> position() {
    final data = XmlText.getPositionXml();
    return request('GetPositionInfo', Utf8Encoder().convert(data));
  }

  Future<String> seekByCurrent(String text, int n) {
    final p = PositionParser(text);
    final sk = p.seek(n);
    return seek(sk);
  }
}

class XmlText {
  static String setPlayURLXml(String url) {
    var title = url;
    final douyu = RegExp(r'^https?://(\d+)\?douyu$');
    final isdouyu = douyu.firstMatch(url);
    if (isdouyu != null) {
      final roomId = isdouyu.group(1);
      // 斗鱼tv的dlna server,只能指定直播间ID,不接受url资源,必须是如下格式
      title = "roomId = $roomId, line = 0";
    }
    var meta =
        '''<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sec="http://www.sec.co.kr/"><item id="false" parentID="1" restricted="0"><dc:title>$title</dc:title><dc:creator>unkown</dc:creator><upnp:class>object.item.videoItem</upnp:class><res resolution="4"></res></item></DIDL-Lite>''';
    meta = htmlEncode(meta);
    url = htmlEncode(url);
    return '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <s:Body>
        <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <InstanceID>0</InstanceID>
            <CurrentURI>$url</CurrentURI>
            <CurrentURIMetaData>$meta</CurrentURIMetaData>
        </u:SetAVTransportURI>
    </s:Body>
</s:Envelope>
        ''';
  }

  static String playActionXml() {
    return '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <s:Body>
        <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <InstanceID>0</InstanceID>
            <Speed>1</Speed>
        </u:Play>
    </s:Body>
</s:Envelope>''';
  }

  static String pauseActionXml() {
    return '''<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
	<s:Body>
		<u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
			<InstanceID>0</InstanceID>
		</u:Pause>
	</s:Body>
</s:Envelope>''';
  }

  static String stopActionXml() {
    return '''<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <s:Body>
        <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <InstanceID>0</InstanceID>
        </u:Stop>
    </s:Body>
</s:Envelope>''';
  }

  static String getPositionXml() {
    return '''<?xml version="1.0" encoding="utf-8" standalone="no"?>
    <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
            <u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                <InstanceID>0</InstanceID>
                <MediaDuration />
            </u:GetPositionInfo>
        </s:Body>
    </s:Envelope>''';
  }

  static String seekToXml(sk) {
    return '''<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
	<s:Body>
		<u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
			<InstanceID>0</InstanceID>
			<Unit>REL_TIME</Unit>
			<Target>$sk</Target>
		</u:Seek>
	</s:Body>
</s:Envelope>''';
  }
}

class Http {
  static final client = HttpClient();

  static Future<String> get(Uri uri) async {
    const timeout = Duration(seconds: 5);
    final req = await client.getUrl(uri);
    final res = await req.close().timeout(timeout);
    if (res.statusCode != HttpStatus.ok) {
      throw Exception("request $uri error , status ${res.statusCode}");
    }
    final body = await res.transform(utf8.decoder).join().timeout(timeout);
    return body;
  }

  static Future<String> post(
      Uri uri, Map<String, Object> headers, List<int> data) async {
    const timeout = Duration(seconds: 5);
    final req = await client.postUrl(uri);
    headers.forEach((name, values) {
      req.headers.set(name, values);
    });
    req.contentLength = data.length;
    req.add(data);
    final res = await req.close().timeout(timeout);
    if (res.statusCode != HttpStatus.ok) {
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      throw Exception("request $uri error , status ${res.statusCode} $body");
    }
    final body = await res.transform(utf8.decoder).join().timeout(timeout);
    return body;
  }
}

class Parser {
  final String message;

  Parser(this.message);

  parse() async {
    final lines = message.split('\n');
    final arr = lines.first.split(' ');
    if (arr.length < 3) {
      return;
    }
    final method = arr[0];
    if (method == 'M-SEARCH') {
      // 忽略别人的搜索请求
    } else if (method == 'NOTIFY' ||
        method == "HTTP/1.1" ||
        method == "HTTP/1.0") {
      lines.removeAt(0);
      return await onNotify(lines);
    } else {
      print(message);
    }
  }

  onNotify(List<String> lines) async {
    String uri = '';
    lines.forEach((element) {
      final arr = element.split(':');
      final key = arr[0].trim().toUpperCase();
      if (key == "LOCATION") {
        arr.removeAt(0);
        final value = arr.join(':');
        uri = value.trim();
      }
    });
    if (uri != '') {
      return await getInfo(uri);
    }
  }

  Future<DeviceInfo> getInfo(String uri) async {
    final target = Uri.parse(uri);
    final body = await Http.get(target);
    final info = XmlParser(body).parse(target);
    return info;
  }
}

class Manager {
  final Map<String, Device> deviceList = Map();

  Manager();

  onMessage(String message) async {
    final DeviceInfo? info = await Parser(message).parse();
    if (info != null) {
      deviceList[info.URLBase] = Device(info);
    }
  }
}

class Search {
  static const String UPNP_IP_V4 = '239.255.255.250';
  static const int UPNP_PORT = 1900;
  final InternetAddress UPNP_AddressIPv4 = InternetAddress(UPNP_IP_V4);
  Timer sender = Timer(Duration(seconds: 2), () {});
  Timer receiver = Timer(Duration(seconds: 2), () {});
  RawDatagramSocket? socket_server;

  Future<Manager> start({reusePort = false}) async {
    stop();
    final m = Manager();
    socket_server = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, UPNP_PORT,
        reusePort: reusePort);
    // https://github.com/dart-lang/sdk/issues/42250 截止到 dart 2.13.4 仍存在问题,期待新版修复
    // 修复IOS joinMulticast 的问题
    if (Platform.isIOS) {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddress.anyIPv4.type,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        final value = Uint8List.fromList(
            UPNP_AddressIPv4.rawAddress + interface.addresses[0].rawAddress);
        socket_server!.setRawOption(
            RawSocketOption(RawSocketOption.levelIPv4, 12, value));
      }
    } else {
      socket_server!.joinMulticast(UPNP_AddressIPv4);
    }
    final r = Random();
    final socket_client =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sender = Timer.periodic(Duration(seconds: 3), (Timer t) async {
      final n = r.nextDouble();
      var st = "ssdp:all";
      if (n > 0.3) {
        if (n > 0.6) {
          st = "urn:schemas-upnp-org:service:AVTransport:1";
        } else {
          st = "urn:schemas-upnp-org:device:MediaRenderer:1";
        }
      }
      String msg = 'M-SEARCH * HTTP/1.1\r\n' +
          'ST: $st\r\n' +
          'HOST: 239.255.255.250:1900\r\n' +
          'MX: 3\r\n' +
          'MAN: \"ssdp:discover\"\r\n\r\n';
      socket_client.send(msg.codeUnits, UPNP_AddressIPv4, UPNP_PORT);
      final replay = socket_client.receive();
      if (replay == null) {
        return;
      }
      try {
        String message = String.fromCharCodes(replay.data).trim();
        await m.onMessage(message);
      } catch (e) {
        print(e);
      }
    });
    receiver = Timer.periodic(Duration(seconds: 2), (Timer t) async {
      final d = socket_server!.receive();
      if (d == null) {
        return;
      }
      String message = String.fromCharCodes(d.data).trim();
      // print('Datagram from ${d.address.address}:${d.port}: ${message}');
      try {
        await m.onMessage(message);
      } catch (e) {
        print(e);
      }
    });
    return m;
  }

  stop() {
    sender.cancel();
    receiver.cancel();
    socket_server?.close();
    socket_server = null;
  }
}

# dlna_dart

simple dlna client

## Getting Started

```dart
import 'dart:async';
import 'package:dlna_dart/dlna.dart';

main(List<String> args) async {
  final m = await search().start();
  Timer.periodic(Duration(seconds: 10), (timer) {
    m.deviceList.forEach((key, value) async {
      print(key);
      if (value.info.friendlyName.contains('Wireless')) return;
      print(value.info.friendlyName);
      final text = await value.position();
      final r = await value.seekByCurrent(text, 10);
      print(r);
    });
  });
}

```

**python version**

https://github.com/suconghou/dlna-python


**app example**

https://github.com/suconghou/u2flutter

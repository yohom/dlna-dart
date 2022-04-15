import 'dart:async';
import '../lib/dlna.dart';

main(List<String> args) async {
  final searcher = Search();
  final m = await searcher.start();
  Timer.periodic(Duration(seconds: 3), (timer) {
    m.deviceList.forEach((key, value) async {
      print(key);
      if (value.info.friendlyName.contains('Wireless')) return;
      print(value.info.friendlyName);
      // final text = await value.position();
      // final r = await value.seekByCurrent(text, 10);
      // print(r);
    });
  });

  // close the server,the closed server can be start by call searcher.start()
  Timer(Duration(seconds: 30), () {
    searcher.stop();
    print('server closed');
  });

  // if you new search() many times , you must use start(reusePort:true)

}

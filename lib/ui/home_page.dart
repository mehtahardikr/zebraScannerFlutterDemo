import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';



class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const platform = MethodChannel('com.hm.zebra/scanner');
  static const _streamScanner = EventChannel('com.hm.zebra/scannerEvents');
  static const _streamBarcode = EventChannel('com.hm.zebra/barcodeEvents');

  static const String EVENT_PAIR = "pair";
  static const String EVENT_INIT = "init";
  static const String EVENT_TEST_BEEP = "testBeep";
  static const String EVENT_DISCONNECT = "disconnect";
  static const String EVENT_GET_LIST = "getList";
  static const String EVENT_ACTIVE_SCANNER_LIST = "getActiveScannerList";

  dynamic map;
  StreamSubscription? _subscriptionScanner, _subscriptionBarcode;
  bool _isDeviceConnected = false;

  List<String> _actions = [] ;
  Map<String,int> _scannedProducts = Map<String,int>();
  String _connectedScannerId ="";

  var eventData = "";

  @override
  void initState() {





    _subscriptionScanner = _streamScanner.receiveBroadcastStream().listen((data) {

      map = data;

      var value =jsonDecode(map);
       print(value);
       if(value is List && (value as List).isEmpty) {
         _actions.insert(0,"No connected Scanners Found");
       }else {
         if(value is List) {
           if(value.isNotEmpty) {
             value = value[0];
           }
         }
         String _id = value["id"] ?? '';
         String _event = value["event"] ?? '';
         String _name = value["name"] ?? '';
         bool _status = value["active"] ?? false;


         if (_event == "disconnected") {
           _isDeviceConnected = false;
         }

         if (!_isDeviceConnected) {
           _isDeviceConnected = (_event == "connected");
         }

         if (_isDeviceConnected) _connectedScannerId = _id;

         _actions.insert(
             0, _name + " :: " + _event + " :: " + _status.toString());
       }
      setState(() {});
     // var _list = map.values.toList();

    });

    _subscriptionBarcode  =_streamBarcode.receiveBroadcastStream().listen((barcodeData) {

      _scannedProducts.update(
        barcodeData,
            (value) => 1 + value,
        ifAbsent: () => 1,
      );

      setState(() {});

    });

    super.initState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> openBarcodeScreen() async {
    String result;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      //result = await Zebrascanner.barcodeScreen;
    } on PlatformException {
      result = 'Failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 10,
            ),
            if(!_isDeviceConnected) ...[

              ElevatedButton(onPressed: ()async{
                try {
                  final result = await platform.invokeMethod(EVENT_INIT);
                  //final result = await platform.invokeMethod(EVENT_GET_LIST);
                  debugPrint('from native : ${result.toString()}');
                } on PlatformException catch (e) {
                  debugPrint('exception $e');
                }

              }, child: const Text("INIT")),

              ElevatedButton(
                onPressed: () async {
                  try {
                    final result = await platform.invokeMethod(EVENT_PAIR);
                    //final result = await platform.invokeMethod(EVENT_GET_LIST);
                    debugPrint('from native : ${result.toString()}');
                  } on PlatformException catch (e) {
                    debugPrint('exception $e');
                  }
                },
                child: const Text("Add device")),


            ],

             if(_isDeviceConnected) ...[
                  ElevatedButton(onPressed: ()async {
                    try {
                      final result = await platform.invokeMethod(EVENT_TEST_BEEP, {"deviceId" : _connectedScannerId});
                    } on PlatformException catch (e) {
                      debugPrint('exception $e');
                    }
                  }, child: const Text("Test Connection")),

               ElevatedButton(onPressed: ()async {
                 try {
                   final result = await platform.invokeMethod(EVENT_DISCONNECT, {"deviceId" : _connectedScannerId});
                 } on PlatformException catch (e) {
                   debugPrint('exception $e');
                 }
               }, child: const Text("Disconnect"))

            ],


            ElevatedButton(
                onPressed: () async {
                  try {
                    //final result = await platform.invokeMethod(EVENT_PAIR);
                    final result = await platform.invokeMethod(EVENT_ACTIVE_SCANNER_LIST);
                    debugPrint('from native : ${result.toString()}');
                  } on PlatformException catch (e) {
                    debugPrint('exception $e');
                  }
                },
                child: const Text("Connected Device List")),

            const SizedBox(
              height: 10,
            ),




            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: ListView.builder(itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_actions[index]),
                      );
                    },itemCount: _actions.length,shrinkWrap: true,) ,
                  ),

                  Flexible(
                    child: ListView.builder(itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(child: Text(_scannedProducts.keys.elementAt(index),style:const TextStyle(fontWeight: FontWeight.w400),)),
                            const SizedBox(width: 10,),
                            Flexible(child: Text("${_scannedProducts[_scannedProducts.keys.elementAt(index)]}",style: const TextStyle(fontWeight: FontWeight.w600),)),
                          ],
                        ),

                      );
                    },itemCount: _scannedProducts.length,shrinkWrap: true,) ,
                  ),


                ],
              ),
            ),


          ],
        ),
      ),
    );
  }


}

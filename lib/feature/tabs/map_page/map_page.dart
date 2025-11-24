import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:ambient/feature/tabs/map_tab/models/map_painter.dart';

import 'package:ambient/feature/tabs/map_tab/models/room_model.dart';



class MapPage extends StatefulWidget {

  final String wsUrl; // e.g., ws://yourserver/ws

  const MapPage({Key? key, required this.wsUrl}) : super(key: key);



  @override

  _MapPageState createState() => _MapPageState();

}



class _MapPageState extends State<MapPage> {

  // Room dimensions

  late double scale;

  late double roomWidth, roomHeight;

  late double roomMargin;

  late double mapWidth, mapHeight;

  late double roomLeft, roomTop, roomRight, roomBottom;

  late double roomCenterX, roomCenterY;



  // Beacons positions (meters)

  final List<Offset> beaconsMeters = [

    Offset(3, 7.3),

    Offset(3, 3.5),

    Offset(5.5, 5.5),

    Offset(8.6, 7.3),

    Offset(8.6, 3.6),

  ];



  // Phone position (meters)

  Offset phonePositionMeters = const Offset(0, 0);

  

  // Room dimensions in meters (constants)

  static const double roomWidthMeters = 8.4;

  static const double roomHeightMeters = 10.0;



  late WebSocketChannel channel;

  

  // Bluetooth scanning

  List<ScanResult> devices = [];

  Stream<List<ScanResult>>? _scanStream;

  StreamSubscription? _scanSubscription;

  Timer? _scanTimer;



  @override

  void initState() {

    super.initState();

    _initializeDefaultDimensions();



    // Connect WebSocket

    channel = WebSocketChannel.connect(Uri.parse(widget.wsUrl));

    channel.stream.listen((message) {

      try {

        final data = json.decode(message);

        // Expecting {"x": 3.0, "y": 5.0}

        if (data is Map && data.containsKey('x') && data.containsKey('y')) {

          setState(() {

            // Normalize the received values to be within room boundaries

            final rawX = (data['x'] ?? 0).toDouble();

            final rawY = (data['y'] ?? 0).toDouble();

            

            phonePositionMeters = _normalizePosition(rawX, rawY);

          });

        }

      } catch (e) {

        print('Error parsing WebSocket message: $e');

      }

    }, onError: (error) {

      print('WebSocket error: $error');

    }, onDone: () {

      print('WebSocket connection closed');

    });



    // Initialize permissions and start scanning

    _initPermissions();

    _startContinuousScanning();

  }



  void _initializeDefaultDimensions() {

    // This will be recalculated in build() based on screen size

    const defaultScale = 50.0; // pixels per meter

    scale = defaultScale;



    roomWidth = roomWidthMeters * defaultScale;

    roomHeight = roomHeightMeters * defaultScale;



    roomMargin = 24.0;

    mapWidth = roomWidth + roomMargin * 2;

    mapHeight = roomHeight + roomMargin * 2;



    roomLeft = roomMargin;

    roomTop = roomMargin;

    roomRight = roomLeft + roomWidth;

    roomBottom = roomTop + roomHeight;

    roomCenterX = roomLeft + roomWidth / 2;

    roomCenterY = roomTop + roomHeight / 2;

  }



  void _calculateMapDimensions(double availableWidth, double availableHeight) {



    // Calculate scale while keeping aspect ratio

    final scaleX = availableWidth / roomWidthMeters;

    final scaleY = availableHeight / roomHeightMeters;

    final computedScale = scaleX < scaleY ? scaleX : scaleY;



    // Save computed scale (meters -> pixels)

    scale = computedScale;



    // Room size in pixels

    roomWidth = roomWidthMeters * scale;

    roomHeight = roomHeightMeters * scale;



    // Margin (centering)

    roomMargin = (availableWidth - roomWidth) / 2; // horizontal centering

    mapWidth = availableWidth;

    mapHeight = availableHeight;



    // Room bounds

    roomLeft = roomMargin;

    roomTop = (mapHeight - roomHeight) / 2; // vertical centering

    roomRight = roomLeft + roomWidth;

    roomBottom = roomTop + roomHeight;



    // Center

    roomCenterX = roomLeft + roomWidth / 2;

    roomCenterY = roomTop + roomHeight / 2;

  }



  // Normalize position to be within room boundaries (in meters)

  Offset _normalizePosition(double x, double y) {

    // Clamp x to [0, roomWidthMeters]

    final normalizedX = x.clamp(0.0, roomWidthMeters);

    

    // Clamp y to [0, roomHeightMeters]

    final normalizedY = y.clamp(0.0, roomHeightMeters);

    

    return Offset(normalizedX, normalizedY);

  }



  // Convert meters to pixels

  Offset _toPixel(Offset pos) {

    // Ensure position is normalized before converting

    final normalized = _normalizePosition(pos.dx, pos.dy);

    return Offset(roomLeft + normalized.dx * scale, roomTop + roomHeight - normalized.dy * scale);

  }



  // Get walls for the room

  List<Wall> get walls => [

    // Bottom wall

    Wall(Offset(roomLeft, roomBottom), Offset(roomRight, roomBottom)),

    // Right wall

    Wall(Offset(roomRight, roomBottom), Offset(roomRight, roomTop)),

    // Top wall

    Wall(Offset(roomRight, roomTop), Offset(roomLeft, roomTop)),

    // Left wall

    Wall(Offset(roomLeft, roomTop), Offset(roomLeft, roomBottom)),

  ];



  // Get doors for the room

  List<Door> get doors => [

    // Door in bottom wall (centered)

    Door(

      Offset(roomCenterX - 20, roomBottom),

      Offset(roomCenterX + 20, roomBottom),

    ),

  ];



  // Get beacons as Offset list (for MapPainter)

  List<Offset> get beaconsPixels => beaconsMeters.map(_toPixel).toList();



  // Get phone as Pin

  Pin get phonePin => Pin(

    position: _toPixel(phonePositionMeters),

    label: 'Phone',

    color: Colors.red,

  );



  Future<void> _initPermissions() async {

    print("Requesting Bluetooth permissions...");

    final permissions = await [

      Permission.bluetoothScan,

      Permission.bluetoothConnect,

      Permission.location,

    ].request();

    

    for (var permission in permissions.entries) {

      print("Permission ${permission.key}: ${permission.value}");

    }

  }



  void _startContinuousScanning() {

    print("Starting continuous Bluetooth scan...");

    _scanStream = FlutterBluePlus.scanResults;

    

    _scanSubscription = _scanStream?.listen(

      (results) {

        print("Scan results received: ${results.length} devices");

        setState(() {

          devices = results;

        });

        

        // Send RSSI values over WebSocket

        _sendRSSIOverWebSocket();

      },

      onError: (error) {

        print("Bluetooth scan error: $error");

      },

    );

    

    try {

      FlutterBluePlus.startScan(

        timeout: const Duration(seconds: 4),

        androidUsesFineLocation: true,

      );

      

      // Restart scan every 5 seconds to keep it continuous

      _scanTimer = Timer.periodic(const Duration(seconds: 5), (_) {

        if (!FlutterBluePlus.isScanningNow) {

          FlutterBluePlus.startScan(

            timeout: const Duration(seconds: 4),

            androidUsesFineLocation: true,

          );

        }

      });

    } catch (e) {

      print("Error starting Bluetooth scan: $e");

    }

  }



  void _sendRSSIOverWebSocket() {

    if (devices.isEmpty) {

      return;

    }

    

    try {

      // Send each device's RSSI value over WebSocket

      for (var device in devices) {

        final jsonData = jsonEncode({

          'uuid': device.device.remoteId.toString(),

          'rssi': device.rssi,

        });

        print("Sending RSSI data: $jsonData");

        channel.sink.add(jsonData);

      }

    } catch (e) {

      print("Error sending RSSI over WebSocket: $e");

    }

  }



  @override

  void dispose() {

    _scanTimer?.cancel();

    _scanSubscription?.cancel();

    FlutterBluePlus.stopScan();

    channel.sink.close();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text("Room Map")),

      body: Column(

        children: [

          // Status info

          Container(

            padding: const EdgeInsets.all(16),

            color: Colors.blue[50],

            child: Row(

              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [

                Column(

                  children: [

                    Text(

                      "Beacons Found",

                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),

                    ),

                    Text(

                      "${devices.length}",

                      style: const TextStyle(

                        fontSize: 20,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ],

                ),

                Column(

                  children: [

                    Text(

                      "Phone Position",

                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),

                    ),

                    Text(

                      "(${phonePositionMeters.dx.toStringAsFixed(2)}, ${phonePositionMeters.dy.toStringAsFixed(2)})",

                      style: const TextStyle(

                        fontSize: 16,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),

          // Map

          Expanded(

            child: LayoutBuilder(

              builder: (context, constraints) {

                // Use available space from LayoutBuilder

                final availableWidth = constraints.maxWidth * 0.95;

                final availableHeight = constraints.maxHeight * 0.95;



                // Calculate dimensions based on available space

                _calculateMapDimensions(availableWidth, availableHeight);



                return Center(

                  child: Container(

                    width: availableWidth,

                    height: availableHeight,

                    decoration: BoxDecoration(

                      border: Border.all(color: Colors.grey[400]!, width: 2),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: CustomPaint(

                      size: Size(availableWidth, availableHeight),

                      painter: MapPainter(

                        walls: walls,

                        doors: doors,

                        beacons: beaconsPixels,

                        pins: [phonePin],

                        zoomLevel: 1.0,

                      ),

                    ),

                  ),

                );

              },

            ),

          ),

        ],

      ),

    );

  }

}


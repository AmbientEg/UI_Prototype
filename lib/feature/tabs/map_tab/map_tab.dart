import 'dart:async';
import 'dart:convert';

import 'package:ambient/feature/tabs/map_tab/models/room_model.dart';
import 'package:ambient/feature/tabs/map_tab/models/signal_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';


import 'models/map_painter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<Offset> beacons = [];
  final List<Pin> pins = [];
  final Map<String, SignalModel> _beaconSignals = {};
  // Scale: meters -> pixels (updated in _calculateMapDimensions)
  double scale = 50.0;
  // Track websocket-sourced beacons by id so we can update/replace them
  final Map<String, BeaconPin> _wsBeacons = {};
  late final WebSocketChannel channel;
  // Scanning state
  List<ScanResult> devices = [];
  Stream<List<ScanResult>>? _scanStream;

  // Zoom state
  double zoomLevel = 1.0;
  final double minZoom = 0.5;
  final double maxZoom = 3.0;
  
  // Pin input controllers
  final TextEditingController xController = TextEditingController();
  final TextEditingController yController = TextEditingController();
  final TextEditingController labelController = TextEditingController();

  // Dynamic map dimensions
  late double mapWidth;
  late double mapHeight;
  late double roomMargin;
  late double roomWidth;
  late double roomHeight;
  late double roomCenterX;
  late double roomCenterY;
  late double roomLeft;
  late double roomTop;
  late double roomRight;
  late double roomBottom;

  Timer? _cleanupTimer;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDefaultDimensions();
    _initWebSocket();
    _initPermissions();

    // Start cleanup timer
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _cleanupStaleBeacons(),
    );
  }

  void _initWebSocket() {
    try {
      channel = WebSocketChannel.connect(
        Uri.parse("ws://192.168.1.3:8000/ws"),
      );
      print("WebSocket connected to ws://10.0.2.2:8000/ws");
      
      // Listen for WebSocket connection events
      channel.stream.listen(
        (data) {
          print("WebSocket received: $data");
          _processWebSocketData(data);
        },
        onError: (error) {
          print("WebSocket error: $error");
        },
        onDone: () {
          print("WebSocket connection closed");
        },
      );
    } catch (e) {
      print("Failed to connect WebSocket: $e");
    }
  }

  void _processWebSocketData(dynamic data) {
    try {
      // Expecting JSON like: {"id":"beacon1","x":1.2,"y":3.4}
      final decoded = data is String ? jsonDecode(data) : data;

      if (decoded is Map && decoded.containsKey('x') && decoded.containsKey('y')) {
        final rawX = decoded['x'];
        final rawY = decoded['y'];
        final id = (decoded['id'] ?? decoded['uuid'] ?? decoded['name'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();

        if (rawX is num && rawY is num) {
          final double xMeters = rawX.toDouble();
          final double yMeters = rawY.toDouble();

          // Convert room coordinates (origin: bottom-left) to screen coordinates
          final offset = _roomToScreenOffset(xMeters, yMeters);

          // Replace any existing WS beacon with same id
          setState(() {
            _wsBeacons[id] = BeaconPin(
              position: offset,
              label: id,
              color: Colors.green,
              // rssi optional
              rssi: decoded['rssi'] is num ? decoded['rssi'].toDouble() : null,
            );

            // Remove previous pins with same label then add all ws beacons
            pins.removeWhere((p) => p is BeaconPin && _wsBeacons.keys.contains(p.label));
            pins.addAll(_wsBeacons.values);
          });
        }
      }
    } catch (e) {
      print('Failed to process websocket data: $e');
    }
  }

  Offset _roomToScreenOffset(double xMeters, double yMeters) {
    // Convert meters to pixels using current scale and room bounds.
    // Origin for incoming data: bottom-left of room (0,0 at bottom-left, y up)
    // Flutter canvas origin: top-left (y down). roomLeft/roomTop/roomBottom are in pixels.

    final px = roomLeft + xMeters * scale;
    final py = roomBottom - yMeters * scale; // invert y
    return Offset(px, py);
  }

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

  void scan() {
    print("Starting Bluetooth scan...");
    setState(() {
      devices.clear();
      _scanStream = FlutterBluePlus.scanResults;
    });
    
    try {
      FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true,
      );
      
      _scanStream?.listen(
        (results) {
          print("Scan results received: ${results.length} devices");
          setState(() {
            devices = results;
          });
          
          // Process scan results into beacon signals
          for (var result in results) {
            print("Processing device: ${result.device.remoteId}, RSSI: ${result.rssi}");
            final signal = SignalModel(
              beaconId: result.device.id.id,
              rssi: result.rssi.toDouble(),
              beaconPosition: _calculateBeaconPosition(result.rssi),
              timestamp: DateTime.now(),
            );
            _handleBeaconSignal(signal);
          }
          
          // Send devices over WebSocket after they are found
          sendDevicesOverWebSocket();
        },
        onError: (error) {
          print("Bluetooth scan error: $error");
        },
      );
    } catch (e) {
      print("Error starting Bluetooth scan: $e");
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      _scanStream = null;
    });
  }

  Offset _calculateBeaconPosition(int rssi) {
    // Example position calculation - replace with your actual positioning logic
    return Offset(
      roomCenterX + (rssi + 100) * 2,
      roomCenterY + (rssi + 90) * 2,
    );
  }

  void _cleanupStaleBeacons() {
    final now = DateTime.now();
    setState(() {
      _beaconSignals.removeWhere((_, signal) {
        return now.difference(signal.timestamp) > const Duration(seconds: 5);
      });
      _updateBeaconPins();
    });
  }

  void _initializeDefaultDimensions() {
    // Fallback scale in pixels per meter
    const defaultScale = 50.0;
    scale = defaultScale;

    final roomWidthMeters = 8.4;
    final roomHeightMeters = 10.0;

    // Apply scale
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



  void _calculateMapDimensions() {
    final screenSize = MediaQuery.of(context).size;

    final roomWidthMeters = 8.4;
    final roomHeightMeters = 10.0;

    // Available space on screen
    final availableWidth = screenSize.width * 0.9;
    final availableHeight = screenSize.height * 0.5;

    // Calculate scale while keeping aspect ratio
    final scaleX = availableWidth / roomWidthMeters;
    final scaleY = availableHeight / roomHeightMeters;
    final computedScale = scaleX < scaleY ? scaleX : scaleY;

    // Save computed scale (meters -> pixels)
    scale = computedScale;

    // Room size in pixels
    roomWidth = roomWidthMeters * scale;
    roomHeight = roomHeightMeters * scale;

    // Margin
    roomMargin = (availableWidth - roomWidth) / 2; // horizontal centering
    mapWidth = roomWidth + roomMargin * 2;
    mapHeight = roomHeight + roomMargin * 2;

    // Room bounds
    roomLeft = roomMargin;
    roomTop = (mapHeight - roomHeight) / 2; // vertical centering
    roomRight = roomLeft + roomWidth;
    roomBottom = roomTop + roomHeight;

    // Center
    roomCenterX = roomLeft + roomWidth / 2;
    roomCenterY = roomTop + roomHeight / 2;
  }


  List<Wall> get walls => [
    // Dynamic room walls based on calculated dimensions (reversed: start from bottom)
    Wall(Offset(roomLeft, roomBottom), Offset(roomRight, roomBottom)), // Bottom wall
    Wall(Offset(roomRight, roomBottom), Offset(roomRight, roomTop)), // Right wall
    Wall(Offset(roomRight, roomTop), Offset(roomLeft, roomTop)), // Top wall
    Wall(Offset(roomLeft, roomTop), Offset(roomLeft, roomBottom)),   // Left wall
  ];

  List<Door> get doors => [
    // Dynamic door position in bottom wall
    Door(
      Offset(roomCenterX - 20, roomBottom), 
      Offset(roomCenterX + 20, roomBottom)
    ),
  ];

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _scanSubscription?.cancel();
    xController.dispose();
    yController.dispose();
    labelController.dispose();
    super.dispose();
    channel.sink.close();
  }

  void _zoomIn() {
    setState(() {
      if (zoomLevel < maxZoom) {
        zoomLevel = (zoomLevel + 0.25).clamp(minZoom, maxZoom);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      if (zoomLevel > minZoom) {
        zoomLevel = (zoomLevel - 0.25).clamp(minZoom, maxZoom);
      }
    });
  }

  void _addPinFromCoordinates() {
    final x = double.tryParse(xController.text);
    final y = double.tryParse(yController.text);
    
    if (x != null && y != null) {
      // Convert centered coordinates to screen coordinates using dynamic dimensions
      final screenX = roomCenterX + x;
      final screenY = roomCenterY - y; // Flip Y axis so positive Y goes up
      
      // Calculate coordinate limits dynamically
      final maxX = roomWidth / 2;
      final maxY = roomHeight / 2;
      
      // Validate coordinates are within room bounds
      if (screenX >= roomLeft && screenX <= roomRight && 
          screenY >= roomTop && screenY <= roomBottom) {
        setState(() {
          pins.add(Pin(
            position: Offset(screenX, screenY),
            label: labelController.text.isNotEmpty ? labelController.text : null,
          ));
        });
        
        // Clear controllers
        xController.clear();
        yController.clear();
        labelController.clear();
        
        // Close dialog
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pin must be placed within the room bounds (X: ${-maxX.round()} to ${maxX.round()}, Y: ${-maxY.round()} to ${maxY.round()})'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid X and Y coordinates')),
      );
    }
  }

  void _showAddPinDialog() {
    // Calculate dynamic coordinate ranges
    final maxX = roomWidth / 2;
    final maxY = roomHeight / 2;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Pin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Coordinate System: (0,0) is at the room center\nX: ${-maxX.round()} to ${maxX.round()}, Y: ${-maxY.round()} to ${maxY.round()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: xController,
                  decoration: InputDecoration(
                    labelText: 'X Coordinate',
                    hintText: 'Enter X (${-maxX.round()} to ${maxX.round()})',
                    border: const OutlineInputBorder(),
                    helperText: 'Positive = right of center',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: yController,
                  decoration: InputDecoration(
                    labelText: 'Y Coordinate',
                    hintText: 'Enter Y (${-maxY.round()} to ${maxY.round()})',
                    border: const OutlineInputBorder(),
                    helperText: 'Positive = above center',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label (Optional)',
                    hintText: 'Enter pin label',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addPinFromCoordinates,
              child: const Text('Add Pin'),
            ),
          ],
        );
      },
    );
  }

  void _handleBeaconSignal(SignalModel signal) {
    setState(() {
      _beaconSignals[signal.beaconId] = signal;
      _updateBeaconPins();
    });
  }

  void _updateBeaconPins() {
    pins.removeWhere((pin) => pin is BeaconPin);

    for (var signal in _beaconSignals.values) {
      pins.add(BeaconPin(
        position: signal.beaconPosition,
        label: signal.beaconName, // Use beacon name instead of ID
        color: Colors.blue,
        rssi: signal.rssi,
      ));
    }
  }
  // void sendDevicesOverWebSocket() {
  //   final deviceList = devices.map((d) => {
  //     'uuid': d.device.remoteId,
  //     'rssi': d.rssi,
  //     // 'minor':d.device.,
  //   }).toList();
  //   final jsonDevicesList=jsonEncode(deviceList);
  //   channel.sink.add(jsonDevicesList);
  // }
  void sendDevicesOverWebSocket() {
    print("sendDevicesOverWebSocket called with ${devices.length} devices");
    if (devices.isEmpty) {
      print("No devices to send - devices list is empty");
      return;
    }
    
    try {
      for (var d in devices) {
        final jsonData = jsonEncode({
          'uuid': d.device.remoteId.toString(),
          'rssi': d.rssi,
        });
        print("Sending device data: $jsonData");
        channel.sink.add(jsonData);
      }
    } catch (e) {
      print("Error sending data over WebSocket: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recalculate map dimensions for current screen size
    _calculateMapDimensions();

    // Detect device type (mobile vs tablet) using shortestSide
    final media = MediaQuery.of(context);
    final isTablet = media.size.shortestSide >= 600;

    // Calculate dynamic coordinate ranges for instructions
    final maxX = roomWidth / 2;
    final maxY = roomHeight / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Interactive Map"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location),
            onPressed: _showAddPinDialog,
            tooltip: 'Add Pin',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info panel with scanning controls (responsive)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: isTablet
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildInfoItem("Walls", walls.length, Colors.brown),
                          const SizedBox(width: 12),
                          _buildInfoItem("Doors", doors.length, Colors.green),
                          const SizedBox(width: 12),
                          _buildInfoItem("Beacons", devices.length, Colors.red),
                          const SizedBox(width: 12),
                          _buildInfoItem("Pins", pins.length, Colors.blue),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: scan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            child: const Text("Search for Beacons"),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: stopScan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            child: const Text("Stop Search"),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildInfoItem("Walls", walls.length, Colors.brown),
                          _buildInfoItem("Doors", doors.length, Colors.green),
                          _buildInfoItem("Beacons", devices.length, Colors.red),
                          _buildInfoItem("Pins", pins.length, Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: scan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Search for Beacons"),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: stopScan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Stop Search"),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          // Map area with zoom controls (responsive sizing)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final containerWidth = isTablet ? constraints.maxWidth * 0.75 : constraints.maxWidth * 0.95;
                final containerHeight = isTablet ? constraints.maxHeight * 0.9 : constraints.maxHeight * 0.95;

                return Stack(
                  children: [
                    Center(
                      child: Container(
                        width: containerWidth,
                        height: containerHeight,
                        margin: EdgeInsets.all(isTablet ? 24 : 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                          onTapUp: (details) {
                            setState(() {
                              // add beacon at tap position
                              beacons.add(details.localPosition);
                            });
                          },
                          child: CustomPaint(
                            size: Size(containerWidth, containerHeight),
                            painter: MapPainter(
                              walls: walls,
                              doors: doors,
                              beacons: beacons,
                              pins: pins,
                              zoomLevel: zoomLevel,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Zoom controls
                    Positioned(
                      right: isTablet ? 32 : 20,
                      top: isTablet ? 32 : 20,
                      child: Column(
                        children: [
                          isTablet
                              ? FloatingActionButton(
                                  onPressed: _zoomIn,
                                  backgroundColor: Colors.blue[700],
                                  child: const Icon(Icons.zoom_in, color: Colors.white),
                                )
                              : FloatingActionButton.small(
                                  onPressed: _zoomIn,
                                  backgroundColor: Colors.blue[700],
                                  child: const Icon(Icons.zoom_in, color: Colors.white),
                                ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              '${(zoomLevel * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          isTablet
                              ? FloatingActionButton(
                                  onPressed: _zoomOut,
                                  backgroundColor: Colors.blue[700],
                                  child: const Icon(Icons.zoom_out, color: Colors.white),
                                )
                              : FloatingActionButton.small(
                                  onPressed: _zoomOut,
                                  backgroundColor: Colors.blue[700],
                                  child: const Icon(Icons.zoom_out, color: Colors.white),
                                ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "Tap anywhere on the map to add a beacon • Use zoom controls to zoom in/out",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Pin coordinates: (0,0) = room center • X: ${-maxX.round()} to ${maxX.round()}, Y: ${-maxY.round()} to ${maxY.round()}",
                  style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$label: $count",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
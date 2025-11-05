import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'room_model.dart';

class MapPainter extends CustomPainter {
  final List<Wall> walls;
  final List<Door> doors;
  final List<Offset> beacons;
  final List<Pin> pins;
  final double zoomLevel;

  MapPainter({
    required this.walls, 
    required this.doors, 
    required this.beacons,
    required this.pins,
    this.zoomLevel = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Apply zoom transformation
    canvas.save();
    
    // Center the zoom transformation
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    canvas.translate(centerX, centerY);
    canvas.scale(zoomLevel);
    canvas.translate(-centerX, -centerY);

    // Draw background
    final backgroundPaint = Paint()
      ..color = Colors.grey[100]!
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    // Vertical grid lines
    for (double x = 0; x <= size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal grid lines
    for (double y = 0; y <= size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final wallPaint = Paint()
      ..color = Colors.brown
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final doorPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final beaconPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw walls
    for (var wall in walls) {
      canvas.drawLine(wall.start, wall.end, wallPaint);
    }

    // Draw doors
    for (var door in doors) {
      canvas.drawLine(door.start, door.end, doorPaint);
    }

    // Draw beacons
    for (var beacon in beacons) {
      canvas.drawCircle(beacon, 8, beaconPaint);
    }

    // Draw pins
    for (var pin in pins) {
      final pinPaint = Paint()
        ..color = pin.color
        ..style = PaintingStyle.fill;
      
      final radius = (pin is BeaconPin) ? 12.0 : 10.0;

      // Draw pin circle
      canvas.drawCircle(pin.position, radius, pinPaint);

      // Draw pin border
      final pinBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(pin.position, radius, pinBorderPaint);

      // Draw pin label if provided
      if (pin.label != null) {
        final String displayText = (pin is BeaconPin)
            ? pin.label! // Show only the beacon name
            : pin.label!;

        final textPainter = TextPainter(
          text: TextSpan(
            text: displayText,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        textPainter.layout(maxWidth: 100);
        textPainter.paint(
          canvas,
          Offset(
            pin.position.dx - textPainter.width / 2,
            pin.position.dy + radius + 5,
          ),
        );
      }
    }

    canvas.restore();
  }


  @override
  bool shouldRepaint(MapPainter old) =>
      !listEquals(old.beacons, beacons) ||
          !listEquals(old.walls, walls) ||
          !listEquals(old.doors, doors) ||
          !listEquals(old.pins, pins) ||
          old.zoomLevel != zoomLevel;

}
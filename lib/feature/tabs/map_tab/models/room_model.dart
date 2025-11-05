import 'dart:ui';
import 'package:flutter/material.dart';

class Wall {
  final Offset start;
  final Offset end;
  Wall(this.start, this.end);
}

class Door {
  final Offset start;
  final Offset end;
  Door(this.start, this.end);
}

class Pin {
  final Offset position;
  final String? label;
  final Color color;
  
  Pin({
    required this.position,
    this.label,
    this.color = Colors.blue,
  });
}

class BeaconPin extends Pin {
  final double rssi;

  BeaconPin({
    required super.position,
    required super.label,
    required super.color,
    required this.rssi,
  });
}

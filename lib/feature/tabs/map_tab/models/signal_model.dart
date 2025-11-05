import 'package:flutter/material.dart';
class SignalModel {
 String beaconId;
 String beaconName; // Add name field
 double rssi;
 Offset beaconPosition;
 DateTime timestamp;

 SignalModel({
 required this.beaconId,
 this.beaconName = '', // Default empty name
 required this.rssi,
 required this.beaconPosition,
 required this.timestamp,
 });
}
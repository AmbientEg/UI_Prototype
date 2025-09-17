import 'package:ambient/core/app_colors.dart';
import 'package:ambient/core/app_images.dart';
import 'package:ambient/core/app_routes.dart';
import 'package:ambient/core/app_text_styles.dart';
import 'package:ambient/feature/tabs/home_tab/widgets/beacons_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<ScanResult> _devices = [];
  Stream<List<ScanResult>>? _scanStream;
  @override
  void initState() {
    super.initState();
    _initPermissions();
  }
  Future<void> _initPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }



    void scan() {
      setState(() {
        _devices.clear();
        _scanStream = FlutterBluePlus.scanResults;
      });

      FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true, // required for beacons
      );

      _scanStream?.listen((results) {
        setState(() {
          _devices = results;
        });
      });
    }
    void stopScan(){
      FlutterBluePlus.stopScan();
      setState(() {
        _scanStream=null;
      });
    }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyColor,
      appBar: AppBar(
        leading: Icon(Icons.arrow_back, color: AppColors.lightCyan),
        title: Text("Home", style: AppTextStyles.bold20white),
        centerTitle: true,
        backgroundColor: AppColors.transparentColor,
        actions: [
          Icon(Icons.settings, color: AppColors.lightCyan),
          SizedBox(width: 16)
        ],
      ),
      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(), // Ensures scrolling is always enabled
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 200,
                width: double.infinity, // Changed from fixed width to full width
                decoration: BoxDecoration(
                    color: AppColors.darkCyan,
                    borderRadius: BorderRadius.circular(16)
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesome.location_dot_solid, color: AppColors.whiteColor, size: 50),
                        SizedBox(width: 8),
                        Text("User's Location\n ( X , Y )", style: AppTextStyles.bold20white),
                      ],
                    )
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Text("Available beacons🌐", style: AppTextStyles.bold20white),
                  Spacer(),
                  ElevatedButton(
                    onPressed: scan,style:ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkCyan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                  ) , child: Text("Search for beacons",style:AppTextStyles.bold16white,)
                    , ),
                  SizedBox(width:10,),
                  ElevatedButton(
                    onPressed: stopScan,style:ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkCyan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                  ) , child: Text("Stop Search",style:AppTextStyles.bold16white,)
                    , ),

                ],
              ),
              SizedBox(height: 20),
              BeaconsItem(devices: _devices,),
              SizedBox(height: 20), // Added bottom padding for better scrolling experience
            ],
          ),
        ),
      ),
    );
  }
}


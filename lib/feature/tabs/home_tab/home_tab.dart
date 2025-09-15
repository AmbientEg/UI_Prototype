import 'package:ambient/core/app_colors.dart';
import 'package:ambient/core/app_images.dart';
import 'package:ambient/core/app_text_styles.dart';
import 'package:ambient/feature/tabs/home_tab/widgets/beacons_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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
              SizedBox(height: 40),
              Text("live Rssi Readings", style: AppTextStyles.bold20white, textAlign: TextAlign.center),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(5),
                      margin: EdgeInsets.only(right: 8),
                      height: 300,
                      decoration: BoxDecoration(
                          color: AppColors.navyColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryGrey, width: 2)
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Better spacing
                          children: [
                            Text("Rssi Reading", style: AppTextStyles.bold20white),
                            Flexible(child: Image.asset(AppImages.waveImg)), // Made image flexible
                            Text("-79 Dbm", style: AppTextStyles.bold20white),
                          ]
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(5),
                      margin: EdgeInsets.only(left: 8),
                      height: 300,
                      decoration: BoxDecoration(
                          color: AppColors.navyColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryGrey, width: 2)
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Better spacing
                          children: [
                            Text("Kalman Rssi", style: AppTextStyles.bold20white),
                            Flexible(child: Image.asset(AppImages.waveImg)), // Made image flexible
                            Text("-50 Dbm", style: AppTextStyles.bold20white),
                          ]
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text("Connected Beacons 🌐", style: AppTextStyles.bold20white),
              SizedBox(height: 20),
              BeaconsItem(),
              SizedBox(height: 20), // Added bottom padding for better scrolling experience
            ],
          ),
        ),
      ),
    );
  }
}
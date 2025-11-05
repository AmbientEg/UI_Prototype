import 'package:ambient/core/app_colors.dart';
import 'package:ambient/core/app_images.dart';
import 'package:ambient/core/app_routes.dart';
import 'package:ambient/core/app_text_styles.dart';
import 'package:ambient/feature/tabs/map_tab/map_tab.dart';
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
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _navigateToMap,
                child: Container(
                  height: 200,
                  width: double.infinity,
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
              ),
              SizedBox(height: 20),
              Text("Navigate to Interactive Map", style: AppTextStyles.bold20white),
              SizedBox(height: 20),
              ElevatedButton(onPressed: (){
                Navigator.pushNamed(context, AppRoutes.testScreen);
              }, child:Text("Test Screen"))
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapScreen(),
      ),
    );
  }
}

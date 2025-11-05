import 'package:ambient/core/app_routes.dart';
import 'package:ambient/feature/tabs/home_tab/home_tab.dart';
import 'package:ambient/feature/tabs/tests/test_screen.dart';
import 'package:flutter/material.dart';

import 'feature/tabs/map_tab/map_tab.dart';
void main() {
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     debugShowCheckedModeBanner: false,
      initialRoute:AppRoutes.homeTab,
      routes:{
        AppRoutes.homeTab:(context)=>HomeTab(),
        AppRoutes.mapScreen:(context)=>const MapScreen(),
        AppRoutes.testScreen:(context)=>const TestScreen(title: 'Test',),

      },
    );
  }
}

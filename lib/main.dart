import 'package:ambient/core/app_routes.dart';
import 'package:ambient/feature/tabs/home_tab/home_tab.dart';
import 'package:ambient/feature/tabs/tests/test_screen.dart';
import 'package:flutter/material.dart';

import 'feature/tabs/map_tab/map_tab.dart';
import 'feature/tabs/map_page/map_page.dart';
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
        AppRoutes.mapPage:(context){
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final wsUrl = args?['wsUrl'] ?? 'ws://192.168.1.3:8000/ws';
          return MapPage(wsUrl: wsUrl);
        },
        AppRoutes.testScreen:(context)=>const TestScreen(title: 'Test',),

      },
    );
  }
}

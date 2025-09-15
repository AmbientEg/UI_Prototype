import 'package:ambient/core/app_routes.dart';
import 'package:ambient/feature/tabs/home_tab/home_tab.dart';
import 'package:flutter/material.dart';

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
      },
    );
  }
}

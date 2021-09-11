import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_tracking/mapTracking.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapTracking(
        deleget_id: 1,
        main_place: LatLng(31.417540, 31.814444),
        order_id: 1,
        isClientVersion: true,
      ),
    );
  }
}

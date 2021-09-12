import 'dart:async';
import 'dart:typed_data';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show SystemChrome, rootBundle;
import 'package:connectivity/connectivity.dart';
import 'package:firebase_database/firebase_database.dart';

class MapTracking extends StatefulWidget {
  LatLng main_place;
  int order_id;
  int deleget_id;
  bool isClientVersion;
  MapTracking(
      {required this.main_place,
      required this.order_id,
      required this.deleget_id,
      required this.isClientVersion});
  @override
  _MapTrackingState createState() => _MapTrackingState();
}

class _MapTrackingState extends State<MapTracking> {
  FlutterTts flutterTts = FlutterTts();

  final databaseReference = FirebaseDatabase(databaseURL: 'https://maptracking-f3214-default-rtdb.firebaseio.com/').reference(
    
  );

  Completer<GoogleMapController> _controller = Completer();
  Location _location = Location();

  late PolylinePoints polylinePoints;

  CameraPosition initLocation = CameraPosition(
      target: LatLng(24.774265, 46.738586), zoom: -200, bearing: 500);

  late Position position;
  List<Marker> _markers = <Marker>[];

// List of coordinates to join
  List<LatLng> polylineCoordinates = [];

// Map storing polylines created by connecting
// two points
  Map<PolylineId, Polyline> polylines = {};

// for my custom icons
  late BitmapDescriptor sourceIcon;
  late BitmapDescriptor destinationIcon;

  late Uint8List markerDelegetIcon;
  late Uint8List markerClientIcon;

  late String _mapStyle;
  late GoogleMapController newController;

  String delegetStreet = '';
  String distance = '0';
  String time = '';

  late bool isConnectingToNetWorking;
  var subscription;

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIOverlays([]);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    rootBundle.loadString('assets/marker.png').then((string) {
      _mapStyle = string;
    });

    checkNetworking().then((value) {
      getMyLocationAndSetMarkers().then((value) {
        if (widget.isClientVersion) {
          databaseReference
              .child("DelegetId_" + widget.deleget_id.toString())
              .reference()
              .onValue
              .listen((snapshot) {
            print('Data : ${snapshot.snapshot.value}');

            updateRoutAndMarkerOfDeleget(
                snapshot.snapshot.value['lat'], snapshot.snapshot.value['lng']);

            setState(() {
              delegetStreet = snapshot.snapshot.value['address'];
              distance = snapshot.snapshot.value['distance'];
              time = snapshot.snapshot.value['time'];
            });
          });
        } else {
          databaseReference
              .child("DelegetId_" + widget.deleget_id.toString())
              .set({
            'lat': 0,
            'lng': 0,
            'address': '',
            'distance': '',
            'time': ''
          });

          _location.onLocationChanged.listen((LocationData currentLocation) {
            updateRoutAndMarkerOfDeleget(
                currentLocation.latitude!, currentLocation.longitude!);
          });
        }
      });
    });

//
    // TODO: implement initState
    super.initState();
  }

  @override
  void dispose() {
    subscription.cancel();
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () async {
          await flutterTts.awaitSpeakCompletion(true);

          if (isConnectingToNetWorking) {
            await flutterTts.speak("مكان المندوب الان :");
            await flutterTts.speak(delegetStreet);
//////////////////////////////////////////////////////////
            await flutterTts.speak("المسافه بينكم :");
            await flutterTts.speak(distance);
//////////////////////////////////////////////////////////
            await flutterTts.speak("الوقت المتوقع لوصول المندوب");
            await flutterTts.speak(time);
          } else {
            await flutterTts
                .speak("يرجي التأكد من الاتصال بالانترنت الخاص بك !");
          }
        },
        child: new Icon(
          Icons.record_voice_over_rounded,
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            child: GoogleMap(
              mapType: MapType.normal,
              markers: Set<Marker>.of(_markers),
              polylines: Set<Polyline>.of(polylines.values),
              initialCameraPosition: initLocation,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                newController = controller;
                newController.setMapStyle(_mapStyle);
              },
            ),
          ),
          Container(
            // margin: EdgeInsets.symmetric(vertical: 8.0),
            // height: 200.0,
            child: DraggableScrollableSheet(
              initialChildSize: 0.08,
              minChildSize: 0.08,
              maxChildSize: 0.26,
              expand: true,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30)),
                  ),
                  child: isConnectingToNetWorking == false
                      ? Center(
                          child: new Text(
                              "يرجي التأكد من الاتصال بالانترنت الخاص بك !"))
                      : SingleChildScrollView(
                          controller: scrollController,
                          child: Container(
                              //   width: 60,
                              // height: 60,

                              child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: new Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 4,
                                ),
                                Container(
                                  width: double.infinity,
                                  child: isConnectingToNetWorking == false
                                      ? new Text(
                                          'please connect to networking first !',
                                          textAlign: TextAlign.center,
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'التفاصيل',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            Image.asset(
                                              'assets/marker.png',
                                              width: 40,
                                              height: 25,
                                            ),
                                          ],
                                        ),
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                Divider(
                                  indent: 40,
                                  endIndent: 40,
                                  thickness: 3,
                                ),
                                SizedBox(
                                  height: 30,
                                ),
                                Row(
                                  children: [
                                    Text("مكان العميل  : "),
                                    Text(delegetStreet),
                                    // Text(delegetStreet),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text("المسافه بينكم :  "),
                                    Text(distance),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text("الوقت المتوقع للوصول : "),
                                    Text(time),
                                  ],
                                ),
                                SizedBox(
                                  height: 40,
                                ),
                              ],
                            ),
                          )),
                        ),
                );
              },
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: ClipOval(
              child: Material(
                color: Colors.black, // button color
                child: InkWell(
                  splashColor: Colors.blue, // inkwell color
                  child: SizedBox(
                      width: 50,
                      height: 50,
                      child: RotationTransition(
                        turns: new AlwaysStoppedAnimation(180 / 360),
                        child: Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      )),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Future getMyLocationAndSetMarkers() async {
    markerDelegetIcon =
        await getBytesFromAsset("assets/marker.png", 120);
    markerClientIcon =
        await getBytesFromAsset('assets/marker.png', 120);

    position = await Geolocator.getCurrentPosition();

    setState(() {
      _markers.add(Marker(
          markerId: MarkerId('1'),
          position: LatLng(position.latitude, position.longitude),
          icon: BitmapDescriptor.fromBytes(markerDelegetIcon),
          infoWindow: InfoWindow(title: 'Deleget Here')));
      _markers.add(Marker(
          markerId: MarkerId('2'),
          position: widget.main_place,
          icon: BitmapDescriptor.fromBytes(markerClientIcon),
          infoWindow: InfoWindow(title: 'Client Here')));
    });

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 15.4746,
      tilt: 59.440717697143555,
    )));

    _createRoute(
      LatLng(position.latitude, position.longitude),
      widget.main_place,
    );
  }

  _createRoute(LatLng start, LatLng destination) async {
    // Initializing PolylinePoints
    polylinePoints = PolylinePoints();

    // Generating the list of coordinates to be used for
    // drawing the polylines
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        'AIzaSyBhwUPb_bGJzGj0Wnj89dcnU5NZQhGx9jY', // Google Maps API Key
        PointLatLng(start.latitude, start.longitude),
        PointLatLng(destination.latitude, destination.longitude),
        optimizeWaypoints: false,
        // wayPoints:<PolylineWayPoint>[
        //   PolylineWayPoint(location: '(31.031954,31.362473)',stopOver: true)
        // ] ,
        //  travelMode: TravelMode.transit,
        avoidFerries: true,
        avoidTolls: true,
        avoidHighways: true,
        travelMode: TravelMode.driving);
    polylineCoordinates.clear();
    // Adding the coordinates to the list
    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        print('dir ::- ' + point.latitude.toString());
      });
    }

    // Defining an ID
    PolylineId id = PolylineId('poly');
    // polylines.;

    // Initializing Polyline
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.black,
      onTap: () {},

      jointType: JointType.bevel,
      geodesic: true,
      zIndex: 5,
      points: polylineCoordinates,
      width: 5,

      // patterns: [PatternItem.dot, PatternItem.gap(20)],
    );

    setState(() {
      polylines.clear();
      // Adding the polyline to the map
      polylines[id] = polyline;
    });
    if (isConnectingToNetWorking == true) {
      if (widget.isClientVersion == false) {
        Dio dio = new Dio();
        Response response = await dio
            .get(
                "https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=${destination.latitude},${destination.longitude}&destinations=${destination.latitude},${destination.longitude}&key=AIzaSyBhwUPb_bGJzGj0Wnj89dcnU5NZQhGx9jY")
            .catchError((onError) {
          isConnectingToNetWorking = false;
        });

        print(response.data);

        setState(() {
          delegetStreet =
              response.data['origin_addresses'][0].toString().split(',')[0] +
                  ' ' +
                  response.data['origin_addresses'][0].toString().split(',')[1];
          distance = response.data['rows'][0]['elements'][0]['distance']['text']
              .toString();
          time = response.data['rows'][0]['elements'][0]['duration']['text'];
        });

        databaseReference
            .child("DelegetId_" + widget.deleget_id.toString())
            .update({
          'lat': start.latitude,
          'lng': start.longitude,
          'address': delegetStreet,
          'distance': distance,
          'time': time
        });
      }
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  updateRoutAndMarkerOfDeleget(double newLat, double newLong) async {
    markerDelegetIcon =
        await getBytesFromAsset("assets/marker.png", 120);

    setState(() {
      this._markers.removeWhere((content) => content.markerId.value == '1');

      _markers.add(Marker(
          markerId: MarkerId('1'),
          position: LatLng(newLat, newLong),
          icon: BitmapDescriptor.fromBytes(markerDelegetIcon),
          infoWindow: InfoWindow(title: 'Delegete Here')));
    });

    _createRoute(
      LatLng(newLat, newLong),
      widget.main_place,
    );
  }

  Future<void> checkNetworking() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      // I am connected to a mobile network.
      setState(() {
        isConnectingToNetWorking = true;
      });
    } else {
      setState(() {
        isConnectingToNetWorking = false;
      });
    }

    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      // Got a new connectivity status!
      if (result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile) {
        setState(() {
          isConnectingToNetWorking = true;
        });
      } else {
        setState(() {
          isConnectingToNetWorking = false;
        });
        //  print('برجاء الاتصال بالانترنت');
      }
    });
  }
}

// ignore_for_file: prefer_const_constructors, unused_local_variable

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:share_plus/share_plus.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  static final CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );
  Position? _currentPosition;
  final Set<Marker> _markers = {};

  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  MapType _currentMapType = MapType.normal;

  bool _showMarkerInfo = false;
  String _selectedMarkerTitle = "";
  String _selectedMarkerAddress = "";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location services are disabled')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are permanently denied')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;

      _markers.add(
        Marker(
          markerId: MarkerId('currentLocation'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });

    GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14.0,
        ),
      ),
    );
  }

  _searchPlace() async {
    if (_searchController.text.isEmpty) return;

    try {
      List<Location> locations =
          await locationFromAddress(_searchController.text);

      if (locations.isNotEmpty) {
        Location location = locations.first;

        List<Placemark> placemarks = await placemarkFromCoordinates(
            location.latitude, location.longitude);

        Placemark place = placemarks.first;
        String address = "${place.street}, ${place.locality}, ${place.country}";

        final MarkerId markerId = MarkerId('searchedLocation');
        final Marker marker = Marker(
          markerId: markerId,
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(
            title: _searchController.text,
            snippet: address,
          ),
          onTap: () {
            setState(() {
              _showMarkerInfo = true;
              _selectedMarkerTitle = _searchController.text;
              _selectedMarkerAddress = address;
            });
          },
        );

        setState(() {
          _markers.add(marker);
        });

        // Move camera to searched location
        GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(location.latitude, location.longitude),
              zoom: 16.0,
            ),
          ),
        );

        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not find the location. Please try again.')),
      );
    }
  }

  _addMarkerAtTappedLocation(LatLng tappedPoint) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          tappedPoint.latitude, tappedPoint.longitude);

      Placemark place = placemarks.first;
      String address = "${place.street}, ${place.locality}, ${place.country}";
      String title =
          place.name?.isNotEmpty == true ? place.name! : "${place.street}";

      final MarkerId markerId =
          MarkerId(DateTime.now().millisecondsSinceEpoch.toString());
      final Marker marker = Marker(
        markerId: markerId,
        position: tappedPoint,
        infoWindow: InfoWindow(
          title: title,
          snippet: address,
        ),
        onTap: () {
          setState(() {
            _showMarkerInfo = true;
            _selectedMarkerTitle = title;
            _selectedMarkerAddress = address;
          });
        },
      );

      setState(() {
        _markers.add(marker);
      });
    } catch (e) {
      log('Error adding marker: $e');
    }
  }

  _getDirections(LatLng origin, LatLng destination) async {
    setState(() {
      polylineCoordinates.clear();
      polylines.clear();
    });

    try {
      PolylineRequest request = PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      );

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: request,
        // Replace your API Key here
        googleApiKey: "AIzaSyDJ2v3f3Qu7uxgrT52j76AYnyC_pDIjWxE",
      );

      if (result.points.isNotEmpty) {
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
      } else {
        print("Failed to get directions: ${result.errorMessage}");
        polylineCoordinates.add(origin);
        polylineCoordinates.add(destination);
      }
    } catch (e) {
      print("Error getting directions: $e");
      polylineCoordinates.add(origin);
      polylineCoordinates.add(destination);
    }

    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blue,
      points: polylineCoordinates,
      width: 3,
    );

    setState(() {
      polylines[id] = polyline;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: Set<Polyline>.of(polylines.values),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onTap: (LatLng latLng) {
              setState(() {
                _showMarkerInfo = false;
              });
            },
            onLongPress: _addMarkerAtTappedLocation,
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search location',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onSubmitted: (value) {
                  _searchPlace();
                },
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  child: Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  child: Icon(Icons.map),
                  onPressed: _changeMapType,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 170,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  child: Icon(Icons.add),
                  onPressed: () async {
                    GoogleMapController controller = await _controller.future;
                    controller.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
                SizedBox(height: 10),
                FloatingActionButton.small(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  child: Icon(Icons.remove),
                  onPressed: () async {
                    GoogleMapController controller = await _controller.future;
                    controller.animateCamera(CameraUpdate.zoomOut());
                  },
                ),
              ],
            ),
          ),
          if (_showMarkerInfo)
            Positioned(
              bottom: 30,
              left: 20,
              right: 80,
              child: Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedMarkerTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      _selectedMarkerAddress,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.directions),
                          label: Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (_currentPosition != null) {
                              LatLng origin = LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              );

                              final selectedMarker = _markers.firstWhere(
                                (marker) =>
                                    marker.infoWindow.title ==
                                    _selectedMarkerTitle,
                                orElse: () => _markers.first,
                              );

                              _getDirections(origin, selectedMarker.position);
                            }
                          },
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.share),
                          label: Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                          ),
                          onPressed: () {
                            Share.share(
                                'hey! check out this app https://drive.google.com/file/d/19q5zSKPXn_DXP9W0BA2h-GBPY5bUvkkf/view?usp=drive_link',
                                subject: 'Google Map');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  _changeMapType() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.map),
              title: Text("Normal"),
              onTap: () {
                setState(() => _currentMapType = MapType.normal);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.satellite),
              title: Text("Satellite"),
              onTap: () {
                setState(() => _currentMapType = MapType.satellite);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.terrain),
              title: Text("Terrain"),
              onTap: () {
                setState(() => _currentMapType = MapType.terrain);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.layers),
              title: Text("Hybrid"),
              onTap: () {
                setState(() => _currentMapType = MapType.hybrid);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SelectLocation extends StatefulWidget {
  final LatLng? initialLocation;

  const SelectLocation({super.key, this.initialLocation});

  @override
  State<SelectLocation> createState() => _SelectLocationState();
}

class _SelectLocationState extends State<SelectLocation> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;

  final LatLng _defaultLocation = const LatLng(24.8607, 67.0011);

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation ?? _defaultLocation;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _pickedLocation = latLng;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        backgroundColor: Colors.green,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _pickedLocation ?? _defaultLocation,
          zoom: 15,
        ),
        onMapCreated: _onMapCreated,
        onTap: _onMapTap,
        markers: {
          if (_pickedLocation != null)
            Marker(
              markerId: const MarkerId("picked"),
              position: _pickedLocation!,
              infoWindow: const InfoWindow(title: "Selected Location"),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FloatingActionButton.extended(
              heroTag: "confirm",
              onPressed: () {
                if (_pickedLocation != null) {
                  Navigator.pop(context, _pickedLocation);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please tap on the map to pick a location")),
                  );
                }
              },
              label: const Text("Confirm"),
              icon: const Icon(Icons.check),
              backgroundColor: Colors.green,
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: "cancel",
              onPressed: () => Navigator.pop(context),
              label: const Text("Cancel"),
              icon: const Icon(Icons.close),
              backgroundColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
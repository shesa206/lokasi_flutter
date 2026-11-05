import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lokasi Saya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String? _kecamatan;
  String? _kota;
  String? _koordinat;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _getLocation() async {
    // 1. Set status loading dan reset data
    setState(() {
      _isLoading = true; // Menandai aplikasi sedang memproses lokasi
      _errorMessage = null; // Menghapus pesan error sebelumnya
      _kecamatan = null; // Menghapus data kecamatan sebelumnya
      _kota = null; // Menghapus data kota sebelumnya
      _koordinat = null;
    });

    try {
      // 2. Cek apakah layanan lokasi (GPS) aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan lokasi tidak aktif. Mohon aktifkan GPS.');
      }

      // 3. Periksa izin akses lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak oleh pengguna.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Izin lokasi ditolak permanen. Anda harus mengubahnya di pengaturan aplikasi.');
      }

      // 4. Ambil posisi perangkat saat ini
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ));

      String latLongStr =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _koordinat = latLongStr;
      });

      // 5. Reverse geocoding: koordinat -> alamat dengan penanganan null aman
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];

          String kec = (place.subLocality != null && place.subLocality!.isNotEmpty)
              ? place.subLocality!
              : (place.locality != null && place.locality!.isNotEmpty)
                  ? place.locality!
                  : 'Tidak terdeteksi';

          String kota = (place.subAdministrativeArea != null &&
                  place.subAdministrativeArea!.isNotEmpty)
              ? place.subAdministrativeArea!
              : (place.administrativeArea != null &&
                      place.administrativeArea!.isNotEmpty)
                  ? place.administrativeArea!
                  : 'Tidak terdeteksi';

          setState(() {
            _kecamatan = kec;
            _kota = kota;
          });
        } else {
          setState(() {
            _kecamatan = 'Lokasi Ditemukan';
            _kota = 'Geocoding tidak mengembalikan alamat';
          });
        }
      } catch (_) {
        // Layanan Android Geocoder pada emulator mengembalikan null / tidak merespon
        setState(() {
          _kecamatan = 'Lokasi Berhasil Diambil';
          _kota = 'Layanan Nama Alamat Emulator Tidak Aktif';
        });
      }
    } catch (e) {
      // 6. Tangani error dan tampilkan pesan
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      // 7. Hentikan status loading
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lokasi Saya',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 10.0),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_errorMessage != null)
                    ? Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                )
                    : (_kecamatan == null && _kota == null && _koordinat == null)
                    ? const Text(
                  'Tekan tombol untuk menampilkan lokasi.',
                  textAlign: TextAlign.center,
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koordinat GPS: ${_koordinat ?? "-"}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kelurahan/Kecamatan: ${_kecamatan ?? "-"}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kota: ${_kota ?? "-"}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(_latitude!, _longitude!),
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.lokasi_flutter',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_latitude!, _longitude!),
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _getLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 5.0,
              ),
              child: const Text(
                'TAMPILKAN LOKASI SAAT INI',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

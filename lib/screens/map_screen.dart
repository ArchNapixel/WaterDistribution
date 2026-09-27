import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import 'client_form_screen.dart';

// Davao City center, used as the map's default view.
const _davaoCity = LatLng(7.0731, 125.6128);

// Roughly covers Davao City's built-up area and outlying districts.
// Panning/zooming out is locked to this box so the map never shows
// anywhere outside Davao City.
final _davaoCityBounds = LatLngBounds(
  const LatLng(6.95, 125.30),
  const LatLng(7.25, 125.75),
);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  late Future<List<_ClientPin>> _future;

  // Non-null while tracing a new boundary on the map.
  String? _drawingForClientId;
  String? _drawingForClientName;
  final List<LatLng> _drawnPoints = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ClientPin>> _load() async {
    final period = DateFormat('yyyy-MM').format(DateTime.now());
    final clientRows = await supabase.from('clients').select();
    final clients = (clientRows as List).map((row) => Client.fromMap(row)).toList();

    final invoiceRows = await supabase.from('invoices').select().eq('period', period);
    final invoicesByClient = {
      for (final row in invoiceRows as List) row['client_id'] as String: Invoice.fromMap(row)
    };

    return clients
        .map((client) => _ClientPin(client: client, invoice: invoicesByClient[client.id]))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Color _pinColor(_ClientPin pin) {
    final invoice = pin.invoice;
    if (invoice == null) return Colors.grey;
    if (invoice.isPaid) return Colors.green;
    if (invoice.isOverdue) return Colors.red;
    return Colors.orange;
  }

  /// Opens the overlay listing all clients. Tapping one zooms/pans to their
  /// plot; a header action starts adding a brand-new client.
  Future<void> openClientList() async {
    final pins = await _future;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (sheetContext, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_add)),
              title: const Text('Add new client'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addNewClient();
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: pins.isEmpty
                  ? const Center(child: Text('No clients yet.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: pins.length,
                      itemBuilder: (context, index) {
                        final pin = pins[index];
                        return ListTile(
                          leading: Icon(Icons.circle, size: 12, color: _pinColor(pin)),
                          title: Text(pin.client.name),
                          subtitle: Text(pin.client.hasBoundary
                              ? 'Boundary set'
                              : (pin.client.hasLocation ? 'Location only' : 'No location yet')),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _zoomToClient(pin.client);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _zoomToClient(Client client) {
    if (client.hasBoundary) {
      final bounds = LatLngBounds.fromPoints(client.boundary!);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } else if (client.hasLocation) {
      _mapController.move(LatLng(client.latitude!, client.longitude!), 18);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('This client has no location yet.')));
    }
  }

  Future<void> _addNewClient() async {
    final newClientId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ClientFormScreen()),
    );
    if (newClientId == null) return;
    await _refresh();
    final pins = await _future;
    final newClient = pins.firstWhere((p) => p.client.id == newClientId).client;
    setState(() {
      _drawingForClientId = newClient.id;
      _drawingForClientName = newClient.name;
      _drawnPoints.clear();
    });
    if (newClient.hasLocation) {
      _mapController.move(LatLng(newClient.latitude!, newClient.longitude!), 18);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_drawingForClientId == null) return;
    setState(() => _drawnPoints.add(point));
  }

  Future<void> _finishDrawing() async {
    if (_drawnPoints.length < 3) return;
    await supabase
        .from('clients')
        .update({'boundary': Client.encodeBoundary(_drawnPoints)}).eq('id', _drawingForClientId!);
    setState(() {
      _drawingForClientId = null;
      _drawingForClientName = null;
      _drawnPoints.clear();
    });
    _refresh();
  }

  void _cancelDrawing() {
    setState(() {
      _drawingForClientId = null;
      _drawingForClientName = null;
      _drawnPoints.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapTilerKey = dotenv.env['MAPTILER_KEY'] ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Clients',
            onPressed: openClientList,
          ),
        ],
      ),
      body: FutureBuilder<List<_ClientPin>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (mapTilerKey.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Add your MapTiler API key to MAPTILER_KEY in .env to show the map.'),
              ),
            );
          }
          final pins = snapshot.data!;
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _davaoCity,
                  initialZoom: 12,
                  minZoom: 11,
                  cameraConstraint: CameraConstraint.contain(bounds: _davaoCityBounds),
                  onTap: _onMapTap,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$mapTilerKey',
                    userAgentPackageName: 'com.waterdistribution.app',
                  ),
                  PolygonLayer(
                    polygons: [
                      for (final pin in pins)
                        if (pin.client.hasBoundary)
                          Polygon(
                            points: pin.client.boundary!,
                            color: _pinColor(pin).withValues(alpha: 0.25),
                            borderColor: _pinColor(pin),
                            borderStrokeWidth: 2,
                          ),
                      if (_drawnPoints.length >= 3)
                        Polygon(
                          points: _drawnPoints,
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final pin in pins)
                        if (pin.client.hasLocation)
                          Marker(
                            point: LatLng(pin.client.latitude!, pin.client.longitude!),
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(pin.client.name),
                                  content: Text(pin.invoice == null
                                      ? 'No invoice generated for this month yet.'
                                      : '${pin.invoice!.status == 'paid' ? 'Paid' : (pin.invoice!.isOverdue ? 'Overdue' : 'Unpaid')} · Due ${DateFormat.yMMMd().format(pin.invoice!.dueDate)}'),
                                ),
                              ),
                              child: Icon(Icons.location_on, color: _pinColor(pin), size: 36),
                            ),
                          ),
                      for (final point in _drawnPoints)
                        Marker(
                          point: point,
                          width: 14,
                          height: 14,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (_drawingForClientId != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tracing boundary for $_drawingForClientName — tap at least 3 points on the map (${_drawnPoints.length} placed)',
                            ),
                          ),
                          TextButton(onPressed: _cancelDrawing, child: const Text('Cancel')),
                          FilledButton(
                            onPressed: _drawnPoints.length >= 3 ? _finishDrawing : null,
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ClientPin {
  final Client client;
  final Invoice? invoice;
  _ClientPin({required this.client, this.invoice});
}

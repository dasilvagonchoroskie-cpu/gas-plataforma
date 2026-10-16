import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapinha (OpenStreetMap) com o pino do endereço. Tocar move o pino.
class MapaEndereco extends StatefulWidget {
  const MapaEndereco({
    required this.latitude,
    required this.longitude,
    required this.aoMover,
    this.altura = 240,
    super.key,
  });

  final double latitude;
  final double longitude;
  final void Function(double latitude, double longitude) aoMover;
  final double altura;

  @override
  State<MapaEndereco> createState() => _MapaEnderecoState();
}

class _MapaEnderecoState extends State<MapaEndereco> {
  final _controle = MapController();

  @override
  void didUpdateWidget(covariant MapaEndereco antigo) {
    super.didUpdateWidget(antigo);
    final mudou = antigo.latitude != widget.latitude || antigo.longitude != widget.longitude;
    if (mudou) {
      _controle.move(LatLng(widget.latitude, widget.longitude), _controle.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ponto = LatLng(widget.latitude, widget.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.altura,
        child: FlutterMap(
          mapController: _controle,
          options: MapOptions(
            initialCenter: ponto,
            initialZoom: 17,
            onTap: (_, posicao) => widget.aoMover(posicao.latitude, posicao.longitude),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'br.com.fortalezadigitalsecurity.gasagua',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: ponto,
                  width: 48,
                  height: 48,
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.location_pin,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap')],
            ),
          ],
        ),
      ),
    );
  }
}

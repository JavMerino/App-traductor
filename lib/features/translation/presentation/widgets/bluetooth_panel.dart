import 'package:audio_traductor/core/services/bluetooth_provider.dart';
import 'package:audio_traductor/core/services/bluetooth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Panel de Bluetooth para Settings.
class BluetoothPanel extends ConsumerWidget {
  const BluetoothPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = ref.watch(bluetoothProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Estado de conexión ──
        if (bt.connectedDevice != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bt.connectedDevice!.name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Text('Conectado', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(bluetoothProvider.notifier).disconnect(),
                  child: const Text('Desconectar'),
                ),
              ],
            ),
          ),

        // ── Botón de escanear ──
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: bt.isScanning
                    ? () => ref.read(bluetoothProvider.notifier).stopScan()
                    : () => ref.read(bluetoothProvider.notifier).startScan(),
                icon: Icon(
                    bt.isScanning ? Icons.stop : Icons.bluetooth_searching),
                label: Text(bt.isScanning ? 'Detener' : 'Escanear'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Escaneando... ──
        if (bt.isScanning)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 8),
                  Text('Buscando dispositivos...', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),

        // ── Sin resultados ──
        if (!bt.isScanning &&
            bt.devices.isEmpty &&
            bt.connectedDevice == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Presioná "Escanear" para buscar dispositivos',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),

        // ── Lista de dispositivos ──
        if (bt.devices.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: bt.devices.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final device = bt.devices[index];
                final isConnected =
                    bt.connectedDevice?.id == device.id;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.bluetooth,
                    color: isConnected ? colorScheme.primary : null,
                  ),
                  title: Text(
                    device.name,
                    style: TextStyle(
                      fontWeight:
                          isConnected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Señal: ${device.rssi} dBm'),
                  trailing: isConnected
                      ? Icon(Icons.check_circle,
                          color: colorScheme.primary, size: 20)
                      : TextButton(
                          onPressed: () {
                            // Connect via the provider using scan results
                            // We need to access the scan result from flutter_blue_plus
                            _connectToDevice(context, ref, device);
                          },
                          child: const Text('Conectar',
                              style: TextStyle(fontSize: 12)),
                        ),
                );
              },
            ),
          ),

        // ── Error ──
        if (bt.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              bt.error!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _connectToDevice(
      BuildContext context, WidgetRef ref, BTDevice device) async {
    final results = await fbp.FlutterBluePlus.scanResults.first;
    final match =
        results.where((r) => r.device.remoteId.str == device.id).firstOrNull;
    if (match != null) {
      ref.read(bluetoothProvider.notifier).connect(match);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispositivo "${device.name}" no encontrado. Escaneá de nuevo.')),
      );
    }
  }
}

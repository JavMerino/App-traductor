import 'dart:async';
import 'package:audio_traductor/core/services/audio_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioDevicesPanel extends ConsumerStatefulWidget {
  const AudioDevicesPanel({super.key});

  @override
  ConsumerState<AudioDevicesPanel> createState() => _AudioDevicesPanelState();
}

class _AudioDevicesPanelState extends ConsumerState<AudioDevicesPanel> {
  final Set<String> _connectingBT = {};
  StreamSubscription<List<fbp.ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _scanSub = fbp.FlutterBluePlus.scanResults.listen((_) {});
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(audioDevicesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Entrada ──
        _sectionLabel('🎤 Entrada (micro)', theme),
        const SizedBox(height: 6),
        ...ds.devices
            .where((d) => d.isInput)
            .map((d) => _DeviceTile(
                  device: d,
                  icon: _iconFor(d.typeLabel),
                  isSelected: ds.selectedInputId == d.id,
                  onTap: () => ref.read(audioDevicesProvider.notifier).selectInput(d.id),
                )),

        const SizedBox(height: 16),

        // ── Salida ──
        _sectionLabel('🔊 Salida (parlante)', theme),
        const SizedBox(height: 6),
        ...ds.devices
            .where((d) => d.isOutput)
            .map((d) => _DeviceTile(
                  device: d,
                  icon: _iconFor(d.typeLabel),
                  isSelected: ds.selectedOutputId == d.id,
                  onTap: () => ref.read(audioDevicesProvider.notifier).selectOutput(d.id),
                )),

        const SizedBox(height: 14),

        // ── Buscar BT ──
        FilledButton.tonalIcon(
          onPressed: () {
            fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
            setState(() {});
          },
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Buscar dispositivos Bluetooth'),
        ),

        const SizedBox(height: 8),

        // ── BT encontrados (no conectados) ──
        StreamBuilder<List<fbp.ScanResult>>(
          stream: fbp.FlutterBluePlus.scanResults,
          builder: (context, snapshot) {
            final results = snapshot.data ?? [];
            if (results.isEmpty) return const SizedBox.shrink();

            return Column(
              children: results.map((r) {
                final id = r.device.remoteId.str;
                final name = r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : r.advertisementData.advName.isNotEmpty
                        ? r.advertisementData.advName
                        : id;
                final isConnecting = _connectingBT.contains(id);

                return ListTile(
                  dense: true,
                  leading: Icon(Icons.bluetooth, size: 20, color: colorScheme.primary),
                  title: Text(name, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Señal: ${r.rssi} dBm'),
                  trailing: isConnecting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(
                          onPressed: () => _connectDevice(r),
                          child: const Text('Conectar', style: TextStyle(fontSize: 12)),
                        ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 8),

        // ── Info ──
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Android rutea el audio automáticamente. Conectá los 2 dispositivos BT y seleccionalos arriba. Si el mic no funciona, desconectá el BT de salida y reconectalo después.',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Future<void> _connectDevice(fbp.ScanResult result) async {
    final id = result.device.remoteId.str;
    setState(() => _connectingBT.add(id));

    try {
      await result.device.connect();
      // Esperar que el sistema detecte el nuevo dispositivo
      await Future.delayed(const Duration(seconds: 1));
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo conectar a ${result.device.platformName}')),
        );
      }
    } finally {
      setState(() => _connectingBT.remove(id));
    }
  }

  Widget _sectionLabel(String text, ThemeData theme) {
    return Text(text, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary));
  }

  IconData _iconFor(String typeLabel) {
    return switch (typeLabel) {
      'Cable' => Icons.headset_mic,
      'Bluetooth' => Icons.bluetooth,
      'Integrado' => Icons.speaker,
      _ => Icons.devices,
    };
  }
}

class _DeviceTile extends StatelessWidget {
  final AudioDevice device;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colorScheme.primary.withValues(alpha: 0.5) : Theme.of(context).dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? colorScheme.primary : null),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                device.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: colorScheme.primary)
            else if (device.isConnected)
              Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}

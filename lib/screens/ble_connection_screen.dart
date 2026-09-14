import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_sensor_service.dart';

class BleConnectionScreen extends StatefulWidget {
  const BleConnectionScreen({
    super.key,
    required this.bleService,
  });

  final BleSensorService bleService;

  @override
  State<BleConnectionScreen> createState() =>
      _BleConnectionScreenState();
}

class _BleConnectionScreenState
    extends State<BleConnectionScreen> {
  StreamSubscription<String>? _statusSubscription;

  List<BluetoothDevice> _devices = [];

  String _status = 'Bluetooth not initialized.';

  bool _initializing = true;
  bool _scanning = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();

    _statusSubscription =
        widget.bleService.statusStream.listen(
      (message) {
        if (!mounted) {
          return;
        }

        setState(() {
          _status = message;
        });
      },
    );

    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _initializing = true;
    });

    final ready =
        await widget.bleService.initialize();

    if (!mounted) {
      return;
    }

    setState(() {
      _initializing = false;
    });

    if (ready) {
      await _scan();
    }
  }

  Future<void> _scan() async {
    if (_scanning || _connecting) {
      return;
    }

    setState(() {
      _scanning = true;
      _devices = [];
    });

    final devices =
        await widget.bleService.scanForKneeBand();

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = devices;
      _scanning = false;
    });
  }

  Future<void> _connect(
    BluetoothDevice device,
  ) async {
    if (_connecting) {
      return;
    }

    setState(() {
      _connecting = true;
    });

    final connected =
        await widget.bleService.connectToDevice(
      device,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _connecting = false;
    });

    if (connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'KneeBand connected successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await widget.bleService.disconnect();

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = [];
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        widget.bleService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KneeBand Connection',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              _buildConnectionCard(
                connected,
              ),

              const SizedBox(height: 16),

              _buildStatusCard(),

              const SizedBox(height: 16),

              if (!connected)
                _buildScanSection()
              else
                _buildConnectedSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(
    bool connected,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              connected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth,
              size: 64,
              color: connected
                  ? Colors.green
                  : Theme.of(context)
                      .colorScheme
                      .primary,
            ),

            const SizedBox(height: 12),

            Text(
              connected
                  ? 'KneeBand Connected'
                  : 'Connect KneeBand',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              connected
                  ? 'The wearable is ready to send IMU data.'
                  : 'Connect the ESP32 wearable before starting the movement assessment.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 24,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(_status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wearable Device',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Make sure the ESP32 is powered on and advertising as KneeBand_OA.',
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed:
                  _initializing ||
                          _scanning ||
                          _connecting
                      ? null
                      : _scan,
              icon: _scanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.bluetooth_searching,
                    ),
              label: Text(
                _scanning
                    ? 'SCANNING...'
                    : 'SCAN FOR KNEEBAND',
              ),
              style:
                  ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 15,
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (!_scanning &&
                _devices.isEmpty)
              const Center(
                child: Padding(
                  padding:
                      EdgeInsets.all(12),
                  child: Text(
                    'No BLE devices found yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            ..._devices.map(
              _buildDeviceTile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(
    BluetoothDevice device,
  ) {
    final name =
        device.platformName.isNotEmpty
            ? device.platformName
            : device.remoteId.str;

    return Card(
      margin: const EdgeInsets.only(
        top: 8,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons.sensors,
          ),
        ),

        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),

        subtitle: Text(
          device.remoteId.str,
        ),

        trailing: ElevatedButton(
          onPressed: _connecting
              ? null
              : () => _connect(device),
          child: Text(
            _connecting
                ? 'CONNECTING'
                : 'CONNECT',
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'KneeBand is ready',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text(
              'The app can now receive thigh and shin IMU packets from the wearable.',
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed:
                  _connecting
                      ? null
                      : _disconnect,
              icon: const Icon(
                Icons.bluetooth_disabled,
              ),
              label: const Text(
                'DISCONNECT',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
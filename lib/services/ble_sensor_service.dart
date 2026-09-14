import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sensor_sample.dart';
import 'sensor_service.dart';

class BleSensorService implements SensorService {
  static const String deviceName = 'KneeBand_OA';

  static const String serviceUuid =
      '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  static const String dataCharacteristicUuid =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  static const String commandCharacteristicUuid =
      'cba1d466-344c-4be3-ab3f-189f80dd7518';

  final StreamController<SensorSample> _sampleController =
      StreamController<SensorSample>.broadcast();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _dataCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;

  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<BluetoothConnectionState>?
      _connectionSubscription;

  bool _isRunning = false;
  bool _isScanning = false;

  @override
  Stream<SensorSample> get sampleStream =>
      _sampleController.stream;

  Stream<String> get statusStream =>
      _statusController.stream;

  BluetoothDevice? get connectedDevice => _device;

  bool get isConnected =>
      _device != null && _device!.isConnected;

  bool get isScanning => _isScanning;

  @override
  bool get isRunning => _isRunning;

  /// Requests the Android Bluetooth permissions required by
  /// the wearable BLE workflow.
  ///
  /// Android 12+ uses:
  /// - BLUETOOTH_SCAN
  /// - BLUETOOTH_CONNECT
  ///
  /// Older Android versions may require location permission
  /// for BLE scanning.
  Future<bool> _requestBluetoothPermissions() async {
    try {
      if (!await Permission.bluetoothScan.isGranted) {
        final scanStatus =
            await Permission.bluetoothScan.request();

        if (!scanStatus.isGranted) {
          _setStatus(
            'Bluetooth scan permission was not granted.',
          );
          return false;
        }
      }

      if (!await Permission.bluetoothConnect.isGranted) {
        final connectStatus =
            await Permission.bluetoothConnect.request();

        if (!connectStatus.isGranted) {
          _setStatus(
            'Bluetooth connection permission was not granted.',
          );
          return false;
        }
      }

      // Android versions before Android 12 can require
      // location permission for BLE discovery.
      if (!await Permission.location.isGranted) {
        final locationStatus =
            await Permission.location.request();

        if (!locationStatus.isGranted &&
            !await Permission.bluetoothScan.isGranted) {
          _setStatus(
            'Location permission is required for BLE scanning '
            'on this Android version.',
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      _setStatus(
        'Bluetooth permission request failed: $e',
      );
      return false;
    }
  }

  Future<bool> initialize() async {
    try {
      final permissionsGranted =
          await _requestBluetoothPermissions();

      if (!permissionsGranted) {
        return false;
      }

      final supported =
          await FlutterBluePlus.isSupported;

      if (!supported) {
        _setStatus(
          'Bluetooth Low Energy is not supported on this device.',
        );
        return false;
      }

      final adapterState =
          await FlutterBluePlus.adapterState.first;

      if (adapterState !=
          BluetoothAdapterState.on) {
        _setStatus(
          'Bluetooth is turned off. Please enable Bluetooth.',
        );
        return false;
      }

      _setStatus('Bluetooth is ready.');
      return true;
    } catch (e) {
      _setStatus(
        'Bluetooth initialization failed: $e',
      );
      return false;
    }
  }

  Future<List<BluetoothDevice>> scanForKneeBand({
    Duration timeout =
        const Duration(seconds: 8),
  }) async {
    if (_isScanning) {
      return [];
    }

    final foundDevices =
        <String, BluetoothDevice>{};

    _isScanning = true;

    _setStatus(
      'Scanning for $deviceName...',
    );

    StreamSubscription<List<ScanResult>>?
        scanSubscription;

    try {
      scanSubscription =
          FlutterBluePlus.onScanResults.listen(
        (results) {
          for (final result in results) {
            final device = result.device;

            final advertisedName =
                result.advertisementData.advName;

            final platformName =
                device.platformName;

            final name = advertisedName.isNotEmpty
                ? advertisedName
                : platformName;

            // The scan itself intentionally has no name filter.
            // This allows us to diagnose whether Android can
            // actually see BLE advertisements from the ESP32.
            //
            // We still select only the expected KneeBand device
            // for the normal application connection workflow.
            if (name == deviceName) {
              foundDevices[device.remoteId.str] =
                  device;
            }
          }
        },
        onError: (Object error) {
          _setStatus(
            'BLE scan error: $error',
          );
        },
      );

      // Do not use withNames here during hardware diagnosis.
      // The ESP32 may advertise correctly while Android reports
      // its name differently through the scan result.
      await FlutterBluePlus.startScan(
        timeout: timeout,
      );

      await FlutterBluePlus.isScanning.firstWhere(
        (scanning) => !scanning,
      );

      await scanSubscription.cancel();
      scanSubscription = null;

      _setStatus(
        foundDevices.isEmpty
            ? '$deviceName not found.'
            : 'Found ${foundDevices.length} KneeBand device(s).',
      );

      return foundDevices.values.toList();
    } catch (e) {
      _setStatus(
        'BLE scan failed: $e',
      );

      return [];
    } finally {
      await scanSubscription?.cancel();
      _isScanning = false;
    }
  }

  Future<bool> connectToDevice(
    BluetoothDevice device,
  ) async {
    try {
      final permissionsGranted =
          await _requestBluetoothPermissions();

      if (!permissionsGranted) {
        return false;
      }

      _setStatus(
        'Connecting to '
        '${device.platformName.isNotEmpty ? device.platformName : device.remoteId.str}...',
      );

      await _connectionSubscription?.cancel();

      // Set _device BEFORE connect() so isConnected returns
      // true immediately when the connectionState stream fires
      // during the connect() call. Without this, the UI rebuilds
      // triggered by _setStatus() see _device == null and show
      // the disconnected state even though we are connected.
      _device = device;

      _connectionSubscription =
          device.connectionState.listen(
        (state) {
          if (state ==
              BluetoothConnectionState.connected) {
            _setStatus(
              'Connected to $deviceName.',
            );
          } else if (state ==
              BluetoothConnectionState.disconnected) {
            _setStatus(
              'KneeBand disconnected.',
            );

            _isRunning = false;
          }
        },
      );

      if (!device.isConnected) {
        await device.connect(
          license: License.nonprofit,
          timeout: const Duration(seconds: 15),
        );
      }

      try {
        await device.requestMtu(512);
        debugPrint('[MedSync-BLE] Requested MTU 512');
      } catch (e) {
        debugPrint('[MedSync-BLE] MTU request warning: $e');
      }

      // Android GATT requires a short settling delay after the
      // connection is established before service discovery will
      // succeed reliably. Without this, discoverServices() may
      // return an empty list or throw on many Android devices.
      await Future.delayed(const Duration(milliseconds: 500));

      _setStatus(
        'Discovering KneeBand services...',
      );

      final services =
          await device.discoverServices();

      BluetoothCharacteristic?
          dataCharacteristic;

      BluetoothCharacteristic?
          commandCharacteristic;

      // Log all discovered services and characteristics to help
      // diagnose UUID mismatches between the app and the ESP32.
      // These print to the flutter run terminal so you can read
      // them even if the screen changes quickly.
      final discoveredUuids = <String>[];
      for (final service in services) {
        discoveredUuids.add('SVC:${service.uuid}');
        for (final c in service.characteristics) {
          discoveredUuids.add('  CHR:${c.uuid}');
        }
      }
      debugPrint('[MedSync-BLE] Discovered ${services.length} service(s):');
      for (final line in discoveredUuids) {
        debugPrint('[MedSync-BLE] $line');
      }
      _setStatus(
        'Found ${services.length} service(s):\n${discoveredUuids.join('\n')}',
      );

      for (final service in services) {
        if (service.uuid ==
            Guid(serviceUuid)) {
          for (final characteristic
              in service.characteristics) {
            if (characteristic.uuid ==
                Guid(dataCharacteristicUuid)) {
              dataCharacteristic =
                  characteristic;
            }

            if (characteristic.uuid ==
                Guid(commandCharacteristicUuid)) {
              commandCharacteristic =
                  characteristic;
            }
          }
        }
      }

      if (dataCharacteristic == null) {
        // Do NOT disconnect here — keep the BLE link alive so
        // the diagnostic UUID list stays visible on screen.
        debugPrint('[MedSync-BLE] ❌ Data characteristic NOT found.');
        debugPrint('[MedSync-BLE]    Expected: $dataCharacteristicUuid');
        _setStatus(
          '❌ Data characteristic not found.\n'
          'Expected UUID:\n  $dataCharacteristicUuid\n\n'
          'Discovered UUIDs (check your ESP32 firmware):\n'
          '${discoveredUuids.join("\n")}',
        );
        return false;
      }

      if (commandCharacteristic == null) {
        debugPrint('[MedSync-BLE] ❌ Command characteristic NOT found.');
        debugPrint('[MedSync-BLE]    Expected: $commandCharacteristicUuid');
        _setStatus(
          '❌ Command characteristic not found.\n'
          'Expected UUID:\n  $commandCharacteristicUuid\n\n'
          'Discovered UUIDs (check your ESP32 firmware):\n'
          '${discoveredUuids.join("\n")}',
        );
        return false;
      }

      _dataCharacteristic =
          dataCharacteristic;

      _commandCharacteristic =
          commandCharacteristic;

      await _subscribeToSensorData();

      _setStatus(
        'KneeBand connected and ready.',
      );

      return true;
    } catch (e) {
      debugPrint('[MedSync-BLE] ❌ Connection error: $e');
      _setStatus(
        'KneeBand connection failed: $e',
      );

      // Only disconnect on a true connection error, not on
      // UUID mismatches (those return false above without disconnecting).
      await disconnect();

      return false;
    }
  }

  Future<void> _subscribeToSensorData() async {
    final characteristic =
        _dataCharacteristic;

    if (characteristic == null) {
      throw StateError(
        'Data characteristic is not available.',
      );
    }

    await _dataSubscription?.cancel();

    await characteristic.setNotifyValue(true);

    _dataSubscription =
        characteristic.onValueReceived.listen(
      (value) {
        _handleIncomingPacket(value);
      },
      onError: (Object error) {
        _setStatus(
          'Sensor data error: $error',
        );
      },
    );
  }

  // Counter used to limit verbose packet logging to the first few packets.
  int _packetLogCount = 0;
  final StringBuffer _rxBuffer = StringBuffer();

  void _handleIncomingPacket(
    List<int> bytes,
  ) {
    if (bytes.isEmpty) {
      return;
    }

    final chunk = utf8.decode(
      bytes,
      allowMalformed: true,
    );

    _rxBuffer.write(chunk);

    String content = _rxBuffer.toString();

    // 1. Process all newline-delimited complete packets (fast path for formatted streams)
    if (content.contains('\n')) {
      final lines = content.split('\n');
      final remaining = lines.removeLast();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          _processSingleJsonString(trimmed);
        }
      }
      _rxBuffer.clear();
      _rxBuffer.write(remaining);
      return;
    }

    // 2. Process boundary-delimited packets (when no newlines are present)
    // Every sensor packet begins with {"seq": or {"ts":
    while (true) {
      final startIdx = content.indexOf('{"seq":');
      final altStartIdx = content.indexOf('{"ts":');
      final firstIdx = (startIdx != -1 && altStartIdx != -1)
          ? (startIdx < altStartIdx ? startIdx : altStartIdx)
          : (startIdx != -1 ? startIdx : altStartIdx);

      if (firstIdx == -1) {
        if (content.length > 512) {
          content = '';
        }
        break;
      }

      // Check if there is a SECOND packet header following this one in the buffer
      final nextStart = content.indexOf('{"seq":', firstIdx + 7);
      final nextAlt = content.indexOf('{"ts":', firstIdx + 6);
      int nextIdx = -1;
      if (nextStart != -1 && nextAlt != -1) {
        nextIdx = nextStart < nextAlt ? nextStart : nextAlt;
      } else if (nextStart != -1) {
        nextIdx = nextStart;
      } else if (nextAlt != -1) {
        nextIdx = nextAlt;
      }

      if (nextIdx != -1) {
        // We have a bounded packet from firstIdx to nextIdx
        final packetStr = content.substring(firstIdx, nextIdx).trim();
        content = content.substring(nextIdx);
        if (packetStr.isNotEmpty) {
          _processSingleJsonString(packetStr);
        }
      } else {
        // Only one packet in buffer so far.
        // If it already contains balanced braces, parse it immediately
        int depth = 0;
        int endIdx = -1;
        for (int i = firstIdx; i < content.length; i++) {
          if (content[i] == '{') depth++;
          if (content[i] == '}') depth--;
          if (depth == 0) {
            endIdx = i;
            break;
          }
        }

        if (endIdx != -1) {
          final packetStr = content.substring(firstIdx, endIdx + 1);
          content = content.substring(endIdx + 1);
          _processSingleJsonString(packetStr);
        } else {
          // If the packet contains both thigh and shin and was truncated by MTU boundary
          // (e.g. >= 160 chars), auto-repair and parse it immediately!
          if (content.contains('"thigh"') &&
              content.contains('"shin"') &&
              content.length >= 160) {
            _processSingleJsonString(content.substring(firstIdx));
            content = '';
          }
          break;
        }
      }
    }

    _rxBuffer.clear();
    if (content.length > 4096) {
      content = '';
    }
    _rxBuffer.write(content);
  }

  void _processSingleJsonString(String text) {
    try {
      final json = _repairAndDecodeJson(text);
      if (json == null) {
        return;
      }

      if (_packetLogCount < 3) {
        debugPrint('[MedSync-BLE] Validated Packet #$_packetLogCount: $text');
        _packetLogCount++;
      }

      final sample = SensorSample.fromJson(json);
      _sampleController.add(sample);
    } catch (e) {
      debugPrint('[MedSync-BLE] ❌ JSON Parse error: $e | Raw: $text');
    }
  }

  Map<String, dynamic>? _repairAndDecodeJson(String text) {
    var s = text.trim();
    if (!s.startsWith('{')) return null;

    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    // Clean up trailing dangling keys, signs, or decimal points caused by MTU truncation
    s = s.replaceAll(RegExp(r',"[a-zA-Z]+":-?$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    s = s.replaceAll(RegExp(r':-?$'), '');
    if (s.endsWith(',')) {
      s = s.substring(0, s.length - 1);
    }

    int openCount = 0;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '{') openCount++;
      if (s[i] == '}') openCount--;
    }
    if (openCount > 0) {
      s = s + ('}' * openCount);
    }

    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> start() async {
    if (!isConnected) {
      throw StateError(
        'KneeBand is not connected.',
      );
    }

    // Do NOT re-subscribe here. The BLE notification subscription
    // is established once in connectToDevice() via _subscribeToSensorData()
    // and must remain alive across start/stop cycles. Re-subscribing here
    // would cancel and recreate the listener, causing packet loss between
    // the calibration and recording phases.
    _rxBuffer.clear();
    _packetLogCount = 0;

    // Small 250ms settling delay allows the ESP32 BLE stack to settle
    // if a STOP command was sent immediately prior (e.g. on test cancel).
    await Future.delayed(const Duration(milliseconds: 250));

    try {
      if (_dataCharacteristic != null) {
        await _dataCharacteristic!.setNotifyValue(true);
      }
    } catch (e) {
      debugPrint('[MedSync-BLE] Warning re-enabling notify: $e');
    }

    await _sendCommand('START');

    _isRunning = true;

    _setStatus(
      'Sensor recording started.',
    );
  }

  @override
  Future<void> stop() async {
    if (!isConnected) {
      _isRunning = false;
      _rxBuffer.clear();
      return;
    }

    try {
      await _sendCommand('STOP');
    } catch (e) {
      debugPrint('[MedSync-BLE] Warning sending STOP command: $e');
    }

    _rxBuffer.clear();
    _isRunning = false;

    _setStatus(
      'Sensor recording stopped.',
    );
  }

  Future<void> calibrate() async {
    if (!isConnected) {
      throw StateError(
        'KneeBand is not connected.',
      );
    }

    await _sendCommand('CALIBRATE');

    _setStatus(
      'Sensor calibration started.',
    );
  }

  Future<void> reset() async {
    if (!isConnected) {
      throw StateError(
        'KneeBand is not connected.',
      );
    }

    await _sendCommand('RESET');

    _isRunning = false;

    _setStatus(
      'Sensor reset command sent.',
    );
  }

  Future<void> _sendCommand(
    String command,
  ) async {
    final characteristic =
        _commandCharacteristic;

    if (characteristic == null) {
      throw StateError(
        'Command characteristic is not available.',
      );
    }

    final bytes =
        utf8.encode(command);

    await characteristic.write(
      bytes,
      withoutResponse:
          characteristic.properties.writeWithoutResponse &&
              !characteristic.properties.write,
    );
  }

  Future<void> disconnect() async {
    _isRunning = false;

    await _dataSubscription?.cancel();
    _dataSubscription = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    final device = _device;

    _device = null;
    _dataCharacteristic = null;
    _commandCharacteristic = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // Device may already be disconnected.
      }
    }

    _setStatus(
      'KneeBand disconnected.',
    );
  }

  void _setStatus(String message) {
    if (!_statusController.isClosed) {
      _statusController.add(message);
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();

    await _sampleController.close();
    await _statusController.close();
  }
}
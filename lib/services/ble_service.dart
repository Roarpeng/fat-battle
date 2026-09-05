import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/game_models.dart';
import 'limb_imu.dart';

/// BLE 状态通知（供 UI SnackBar 等使用）
class BleStatusEvent {
  final String message;
  final bool isError;

  const BleStatusEvent(this.message, {this.isError = false});
}

/// BLE蓝牙服务 - 与ESP32腰部Hub通信
class BleService {
  // ESP32设备名称
  static const String targetDeviceName = 'ESP32-Hub';

  /// 四肢节点广播前缀。默认关闭，打开 [limbNodesEnabled] 才尝试发现，不打断单 Hub。
  static const String limbDevicePrefix = 'ESP32-Limb-';
  static const String prefsLimbFlag = 'coach_limb_imu_enabled';
  
  // BLE服务UUID（需要与ESP32固件匹配）
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  
  // BLE特征UUID（用于接收IMU数据）
  static const String imuCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  
  // BLE特征UUID（用于发送命令）
  static const String commandCharacteristicUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  
  BluetoothDevice? _device;
  BluetoothCharacteristic? _imuCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;
  
  final StreamController<ImuData> _imuDataStreamController = StreamController.broadcast();
  final StreamController<BleDeviceState> _connectionStateController = StreamController.broadcast();
  final StreamController<String> _logController = StreamController.broadcast();
  final StreamController<BleStatusEvent> _statusController = StreamController.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _scanTimeoutTimer;
  
  Stream<ImuData> get imuDataStream => _imuDataStreamController.stream;
  Stream<BleDeviceState> get connectionStateStream => _connectionStateController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<BleStatusEvent> get statusStream => _statusController.stream;
  
  bool _isScanning = false;
  bool _isConnected = false;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;

  /// 架构开关：发现四肢节点但不自动替换腰部 Hub 主连接。
  bool limbNodesEnabled = false;

  final Map<ImuNodeId, BluetoothDevice> _limbDevices = {};
  final StreamController<AggregatedImuFrame> _aggController =
      StreamController.broadcast();
  final StreamController<ImuNodeId> _limbFoundController =
      StreamController.broadcast();

  Stream<AggregatedImuFrame> get aggregatedImuStream => _aggController.stream;
  Stream<ImuNodeId> get limbDiscoveredStream => _limbFoundController.stream;
  Map<ImuNodeId, BluetoothDevice> get discoveredLimbDevices =>
      Map.unmodifiable(_limbDevices);

  void _emitLog(String message, {bool isError = false}) {
    _logController.add(message);
    _statusController.add(BleStatusEvent(message, isError: isError));
  }
  
  /// 开始扫描设备
  Future<bool> startScan() async {
    if (_isScanning) return false;
    
    _isScanning = true;
    _emitLog('开始扫描BLE设备...');
    
    try {
      // 检查蓝牙是否可用
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        _emitLog('蓝牙未开启，请先开启蓝牙', isError: true);
        _isScanning = false;
        return false;
      }
      
      await _scanSubscription?.cancel();
      _scanTimeoutTimer?.cancel();

      // 监听扫描结果
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.device.advName;
          if (name.contains(targetDeviceName)) {
            _emitLog('发现设备: $name (${result.device.remoteId})');
            _stopScanInternal();
            connectToDevice(result.device);
            break;
          }
          if (limbNodesEnabled) {
            final node = ImuNodeIdX.fromAdvertisedName(name);
            if (node != null && node != ImuNodeId.waist) {
              _limbDevices[node] = result.device;
              _limbFoundController.add(node);
              _emitLog('发现四肢节点（未自动连接）: $name → ${node.label}');
            }
          }
        }
      });

      // 开始扫描
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // 扫描超时
      _scanTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (_isScanning && !_isConnected) {
          _emitLog('扫描超时，未找到 $targetDeviceName 设备', isError: true);
          _stopScanInternal();
        }
      });

      return true;
    } catch (e) {
      _emitLog('扫描错误: $e', isError: true);
      _stopScanInternal();
      return false;
    }
  }

  void _stopScanInternal() {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    FlutterBluePlus.stopScan();
    _isScanning = false;
  }
  
  /// 连接到设备
  Future<void> connectToDevice(BluetoothDevice device) async {
    _emitLog('正在连接到 ${device.platformName}...');
    
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;
      _isConnected = true;
      _stopScanInternal();
      
      _connectionStateController.add(BleDeviceState(
        name: device.platformName,
        deviceId: device.remoteId.str,
        isConnected: true,
        rssi: -50,
        lastUpdate: DateTime.now(),
      ));
      
      _emitLog('已连接到 ${device.platformName}');
      
      // 监听连接状态
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          _connectionStateController.add(BleDeviceState(
            name: device.platformName,
            deviceId: device.remoteId.str,
            isConnected: false,
          ));
          _emitLog('设备断开连接', isError: true);
        }
      });
      
      // 发现服务
      await discoverServices();
    } catch (e) {
      _emitLog('连接失败: $e', isError: true);
      _isConnected = false;
    }
  }
  
  /// 发现服务和特征
  Future<void> discoverServices() async {
    if (_device == null) return;
    
    _logController.add('正在发现服务...');
    
    try {
      final services = await _device!.discoverServices();
      
      for (final service in services) {
        if (service.uuid.str128.toLowerCase() == serviceUuid.toLowerCase()) {
          _logController.add('找到IMU服务');
          
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.str128.toLowerCase() == imuCharacteristicUuid.toLowerCase()) {
              _imuCharacteristic = characteristic;
              _logController.add('找到IMU特征');
              
              // 启用通知
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                _parseImuData(value);
              });
            }
            
            if (characteristic.uuid.str128.toLowerCase() == commandCharacteristicUuid.toLowerCase()) {
              _commandCharacteristic = characteristic;
              _logController.add('找到命令特征');
            }
          }
        }
      }
      
      if (_imuCharacteristic == null) {
        _logController.add('未找到IMU特征，尝试使用通用UUID...');
        // 尝试使用通用UART UUID
        for (final service in services) {
          for (final characteristic in service.characteristics) {
            if (characteristic.properties.notify) {
              _imuCharacteristic = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                _parseImuData(value);
              });
              _logController.add('使用特征: ${characteristic.uuid}');
            }
            if (characteristic.properties.write) {
              _commandCharacteristic = characteristic;
            }
          }
        }
      }
    } catch (e) {
      _logController.add('发现服务失败: $e');
    }
  }
  
  /// 解析IMU数据
  /// 旧格式：12 字节腰部六轴。新格式：0xFB 聚合帧（腰 + 四肢）。
  void _parseImuData(List<int> data) {
    if (data.length < 12) return;

    try {
      final frame = LimbImuCodec.decode(data);
      if (frame == null) return;
      _aggController.add(frame);
      final waist = frame.waist;
      if (waist != null) {
        _imuDataStreamController.add(waist);
      }
    } catch (e) {
      _logController.add('解析IMU数据失败: $e');
    }
  }

  /// 预留：显式连接已发现的四肢节点。默认不调用，避免打断单 Hub。
  Future<bool> connectLimbNode(ImuNodeId node) async {
    if (!limbNodesEnabled) {
      _emitLog('四肢 IMU 未开启（$prefsLimbFlag）', isError: true);
      return false;
    }
    final device = _limbDevices[node];
    if (device == null) {
      _emitLog('尚未发现 ${node.label}', isError: true);
      return false;
    }
    _emitLog('四肢连接为架构预留，当前仍以腰部 Hub 为主: ${node.label}');
    return false;
  }
  
  /// 发送命令到ESP32
  Future<void> sendCommand(String command) async {
    if (_commandCharacteristic == null || !_isConnected) {
      _logController.add('未连接，无法发送命令');
      return;
    }
    
    try {
      final data = Uint8List.fromList(command.codeUnits);
      await _commandCharacteristic!.write(data);
      _logController.add('发送命令: $command');
    } catch (e) {
      _logController.add('发送命令失败: $e');
    }
  }
  
  /// 开始IMU数据流
  Future<void> startImuStream() async {
    await sendCommand('START_IMU');
  }
  
  /// 停止IMU数据流
  Future<void> stopImuStream() async {
    await sendCommand('STOP_IMU');
  }
  
  /// 设置采样率
  Future<void> setSampleRate(int rateHz) async {
    await sendCommand('RATE_$rateHz');
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    if (_device != null) {
      await _device!.disconnect();
      _device = null;
      _imuCharacteristic = null;
      _commandCharacteristic = null;
      _isConnected = false;
    }
  }
  
  /// 释放资源
  void dispose() {
    _scanSubscription?.cancel();
    _scanTimeoutTimer?.cancel();
    _imuDataStreamController.close();
    _connectionStateController.close();
    _logController.close();
    _statusController.close();
    _aggController.close();
    _limbFoundController.close();
    disconnect();
  }
}

/// BLE服务Provider
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
});

/// BLE连接状态Provider
final bleConnectionStateProvider = StreamProvider<BleDeviceState>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.connectionStateStream;
});

/// IMU数据流Provider
final imuDataStreamProvider = StreamProvider<ImuData>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.imuDataStream;
});

/// 腰+四肢聚合帧（缺肢时仍只有腰点）。
final aggregatedImuStreamProvider = StreamProvider<AggregatedImuFrame>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.aggregatedImuStream;
});

/// BLE日志Provider
final bleLogProvider = StreamProvider<String>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.logStream;
});

/// BLE 状态事件 Provider（含错误标记，供 SnackBar）
final bleStatusProvider = StreamProvider<BleStatusEvent>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.statusStream;
});
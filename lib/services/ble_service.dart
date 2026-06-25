import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/game_models.dart';

/// BLE蓝牙服务 - 与ESP32腰部Hub通信
class BleService {
  // ESP32设备名称
  static const String targetDeviceName = 'ESP32-Hub';
  
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
  
  Stream<ImuData> get imuDataStream => _imuDataStreamController.stream;
  Stream<BleDeviceState> get connectionStateStream => _connectionStateController.stream;
  Stream<String> get logStream => _logController.stream;
  
  bool _isScanning = false;
  bool _isConnected = false;
  
  /// 开始扫描设备
  Future<void> startScan() async {
    if (_isScanning) return;
    
    _isScanning = true;
    _logController.add('开始扫描BLE设备...');
    
    try {
      // 检查蓝牙是否可用
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        _logController.add('蓝牙未开启，请先开启蓝牙');
        _isScanning = false;
        return;
      }
      
      // 开始扫描
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
      
      // 监听扫描结果
      FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (result.device.platformName.contains(targetDeviceName) ||
              result.device.advName.contains(targetDeviceName)) {
            _logController.add('发现设备: ${result.device.platformName} (${result.device.remoteId})');
            connectToDevice(result.device);
            FlutterBluePlus.stopScan();
            break;
          }
        }
      });
      
      // 扫描超时
      await Future.delayed(Duration(seconds: 10));
      if (_isScanning && !_isConnected) {
        _logController.add('扫描超时，未找到设备');
        FlutterBluePlus.stopScan();
      }
    } catch (e) {
      _logController.add('扫描错误: $e');
    }
    
    _isScanning = false;
  }
  
  /// 连接到设备
  Future<void> connectToDevice(BluetoothDevice device) async {
    _logController.add('正在连接到 ${device.platformName}...');
    
    try {
      await device.connect(timeout: Duration(seconds: 10));
      _device = device;
      _isConnected = true;
      
      _connectionStateController.add(BleDeviceState(
        name: device.platformName,
        deviceId: device.remoteId.str,
        isConnected: true,
        rssi: -50,
        lastUpdate: DateTime.now(),
      ));
      
      _logController.add('已连接到 ${device.platformName}');
      
      // 监听连接状态
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          _connectionStateController.add(BleDeviceState(
            name: device.platformName,
            deviceId: device.remoteId.str,
            isConnected: false,
          ));
          _logController.add('设备断开连接');
        }
      });
      
      // 发现服务
      await discoverServices();
    } catch (e) {
      _logController.add('连接失败: $e');
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
  /// 数据格式：ax(2bytes) ay(2bytes) az(2bytes) gx(2bytes) gy(2bytes) gz(2bytes)
  /// 每个值是int16，单位：加速度g，角速度deg/s
  void _parseImuData(List<int> data) {
    if (data.length < 12) return;
    
    try {
      // 解析加速度（假设单位是0.01g）
      final ax = _toInt16(data[0], data[1]) / 100.0;
      final ay = _toInt16(data[2], data[3]) / 100.0;
      final az = _toInt16(data[4], data[5]) / 100.0;
      
      // 解析角速度（假设单位是0.1deg/s）
      final gx = _toInt16(data[6], data[7]) / 10.0;
      final gy = _toInt16(data[8], data[9]) / 10.0;
      final gz = _toInt16(data[10], data[11]) / 10.0;
      
      final imuData = ImuData(
        timestamp: DateTime.now(),
        ax: ax,
        ay: ay,
        az: az,
        gx: gx,
        gy: gy,
        gz: gz,
      );
      
      _imuDataStreamController.add(imuData);
    } catch (e) {
      _logController.add('解析IMU数据失败: $e');
    }
  }
  
  /// 将两个字节转换为int16
  int _toInt16(int low, int high) {
    return (high << 8) | low;
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
    _imuDataStreamController.close();
    _connectionStateController.close();
    _logController.close();
    disconnect();
  }
}

/// BLE服务Provider
final bleServiceProvider = Provider<BleService>((ref) {
  return BleService();
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

/// BLE日志Provider
final bleLogProvider = StreamProvider<String>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.logStream;
});
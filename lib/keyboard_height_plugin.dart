import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 键盘高度变化回调函数类型
typedef KeyboardHeightCallback = void Function(double height);

/// 键盘高度检测插件
///
/// 用于检测虚拟键盘的高度变化，支持Android和iOS平台
///
/// 使用示例：
/// ```dart
/// final KeyboardHeightPlugin _keyboardHeightPlugin = KeyboardHeightPlugin();
///
/// @override
/// void initState() {
///   super.initState();
///   _keyboardHeightPlugin.onKeyboardHeightChanged((double height) {
///     setState(() {
///       _keyboardHeight = height;
///     });
///   });
/// }
///
/// @override
/// void dispose() {
///   _keyboardHeightPlugin.dispose();
///   super.dispose();
/// }
/// ```
class KeyboardHeightPlugin {
  static const String _channelName = 'keyboardHeightEventChannel';
  static const EventChannel _keyboardHeightEventChannel = EventChannel(_channelName);

  StreamSubscription<double>? _keyboardHeightSubscription;
  KeyboardHeightCallback? _callback;
  bool _isListening = false;
  double _lastHeight = 0.0;

  /// 设置键盘高度变化监听回调
  ///
  /// [callback] 键盘高度变化时的回调函数，参数为键盘高度（逻辑像素）
  void onKeyboardHeightChanged(KeyboardHeightCallback callback) {
    if (_isListening) {
      _log('Warning: Already listening for keyboard height changes. Replacing callback.');
      _stopListening();
    }

    _callback = callback;
    _startListening();
  }

  /// 开始监听键盘高度变化
  void _startListening() {
    if (_isListening) {
      return;
    }

    try {
      _log('Starting keyboard height listener');
      _keyboardHeightSubscription = _keyboardHeightEventChannel
          .receiveBroadcastStream()
          .cast<double>()
          .distinct() // 过滤重复值
          .listen(
            _onHeightChanged,
            onError: _onError,
            onDone: _onDone,
            cancelOnError: false,
          );
      _isListening = true;
      _log('Keyboard height listener started successfully');
    } catch (e) {
      _log('Error starting keyboard height listener: $e');
      _handleError('LISTEN_ERROR', 'Failed to start listening: $e');
    }
  }

  /// 停止监听键盘高度变化
  void _stopListening() {
    if (!_isListening) {
      return;
    }

    try {
      _keyboardHeightSubscription?.cancel();
      _keyboardHeightSubscription = null;
      _isListening = false;
      _log('Keyboard height listener stopped');
    } catch (e) {
      _log('Error stopping keyboard height listener: $e');
    }
  }

  /// 处理高度变化事件
  void _onHeightChanged(double height) {
    try {
      // 过滤微小变化（小于1dp的变化忽略）
      if ((height - _lastHeight).abs() < 1.0) {
        return;
      }

      _lastHeight = height;
      _log('Keyboard height changed to: $height');
      _callback?.call(height);
    } catch (e) {
      _log('Error handling height change: $e');
      _handleError('CALLBACK_ERROR', 'Error in height callback: $e');
    }
  }

  /// 处理监听错误
  void _onError(dynamic error) {
    _log('Keyboard height listener error: $error');

    if (error is PlatformException) {
      _handleError(error.code, error.message ?? 'Unknown platform error');
    } else {
      _handleError('STREAM_ERROR', 'Stream error: $error');
    }

    // 尝试重新连接
    _attemptReconnect();
  }

  /// 处理监听完成事件
  void _onDone() {
    _log('Keyboard height listener stream closed');
    _isListening = false;

    // 尝试重新连接
    _attemptReconnect();
  }

  /// 尝试重新连接
  void _attemptReconnect() {
    if (_callback != null && !_isListening) {
      _log('Attempting to reconnect keyboard height listener');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_callback != null && !_isListening) {
          _startListening();
        }
      });
    }
  }

  /// 处理错误
  void _handleError(String code, String message) {
    _log('Error [$code]: $message');

    // 可以在这里添加错误回调，通知调用者
    // 暂时只记录日志
  }

  /// 获取当前键盘高度
  ///
  /// 返回最后一次检测到的键盘高度
  double get currentKeyboardHeight => _lastHeight;

  /// 检查是否正在监听
  bool get isListening => _isListening;

  /// 释放资源
  ///
  /// 在不再需要键盘高度检测时调用，通常在widget的dispose方法中调用
  void dispose() {
    _log('Disposing keyboard height plugin');
    _stopListening();
    _callback = null;
    _lastHeight = 0.0;
  }

  /// 记录日志
  void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'KeyboardHeightPlugin');
    }
  }
}

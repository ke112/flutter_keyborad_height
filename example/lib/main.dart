import 'package:flutter/material.dart';
import 'package:keyboard_height_plugin/keyboard_height_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keyboard Height Plugin Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _keyboardHeight = 0;
  bool _isKeyboardVisible = false;
  String _statusMessage = '等待键盘状态变化...';
  final KeyboardHeightPlugin _keyboardHeightPlugin = KeyboardHeightPlugin();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupKeyboardListener();
    _setupFocusListener();
  }

  /// 设置键盘高度监听
  void _setupKeyboardListener() {
    try {
      _keyboardHeightPlugin.onKeyboardHeightChanged((double height) {
        setState(() {
          _keyboardHeight = height;
          _isKeyboardVisible = height > 0;
          _statusMessage = _isKeyboardVisible ? '键盘已弹起，高度: ${height.toStringAsFixed(1)} dp' : '键盘已收起';
        });
      });
    } catch (e) {
      setState(() {
        _statusMessage = '监听器设置失败: $e';
      });
    }
  }

  /// 设置焦点监听
  void _setupFocusListener() {
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isKeyboardVisible) {
        // 焦点丢失但键盘仍显示时的处理
        setState(() {
          _statusMessage = '输入框失去焦点，等待键盘收起...';
        });
      }
    });
  }

  /// 强制显示键盘
  void _showKeyboard() {
    _focusNode.requestFocus();
  }

  /// 强制隐藏键盘
  void _hideKeyboard() {
    _focusNode.unfocus();
  }

  /// 清空文本
  void _clearText() {
    _textController.clear();
  }

  @override
  void dispose() {
    _keyboardHeightPlugin.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('键盘高度检测'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 状态信息区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: _isKeyboardVisible ? Colors.green.shade50 : Colors.grey.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isKeyboardVisible ? Icons.keyboard : Icons.keyboard_hide,
                          color: _isKeyboardVisible ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _isKeyboardVisible ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '插件状态: ${_keyboardHeightPlugin.isListening ? "正在监听" : "未监听"}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // 主要内容区域
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '键盘高度',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _keyboardHeight.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 控制按钮
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showKeyboard,
                        icon: const Icon(Icons.keyboard),
                        label: const Text('显示键盘'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _hideKeyboard,
                        icon: const Icon(Icons.keyboard_hide),
                        label: const Text('隐藏键盘'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _clearText,
                        icon: const Icon(Icons.clear),
                        label: const Text('清空文本'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 输入框 - 跟随键盘位置
          Positioned(
            bottom: _keyboardHeight,
            left: 16,
            right: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black26,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '在这里输入文本以测试键盘高度检测...',
                    filled: true,
                    fillColor: Colors.orange.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Icon(
                      Icons.edit,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

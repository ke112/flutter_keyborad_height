import 'package:flutter/material.dart';
import 'package:keyboard_height_plugin/keyboard_height_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> with TickerProviderStateMixin {
  double _keyboardHeight = 0;
  double _cachedKeyboardHeight = 0;
  bool _isKeyboardVisible = false;
  String _statusMessage = '等待键盘状态变化...';
  final KeyboardHeightPlugin _keyboardHeightPlugin = KeyboardHeightPlugin();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool hasSetKeyboardHeight = false;

  /// 键盘缓存键名
  static const String _keyboardHeightCacheKey = 'cached_keyboard_height';
  static const String _hasKeyboardCacheKey = 'has_keyboard_cache';

  @override
  void initState() {
    super.initState();
    _loadCachedKeyboardHeight();
    _setupKeyboardListener();
    _setupFocusListener();
  }

  /// 加载本地缓存的键盘高度
  Future<void> _loadCachedKeyboardHeight() async {
    try {
      final SharedPreferences pref = await SharedPreferences.getInstance();
      final bool hasCache = pref.getBool(_hasKeyboardCacheKey) ?? false;

      if (hasCache) {
        final double cachedHeight = pref.getDouble(_keyboardHeightCacheKey) ?? 0;
        if (cachedHeight > 0) {
          setState(() {
            _cachedKeyboardHeight = cachedHeight;
            _keyboardHeight = 0; // 初始键盘高度为0，但缓存存在
            _statusMessage = '已加载缓存键盘高度: ${cachedHeight.toStringAsFixed(1)} dp';
          });

          // 不要预先动画，让输入框保持在底部，等用户点击时才弹起
        }
      }

      // 界面加载完成后自动弹起键盘
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    } catch (e) {
      setState(() {
        _statusMessage = '加载缓存失败: $e';
      });
    }
  }

  /// 保存键盘高度到本地缓存
  Future<void> _saveCachedKeyboardHeight(double height) async {
    try {
      final SharedPreferences pref = await SharedPreferences.getInstance();
      await pref.setDouble(_keyboardHeightCacheKey, height);
      await pref.setBool(_hasKeyboardCacheKey, height > 0);
    } catch (e) {
      debugPrint('保存键盘高度缓存失败: $e');
    }
  }

  /// 设置键盘高度监听
  void _setupKeyboardListener() {
    try {
      _keyboardHeightPlugin.onKeyboardHeightChanged((double height) {
        _handleKeyboardHeightChange(height);
      });
    } catch (e) {
      setState(() {
        _statusMessage = '监听器设置失败: $e';
      });
    }
  }

  /// 处理键盘高度变化
  void _handleKeyboardHeightChange(double height) {
    final bool keyboardVisible = height > 0;

    if (height > 0 && height != _keyboardHeight) {
      _keyboardHeight = height;
      hasSetKeyboardHeight = true;
    } else if (height == 0) {
      hasSetKeyboardHeight = true;
    }

    setState(() {
      _isKeyboardVisible = keyboardVisible;

      if (keyboardVisible) {
        _statusMessage = '键盘已弹起，高度: ${height.toStringAsFixed(1)} dp或px';
        // 更新缓存高度
        if (height != _cachedKeyboardHeight) {
          _cachedKeyboardHeight = height;
        }
      } else {
        _statusMessage = '键盘已收起';
      }
    });

    // 保存最新的键盘高度到缓存
    _saveCachedKeyboardHeight(height);
  }

  /// 设置焦点监听
  void _setupFocusListener() {
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isKeyboardVisible) {
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

  /// 清除缓存
  void _clearCache() async {
    try {
      final SharedPreferences pref = await SharedPreferences.getInstance();
      await pref.remove(_keyboardHeightCacheKey);
      await pref.remove(_hasKeyboardCacheKey);

      setState(() {
        _cachedKeyboardHeight = 0;
        _statusMessage = '缓存已清除';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '清除缓存失败: $e';
      });
    }
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
      resizeToAvoidBottomInset: hasSetKeyboardHeight,
      appBar: AppBar(
        title: const Text('键盘高度检测 - 夸克效果', style: TextStyle(color: Colors.black, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _clearCache,
            icon: const Icon(Icons.clear_all),
            tooltip: '清除缓存',
          ),
        ],
      ),
      body: Builder(builder: (context) {
        double bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        return Stack(
          children: [
            Column(
              children: [
                // 状态信息区域
                keyboardObserverWidget(),

                // 主要内容区域
                keyboardFuncWidget(),
              ],
            ),
            PositionedDirectional(
              bottom: hasSetKeyboardHeight ? 0 : _keyboardHeight + bottomPadding,
              start: 0,
              end: 0,
              child: inputViewWidget(),
            ),
          ],
        );
      }),
    );
  }

  Widget inputViewWidget() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(12),
          topEnd: Radius.circular(12),
        ),
        color: Color(0xFF0F131A),
      ),
      padding: const EdgeInsetsDirectional.only(start: 10, end: 10, top: 10, bottom: 10),
      child: Scrollbar(
        thickness: 2,
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '在这里输入文本体验夸克式键盘跟随效果...',
            hintStyle: TextStyle(color: Color(0xFF6C727F)),
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.send,
          style: const TextStyle(fontSize: 16, color: Colors.white),
          onChanged: (text) {
            setState(() {});
          },
          onSubmitted: (value) {
            _clearText();
          },
        ),
      ),
    );
  }

  Widget keyboardObserverWidget() {
    return Container(
      width: double.infinity,
      height: 120,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.only(start: 16, top: 16),
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
          if (_cachedKeyboardHeight > 0)
            Text(
              '缓存高度: ${_cachedKeyboardHeight.toStringAsFixed(1)} dp或px',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget keyboardFuncWidget() {
    return Container(
      color: Colors.purple.shade50,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 键盘高度显示
          Container(
            width: 140,
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '当前键盘高度',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _keyboardHeight.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'dp或px',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),

          // 控制按钮
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: _showKeyboard,
                icon: const Icon(Icons.keyboard),
                label: const Text('显示键盘'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _hideKeyboard,
                icon: const Icon(Icons.keyboard_hide),
                label: const Text('隐藏键盘'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _clearText,
                icon: const Icon(Icons.clear),
                label: const Text('清空文本'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

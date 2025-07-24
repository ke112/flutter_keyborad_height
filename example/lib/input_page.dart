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
  double _currentInputBottom = 24; // 当前输入框底部位置
  bool _isKeyboardVisible = false;
  bool _isInitialized = false; // 是否已初始化
  String _statusMessage = '正在初始化...';

  final KeyboardHeightPlugin _keyboardHeightPlugin = KeyboardHeightPlugin();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 动画控制器
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;

  /// 键盘缓存键名
  static const String _keyboardHeightCacheKey = 'cached_keyboard_height';

  /// 默认底部间距
  static const double _defaultBottomPadding = 24.0;

  /// 键盘顶部间距
  static const double _keyboardTopPadding = 8.0;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _loadCachedKeyboardHeight();
    _setupKeyboardListener();
    _setupFocusListener();
  }

  /// 初始化动画控制器
  void _initAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _positionAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  /// 加载本地缓存的键盘高度
  Future<void> _loadCachedKeyboardHeight() async {
    try {
      final SharedPreferences pref = await SharedPreferences.getInstance();
      final double cachedHeight = pref.getDouble(_keyboardHeightCacheKey) ?? 0;

      setState(() {
        _cachedKeyboardHeight = cachedHeight;
        _isInitialized = true;

        if (cachedHeight > 0) {
          // 有缓存时，直接定位到缓存位置，无动画
          _currentInputBottom = cachedHeight + _keyboardTopPadding;
          _statusMessage = '已加载缓存键盘高度: ${cachedHeight.toStringAsFixed(1)} dp，输入框已定位';
        } else {
          // 无缓存时，使用默认位置
          _currentInputBottom = _defaultBottomPadding;
          _statusMessage = '无缓存数据，等待键盘弹起';
        }
      });

      // 界面加载完成后自动弹起键盘
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    } catch (e) {
      setState(() {
        _isInitialized = true;
        _currentInputBottom = _defaultBottomPadding;
        _statusMessage = '加载缓存失败: $e';
      });
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
    double targetBottom;

    if (keyboardVisible) {
      // 键盘显示时：定位到键盘顶部
      targetBottom = height + _keyboardTopPadding;
    } else {
      // 键盘隐藏时：总是回到底部
      targetBottom = _defaultBottomPadding;
    }

    // 更新键盘高度和状态
    setState(() {
      _keyboardHeight = height;
      _isKeyboardVisible = keyboardVisible;

      if (keyboardVisible) {
        _statusMessage = '键盘已弹起，高度: ${height.toStringAsFixed(1)} dp';
        // 更新缓存高度
        if (height != _cachedKeyboardHeight) {
          _cachedKeyboardHeight = height;
          _saveCachedKeyboardHeight(height);
        }
      } else {
        _statusMessage = '键盘已收起，输入框跟随下降';
      }
    });

    // 只有在目标位置和当前位置不同时才执行动画
    if (targetBottom != _currentInputBottom) {
      _animateToPosition(targetBottom);
    }
  }

  /// 执行位置动画
  void _animateToPosition(double targetBottom) {
    final double startBottom = _currentInputBottom;

    _animationController.reset();
    _positionAnimation = Tween<double>(
      begin: startBottom,
      end: targetBottom,
    ).animate(_animationController);

    _animationController.forward().then((_) {
      setState(() {
        _currentInputBottom = targetBottom;
      });
    });
  }

  /// 保存键盘高度到本地缓存
  Future<void> _saveCachedKeyboardHeight(double height) async {
    if (height <= 0) return;

    try {
      final SharedPreferences pref = await SharedPreferences.getInstance();
      await pref.setDouble(_keyboardHeightCacheKey, height);
    } catch (e) {
      debugPrint('保存键盘高度缓存失败: $e');
    }
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

      setState(() {
        _cachedKeyboardHeight = 0;
        _statusMessage = '缓存已清除';
      });

      // 如果当前键盘没有显示，动画回到默认位置
      if (!_isKeyboardVisible) {
        _animateToPosition(_defaultBottomPadding);
      }
    } catch (e) {
      setState(() {
        _statusMessage = '清除缓存失败: $e';
      });
    }
  }

  /// 计算当前输入框位置
  double _getCurrentInputBottom() {
    if (!_isInitialized) {
      return _defaultBottomPadding; // 初始化前使用默认位置
    }

    if (_animationController.isAnimating) {
      return _positionAnimation.value; // 动画进行中使用动画值
    }

    return _currentInputBottom; // 使用当前位置
  }

  @override
  void dispose() {
    _animationController.dispose();
    _keyboardHeightPlugin.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 禁用自动调整，使用自定义逻辑
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
      body: Stack(
        children: [
          Column(
            children: [
              // 状态信息区域
              keyboardObserverWidget(),
              // 主要内容区域
              keyboardFuncWidget(),
            ],
          ),
          // 使用AnimatedBuilder实现流畅的位置动画
          AnimatedBuilder(
            animation: _positionAnimation,
            builder: (context, child) {
              return Positioned(
                bottom: _getCurrentInputBottom(),
                left: 0,
                right: 0,
                child: inputViewWidget(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget inputViewWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadiusDirectional.all(Radius.circular(16)),
        color: Color(0xFF0F131A),
      ),
      padding: const EdgeInsets.all(16),
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
              '缓存高度: ${_cachedKeyboardHeight.toStringAsFixed(1)} dp，输入框位置: ${_currentInputBottom.toStringAsFixed(1)} dp',
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
                  'dp',
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

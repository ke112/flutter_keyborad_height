package com.nschairer.keyboard_height_plugin

import android.app.Activity
import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowInsets
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel

/// 键盘高度检测插件
class KeyboardHeightPlugin : FlutterPlugin, EventChannel.StreamHandler, ActivityAware {
    companion object {
        private const val TAG = "KeyboardHeightPlugin"
        private const val KEYBOARD_HEIGHT_EVENT_CHANNEL_NAME = "keyboardHeightEventChannel"
        private const val KEYBOARD_HEIGHT_THRESHOLD = 0.15 // 键盘高度阈值（屏幕高度的15%）
    }

    private var eventSink: EventChannel.EventSink? = null
    private var eventChannel: EventChannel? = null
    private var activityPluginBinding: ActivityPluginBinding? = null
    private var globalLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    private var lastKeyboardHeight: Double = 0.0

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin attached to engine")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, KEYBOARD_HEIGHT_EVENT_CHANNEL_NAME)
        eventChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin detached from engine")
        cleanupListener()
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "Starting to listen for keyboard height changes")
        eventSink = events
        setupKeyboardListener()
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "Cancelled listening for keyboard height changes")
        cleanupListener()
        eventSink = null
    }

    /// 设置键盘监听器
    private fun setupKeyboardListener() {
        val activity = activityPluginBinding?.activity
        if (activity == null) {
            Log.e(TAG, "Activity is null, cannot setup keyboard listener")
            eventSink?.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        val rootView = activity.window?.decorView?.rootView
        if (rootView == null) {
            Log.e(TAG, "Root view is null, cannot setup keyboard listener")
            eventSink?.error("NO_ROOT_VIEW", "Root view is not available", null)
            return
        }

        // 清理之前的监听器
        cleanupListener()

        // 创建新的监听器
        globalLayoutListener = object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                try {
                    val keyboardHeight = calculateKeyboardHeight(activity, rootView)
                    if (keyboardHeight != lastKeyboardHeight) {
                        lastKeyboardHeight = keyboardHeight
                        Log.d(TAG, "Keyboard height changed to: $keyboardHeight")
                        eventSink?.success(keyboardHeight)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error calculating keyboard height", e)
                    eventSink?.error("CALCULATION_ERROR", "Failed to calculate keyboard height: ${e.message}", null)
                }
            }
        }

        // 添加监听器
        rootView.viewTreeObserver?.addOnGlobalLayoutListener(globalLayoutListener)
        Log.d(TAG, "Keyboard listener setup completed")
    }

    /// 计算键盘高度
    private fun calculateKeyboardHeight(activity: Activity, rootView: View): Double {
        val displayMetrics = activity.resources.displayMetrics
        val density = displayMetrics.density
        
        // 方法1：使用WindowInsets (Android R+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val keyboardHeight = calculateKeyboardHeightWithInsets(rootView, density)
            if (keyboardHeight > 0) {
                Log.d(TAG, "Using WindowInsets method, height: $keyboardHeight")
                return keyboardHeight
            }
        }

        // 方法2：使用传统的Rect计算方法
        val keyboardHeight = calculateKeyboardHeightWithRect(activity, rootView, density)
        Log.d(TAG, "Using Rect method, height: $keyboardHeight")
        return keyboardHeight
    }

    /// 使用WindowInsets计算键盘高度 (Android R+)
    @RequiresApi(Build.VERSION_CODES.R)
    private fun calculateKeyboardHeightWithInsets(rootView: View, density: Float): Double {
        val windowInsets = rootView.rootWindowInsets ?: return 0.0
        val imeInsets = windowInsets.getInsets(WindowInsets.Type.ime())
        val keyboardHeightPx = imeInsets.bottom
        return (keyboardHeightPx / density).toDouble()
    }

    /// 使用Rect计算键盘高度（兼容性方法）
    private fun calculateKeyboardHeightWithRect(activity: Activity, rootView: View, density: Float): Double {
        val rect = Rect()
        rootView.getWindowVisibleDisplayFrame(rect)
        
        val screenHeight = rootView.height
        val visibleFrameHeight = rect.bottom - rect.top
        
        // 计算键盘占用的像素高度
        var keyboardHeightPx = screenHeight - visibleFrameHeight
        
        // 处理导航栏
        if (hasNavigationBar(activity)) {
            val navigationBarHeight = getNavigationBarHeight(activity)
            if (!isNavigationBarVisible(activity)) {
                keyboardHeightPx -= navigationBarHeight
            }
        }
        
        // 转换为逻辑像素
        val keyboardHeightDp = keyboardHeightPx / density
        
        // 应用阈值过滤
        val screenHeightDp = screenHeight / density
        return if (keyboardHeightDp > screenHeightDp * KEYBOARD_HEIGHT_THRESHOLD) {
            keyboardHeightDp.toDouble()
        } else {
            0.0
        }
    }

    /// 获取导航栏高度
    private fun getNavigationBarHeight(activity: Activity): Int {
        val resourceId = activity.resources.getIdentifier(
            "navigation_bar_height", 
            "dimen", 
            "android"
        )
        return if (resourceId > 0) {
            activity.resources.getDimensionPixelSize(resourceId)
        } else {
            0
        }
    }

    /// 检查设备是否有导航栏
    private fun hasNavigationBar(activity: Activity): Boolean {
        val id = activity.resources.getIdentifier("config_showNavigationBar", "bool", "android")
        return id > 0 && activity.resources.getBoolean(id)
    }

    /// 检查导航栏是否可见
    private fun isNavigationBarVisible(activity: Activity): Boolean {
        val decorView = activity.window?.decorView ?: return false
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val windowInsets = decorView.rootWindowInsets ?: return false
            windowInsets.isVisible(WindowInsets.Type.navigationBars())
        } else {
            @Suppress("DEPRECATION")
            val systemWindowInsets = decorView.rootWindowInsets?.systemWindowInsetBottom ?: 0
            systemWindowInsets > 0
        }
    }

    /// 清理监听器
    private fun cleanupListener() {
        globalLayoutListener?.let { listener ->
            val activity = activityPluginBinding?.activity
            val rootView = activity?.window?.decorView?.rootView
            rootView?.viewTreeObserver?.removeOnGlobalLayoutListener(listener)
            globalLayoutListener = null
            Log.d(TAG, "Cleaned up keyboard listener")
        }
    }

    // ActivityAware接口实现
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "Attached to activity")
        activityPluginBinding = binding
        // 如果已经有监听器，重新设置
        if (eventSink != null) {
            setupKeyboardListener()
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "Detached from activity for config changes")
        cleanupListener()
        activityPluginBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "Reattached to activity after config changes")
        activityPluginBinding = binding
        // 重新设置监听器
        if (eventSink != null) {
            setupKeyboardListener()
        }
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "Detached from activity")
        cleanupListener()
        activityPluginBinding = null
    }
}

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// 开机启动管理器
class AutoStartManager {
  /// 保存用户设置的键
  static const String _autoStartKey = 'auto_start_enabled';
  
  /// 应用名称
  static const String _appName = 'GleetmallPrintAssistant';
  
  /// 注册表路径
  static const String _registryPath = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  
  /// 获取应用可执行文件路径
  static String get _executablePath {
    if (Platform.isWindows) {
      // 获取当前应用的可执行文件路径
      return Platform.resolvedExecutable;
    }
    throw UnsupportedError('Only Windows is supported');
  }
  
  /// 检查是否已设置开机启动
  static Future<bool> isAutoStartEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoStartKey) ?? false;
  }
  
  /// 设置开机启动
  static Future<void> setAutoStartEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartKey, enabled);
    
    if (Platform.isWindows) {
      if (enabled) {
        // 添加到注册表
        await _addToRegistry();
      } else {
        // 从注册表移除
        await _removeFromRegistry();
      }
    }
  }
  
  /// 添加到注册表
  static Future<void> _addToRegistry() async {
    if (Platform.isWindows) {
      final String exePath = _executablePath;
      
      // 使用reg.exe命令添加注册表项
      final ProcessResult result = await Process.run(
        'reg',
        [
          'add',
          _registryPath,
          '/v',
          _appName,
          '/t',
          'REG_SZ',
          '/d',
          exePath,
          '/f'
        ],
        runInShell: true
      );
      
      if (result.exitCode != 0) {
        print('添加到注册表失败: ${result.stderr}');
      } else {
        print('添加到注册表成功');
      }
    }
  }
  
  /// 从注册表移除
  static Future<void> _removeFromRegistry() async {
    if (Platform.isWindows) {
      // 使用reg.exe命令删除注册表项
      final ProcessResult result = await Process.run(
        'reg',
        [
          'delete',
          _registryPath,
          '/v',
          _appName,
          '/f'
        ],
        runInShell: true
      );
      
      if (result.exitCode != 0) {
        print('从注册表移除失败: ${result.stderr}');
      } else {
        print('从注册表移除成功');
      }
    }
  }
}
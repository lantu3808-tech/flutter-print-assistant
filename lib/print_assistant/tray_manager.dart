import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/auto_start_manager.dart';
import './print_history_manager.dart';
import './print_queue_manager.dart';

class TrayManagerHelper implements TrayListener {
  static final TrayManagerHelper _instance = TrayManagerHelper._internal();
  factory TrayManagerHelper() => _instance;

  TrayManagerHelper._internal();

  Future<void> init() async {
    try {
      // 注册托盘事件监听器
      trayManager.addListener(this);
      
      // 设置托盘图标
      await _setTrayIcon();
      
      // 创建托盘菜单
      await _createTrayMenu();
      
      print('系统托盘初始化成功');
    } catch (e) {
      print('系统托盘初始化失败: $e');
      // 输出详细的错误信息，帮助调试
      print(e.toString());
    }
  }

  Future<void> dispose() async {
    try {
      // 移除监听器
      trayManager.removeListener(this);
      // 销毁托盘图标
      await trayManager.destroy();
      print('系统托盘资源清理成功');
    } catch (e) {
      print('系统托盘资源清理失败: $e');
    }
  }

  // 显示主窗口
  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.restore();
      print('窗口已成功显示');
    } catch (e) {
      print('显示窗口失败: $e');
    }
  }

  // 退出应用
  Future<void> _quitApp() async {
    try {
      await dispose();
      // 退出应用
      exit(0);
      print('应用已成功退出');
    } catch (e) {
      print('退出应用失败: $e');
    }
  }

  // 设置托盘图标
  Future<void> _setTrayIcon() async {
    try {
      // 设置托盘工具提示
      await trayManager.setToolTip('Gleetmall 打印助手');
      print('托盘提示设置成功');
      
      // 根据用户推荐，使用ico格式的图标文件，这是最稳定的方案
      print('开始设置托盘图标...');
      
      // 使用项目中已有的ico图标文件（Windows资源目录）
      final icoPath = 'G:/javasdk/CascadeProjects/print_assistant_flutter/windows/runner/resources/app_icon.ico';
      print('步骤1：尝试使用ico图标: $icoPath');
      
      // 检查ico文件是否存在
      if (await File(icoPath).exists()) {
        print('ico文件存在，大小: ${await File(icoPath).length()} 字节');
        await trayManager.setIcon(icoPath);
        print('托盘图标设置成功！使用ico格式图标');
      } else {
        print('ico文件不存在，尝试使用png图标...');
        
        // 备选方案：使用png图标
        final pngPath = 'G:/javasdk/CascadeProjects/print_assistant_flutter/assets/images/tray_icon.png';
        if (await File(pngPath).exists()) {
          print('png文件存在，使用png图标');
          await trayManager.setIcon(pngPath);
          print('托盘图标设置成功！使用png格式图标');
        } else {
          print('所有图标文件都不存在，仅显示托盘提示');
        }
      }
      
      // 验证托盘设置
      print('托盘设置完成，提示文本: Gleetmall 打印助手');
      
    } catch (e) {
      print('设置托盘失败: $e');
      print('错误详情: ${e.toString()}');
      
      // 最终保障：无论如何都要确保托盘存在
      await trayManager.setToolTip('Gleetmall 打印助手');
      print('已确保托盘提示存在');
    }
  }

  // 创建托盘菜单
  Future<void> _createTrayMenu() async {
    // 获取当前开机启动状态
    final bool isAutoStartEnabled = await AutoStartManager.isAutoStartEnabled();
    
    // 改进的托盘菜单设计，匹配设计要求
    final menu = Menu(items: [
      // 打印助手标题
      MenuItem(label: '打印助手'),
      // 分隔线
      MenuItem.separator(),
      // 运行中状态（带勾选标记）
      MenuItem.checkbox(
        label: '运行中',
        checked: true,
        disabled: true,
      ),
      // 开机启动选择项 - 使用复选框构造函数
      MenuItem.checkbox(
        label: '开机启动',
        checked: isAutoStartEnabled,
        onClick: (menuItem) async {
          // 切换开机启动状态
          final newStatus = !(menuItem.checked ?? false);
          await AutoStartManager.setAutoStartEnabled(newStatus);
          // 重新创建菜单以更新状态
          await _createTrayMenu();
          print('开机启动状态已切换为: $newStatus');
        },
      ),
      // 打印队列菜单项
      MenuItem(label: '打印队列', onClick: (menuItem) async {
        await _showWindow();
      }),
      // 设置菜单项
      MenuItem(label: '设置', onClick: (menuItem) async {
        await _showWindow();
      }),
      // 清除缓存菜单项
      MenuItem(label: '清除缓存', onClick: (menuItem) async {
        // 清除打印历史记录
        await PrintHistoryManager().clearHistory();
        // 清除打印队列
        PrintQueueManager().clearQueue();
        print('缓存已清除');
      }),
      // 退出菜单项
      MenuItem(label: '退出', onClick: (menuItem) async {
        await _quitApp();
      }),
    ]);
    
    try {
      await trayManager.setContextMenu(menu);
      print('托盘菜单创建成功');
    } catch (e) {
      print('创建托盘菜单失败: $e');
    }
  }

  // 处理窗口关闭事件，最小化到托盘
  Future<void> handleWindowClose() async {
    try {
      await windowManager.hide();
      print('窗口已最小化到托盘');
    } catch (e) {
      print('最小化窗口到托盘失败: $e');
    }
  }

  // 托盘事件处理
  @override
  void onTrayIconMouseDown() {
    print('托盘图标鼠标按下事件');
    // 点击托盘图标显示/隐藏窗口
    windowManager.isVisible().then((visible) {
      print('当前窗口可见性: $visible');
      if (visible) {
        windowManager.hide();
        print('窗口已隐藏');
      } else {
        _showWindow();
      }
    });
  }

  @override
  void onTrayIconRightMouseDown() {
    print('托盘图标右键按下事件');
    // 右键点击显示菜单
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
    // 右键释放事件
  }

  @override
  void onTrayIconMouseUp() {
    // 左键释放事件
  }

  @override
  void onTrayIconMouseMove() {
    // 鼠标移动事件
  }

  @override
  void onTrayIconDoubleClick() {
    print('托盘图标双击事件');
    // 双击显示窗口
    _showWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    print('托盘菜单项点击事件: ${menuItem.label}');
    // 菜单项点击事件已通过onClick回调处理
  }
}

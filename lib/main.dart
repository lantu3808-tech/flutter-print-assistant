import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'print_assistant/tray_manager.dart';
import 'ui/print_assistant_ui.dart';
import 'print_assistant/http_server.dart';
import 'dart:io';

// 全局变量，确保实例不会被垃圾回收
late final PrintAssistantServer httpServer;
late final TrayManagerHelper trayManagerHelper;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 添加详细日志
  print('开始初始化应用程序...');
  
  // 初始化系统托盘 - 这是保持应用运行的关键
  print('初始化系统托盘...');
  trayManagerHelper = TrayManagerHelper();
  try {
    await trayManagerHelper.init();
    print('系统托盘初始化成功');
  } catch (e) {
    print('系统托盘初始化失败: $e');
  }
  
  // 启动HTTP服务器 - 这也是保持应用运行的关键
  print('启动HTTP服务器...');
  httpServer = PrintAssistantServer();
  try {
    await httpServer.start();
    print('HTTP服务器已启动，监听端口：9101');
  } catch (e) {
    print('Failed to start HTTP server: $e');
  }
  
  // 初始化窗口管理器
  print('初始化窗口管理器...');
  await windowManager.ensureInitialized();
  print('窗口管理器初始化成功');
  
  // 使用旧版本window_manager的正确API设置窗口属性
  WindowOptions options = const WindowOptions(
    size: Size(600, 400),
    center: true,
    title: '打印助手',
    minimumSize: Size(600, 400),
    maximumSize: Size(800, 600),
  );
  
  // 等待窗口准备好显示，然后应用设置
  print('等待窗口准备好显示...');
  await windowManager.waitUntilReadyToShow(options, () async {
    print('窗口准备好显示，正在显示窗口...');
    await windowManager.show();
    print('窗口已显示');
    await windowManager.focus();
    print('窗口已获得焦点');
    await windowManager.setPreventClose(true);
    print('已设置阻止窗口关闭');
    
    // 暂时移除自动隐藏到托盘的功能，便于调试和测试
    // Future.delayed(const Duration(seconds: 1), () async {
    //   await windowManager.hide();
    //   print('窗口已自动隐藏到托盘');
    // });
  });
  
  // 主应用运行
  print('启动Flutter应用...');
  runApp(const MyApp());
  print('Flutter应用启动完成');
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gleetmall 打印助手',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PrintAssistantUI(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化窗口管理器
  await windowManager.ensureInitialized();
  
  // 使用旧版本window_manager的正确API
  WindowOptions options = WindowOptions(
    size: Size(200, 160),
    center: true,
    title: 'Gleetmall 打印助手',
    minimumSize: Size(200, 160),
    maximumSize: Size(200, 160),
  );
  
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true);
    print('窗口已显示，大小: 200x160');
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gleetmall 打印助手',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gleetmall 打印助手'),
        toolbarHeight: 30,
        titleTextStyle: const TextStyle(fontSize: 12),
      ),
      body: const Center(
        child: Text('测试窗口大小'),
      ),
    );
  }
}
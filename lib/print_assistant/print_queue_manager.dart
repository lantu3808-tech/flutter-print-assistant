import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'print_queue_item.dart';
import 'print_service.dart';
import 'print_history_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

/// 打印队列管理器
class PrintQueueManager {
  static final PrintQueueManager _instance = PrintQueueManager._internal();
  factory PrintQueueManager() => _instance;
  PrintQueueManager._internal();

  final List<PrintQueueItem> _queue = [];
  final PrintService _printService = PrintService();
  final PrintHistoryManager _historyManager = PrintHistoryManager();
  final StreamController<List<PrintQueueItem>> _queueController = StreamController<List<PrintQueueItem>>.broadcast();
  final Uuid _uuid = const Uuid();
  bool _isProcessing = false;
  late final File _queueFile;

  /// 初始化打印队列管理器，包括历史记录和加载队列
  Future<void> init() async {
    await _historyManager.init();
    await _setupQueueFile();
    await _loadQueue();
  }

  /// 设置队列文件路径
  Future<void> _setupQueueFile() async {
    final directory = await getApplicationDocumentsDirectory();
    _queueFile = File('${directory.path}/print_queue.json');
    print('打印队列文件路径: ${_queueFile.path}');
    
    // 如果文件不存在，创建一个空文件
    if (!await _queueFile.exists()) {
      await _queueFile.create(recursive: true);
      await _queueFile.writeAsString(jsonEncode([]));
    }
  }

  /// 从文件加载打印队列
  Future<void> _loadQueue() async {
    try {
      final content = await _queueFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final List<PrintQueueItem> loadedQueue = jsonList
          .map((item) => PrintQueueItem.fromJson(item as Map<String, dynamic>))
          .toList();
      
      // 只加载待处理和打印中的任务，已完成和失败的任务不应在重启后保留
      final activeTasks = loadedQueue.where((item) => 
        item.status == PrintStatus.pending || 
        item.status == PrintStatus.printing
      ).toList();
      
      _queue.addAll(activeTasks);
      _notifyQueueChanged();
      print('从文件加载了 ${activeTasks.length} 个打印任务');
    } catch (e) {
      print('加载打印队列失败: $e');
      // 如果加载失败，清空队列文件
      await _queueFile.writeAsString(jsonEncode([]));
    }
  }

  /// 保存打印队列到文件
  Future<void> _saveQueue() async {
    try {
      final jsonList = _queue.map((item) => item.toJson()).toList();
      await _queueFile.writeAsString(jsonEncode(jsonList));
      print('打印队列已保存到文件');
    } catch (e) {
      print('保存打印队列失败: $e');
    }
  }

  /// 获取打印队列的流
  Stream<List<PrintQueueItem>> get queueStream => _queueController.stream;

  /// 获取当前队列
  List<PrintQueueItem> get queue => List.unmodifiable(_queue);

  /// 添加PDF打印任务
  Future<PrintQueueItem> addPdfPrintTask(String pdfData, {
    String printerName = '',
    int copies = 1,
    PrintPriority priority = PrintPriority.medium,
    Map<String, dynamic>? additionalData,
  }) async {
    final taskData = {
      'pdfBase64': pdfData,
      'printerName': printerName,
      'copies': copies,
      ...?additionalData,
    };

    final item = PrintQueueItem(
      id: _uuid.v4(),
      fileName: 'print_${DateTime.now().millisecondsSinceEpoch}.pdf',
      printerName: printerName,
      taskData: taskData,
      timestamp: DateTime.now(),
      priority: priority,
      status: PrintStatus.pending,
    );

    _queue.add(item);
    // 按优先级排序，高优先级任务排在前面
    _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    _notifyQueueChanged();
    _processQueue();

    return item;
  }

  /// 添加原始打印任务
  Future<PrintQueueItem> addRawPrintTask(String rawData, {
    String printerName = '',
    String contentType = 'RAW',
    int copies = 1,
    PrintPriority priority = PrintPriority.medium,
    Map<String, dynamic>? additionalData,
  }) async {
    final taskData = {
      'data': rawData,
      'printerName': printerName,
      'contentType': contentType,
      'copies': copies,
      ...?additionalData,
    };

    final item = PrintQueueItem(
      id: _uuid.v4(),
      fileName: 'print_${DateTime.now().millisecondsSinceEpoch}.raw',
      printerName: printerName,
      taskData: taskData,
      timestamp: DateTime.now(),
      priority: priority,
      status: PrintStatus.pending,
    );

    _queue.add(item);
    // 按优先级排序，高优先级任务排在前面
    _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    _notifyQueueChanged();
    _processQueue();

    return item;
  }

  /// 处理打印队列
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) {
      return;
    }

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final item = _queue.first;

      // 更新状态为打印中
      item.status = PrintStatus.printing;
      _notifyQueueChanged();

      try {
        // 执行真实打印
        Map<String, dynamic> result;
        if (item.fileName.endsWith('.pdf')) {
          // 使用任务项中的实际PDF数据
          result = await _printService.printPdf(jsonEncode(item.taskData));
        } else {
          // 检查内容类型，区分RAW和图像打印
          final contentType = item.taskData['contentType'] ?? '';
          if (contentType.toUpperCase() == 'IMAGE' || item.taskData.containsKey('imageBase64')) {
            // 处理图像打印
            result = await _printService.printImage(jsonEncode(item.taskData));
          } else {
            // 处理普通RAW打印
            result = await _printService.printRaw(jsonEncode(item.taskData));
          }
        }

        // 根据打印结果更新状态
        if (result['ok'] == true) {
          item.status = PrintStatus.completed;
        } else {
          item.status = PrintStatus.failed;
          item.errorMessage = result['message'];
        }
      } catch (e) {
        // 更新状态为失败
        item.status = PrintStatus.failed;
        item.errorMessage = e.toString();
      } finally {
        // 将任务添加到历史记录
        await _historyManager.addToHistory(item);
        // 从队列中移除已完成的任务
        await Future.delayed(const Duration(milliseconds: 500));
        _queue.removeAt(0);
        _notifyQueueChanged();
      }
    }

    _isProcessing = false;
  }

  /// 清空打印队列
  void clearQueue() {
    _queue.clear();
    _notifyQueueChanged();
  }

  /// 移除特定任务
  void removeTask(String id) {
    _queue.removeWhere((item) => item.id == id);
    _notifyQueueChanged();
  }

  /// 重试特定失败任务
  void retryTask(String id) {
    final index = _queue.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _queue[index];
      if (item.canRetry) {
        // 重置任务状态以便重试
        item.resetForRetry();
        // 将任务移到队列前面
        _queue.removeAt(index);
        _queue.insert(0, item);
        _notifyQueueChanged();
        // 开始处理队列
        _processQueue();
      }
    }
  }

  /// 通知队列变化并保存到文件
  void _notifyQueueChanged() {
    _queueController.add(List.from(_queue));
    // 保存队列到文件
    _saveQueue();
  }

  /// 关闭流控制器
  void dispose() {
    _queueController.close();
  }
}

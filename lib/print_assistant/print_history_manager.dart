import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'print_queue_item.dart';
import 'package:path_provider/path_provider.dart';

/// 打印历史记录管理器
class PrintHistoryManager {
  static final PrintHistoryManager _instance = PrintHistoryManager._internal();
  factory PrintHistoryManager() => _instance;
  PrintHistoryManager._internal();

  final List<PrintQueueItem> _history = [];
  final StreamController<List<PrintQueueItem>> _historyController = StreamController<List<PrintQueueItem>>.broadcast();
  static const int _maxHistoryItems = 100;
  File? _historyFile;

  /// 获取打印历史记录的流
  Stream<List<PrintQueueItem>> get historyStream => _historyController.stream;

  /// 获取当前历史记录
  List<PrintQueueItem> get history => List.unmodifiable(_history);

  /// 初始化历史记录管理器
  Future<void> init() async {
    try {
      final directory = await getApplicationSupportDirectory();
      _historyFile = File('${directory.path}/print_history.json');
      await _loadHistory();
    } catch (e) {
      print('初始化打印历史记录失败: $e');
    }
  }

  /// 加载历史记录
  Future<void> _loadHistory() async {
    if (_historyFile == null) return;
    
    try {
      if (await _historyFile!.exists()) {
        final content = await _historyFile!.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          _history.clear();
          for (final itemJson in jsonList) {
            try {
              final item = PrintQueueItem.fromJson(itemJson as Map<String, dynamic>);
              _history.add(item);
            } catch (e) {
              print('解析历史记录项失败: $e');
            }
          }
          _notifyHistoryChanged();
        }
      }
    } catch (e) {
      print('加载打印历史记录失败: $e');
    }
  }

  /// 保存历史记录
  Future<void> _saveHistory() async {
    if (_historyFile == null) return;
    
    try {
      final jsonList = _history.map((item) => item.toJson()).toList();
      await _historyFile!.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('保存打印历史记录失败: $e');
    }
  }

  /// 添加任务到历史记录
  Future<void> addToHistory(PrintQueueItem item) async {
    // 创建任务的副本，避免修改原任务
    final historyItem = PrintQueueItem(
      id: item.id,
      fileName: item.fileName,
      printerName: item.printerName,
      taskData: Map<String, dynamic>.from(item.taskData),
      timestamp: item.timestamp,
      priority: item.priority,
      status: item.status,
      errorMessage: item.errorMessage,
    );
    historyItem.retryCount = item.retryCount;

    // 添加到历史记录开头
    _history.insert(0, historyItem);
    
    // 限制历史记录数量
    if (_history.length > _maxHistoryItems) {
      _history.removeRange(_maxHistoryItems, _history.length);
    }
    
    _notifyHistoryChanged();
    await _saveHistory();
  }

  /// 清空历史记录
  Future<void> clearHistory() async {
    _history.clear();
    _notifyHistoryChanged();
    await _saveHistory();
  }

  /// 移除特定历史记录
  Future<void> removeHistoryItem(String id) async {
    _history.removeWhere((item) => item.id == id);
    _notifyHistoryChanged();
    await _saveHistory();
  }

  /// 通知历史记录变化
  void _notifyHistoryChanged() {
    _historyController.add(List.from(_history));
  }

  /// 关闭流控制器
  void dispose() {
    _historyController.close();
  }
}
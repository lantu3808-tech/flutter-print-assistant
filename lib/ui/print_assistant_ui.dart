import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import '../main.dart';
import '../print_assistant/http_server.dart';
import '../print_assistant/print_queue_manager.dart';
import '../print_assistant/print_queue_item.dart';
import '../print_assistant/print_history_manager.dart';

class PrintAssistantUI extends StatefulWidget {
  const PrintAssistantUI({Key? key}) : super(key: key);

  @override
  State<PrintAssistantUI> createState() => _PrintAssistantUIState();
}

class _PrintAssistantUIState extends State<PrintAssistantUI> with WindowListener {
  final PrintQueueManager _queueManager = PrintQueueManager();
  final PrintHistoryManager _historyManager = PrintHistoryManager();
  bool _isRunning = true;
  String _statusMessage = '运行中';
  Color _statusColor = Colors.green;
  List<PrintQueueItem> _printQueue = [];
  List<PrintQueueItem> _printHistory = [];
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // 注册窗口监听器
    windowManager.addListener(this);
    // 异步调用setPreventClose，确保阻止窗口关闭
    _setupWindowCloseHandler();
    // 初始化打印历史记录
    _historyManager.init();
    // 监听打印队列变化
    _queueManager.queueStream.listen((queue) {
      setState(() {
        _printQueue = queue;
      });
    });
    // 监听打印历史记录变化
    _historyManager.historyStream.listen((history) {
      setState(() {
        _printHistory = history;
      });
    });
  }

  @override
  void dispose() {
    // 移除窗口监听器
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    // 当用户点击关闭按钮时，隐藏窗口而不是关闭应用
    windowManager.hide();
  }

  @override
  void onWindowMinimize() {
    // 当用户点击最小化按钮时，隐藏窗口到托盘
    windowManager.hide();
  }

  /// 设置窗口关闭处理
  Future<void> _setupWindowCloseHandler() async {
    await windowManager.setPreventClose(true);
    bool isPreventClose = await windowManager.isPreventClose();
    print('已设置阻止窗口关闭: $isPreventClose');
  }
  

  


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // 简洁的AppBar设计
        appBar: AppBar(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 0,
          bottom: TabBar(
            tabs: const [
              Tab(text: '打印队列'),
              Tab(text: '打印历史'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // 简洁的背景色
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 主要内容区域
            Column(
              children: [
                // 标签页内容
                Expanded(
                  child: TabBarView(
                    children: [
                      // 打印队列标签页
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        margin: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // 表格头部
                            Container(
                              color: Colors.grey.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      '任务ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 1,
                                    child: Text(
                                      '任务状态',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      '文档名称',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      '打印机',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      '任务下发时间',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 1,
                                    child: Text(
                                      '操作',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 分割线
                            Container(height: 1, color: Colors.grey.shade200),
                            // 打印队列列表
                            Expanded(
                              child: _printQueue.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '打印队列为空',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _printQueue.length,
                                      itemBuilder: (context, index) {
                                        final item = _printQueue[index];
                                        return Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                              color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                              child: Row(
                                                children: [
                                                  // 任务ID
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      item.id.substring(0, 8),
                                                      style: const TextStyle(fontSize: 13),
                                                    ),
                                                  ),
                                                  // 任务状态
                                                  Expanded(
                                                    flex: 1,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                      decoration: BoxDecoration(
                                                        color: item.statusColor.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        item.statusText,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: item.statusColor,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                  // 文档名称
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      item.fileName,
                                                      style: const TextStyle(fontSize: 13),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 打印机
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      item.printerName.isNotEmpty ? item.printerName : '默认打印机',
                                                      style: const TextStyle(fontSize: 13),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 任务下发时间
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ),
                                                  // 操作按钮
                                                  Expanded(
                                                    flex: 1,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        // 重试按钮
                                                        if (item.status == PrintStatus.failed && item.canRetry)
                                                          IconButton(
                                                            onPressed: () {
                                                              _queueManager.retryTask(item.id);
                                                            },
                                                            icon: Icon(
                                                              Icons.refresh,
                                                              size: 16,
                                                              color: Colors.orange.shade600,
                                                            ),
                                                            padding: EdgeInsets.zero,
                                                            visualDensity: VisualDensity.compact,
                                                            tooltip: '重试打印',
                                                          ),
                                                        // 失败信息提示
                                                        if (item.status == PrintStatus.failed)
                                                          IconButton(
                                                            onPressed: () {
                                                              // 显示错误信息
                                                              showDialog(
                                                                context: context,
                                                                builder: (context) => AlertDialog(
                                                                  title: const Text('打印失败'),
                                                                  content: Text(item.errorMessage ?? '未知错误'),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () {
                                                                        Navigator.of(context).pop();
                                                                      },
                                                                      child: const Text('确定'),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                            icon: Icon(
                                                              Icons.error_outline,
                                                              size: 16,
                                                              color: Colors.red.shade600,
                                                            ),
                                                            padding: EdgeInsets.zero,
                                                            visualDensity: VisualDensity.compact,
                                                            tooltip: '查看错误信息',
                                                          ),
                                                        // 删除按钮
                                                        IconButton(
                                                          onPressed: () {
                                                            _queueManager.removeTask(item.id);
                                                          },
                                                          icon: Icon(
                                                            Icons.delete_outline,
                                                            size: 16,
                                                            color: Colors.grey.shade500,
                                                          ),
                                                          padding: EdgeInsets.zero,
                                                          visualDensity: VisualDensity.compact,
                                                          tooltip: '删除任务',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // 分割线
                                            Container(height: 1, color: Colors.grey.shade200),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      // 打印历史标签页
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        margin: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // 表格头部
                            Container(
                              color: Colors.grey.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      '任务ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 1,
                                    child: Text(
                                      '任务状态',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      '文档名称',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      '打印机',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      '打印时间',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 1,
                                    child: Text(
                                      '操作',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 分割线
                            Container(height: 1, color: Colors.grey.shade200),
                            // 优化后的清除历史按钮
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // 空容器占位，保持按钮靠右
                                  const SizedBox(),
                                  // 更美观的清除历史按钮
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      // 显示确认对话框
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('确认清除'),
                                          content: const Text('确定要清除所有打印历史记录吗？此操作不可恢复。'),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('取消'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await _historyManager.clearHistory();
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('确认'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('清除历史'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade600,
                                      side: BorderSide(color: Colors.red.shade200),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 打印历史列表
                            Expanded(
                              child: _printHistory.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.history_outlined,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '打印历史为空',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _printHistory.length,
                                      itemBuilder: (context, index) {
                                        final item = _printHistory[index];
                                        return Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                              color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                              child: Row(
                                                children: [
                                                  // 任务ID
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      item.id.substring(0, 8),
                                                      style: const TextStyle(fontSize: 13),
                                                    ),
                                                  ),
                                                  // 任务状态
                                                  Expanded(
                                                    flex: 1,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                      decoration: BoxDecoration(
                                                        color: item.statusColor.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        item.statusText,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: item.statusColor,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                  // 文档名称
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      item.fileName,
                                                      style: const TextStyle(fontSize: 13),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 打印机
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      item.printerName.isNotEmpty ? item.printerName : '默认打印机',
                                                      style: const TextStyle(fontSize: 13),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // 打印时间
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '${item.timestamp.year}-${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')} ${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ),
                                                  // 操作按钮
                                                  Expanded(
                                                    flex: 1,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        // 失败信息提示
                                                        if (item.status == PrintStatus.failed)
                                                          IconButton(
                                                            onPressed: () {
                                                              // 显示错误信息
                                                              showDialog(
                                                                context: context,
                                                                builder: (context) => AlertDialog(
                                                                  title: const Text('打印失败'),
                                                                  content: Text(item.errorMessage ?? '未知错误'),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () {
                                                                        Navigator.of(context).pop();
                                                                      },
                                                                      child: const Text('确定'),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                            icon: Icon(
                                                              Icons.error_outline,
                                                              size: 16,
                                                              color: Colors.red.shade600,
                                                            ),
                                                            padding: EdgeInsets.zero,
                                                            visualDensity: VisualDensity.compact,
                                                            tooltip: '查看错误信息',
                                                          ),
                                                        // 删除按钮
                                                        IconButton(
                                                          onPressed: () {
                                                            _historyManager.removeHistoryItem(item.id);
                                                          },
                                                          icon: Icon(
                                                            Icons.delete_outline,
                                                            size: 16,
                                                            color: Colors.grey.shade500,
                                                          ),
                                                          padding: EdgeInsets.zero,
                                                          visualDensity: VisualDensity.compact,
                                                          tooltip: '删除历史',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // 分割线
                                            Container(height: 1, color: Colors.grey.shade200),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 右下角服务状态
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _statusColor,
                      ),
                      margin: const EdgeInsets.only(right: 6.0),
                    ),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 打印任务优先级枚举
enum PrintPriority {
  low,     // 低优先级
  medium,  // 中优先级
  high,    // 高优先级
}

/// 打印任务状态枚举
enum PrintStatus {
  pending,      // 待处理
  printing,     // 打印中
  completed,    // 完成
  failed,       // 失败
}

/// 打印队列项数据模型
class PrintQueueItem {
  final String id;
  final String fileName;
  final String printerName;
  final Map<String, dynamic> taskData;
  final DateTime timestamp;
  final PrintPriority priority;
  PrintStatus status;
  String? errorMessage;
  int retryCount = 0;
  static const int maxRetries = 3;

  PrintQueueItem({
    required this.id,
    required this.fileName,
    required this.printerName,
    required this.taskData,
    required this.timestamp,
    this.priority = PrintPriority.medium,
    this.status = PrintStatus.pending,
    this.errorMessage,
  });

  /// 是否可以重试
  bool get canRetry => status == PrintStatus.failed && retryCount < maxRetries;

  /// 重置状态以便重试
  void resetForRetry() {
    if (canRetry) {
      status = PrintStatus.pending;
      retryCount++;
      errorMessage = null;
    }
  }

  /// 获取优先级显示文本
  String get priorityText {
    switch (priority) {
      case PrintPriority.low:
        return '低优先级';
      case PrintPriority.medium:
        return '中优先级';
      case PrintPriority.high:
        return '高优先级';
    }
  }

  /// 获取优先级显示颜色
  Color get priorityColor {
    switch (priority) {
      case PrintPriority.low:
        return Colors.green;
      case PrintPriority.medium:
        return Colors.orange;
      case PrintPriority.high:
        return Colors.red;
    }
  }

  /// 获取状态显示文本
  String get statusText {
    switch (status) {
      case PrintStatus.pending:
        return '待处理';
      case PrintStatus.printing:
        return '打印中';
      case PrintStatus.completed:
        return '完成';
      case PrintStatus.failed:
        return '失败';
    }
  }

  /// 获取状态显示颜色
  Color get statusColor {
    switch (status) {
      case PrintStatus.pending:
        return Colors.orange;
      case PrintStatus.printing:
        return Colors.blue;
      case PrintStatus.completed:
        return Colors.green;
      case PrintStatus.failed:
        return Colors.red;
    }
  }

  /// 从JSON创建PrintQueueItem实例
  factory PrintQueueItem.fromJson(Map<String, dynamic> json) {
    return PrintQueueItem(
      id: json['id'],
      fileName: json['fileName'],
      printerName: json['printerName'],
      taskData: json['taskData'],
      timestamp: DateTime.parse(json['timestamp']),
      priority: PrintPriority.values.firstWhere(
        (e) => e.toString() == 'PrintPriority.${json['priority']}',
        orElse: () => PrintPriority.medium,
      ),
      status: PrintStatus.values.firstWhere(
        (e) => e.toString() == 'PrintStatus.${json['status']}',
        orElse: () => PrintStatus.pending,
      ),
      errorMessage: json['errorMessage'],
    )..retryCount = json['retryCount'] ?? 0;
  }

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'printerName': printerName,
      'taskData': taskData,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'errorMessage': errorMessage,
      'retryCount': retryCount,
    };
  }
}

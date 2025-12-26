import 'dart:io';
import 'dart:convert';
import 'print_service.dart';
import 'print_queue_manager.dart';
import 'print_queue_item.dart';

class PrintAssistantServer {
  static HttpServer? _server;
  final PrintService _printService = PrintService();
  final PrintQueueManager _queueManager = PrintQueueManager();
  static const int port = 9101;
  // 允许所有来源的跨域请求，更灵活地支持不同环境
  // 允许所有来源的跨域请求，与Python版本保持一致
  static const String allowedOrigin = '*';

  Future<void> start() async {
    // 检查服务器是否已经在运行
    if (_server != null) {
      _printLog('HTTP服务器已在运行，监听端口：$port');
      return;
    }
    
    try {
      // 初始化打印队列管理器
      _printLog('开始初始化打印队列管理器...');
      await _queueManager.init();
      _printLog('打印队列管理器初始化完成');
      
      // 启动HTTP服务器，监听所有网络接口，以便外部访问
      _printLog('开始启动HTTP服务器...');
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _printLog('HTTP服务器已启动，监听地址：${_server!.address}，端口：$port');
      _printLog('本地访问地址：http://localhost:$port');
      _printLog('健康检查：http://localhost:$port/health');
      _printLog('打印机列表：http://localhost:$port/printers');
      _printLog('PDF打印：http://localhost:$port/print/pdf');
      _printLog('RAW打印：http://localhost:$port/print/raw');
      _printLog('ZPL打印：http://localhost:$port/print-zpl');
      _printLog('图像打印：http://localhost:$port/print-image');

      // 处理请求
      _server!.listen((request) {
        _handleRequest(request);
      });
      _printLog('HTTP服务器已准备就绪，等待请求...');
    } catch (e) {
      _printLog('启动HTTP服务器失败：$e');
      _server = null;
      rethrow;
    }
  }

  /// 打印日志，确保在所有环境中都能正确输出
  void _printLog(String message) {
    // 只打印一次，避免重复输出
    print(message);
  }

  Future<void> stop() async {
    if (_server != null) {
      try {
        // 创建一个临时引用，确保即使_server被设置为null，也能正确关闭
        final server = _server;
        _server = null;
        // 关闭服务器，允许现有的连接完成
        await server!.close(force: false);
        print('HTTP服务器已停止');
        // 等待端口释放，增加等待时间到10秒
        await Future.delayed(const Duration(seconds: 10));
      } catch (e) {
        print('停止HTTP服务器失败：$e');
      }
    }
  }
  
  // 检查服务器是否已经在运行
  bool isRunning() {
    return _server != null;
  }
  
  // 强制停止所有服务器实例
  Future<void> forceStopAll() async {
    if (_server != null) {
      try {
        final server = _server;
        _server = null;
        // 强制关闭服务器，立即终止所有连接
        await server!.close(force: true);
        print('HTTP服务器已强制停止');
        // 等待端口释放，增加等待时间到10秒
        await Future.delayed(const Duration(seconds: 10));
      } catch (e) {
        print('强制停止HTTP服务器失败：$e');
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    
    // 记录请求信息，便于调试
    _printLog('收到请求: ${request.method} ${request.uri.path}');
    _printLog('请求来源: ${request.headers.value('origin')}');
    
    // 设置CORS头
    response.headers.add('Access-Control-Allow-Origin', allowedOrigin);
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    // 处理OPTIONS请求（CORS预检）
    if (request.method == 'OPTIONS') {
      _printLog('处理OPTIONS请求，返回204');
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    final path = request.uri.path;
    final method = request.method;

    try {
      if (method == 'GET' && path == '/health') {
        _printLog('处理健康检查请求');
        await _handleHealthCheck(request);
      } else if (method == 'GET' && path == '/printers') {
        _printLog('处理获取打印机列表请求');
        await _handleListPrinters(request);
      } else if (method == 'POST' && path == '/print/pdf') {
        _printLog('处理PDF打印请求');
        await _handlePrintPdf(request);
      } else if (method == 'POST' && path == '/print/raw') {
        _printLog('处理RAW打印请求');
        await _handlePrintRaw(request);
      } else if (method == 'POST' && path == '/print-zpl') {
        _printLog('处理ZPL打印请求');
        await _handlePrintRaw(request);
      } else if (method == 'POST' && path == '/print-image') {
        _printLog('处理图片打印请求');
        await _handlePrintImage(request);
      } else if (method == 'GET' && path == '/medias') {
        _printLog('处理获取纸张尺寸请求');
        await _handleGetMedias(request);
      } else {
        _printLog('处理未知请求: $path');
        await _handleNotFound(request);
      }
    } catch (e) {
      _printLog('处理请求时发生错误: $e');
      await _handleError(request, e);
    }
  }

  Future<void> _handleHealthCheck(HttpRequest request) async {
    final response = request.response;
    final healthInfo = {
      'ok': true,
      'version': '0.2.0', // 修改版本号，用于测试
      'os': Platform.operatingSystem,
      'hostname': Platform.localHostname,
      'test': 'modification test', // 添加测试字段
    };
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(healthInfo));
    await response.close();
  }

  Future<void> _handleListPrinters(HttpRequest request) async {
    final response = request.response;
    final result = await _printService.listPrinters();
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(result));
    await response.close();
  }

  Future<void> _handlePrintPdf(HttpRequest request) async {
    final response = request.response;
    try {
      final bodyBytes = await request.toList();
      final bodyString = String.fromCharCodes(bodyBytes.expand((bytes) => bytes));
      final data = jsonDecode(bodyString);
      
      // 将PDF打印任务添加到打印队列
      final pdfBase64 = data['pdfBase64'];
      final printerName = data['printerName'] ?? '';
      final copies = data['copies'] ?? 1;
      final priorityStr = data['priority'] ?? 'medium';
      PrintPriority priority;
      switch (priorityStr) {
        case 'low':
          priority = PrintPriority.low;
          break;
        case 'high':
          priority = PrintPriority.high;
          break;
        default:
          priority = PrintPriority.medium;
          break;
      }
      
      await _queueManager.addPdfPrintTask(
        pdfBase64,
        printerName: printerName,
        copies: copies,
        priority: priority,
      );
      
      // 与Python版本保持一致的响应格式
      final result = {'ok': true, 'message': 'PDF打印任务已添加到队列'};
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.ok;
      response.write(jsonEncode(result));
    } catch (e) {
      // 与Python版本保持一致的错误响应格式
      final result = {'ok': false, 'message': '添加PDF打印任务失败: $e'};
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode(result));
    } finally {
      await response.close();
    }
  }

  Future<void> _handlePrintRaw(HttpRequest request) async {
    final response = request.response;
    try {
      final bodyBytes = await request.toList();
      final bodyString = String.fromCharCodes(bodyBytes.expand((bytes) => bytes));
      final data = jsonDecode(bodyString);
      
      // 将RAW打印任务添加到打印队列
      final rawData = data['data'];
      final printerName = data['printerName'] ?? '';
      final contentType = data['contentType'] ?? 'RAW';
      final copies = data['copies'] ?? 1;
      final priorityStr = data['priority'] ?? 'medium';
      PrintPriority priority;
      switch (priorityStr) {
        case 'low':
          priority = PrintPriority.low;
          break;
        case 'high':
          priority = PrintPriority.high;
          break;
        default:
          priority = PrintPriority.medium;
          break;
      }
      
      await _queueManager.addRawPrintTask(
        rawData,
        printerName: printerName,
        contentType: contentType,
        copies: copies,
        priority: priority,
      );
      
      // 与Python版本保持一致的响应格式
      final result = {'ok': true, 'message': 'RAW打印任务已添加到队列'};
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.ok;
      response.write(jsonEncode(result));
    } catch (e) {
      // 与Python版本保持一致的错误响应格式
      final result = {'ok': false, 'message': '添加RAW打印任务失败: $e'};
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode(result));
    } finally {
      await response.close();
    }
  }

  Future<void> _handlePrintImage(HttpRequest request) async {
    final response = request.response;
    try {
      final bodyBytes = await request.toList();
      final bodyString = String.fromCharCodes(bodyBytes.expand((bytes) => bytes));
      final data = jsonDecode(bodyString);
      
      // 将图像打印任务添加到打印队列
      final imageBase64 = data['imageBase64'];
      final printerName = data['printerName'] ?? '';
      final copies = data['copies'] ?? 1;
      final priorityStr = data['priority'] ?? 'medium';
      PrintPriority priority;
      switch (priorityStr) {
        case 'low':
          priority = PrintPriority.low;
          break;
        case 'high':
          priority = PrintPriority.high;
          break;
        default:
          priority = PrintPriority.medium;
          break;
      }
      
      // 构建图像打印任务数据
      final imagePrintData = {
        'printerName': printerName,
        'imageBase64': imageBase64,
        'paperWidthMm': data['paperWidthMm'],
        'paperHeightMm': data['paperHeightMm'],
        'paperId': data['paperId'],
        'dpi': data['dpi'],
        'copies': copies,
        'rotate180': data['rotate180'],
      };
      
      // 将图像数据转换为RAW格式任务，以便使用现有队列管理
      // 注意：这里需要调整，因为我们添加了专门的printImage方法
      // 目前先使用RAW打印队列，后续可以考虑添加专门的图像打印队列
      await _queueManager.addRawPrintTask(
        jsonEncode(imagePrintData),
        printerName: printerName,
        contentType: 'IMAGE',
        copies: copies,
        priority: priority,
        additionalData: imagePrintData,
      );
      
      // 与Python版本保持一致的响应格式
      final result = {'ok': true, 'message': '图像打印任务已添加到队列'};
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.ok;
      response.write(jsonEncode(result));
    } catch (e) {
      // 与Python版本保持一致的错误响应格式
      final result = {'ok': false, 'message': '添加图像打印任务失败: $e'};
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode(result));
    } finally {
      await response.close();
    }
  }

  Future<void> _handleGetMedias(HttpRequest request) async {
    final response = request.response;
    try {
      // 获取查询参数
      final queryParams = request.uri.queryParameters;
      final printerName = queryParams['printerName'] ?? '';
      
      // 调用打印服务获取纸张尺寸列表
      final result = await _printService.getMedias(printerName);
      
      // 返回纸张尺寸列表
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.ok;
      response.write(jsonEncode(result));
    } catch (e) {
      // 与Python版本保持一致的错误响应格式
      final result = {'ok': false, 'message': '获取纸张尺寸失败: $e'};
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode(result));
    } finally {
      await response.close();
    }
  }

  Future<void> _handleNotFound(HttpRequest request) async {
    final response = request.response;
    response.statusCode = HttpStatus.notFound;
    response.write(jsonEncode({'ok': false, 'message': 'Not Found'}));
    await response.close();
  }

  Future<void> _handleError(HttpRequest request, dynamic error) async {
    final response = request.response;
    response.statusCode = HttpStatus.internalServerError;
    response.write(jsonEncode({'ok': false, 'message': error.toString()}));
    await response.close();
  }
}

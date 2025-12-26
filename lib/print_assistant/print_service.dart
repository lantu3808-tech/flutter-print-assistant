import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class PrintService {
  static const MethodChannel _channel = MethodChannel('printer_utils');
  /// 打印PDF文件
  Future<Map<String, dynamic>> printPdf(String requestBody) async {
    try {
      // 暂时禁用PDF打印功能，因为我们移除了printing插件依赖
      // 后续可以实现自定义的PDF打印解决方案
      return {'ok': false, 'message': 'PDF打印功能已暂时禁用'};
    } catch (e) {
      return {'ok': false, 'message': 'PDF打印失败: $e'};
    }
  }

  /// 打印RAW数据（ZPL/TSPL/ESC-POS）
  Future<Map<String, dynamic>> printRaw(String requestBody) async {
    try {
      final data = json.decode(requestBody);
      String content = data['data'];
      final printerName = data['printerName'];
      final contentType = data['contentType'] ?? 'RAW';
      final copies = data['copies'] ?? 1;
      final paperWidthMm = data['paperWidthMm'];
      final paperHeightMm = data['paperHeightMm'];
      final paperId = data['paperId'];

      // 处理ZPL内容，添加纸张设置命令
      if (contentType.toUpperCase() == 'ZPL' || content.startsWith('^XA')) {
        if (paperWidthMm != null && paperHeightMm != null) {
          try {
            // 转换为点数（203 DPI）
            final widthDots = (paperWidthMm / 25.4 * 203).toInt();
            final heightDots = (paperHeightMm / 25.4 * 203).toInt();
            
            // 确保ZPL命令格式正确，解决打印位置偏移问题
            if (content.startsWith('^XA')) {
              // 如果已经包含^XA，确保^PW和^LL命令正确设置
              // 先检查是否已经包含^PW和^LL命令
              if (!content.contains('^PW')) {
                // 插入^PW命令
                content = content.replaceFirst('^XA', '^XA^PW$widthDots');
              }
              if (!content.contains('^LL')) {
                // 插入^LL命令
                content = content.replaceFirst('^XA', '^XA^LL$heightDots');
              }
            } else {
              // 添加^XA和纸张设置
              content = '^XA^PW$widthDots^LL$heightDots$content^XZ';
            }
          } catch (e) {
            print('设置ZPL纸张尺寸失败: $e');
          }
        }
      }

      if (Platform.isMacOS) {
        return {'ok': false, 'message': 'MacOS RAW打印功能正在开发中'};
      } else if (Platform.isWindows) {
        try {
          // 实现Windows RAW打印，使用copy命令方式，与旧版本Python打印助手和simple-backend实现一致
          final targetPrinter = printerName ?? '';
          print('开始RAW打印到打印机: $targetPrinter');
          
          // 创建临时文件保存打印数据
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/print_${DateTime.now().millisecondsSinceEpoch}.zpl');
          await tempFile.writeAsString(content, mode: FileMode.write);
          
          // 使用copy命令发送数据到打印机
          final printerPath = '\\\\localhost\\\\$targetPrinter';
          final copyCommand = '/c copy /b "${tempFile.path}" "$printerPath"';
          print('执行打印命令: $copyCommand');
          
          final process = await Process.run(
            'cmd.exe',
            [copyCommand],
            runInShell: true,
          );
          
          // 删除临时文件
          try {
            await tempFile.delete();
          } catch (e) {
            print('删除临时文件失败: $e');
          }
          
          if (process.exitCode != 0) {
            return {'ok': false, 'message': 'RAW打印失败，退出码: ${process.exitCode}, 输出: ${process.stdout}, 错误: ${process.stderr}'};
          }
          
          return {'ok': true, 'message': 'RAW打印成功'};
        } catch (e) {
          return {'ok': false, 'message': 'Windows RAW打印失败: $e'};
        }
      } else {
        return {'ok': false, 'message': '不支持的平台'};
      }
    } catch (e) {
      return {'ok': false, 'message': 'RAW打印失败: $e'};
    }
  }

  /// 打印图像
  Future<Map<String, dynamic>> printImage(String requestBody) async {
    try {
      final data = json.decode(requestBody);
      final printerName = data['printerName'];
      final imageBase64 = data['imageBase64'];
      final paperWidthMm = data['paperWidthMm'];
      final paperHeightMm = data['paperHeightMm'];
      final paperId = data['paperId'];
      // 不设置默认DPI，让C++端使用打印机真实DPI，与Python版本保持一致
      final renderDpi = data['dpi'];
      final copies = data['copies'] ?? 1;
      final rotate180 = data['rotate180'] ?? false;

      print('图像打印请求数据: $data');

      if (Platform.isWindows) {
        try {
          // 解码Base64图像数据
          final imageBytes = base64Decode(imageBase64);
          final image = img.decodeImage(imageBytes);
          if (image == null) {
            return {'ok': false, 'message': '无法解码图像数据'};
          }
          print('图像解码成功，尺寸: ${image.width}x${image.height}');

          // 处理图像旋转和位置调整
          img.Image processedImage = image;
          if (rotate180) {
            processedImage = img.copyRotate(image, angle: 180);
            print('图像旋转180度');
          }

          // 保存图像到临时文件，使用唯一文件名
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/temp_print_image_${DateTime.now().millisecondsSinceEpoch}.png');
          await tempFile.writeAsBytes(img.encodePng(processedImage));
          print('图像保存到临时文件: ${tempFile.path}');
          
          // 保存一份到打印助手文件夹，以便检查
          try {
            final appDir = Directory.current;
            final saveFile = File('${appDir.path}/print_preview_${DateTime.now().millisecondsSinceEpoch}.png');
            await saveFile.writeAsBytes(img.encodePng(processedImage));
            print('图像保存到打印助手文件夹: ${saveFile.path}');
          } catch (e) {
            print('保存预览图像失败: $e');
          }

          // 调用C++端的PrintImage函数，这是旧版本常用的可靠方法
          final targetPrinter = printerName ?? '';
          print('开始图像打印到打印机: $targetPrinter');
          
          try {
            // 调用C++端的PrintImage函数，传递更多参数以实现正确的缩放
            final bool success = await _channel.invokeMethod('printImage', {
              'printerName': targetPrinter,
              'imagePath': tempFile.path,
              'dpi': renderDpi,
              'paperWidthMm': paperWidthMm,
              'paperHeightMm': paperHeightMm,
              'paperId': paperId,
              'copies': copies,
            });
            
            print('Windows原生API打印结果: $success');
            
            // 清理临时文件
            try {
              await tempFile.delete();
              print('临时文件已删除: ${tempFile.path}');
            } catch (e) {
              print('删除临时文件失败: $e');
            }
            
            if (success) {
              return {'ok': true, 'message': '图像打印成功'};
            } else {
              return {'ok': false, 'message': 'Windows原生API打印失败'};
            }
          } catch (e) {
            print('调用Windows原生API失败: $e');
            
            // 清理临时文件
            try {
              await tempFile.delete();
              print('临时文件已删除: ${tempFile.path}');
            } catch (deleteError) {
              print('删除临时文件失败: $deleteError');
            }
            
            return {'ok': false, 'message': '调用Windows原生API打印失败: $e'};
          }
        } catch (e, stackTrace) {
          print('Windows图像打印异常: $e, 堆栈: $stackTrace');
          return {'ok': false, 'message': 'Windows图像打印失败: $e'};
        }
      } else {
        return {'ok': false, 'message': '不支持的平台'};
      }
    } catch (e, stackTrace) {
      print('图像打印请求处理异常: $e, 堆栈: $stackTrace');
      return {'ok': false, 'message': '图像打印失败: $e'};
    }
  }

  /// 获取打印机列表
  Future<Map<String, dynamic>> listPrinters() async {
    try {
      if (Platform.isWindows) {
        // 调用C++端的listPrinters方法获取打印机列表
        final List<dynamic> result = await _channel.invokeMethod('listPrinters');
        
        // 转换为需要的格式
        List<Map<String, dynamic>> printers = [];
        for (var printer in result) {
          if (printer is Map<dynamic, dynamic>) {
            printers.add({
              'name': printer['name'] as String,
              'displayName': printer['displayName'] as String,
              'portName': printer['portName'] as String,
              'status': printer['status'] as int,
            });
          }
        }
        
        print('获取到打印机列表: $printers');
        return {
          'ok': true,
          'printers': printers,
        };
      } else {
        return {
          'ok': false,
          'message': '不支持的平台',
          'printers': [],
        };
      }
    } catch (e) {
      print('获取打印机列表失败: $e');
      return {
        'ok': false,
        'message': '获取打印机列表失败: $e',
        'printers': [],
      };
    }
  }

  /// 获取纸张尺寸列表，使用PowerShell调用System.Drawing.PrintDocument获取真实纸张，与Python版本实现一致
  Future<Map<String, dynamic>> getMedias(String printerName) async {
    try {
      List<Map<String, dynamic>> medias = [];
      List<Map<String, dynamic>> papersDetailed = [];
      List<Map<String, dynamic>> formsDetailed = [];
      
      print('获取纸张尺寸，打印机名称: $printerName');
      
      if (Platform.isWindows) {
        try {
          // 使用MethodChannel调用Windows原生代码获取纸张尺寸
          final List<dynamic> result = await _channel.invokeMethod('getPaperSizes', {
            'printerName': printerName,
          });
          
          print('Windows原生API返回纸张数量: ${result.length}');
          
          for (var paper in result) {
            try {
              final name = paper['name'] as String;
              // width和height是1/10毫米单位
              final widthTenthMm = paper['width'] as int;
              final heightTenthMm = paper['height'] as int;
              final paperId = paper['id'] as int;
              
              // 转换为毫米（除以10）
              final widthMm = (widthTenthMm / 10).roundToDouble();
              final heightMm = (heightTenthMm / 10).roundToDouble();
              
              // 生成友好的纸张名称
              final friendlyName = "$widthMm×$heightMm mm";
              
              print('处理纸张: $name -> $friendlyName, 宽度: $widthMm mm, 高度: $heightMm mm, ID: $paperId');
              
              // 计算像素尺寸（96 DPI）
              final widthPx = (widthMm / 25.4 * 96).round();
              final heightPx = (heightMm / 25.4 * 96).round();
              
              medias.add({
                'name': friendlyName,
                'displayName': name,
                'width_mm': widthMm,
                'height_mm': heightMm,
                'width': widthPx,
                'height': heightPx,
                'id': paperId,
                'paper_id': paperId, // 兼容旧版打印助手格式
                'paperId': paperId, // 兼容旧版打印助手格式
              });
            } catch (e) {
              print('处理纸张失败: $e, 纸张数据: $paper');
              // 跳过处理失败的纸张
              continue;
            }
          }
        } catch (e) {
          print('调用Windows原生API失败: $e');
        }
      }
      
      papersDetailed = medias;
      
      // 去重，避免重复的纸张尺寸，使用displayName作为唯一标识
      final seenDisplayNames = <String>{};
      final uniqueMedias = medias.where((paper) {
        final displayName = paper['displayName'] as String;
        // 修复乱码问题，确保中文显示正常
        return seenDisplayNames.add(displayName);
      }).toList();
      
      // 生成简化的纸张名称列表，使用displayName显示快递名称
      final simplifiedMedias = uniqueMedias.map((paper) {
        return paper['displayName'];
      }).toList();
      
      print('最终纸张列表: $simplifiedMedias');
      print('纸张详细信息: ${uniqueMedias.map((p) => p['displayName']).toList()}');
      
      // 设置默认纸张，仅使用真实获取到的纸张
      final defaultMedia = uniqueMedias.isNotEmpty ? uniqueMedias[0] : {'name': '', 'displayName': '', 'width_mm': 0, 'height_mm': 0};
      
      return {
        'ok': true,
        'medias': simplifiedMedias,
        'defaultMedia': defaultMedia['displayName'],
        'defaultMediaDetailed': defaultMedia,
        'papersDetailed': uniqueMedias,
        'formsDetailed': formsDetailed,
        'supportCustom': true,
        'success': true,
        'printer': printerName,
      };
    } catch (e) {
      print('获取纸张尺寸失败: $e');
      return {
        'ok': false,
        'message': '获取纸张尺寸失败: $e',
        'medias': [],
        'defaultMedia': '',
        'defaultMediaDetailed': {},
        'papersDetailed': [],
        'formsDetailed': [],
        'supportCustom': true,
        'success': false,
        'printer': printerName,
      };
    }
  }
}
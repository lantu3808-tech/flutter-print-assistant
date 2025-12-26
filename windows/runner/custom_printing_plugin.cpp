// Custom printing plugin for image printing only, no PDFium dependency
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <winspool.h>
#include <wingdi.h>
#include <gdiplus.h>

#include <memory>
#include <vector>
#include <string>
#include <algorithm>

using namespace Gdiplus;
#pragma comment(lib, "gdiplus.lib")

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

using flutter::EncodableMap;
using flutter::EncodableList;
using flutter::EncodableValue;

// Helper function to convert std::string to std::wstring
std::wstring StringToWString(const std::string& str) {
  int bufferSize = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, NULL, 0);
  std::wstring wstr(bufferSize, 0);
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &wstr[0], bufferSize);
  wstr.resize(bufferSize - 1);
  return wstr;
}

// Helper function to list all printers
EncodableList ListPrinters() {
  EncodableList printers;
  
  printf("ListPrinters function called\n");
  
  DWORD bytesNeeded = 0;
  DWORD printerCount = 0;
  DWORD flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
  
  // Try to get printer count and buffer size using level 4 (simplest structure)
  printf("EnumPrintersW: first call with NULL buffer, level 4\n");
  BOOL result = EnumPrintersW(
      flags,
      NULL,
      4,  // Level 4 - minimal information
      NULL,
      0,
      &bytesNeeded,
      &printerCount);
  
  printf("First call result: %d, bytesNeeded: %lu, printerCount: %lu, error: %lu\n", 
         result, bytesNeeded, printerCount, GetLastError());
  
  if (bytesNeeded == 0) {
    printf("No printers found or error occurred\n");
    return printers;
  }
  
  // Allocate buffer
  auto buffer = std::make_unique<BYTE[]>(bytesNeeded);
  
  // Call EnumPrintersW again with the buffer
  printf("EnumPrintersW: second call with buffer, level 4\n");
  result = EnumPrintersW(
      flags,
      NULL,
      4,
      buffer.get(),
      bytesNeeded,
      &bytesNeeded,
      &printerCount);
  
  printf("Second call result: %d, error: %lu\n", result, GetLastError());
  printf("Found %lu printers\n", printerCount);
  
  if (!result) {
    printf("EnumPrintersW failed: %lu\n", GetLastError());
    return printers;
  }
  
  // Process printer information
  PRINTER_INFO_4W* printerInfo = reinterpret_cast<PRINTER_INFO_4W*>(buffer.get());
  for (DWORD i = 0; i < printerCount; i++) {
    printf("Printer %lu: name=%ls, attributes=0x%x\n", 
           i, printerInfo[i].pPrinterName, printerInfo[i].Attributes);
    
    EncodableMap printerItem;
    
    // Convert printer name to UTF-8 string
    std::wstring printerNameW = printerInfo[i].pPrinterName;
    int utf8Len = WideCharToMultiByte(CP_UTF8, 0, printerNameW.c_str(), -1, NULL, 0, NULL, NULL);
    std::string printerNameA(utf8Len - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, printerNameW.c_str(), -1, &printerNameA[0], utf8Len, NULL, NULL);
    
    // Add printer information
    printerItem[EncodableValue("name")] = EncodableValue(printerNameA);
    printerItem[EncodableValue("displayName")] = EncodableValue(printerNameA);
    printerItem[EncodableValue("portName")] = EncodableValue(std::string()); // Level 4 doesn't provide port
    printerItem[EncodableValue("status")] = EncodableValue(0); // Level 4 doesn't provide status
    
    printers.push_back(printerItem);
  }
  
  printf("Total printers added to list: %llu\n", printers.size());
  return printers;
}

// Helper function to get paper sizes
EncodableList GetPaperSizes(const std::wstring& printerName) {
  EncodableList result;

  HANDLE hPrinter = nullptr;
  if (!OpenPrinterW(const_cast<LPWSTR>(printerName.c_str()), &hPrinter, nullptr)) {
    return result;
  }

  DWORD needed = 0;
  GetPrinterW(hPrinter, 2, nullptr, 0, &needed);

  auto buffer = std::make_unique<BYTE[]>(needed);
  if (!GetPrinterW(hPrinter, 2, buffer.get(), needed, &needed)) {
    ClosePrinter(hPrinter);
    return result;
  }

  auto info = reinterpret_cast<PRINTER_INFO_2W*>(buffer.get());
  std::wstring portName = info->pPortName;

  int paperCount = DeviceCapabilitiesW(
      printerName.c_str(),
      portName.c_str(),
      DC_PAPERS,
      nullptr,
      nullptr);

  if (paperCount <= 0) {
    ClosePrinter(hPrinter);
    return result;
  }

  int nameCount = DeviceCapabilitiesW(
      printerName.c_str(),
      portName.c_str(),
      DC_PAPERNAMES,
      nullptr,
      nullptr);

  int sizeCount = DeviceCapabilitiesW(
      printerName.c_str(),
      portName.c_str(),
      DC_PAPERSIZE,
      nullptr,
      nullptr);

  int actualCount = std::min(std::min(paperCount, nameCount), sizeCount);

  if (actualCount <= 0) {
    ClosePrinter(hPrinter);
    return result;
  }

  std::vector<WORD> paperIds(paperCount);
  std::vector<wchar_t> paperNames(nameCount * 64);
  std::vector<POINT> paperSizes(sizeCount);

  DeviceCapabilitiesW(
      printerName.c_str(),
      portName.c_str(),
      DC_PAPERS,
      (LPWSTR)paperIds.data(),
      nullptr);

  DeviceCapabilitiesW(
      printerName.c_str(),
      portName.c_str(),
      DC_PAPERNAMES,
      paperNames.data(),
      nullptr);

  DeviceCapabilitiesW(
      printerName.c_str(),
      portName.c_str(),
      DC_PAPERSIZE,
      (LPWSTR)paperSizes.data(),
      nullptr);

  for (int i = 0; i < actualCount; i++) {
    EncodableMap item;
    
    item[EncodableValue("id")] = EncodableValue((int)paperIds[i]);
    
    std::wstring paperNameW(&paperNames[i * 64]);
    int bufferSize = WideCharToMultiByte(CP_UTF8, 0, paperNameW.c_str(), -1, NULL, 0, NULL, NULL);
    std::string paperNameA(bufferSize, 0);
    WideCharToMultiByte(CP_UTF8, 0, paperNameW.c_str(), -1, &paperNameA[0], bufferSize, NULL, NULL);
    paperNameA.resize(bufferSize - 1);
    
    item[EncodableValue("name")] = EncodableValue(paperNameA);
    
    item[EncodableValue("width")] = EncodableValue(paperSizes[i].x);
    item[EncodableValue("height")] = EncodableValue(paperSizes[i].y);

    result.push_back(item);
  }

  ClosePrinter(hPrinter);
  return result;
}

// Implement Windows API printing functionality exactly like Python version
bool PrintImage(const std::wstring& printerName, const std::wstring& imagePath, 
                int dpi = 203, int paperWidthMm = 0, int paperHeightMm = 0, 
                int paperId = 0, int copies = 1) {
  printf("Printing image using Windows API - Exact match to Python version\n");
  printf("Printer name: %ls\n", printerName.c_str());
  printf("Image path: %ls\n", imagePath.c_str());
  printf("DPI: %d, Paper Width: %d mm, Paper Height: %d mm, Paper ID: %d, Copies: %d\n", 
         dpi, paperWidthMm, paperHeightMm, paperId, copies);
  
  BOOL success = FALSE;
  
  // If paper ID is provided, set it as default paper for the printer
  if (paperId > 0) {
    printf("Setting printer paper ID: %d\n", paperId);
    HANDLE hPrinter = NULL;
    if (OpenPrinterW(const_cast<LPWSTR>(printerName.c_str()), &hPrinter, NULL)) {
      DWORD needed = 0;
      GetPrinterW(hPrinter, 2, NULL, 0, &needed);
      if (needed > 0) {
        auto buffer = std::make_unique<BYTE[]>(needed);
        PRINTER_INFO_2W* printerInfo = reinterpret_cast<PRINTER_INFO_2W*>(buffer.get());
        if (GetPrinterW(hPrinter, 2, buffer.get(), needed, &needed)) {
          DEVMODEW* devMode = printerInfo->pDevMode;
          if (devMode) {
            devMode->dmPaperSize = static_cast<short>(paperId);
            devMode->dmFields |= DM_PAPERSIZE;
            if (SetPrinterW(hPrinter, 2, buffer.get(), 0)) {
              printf("Successfully set printer paper ID: %d\n", paperId);
            } else {
              printf("Failed to set printer paper: %lu\n", GetLastError());
            }
          }
        }
      }
      ClosePrinter(hPrinter);
    } else {
      printf("Failed to open printer for paper setting: %lu\n", GetLastError());
    }
  }
  
  // Open printer to get its DEVMODE - this is what Python's win32ui.CreateDC() does internally
  HANDLE hPrinter = NULL;
  if (!OpenPrinterW(const_cast<LPWSTR>(printerName.c_str()), &hPrinter, NULL)) {
    printf("OpenPrinterW failed with error code: %lu\n", GetLastError());
    return false;
  }
  
  // Get printer info to access DEVMODE
  DWORD needed = 0;
  GetPrinterW(hPrinter, 2, NULL, 0, &needed);
  if (needed == 0) {
    printf("GetPrinterW failed to get needed size: %lu\n", GetLastError());
    ClosePrinter(hPrinter);
    return false;
  }
  
  auto printerInfoBuffer = std::make_unique<BYTE[]>(needed);
  PRINTER_INFO_2W* printerInfo = reinterpret_cast<PRINTER_INFO_2W*>(printerInfoBuffer.get());
  
  if (!GetPrinterW(hPrinter, 2, printerInfoBuffer.get(), needed, &needed)) {
    printf("GetPrinterW failed to get printer info: %lu\n", GetLastError());
    ClosePrinter(hPrinter);
    return false;
  }
  
  // Get DEVMODE from printer info
  DEVMODEW* devMode = printerInfo->pDevMode;
  if (!devMode) {
    printf("No DEVMODE available for printer\n");
    ClosePrinter(hPrinter);
    return false;
  }
  
  // Create printer DC using the printer's DEVMODE - EXACTLY like Python's win32ui.CreateDC().CreatePrinterDC()
  HDC hPrinterDC = CreateDCW(L"WINSPOOL", printerName.c_str(), NULL, devMode);
  if (!hPrinterDC) {
    printf("CreateDCW failed with error code: %lu\n", GetLastError());
    ClosePrinter(hPrinter);
    return false;
  }
  
  // Get printer DPI - same as Python's GetDeviceCaps(LOGPIXELSX/Y)
  int printerDpiX = GetDeviceCaps(hPrinterDC, LOGPIXELSX);
  int printerDpiY = GetDeviceCaps(hPrinterDC, LOGPIXELSY);
  printf("Printer DPI: %d x %d\n", printerDpiX, printerDpiY);
  
  // Use Java render DPI if provided, otherwise use printer DPI - exact match to Python
  int usedDpiX = (dpi > 0) ? dpi : printerDpiX;
  int usedDpiY = (dpi > 0) ? dpi : printerDpiY;
  printf("Using DPI: %d x %d\n", usedDpiX, usedDpiY);
  
  // Overall scale factor - exact match to Python's overall_scale = 1.0
  // IMPORTANT: This must match the Python version exactly
  float overallScale = 1.0f;
  printf("Overall scale: %.2f\n", overallScale);
  
  // Close the printer handle since we don't need it anymore
  ClosePrinter(hPrinter);
  
  // Initialize GDI+ for image processing
  Gdiplus::GdiplusStartupInput gdiplusStartupInput;
  ULONG_PTR gdiplusToken;
  Gdiplus::Status gdiplusStatus = Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
  if (gdiplusStatus != Gdiplus::Ok) {
    printf("GdiplusStartup failed with status: %d\n", gdiplusStatus);
    DeleteDC(hPrinterDC);
    return false;
  }
  
  // Load image - same as Python's Image.open()
  Gdiplus::Bitmap* originalBitmap = Gdiplus::Bitmap::FromFile(imagePath.c_str());
  if (!originalBitmap) {
    printf("Failed to load image\n");
    Gdiplus::GdiplusShutdown(gdiplusToken);
    DeleteDC(hPrinterDC);
    return false;
  }
  
  int imageWidth = originalBitmap->GetWidth();
  int imageHeight = originalBitmap->GetHeight();
  printf("Image dimensions: %d x %d\n", imageWidth, imageHeight);
  
  int printWidth, printHeight;
  
  // Calculate print area exactly like Python
  if (paperWidthMm > 0 && paperHeightMm > 0) {
    // Convert mm to inches, then to pixels, applying overall scale - exact match to Python
    // Formula: print_width = int(paper_width_mm / 25.4 * dpi_x * overall_scale)
    printWidth = (int)((float)paperWidthMm / 25.4f * usedDpiX * overallScale);
    printHeight = (int)((float)paperHeightMm / 25.4f * usedDpiY * overallScale);
    printf("Paper size: %d×%dmm = %d×%dpx (scale: %.2fx)\n", 
           paperWidthMm, paperHeightMm, printWidth, printHeight, overallScale);
  } else {
    // If no paper size provided, use original image dimensions with scaling - exact match to Python
    printWidth = (int)(imageWidth * overallScale);
    printHeight = (int)(imageHeight * overallScale);
    printf("No paper size specified, using image dimensions: %d×%dpx (scale: %.2fx)\n", 
           printWidth, printHeight, overallScale);
  }
  
  // Print position offset exactly like Python
  // IMPORTANT: This matches the Python version's offset values
  float offsetXmm = 0.0f; // Horizontal offset: 0mm, exact match to Python
  float offsetYmm = 0.5f;  // Vertical offset: 0.5mm, exact match to Python
  
  // Convert mm to pixels - exact match to Python's calculation
  // Formula: x = int(offset_x_mm / 25.4 * dpi_x)
  int x = (int)((float)offsetXmm / 25.4f * usedDpiX);
  int y = (int)((float)offsetYmm / 25.4f * usedDpiY);
  
  printf("Print position: %d, %d\n", x, y);
  printf("Print area: %d x %d\n", printWidth, printHeight);
  
  // Create scaled image - EXACTLY like Python's scaled_image = image.resize((print_width, print_height), Image.Resampling.LANCZOS)
    // LANCZOS is similar to InterpolationModeHighQualityBicubic but with more advanced filtering
    Gdiplus::Bitmap* scaledBitmap = new Gdiplus::Bitmap(printWidth, printHeight, PixelFormat24bppRGB);
    Gdiplus::Graphics* scaleGraphics = Gdiplus::Graphics::FromImage(scaledBitmap);
    // Use InterpolationModeHighQualityBicubic with additional settings to match LANCZOS quality
    scaleGraphics->SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
    scaleGraphics->SetSmoothingMode(Gdiplus::SmoothingModeNone); // LANCZOS doesn't do smoothing
    scaleGraphics->SetCompositingMode(Gdiplus::CompositingModeSourceOver);
    scaleGraphics->SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf); // This helps with sharpness
    scaleGraphics->SetCompositingQuality(Gdiplus::CompositingQualityHighSpeed); // No need for high quality compositing since we're drawing directly
    scaleGraphics->DrawImage(originalBitmap, 0, 0, printWidth, printHeight);
    delete scaleGraphics;
    
    // No need for separate rotated bitmap - we'll handle rotation during pixel access
  
  // Start print job - same as Python's hDC.StartDoc()
  DOCINFO di;
  memset(&di, 0, sizeof(DOCINFO));
  di.cbSize = sizeof(DOCINFO);
  di.lpszDocName = L"Label Print Job";
  di.lpszOutput = NULL;
  di.lpszDatatype = NULL;
  
  int startDocResult = StartDoc(hPrinterDC, &di);
  if (startDocResult <= 0) {
    printf("StartDoc failed with error code: %lu\n", GetLastError());
    delete scaledBitmap;
    delete originalBitmap;
    Gdiplus::GdiplusShutdown(gdiplusToken);
    DeleteDC(hPrinterDC);
    return false;
  }
  
  printf("Print job started, job ID: %d\n", startDocResult);
  
  BOOL allCopiesSuccess = TRUE;
  for (int copyIndex = 0; copyIndex < copies; copyIndex++) {
    printf("Printing copy %d/%d\n", copyIndex + 1, copies);
    
    if (!StartPage(hPrinterDC)) {
      printf("StartPage failed with error code: %lu\n", GetLastError());
      allCopiesSuccess = FALSE;
      break;
    }
    
    // Get the image data from the scaled bitmap - this is what Python's ImageWin.Dib does
    BITMAPINFO bmi;
    memset(&bmi, 0, sizeof(BITMAPINFO));
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = printWidth;
    bmi.bmiHeader.biHeight = -printHeight; // Negative for top-down bitmap, same as PIL's ImageWin.Dib
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 24;
    bmi.bmiHeader.biCompression = BI_RGB;
    
    // Lock the scaled bitmap bits to get the pixel data
    Gdiplus::BitmapData bmpData;
    Gdiplus::Rect rect(0, 0, printWidth, printHeight);
    Gdiplus::Status lockStatus = scaledBitmap->LockBits(&rect, Gdiplus::ImageLockModeRead, PixelFormat24bppRGB, &bmpData);
    if (lockStatus != Gdiplus::Ok) {
        printf("Failed to lock bitmap bits: %d\n", lockStatus);
        allCopiesSuccess = FALSE;
        EndPage(hPrinterDC);
        break;
    }
    
    // Create a buffer to hold the rotated image data (180 degrees clockwise)
    BYTE* rotatedData = new BYTE[bmpData.Stride * printHeight];
    
    // Fix left-right mirroring issue
    // Only perform horizontal flip on each row, no vertical flip
    // This corrects the mirroring problem while maintaining orientation
    for (int yRow = 0; yRow < printHeight; yRow++) {
        BYTE* srcRow = (BYTE*)bmpData.Scan0 + yRow * bmpData.Stride;
        BYTE* destRow = rotatedData + yRow * bmpData.Stride;
        
        // Flip each row horizontally to fix mirroring
        for (int xCol = 0; xCol < printWidth; xCol++) {
            // Source column is from left to right
            int srcX = xCol;
            int srcPos = srcX * 3;
            // Destination column is from right to left (horizontal flip)
            int destPos = (printWidth - 1 - xCol) * 3;
            
            // Copy the pixels with horizontal flip to fix mirroring
            destRow[destPos] = srcRow[srcPos];       // Red
            destRow[destPos + 1] = srcRow[srcPos + 1]; // Green
            destRow[destPos + 2] = srcRow[srcPos + 2]; // Blue
        }
    }
    
    // Use SetDIBitsToDevice to draw the rotated image directly to the printer DC
    BOOL drawResult = SetDIBitsToDevice(
        hPrinterDC,
        x, y,                 // Destination x, y
        printWidth, printHeight,  // Destination width, height
        0, 0,                 // Source x, y
        0,                    // Start scan line
        printHeight,          // Number of scan lines
        rotatedData,          // Pointer to rotated pixel data
        &bmi,                 // Pointer to bitmap info
        DIB_RGB_COLORS        // Color table type
    );
    
    // Free the rotated image data buffer
    delete[] rotatedData;
    
    // Unlock the bitmap bits
    scaledBitmap->UnlockBits(&bmpData);
    
    if (!drawResult) {
        printf("SetDIBitsToDevice failed with error code: %lu\n", GetLastError());
        allCopiesSuccess = FALSE;
        EndPage(hPrinterDC);
        break;
    }
    
    if (!EndPage(hPrinterDC)) {
      printf("EndPage failed with error code: %lu\n", GetLastError());
      allCopiesSuccess = FALSE;
      break;
    }
  }
  
  if (!EndDoc(hPrinterDC)) {
    printf("EndDoc failed with error code: %lu\n", GetLastError());
    allCopiesSuccess = FALSE;
  }
  
  // Clean up resources
  delete scaledBitmap;
  delete originalBitmap;
  Gdiplus::GdiplusShutdown(gdiplusToken);
  DeleteDC(hPrinterDC);
  
  if (allCopiesSuccess) {
    printf("Print job completed successfully\n");
    success = TRUE;
  } else {
    printf("Print job failed\n");
    success = FALSE;
  }
  
  return success;
}

// Function to register the custom printing channel
void RegisterCustomPrintingChannel(flutter::FlutterEngine* engine) {
  if (!engine) {
    return;
  }

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(),
      "printer_utils",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getPaperSizes") {
          const auto* args = 
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("printerName"));
            if (it != args->end()) {
              const auto& printerNameValue = it->second;
              const auto* printerNameStr = std::get_if<std::string>(&printerNameValue);
              if (printerNameStr) {
                std::wstring printerNameW = StringToWString(*printerNameStr);
                result->Success(
                    flutter::EncodableValue(GetPaperSizes(printerNameW)));
                return;
              }
            }
          }
          result->Error("invalid_args", "Invalid arguments");
        } else if (call.method_name() == "listPrinters") {
          // Handle listPrinters method call - no arguments needed
          result->Success(flutter::EncodableValue(ListPrinters()));
          return;
        } else if (call.method_name() == "printImage") {
          const auto* args = 
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto printerIt = args->find(flutter::EncodableValue("printerName"));
            auto imagePathIt = args->find(flutter::EncodableValue("imagePath"));
            
            if (printerIt != args->end() && imagePathIt != args->end()) {
              const auto* printerNameStr = std::get_if<std::string>(&printerIt->second);
              const auto* imagePathStr = std::get_if<std::string>(&imagePathIt->second);
              
              if (printerNameStr && imagePathStr) {
                int dpi = 203;
                int paperWidthMm = 0;
                int paperHeightMm = 0;
                int paperId = 0;
                int copies = 1;
                
                auto dpiIt = args->find(flutter::EncodableValue("dpi"));
                if (dpiIt != args->end()) {
                  const auto* dpiValue = std::get_if<int>(&dpiIt->second);
                  if (dpiValue) {
                    dpi = *dpiValue;
                  }
                }
                
                auto paperWidthIt = args->find(flutter::EncodableValue("paperWidthMm"));
                if (paperWidthIt != args->end()) {
                  const auto* widthValue = std::get_if<int>(&paperWidthIt->second);
                  if (widthValue) {
                    paperWidthMm = *widthValue;
                  }
                }
                
                auto paperHeightIt = args->find(flutter::EncodableValue("paperHeightMm"));
                if (paperHeightIt != args->end()) {
                  const auto* heightValue = std::get_if<int>(&paperHeightIt->second);
                  if (heightValue) {
                    paperHeightMm = *heightValue;
                  }
                }
                
                auto paperIdIt = args->find(flutter::EncodableValue("paperId"));
                if (paperIdIt != args->end()) {
                  const auto* idValue = std::get_if<int>(&paperIdIt->second);
                  if (idValue) {
                    paperId = *idValue;
                  }
                }
                
                auto copiesIt = args->find(flutter::EncodableValue("copies"));
                if (copiesIt != args->end()) {
                  const auto* copiesValue = std::get_if<int>(&copiesIt->second);
                  if (copiesValue) {
                    copies = *copiesValue;
                  }
                }
                
                std::wstring printerNameW = StringToWString(*printerNameStr);
                std::wstring imagePathW = StringToWString(*imagePathStr);
                
                bool success = PrintImage(printerNameW, imagePathW, dpi, paperWidthMm, paperHeightMm, paperId, copies);
                result->Success(flutter::EncodableValue(success));
                return;
              }
            }
          }
          result->Error("invalid_args", "Invalid arguments for printImage");
        } else {
          result->NotImplemented();
        }
      });
}
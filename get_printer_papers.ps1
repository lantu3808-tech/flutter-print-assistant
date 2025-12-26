param([string]$PrinterName)

# 按照旧版本Python应用的方式获取打印机纸张尺寸
# 使用winspool.drv中的DeviceCapabilities函数

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class Win32PrintHelper {
    [DllImport("winspool.drv", CharSet = CharSet.Unicode)]
    public static extern int DeviceCapabilities(
        string lpDeviceName,
        string lpPort,
        int iIndex,
        IntPtr lpOutput,
        IntPtr devMode
    );

    [DllImport("winspool.drv", CharSet = CharSet.Unicode)]
    public static extern int DeviceCapabilities(
        string lpDeviceName,
        string lpPort,
        int iIndex,
        StringBuilder lpOutput,
        IntPtr devMode
    );

    [DllImport("winspool.drv", CharSet = CharSet.Unicode)]
    public static extern int DeviceCapabilities(
        string lpDeviceName,
        string lpPort,
        int iIndex,
        [Out] short[] lpOutput,
        IntPtr devMode
    );

    [DllImport("winspool.drv", CharSet = CharSet.Unicode)]
    public static extern int OpenPrinter(
        string pPrinterName,
        out IntPtr phPrinter,
        IntPtr pDefault
    );

    [DllImport("winspool.drv", CharSet = CharSet.Unicode)]
    public static extern int ClosePrinter(
        IntPtr hPrinter
    );

    [DllImport("winspool.drv", CharSet = CharSet.Unicode)]
    public static extern int GetPrinter(
        IntPtr hPrinter,
        int Level,
        IntPtr pPrinter,
        int cbBuf,
        out int pcbNeeded
    );

    // 常量定义
    public const int DC_PAPERNAMES = 16;
    public const int DC_PAPERSIZE = 3;
    public const int DC_PAPERS = 2;
    public const int PRINTER_DEFAULTS_SIZE = 12;
}
"@

# 获取打印机信息，包括端口名称
$printer = Get-WmiObject -Class Win32_Printer -Filter "Name='$PrinterName'" -ErrorAction Stop
$portName = $printer.PortName

# 常量定义
$DC_PAPERNAMES = 16
$DC_PAPERSIZE = 3
$DC_PAPERS = 2

# 1. 获取纸张ID数量
$paperCount = [Win32PrintHelper]::DeviceCapabilities($PrinterName, $portName, $DC_PAPERS, [IntPtr]::Zero, [IntPtr]::Zero)

if ($paperCount -le 0) {
    Write-Output "[]"
    exit 0
}

# 2. 获取纸张ID列表
$paperIds = New-Object short[] $paperCount
$null = [Win32PrintHelper]::DeviceCapabilities($PrinterName, $portName, $DC_PAPERS, $paperIds, [IntPtr]::Zero)

# 3. 获取纸张尺寸列表
$paperSizes = New-Object short[] ($paperCount * 2)
$null = [Win32PrintHelper]::DeviceCapabilities($PrinterName, $portName, $DC_PAPERSIZE, $paperSizes, [IntPtr]::Zero)

# 4. 获取纸张名称
$nameBufferSize = [Win32PrintHelper]::DeviceCapabilities($PrinterName, $portName, $DC_PAPERNAMES, [IntPtr]::Zero, [IntPtr]::Zero)
$nameBuffer = New-Object System.Text.StringBuilder $nameBufferSize
$null = [Win32PrintHelper]::DeviceCapabilities($PrinterName, $portName, $DC_PAPERNAMES, $nameBuffer, [IntPtr]::Zero)
$rawNames = $nameBuffer.ToString().Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries)

# 5. 组合结果
$papers = @()
for ($i = 0; $i -lt $paperCount; $i++) {
    $name = $rawNames[$i].Trim()
    $width = $paperSizes[$i * 2]  # 0.1mm单位
    $height = $paperSizes[$i * 2 + 1]  # 0.1mm单位
    $paperId = $paperIds[$i]
    
    # 转换为毫米
    $widthMm = [math]::Round($width / 10, 1)
    $heightMm = [math]::Round($height / 10, 1)
    
    # 生成友好名称
    $friendlyName = "$widthMm×$heightMm mm"
    
    $papers += @{
        name = $friendlyName
        displayName = $name
        width_mm = $widthMm
        height_mm = $heightMm
        width = $width
        height = $height
        id = $paperId
    }
}

# 6. 去重
$uniquePapers = $papers | Sort-Object -Property name -Unique

# 7. 输出JSON
ConvertTo-Json $uniquePapers -Compress

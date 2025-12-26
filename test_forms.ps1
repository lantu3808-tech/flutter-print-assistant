param([string]$PrinterName)

Write-Host "Getting paper sizes for printer: $PrinterName"

# 直接使用更简单的方法，避免复杂的嵌套结构

# 1. 导入System.Drawing
Add-Type -AssemblyName System.Drawing

# 2. 创建PrintDocument
$printDoc = New-Object System.Drawing.Printing.PrintDocument
$printDoc.PrinterSettings.PrinterName = $PrinterName

# 3. 检查打印机是否有效
if (-not $printDoc.PrinterSettings.IsValid) {
    Write-Host "Invalid printer"
    ConvertTo-Json @()
    exit 0
}

# 4. 获取纸张尺寸
$paperSizes = $printDoc.PrinterSettings.PaperSizes
Write-Host "Found $($paperSizes.Count) paper sizes"

# 5. 准备结果列表
$formsList = @()

# 6. 处理每个纸张
foreach ($ps in $paperSizes) {
    if ($ps.Width -gt 0 -and $ps.Height -gt 0) {
        # 转换为毫米：0.01英寸 = 0.254毫米
        $widthMm = [math]::Round($ps.Width * 0.254, 1)
        $heightMm = [math]::Round($ps.Height * 0.254, 1)
        
        # 生成友好名称
        $name = "$widthMm×$heightMm mm"
        
        # 添加到列表
        $formsList += @{
            name = $name
            displayName = $ps.PaperName
            width_mm = $widthMm
            height_mm = $heightMm
            width = $ps.Width
            height = $ps.Height
            id = $ps.Kind
        }
        
        Write-Host "Added paper: $name ($($ps.PaperName))"
    }
}

# 7. 去重
$uniqueForms = $formsList | Sort-Object -Property name -Unique

# 8. 输出结果
Write-Host "Final papers: $($uniqueForms.Count)"
$uniqueForms | ConvertTo-Json -Depth 3

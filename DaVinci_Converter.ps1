#Requires -Version 3.0

function Test-Command {
    param (
        [string]$CommandName,
        [string]$InstallPrompt,
        [scriptblock]$InstallAction
    )
    try {
        $null = Get-Command $CommandName -ErrorAction Stop
        return $true
    } catch {
        Write-Host "ОШИБКА: $CommandName не найден." -ForegroundColor Red
        if ((Read-Host "$InstallPrompt (Y/n)" ) -match "^(|y|Y)$") {
            & $InstallAction
        }
        return $false
    }
}

function Install-FFmpeg {
    Test-Command -CommandName "winget" -InstallPrompt "Хотите установить winget?" -InstallAction {
        Write-Host "Установка winget невозможна автоматически." -ForegroundColor Yellow
    }
    if (Test-Command -CommandName "winget") {
        Write-Host "Устанавливаю ffmpeg..." -ForegroundColor Yellow
        winget install -e --id Gyan.FFmpeg
    }
}

function Select-File {
    Add-Type -AssemblyName System.Windows.Forms
    $FileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $FileDialog.Filter = "Видео файлы|*.mp4;*.mov;*.avi;*.mkv|Все файлы|*.*"
    if ($FileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $FileDialog.FileName
    }
    return $null
}

function Convert-Video {
    param (
        [string]$InputFile,
        [string]$OutputFile,
        [string]$Format = "mp4"
    )
    if (-not (Test-Command -CommandName "ffmpeg" -InstallPrompt "Установить ffmpeg через winget?" -InstallAction { Install-FFmpeg })) {
        return
    }
    ffmpeg -i $InputFile -c:v libx264 -preset slow -crf 23 -c:a aac -b:a 192k "$OutputFile.$Format"
    Write-Host "Конвертация завершена: $OutputFile.$Format" -ForegroundColor Green
}

# Основной запуск
$inputFile = Select-File
if ($inputFile) {
    $outputFile = Read-Host "Введите имя выходного файла без расширения (оставьте пустым для автогенерации)"
    if (-not $outputFile) {
        $outputFile = [System.IO.Path]::GetFileNameWithoutExtension($inputFile) + "_Converted"
    }
    Convert-Video -InputFile $inputFile -OutputFile $outputFile
} else {
    Write-Host "Файл не выбран." -ForegroundColor Red
}

<#
.SYNOPSIS
    Convertze Automizze Studio (RTX 4080 - v7.0 Shareable Edition)
    Run via: irm convertze.automizze.us | iex
#>

# ================= SYSTEM SETUP =================
$Host.UI.RawUI.WindowTitle = "Convertze Studio (Auto-Detect + Installer Engine)"

# ---------------------------------------------------------
#  MODERN FOLDER PICKER
# ---------------------------------------------------------
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class FolderPicker {
    public string ResultPath;
    public bool ShowDialog() {
        var dialog = new System.Windows.Forms.FolderBrowserDialog();
        dialog.Description = "Select Media Folder";
        dialog.ShowNewFolderButton = false;
        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK) {
            ResultPath = dialog.SelectedPath;
            return true;
        }
        return false;
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

# ---------------------------------------------------------
#  THE AUTO-INSTALLER (NO ADMIN REQUIRED)
# ---------------------------------------------------------
function Install-FFmpeg {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "    FFMPEG AUTO-INSTALLER (No Admin)      " -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Cyan

    $installDir = "$env:LOCALAPPDATA\Convertze_FFmpeg"
    
    # 1. Create the hidden directory
    if (-not (Test-Path $installDir)) { 
        New-Item -ItemType Directory -Path $installDir | Out-Null 
    }

    $zipPath = "$installDir\ffmpeg.zip"
    $url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

    Write-Host "`n[1/4] Downloading Latest FFmpeg..." -ForegroundColor White
    Write-Host "      (Please wait, this is a ~100MB file...)" -ForegroundColor Gray
    
    # Speed trick: Turn off PS progress bar to make download 10x faster
    $ProgressPreference = 'SilentlyContinue' 
    Invoke-WebRequest -Uri $url -OutFile $zipPath
    $ProgressPreference = 'Continue'

    Write-Host "[2/4] Extracting files..." -ForegroundColor White
    Expand-Archive -Path $zipPath -DestinationPath "$installDir\extracted" -Force

    Write-Host "[3/4] Organizing executables..." -ForegroundColor White
    $exeFiles = Get-ChildItem -Path "$installDir\extracted" -Filter "*.exe" -Recurse
    foreach ($exe in $exeFiles) {
        Move-Item -Path $exe.FullName -Destination $installDir -Force
    }

    Write-Host "[4/4] Wiring it into Windows..." -ForegroundColor White
    # Clean up the trash
    Remove-Item -Path $zipPath -Force
    Remove-Item -Path "$installDir\extracted" -Recurse -Force

    # Add to Windows User PATH (Doesn't need Admin!)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notmatch [regex]::Escape($installDir)) {
        $newPath = $currentPath + ";" + $installDir
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = $env:Path + ";" + $installDir # Updates current window instantly
    }

    Write-Host "`nSUCCESS! FFmpeg is installed and ready to use." -ForegroundColor Green
    Write-Host "Press any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ---------------------------------------------------------
#  CORE CONVERSION
# ---------------------------------------------------------
function Start-Conversion {
    param ([string]$TargetFolder, [bool]$DeleteSource)

    # Check for tools before starting
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue) -or -not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
        Write-Host "`n[ERROR] FFmpeg is missing!" -ForegroundColor Red
        Write-Host "Please use Option 3 to install it first." -ForegroundColor Yellow
        Start-Sleep 3; return
    }

    $files = Get-ChildItem -Path $TargetFolder -Filter *.ts -Recurse | 
        Sort-Object { [regex]::Replace($_.Name, '\d+', { $args[0].Value.PadLeft(10, '0') }) }

    $totalFiles = $files.Count

    if ($totalFiles -eq 0) {
        Write-Host "No .ts files found!" -ForegroundColor Red; Start-Sleep 2; return
    }

    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " BATCH START: SMART AUTO-DETECT" -ForegroundColor Yellow
    Write-Host " Folder: $TargetFolder" -ForegroundColor Gray
    Write-Host " Files:  $totalFiles" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $count = 0

    foreach ($file in $files) {
        $count++
        $inputPath = $file.FullName
        $outputPath = [System.IO.Path]::ChangeExtension($inputPath, ".mp4")

        try {
            $heightStr = (ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "`"$inputPath`"")
            $height = [int]$heightStr
        } catch {
            $height = 1080 
        }

        if ($height -ge 1080) { $cq = 27; $resTag = "1080p" } 
        elseif ($height -ge 720) { $cq = 29; $resTag = "720p" } 
        else { $cq = 31; $resTag = "$($height)p" }

        Write-Host "------------------------------------------" -ForegroundColor DarkGray
        Write-Host "[$count/$totalFiles] Processing: " -NoNewline -ForegroundColor Green
        Write-Host "$($file.Name) " -NoNewline -ForegroundColor White
        Write-Host "[$resTag]" -ForegroundColor Magenta

        if (Test-Path $outputPath) {
            Write-Host "    -> Skipped (Exists)" -ForegroundColor DarkGray
            continue
        }

        $process = Start-Process -FilePath "ffmpeg" -ArgumentList `
            "-y -hide_banner -loglevel error -stats",
            "-fflags +genpts+discardcorrupt",
            "-hwaccel cuda -hwaccel_output_format cuda",
            "-i `"$inputPath`"",
            "-c:v hevc_nvenc -preset p5 -cq $cq -rc-lookahead 32",
            "-c:a copy",
            "`"$outputPath`"" -PassThru -Wait -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            $inSize = (Get-Item $inputPath).Length / 1MB
            $outSize = (Get-Item $outputPath).Length / 1MB
            
            if ($outSize -lt $inSize) {
                Write-Host "    [OK] Done! Saved $([math]::Round($inSize - $outSize)) MB" -ForegroundColor Cyan
            } else {
                Write-Host "    [OK] Done! (+$([math]::Round($outSize - $inSize)) MB)" -ForegroundColor Yellow
            }

            if ($DeleteSource -and $outSize -gt 1) {
                Remove-Item $inputPath -Force
                Write-Host "    -> Original deleted." -ForegroundColor Red
            }
        } else {
            Write-Host "    [ERROR] Conversion Failed!" -ForegroundColor Red
        }
    }

    $swTotal.Stop()
    $avg = $swTotal.Elapsed.TotalSeconds / $totalFiles
    
    Write-Host "`n==========================================" -ForegroundColor Yellow
    Write-Host " BATCH COMPLETE " -ForegroundColor Green
    Write-Host " Total Time: $($swTotal.Elapsed.ToString('hh\:mm\:ss'))" 
    Write-Host " Avg Time:   $([math]::Round($avg, 0)) sec/file"
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host "Press any key to return..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ================= MAIN MENU =================
do {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "    CONVERTZE STUDIO (Shareable Edition)  " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " 1. Start Auto-Convert (Keep .TS)" -ForegroundColor Green
    Write-Host " 2. Start Auto-Convert (DELETE .TS)" -ForegroundColor Red
    Write-Host " -----------------------------------------" -ForegroundColor DarkGray
    Write-Host " 3. Install/Update FFmpeg Package" -ForegroundColor Magenta
    Write-Host " Q. Exit" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $choice = Read-Host " Select Option"

    if ($choice -eq '3') {
        Install-FFmpeg
    }
    elseif ($choice -in '1','2') {
        $p = $null
        $picker = New-Object FolderPicker
        if ($picker.ShowDialog()) { 
            $p = $picker.ResultPath 
        } else {
             Write-Host "`nGUI Cancelled. Paste Path manually:" -ForegroundColor Yellow
             $p = Read-Host "Path"
        }

        if ($p -and (Test-Path $p)) {
            switch ($choice) {
                '1' { Start-Conversion $p $false }
                '2' { Start-Conversion $p $true }
            }
        }
    }
} until ($choice -eq 'Q' -or $choice -eq 'q')

Exit

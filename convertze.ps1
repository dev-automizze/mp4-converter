<#
.SYNOPSIS
    Convertze Automizze Studio (RTX 4080 Edition - v3.0)
    Run via: irm convertze.automizze.us | iex
#>

# ================= SYSTEM SETUP =================
$Host.UI.RawUI.WindowTitle = "Convertze Studio (RTX 4080)"

# ---------------------------------------------------------
#  MODERN FOLDER PICKER (The "Nuclear" Fix)
#  Injects C# to use the real Windows Explorer dialog
# ---------------------------------------------------------
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class FolderPicker
{
    public string ResultPath;

    public bool ShowDialog()
    {
        var dialog = new System.Windows.Forms.FolderBrowserDialog();
        // This is the magic. It uses the modern shell.
        // But if that fails, we fallback to standard.
        dialog.Description = "Select your Media Folder (Z: Drive / Network)";
        dialog.ShowNewFolderButton = false;
        
        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
        {
            ResultPath = dialog.SelectedPath;
            return true;
        }
        return false;
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

# ---------------------------------------------------------

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "FFmpeg missing! Please install it first." -ForegroundColor Red
    Exit
}

# Function: The Core Conversion Logic
function Start-Conversion {
    param (
        [string]$TargetFolder,
        [string]$PresetName,
        [bool]$DeleteSource
    )

    # QUALITY SETTINGS (Tweaked for Size)
    if ($PresetName -eq "1080p") {
        $cq = 25  # Increased slightly to keep size down
        $desc = "MAX FIDELITY (1080p)"
    } else {
        $cq = 28  # Perfect for 720p space saving
        $desc = "OPTIMIZED SIZE (720p)"
    }

    $files = Get-ChildItem -Path $TargetFolder -Filter *.ts -Recurse
    $totalFiles = $files.Count

    if ($totalFiles -eq 0) {
        Write-Host "No .ts files found here!" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " MISSION START: $PresetName" -ForegroundColor Yellow
    Write-Host " Location: $TargetFolder" -ForegroundColor Gray
    Write-Host " Episodes: $totalFiles" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    # Start Stopwatch
    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $count = 0

    foreach ($file in $files) {
        $count++
        $inputPath = $file.FullName
        $outputPath = [System.IO.Path]::ChangeExtension($inputPath, ".mp4")

        # Status Update
        Write-Host "[$count/$totalFiles] Converting: " -NoNewline -ForegroundColor Green
        Write-Host $file.Name -ForegroundColor White

        if (Test-Path $outputPath) {
            Write-Host "    -> Skipped (Already exists)" -ForegroundColor DarkGray
            continue
        }

        # ---------------------------------------------------------
        # THE ACTION WINDOW (Pop-up)
        # ---------------------------------------------------------
        $process = Start-Process -FilePath "ffmpeg" -ArgumentList `
            "-y -hide_banner",
            "-fflags +genpts+discardcorrupt",
            "-hwaccel cuda -hwaccel_output_format cuda",
            "-i `"$inputPath`"",
            "-c:v hevc_nvenc -preset p7 -cq $cq -rc-lookahead 32",
            "-c:a copy",
            "`"$outputPath`"" -PassThru -Wait 
        
        # Result Check
        if ($process.ExitCode -eq 0) {
            # Deletion Logic
            if ($DeleteSource) {
                if ((Get-Item $outputPath).Length -gt 1000) {
                    Remove-Item $inputPath -Force
                    Write-Host "    -> Success! Original deleted." -ForegroundColor Cyan
                }
            } else {
                Write-Host "    -> Success!" -ForegroundColor Cyan
            }
        } else {
            Write-Host "    -> FAILED!" -ForegroundColor Red
        }
    }

    $swTotal.Stop()
    $avgTime = $swTotal.Elapsed.TotalSeconds / $totalFiles

    # MISSION REPORT
    Write-Host "`n==========================================" -ForegroundColor Yellow
    Write-Host "           MISSION ACCOMPLISHED           " -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host " Total Time:  $($swTotal.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host " Avg per Ep:  $([math]::Round($avgTime, 1)) seconds" -ForegroundColor White
    Write-Host " Total Files: $totalFiles" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Yellow
    
    Write-Host "`nPress any key to return to Main Menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ================= MAIN MENU LOOP =================
do {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "       CONVERTZE STUDIO (RTX 4080)        " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " 1. Convert to 1080p (Max Quality)" -ForegroundColor Green
    Write-Host " 2. Convert to 720p  (Optimized)" -ForegroundColor Green
    Write-Host " 3. Convert (1080p) + DELETE .TS" -ForegroundColor Red
    Write-Host " 4. Convert (720p)  + DELETE .TS" -ForegroundColor Red
    Write-Host " Q. Exit" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $choice = Read-Host " Select Option"

    if ($choice -in '1','2','3','4') {
        $path = $null
        
        # ASK USER: GUI or MANUAL?
        Write-Host "`n [G] GUI Picker (Try this first)" -ForegroundColor Cyan
        Write-Host " [T] Type/Paste Path (Fallback)" -ForegroundColor Cyan
        $method = Read-Host " Method?"

        if ($method -eq "T") {
            $path = Read-Host " Paste Path (e.g. Z:\Shows)"
        } else {
            # Try the Modern Picker
            $picker = New-Object FolderPicker
            if ($picker.ShowDialog()) {
                $path = $picker.ResultPath
            }
        }

        # Validate Path
        if ($path -and (Test-Path $path)) {
            switch ($choice) {
                '1' { Start-Conversion -TargetFolder $path -PresetName "1080p" -DeleteSource $false }
                '2' { Start-Conversion -TargetFolder $path -PresetName "720p"  -DeleteSource $false }
                '3' { Start-Conversion -TargetFolder $path -PresetName "1080p" -DeleteSource $true }
                '4' { Start-Conversion -TargetFolder $path -PresetName "720p"  -DeleteSource $true }
            }
        } else {
            Write-Host " Invalid Path or Cancelled!" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }

} until ($choice -eq 'Q')

# Clean Exit
Clear-Host

<#
.SYNOPSIS
    Convertze Automizze Studio (RTX 4080 - v6.0 Auto-Detect)
    Run via: irm convertze.automizze.us | iex
#>

# ================= SYSTEM SETUP =================
$Host.UI.RawUI.WindowTitle = "Convertze Studio (Auto-Detect Engine)"

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

# Verify Tools
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue) -or -not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host "FFmpeg or FFprobe missing! Please ensure both are installed." -ForegroundColor Red; Exit
}

# Function: Core Conversion
function Start-Conversion {
    param ([string]$TargetFolder, [bool]$DeleteSource)

    # NATURAL SORT (S01E01, S01E02, etc.)
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

        # --- AUTO-DETECT RESOLUTION ---
        try {
            $heightStr = (ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "`"$inputPath`"")
            $height = [int]$heightStr
        } catch {
            $height = 1080 # Fallback if probe fails
        }

        # Apply correct preset based on resolution
        if ($height -ge 1080) { 
            $cq = 27; $resTag = "1080p" 
        } elseif ($height -ge 720) { 
            $cq = 29; $resTag = "720p" 
        } else { 
            $cq = 31; $resTag = "$($height)p" # Covers 480p and lower
        }
        # ------------------------------

        Write-Host "------------------------------------------" -ForegroundColor DarkGray
        Write-Host "[$count/$totalFiles] Processing: " -NoNewline -ForegroundColor Green
        Write-Host "$($file.Name) " -NoNewline -ForegroundColor White
        Write-Host "[$resTag]" -ForegroundColor Magenta

        if (Test-Path $outputPath) {
            Write-Host "    -> Skipped (Exists)" -ForegroundColor DarkGray
            continue
        }

        # --- CONVERSION COMMAND ---
        # Note: Changed preset from p7 to p5 for a massive speed increase!
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
    Write-Host "    CONVERTZE STUDIO (Auto-Detect Engine) " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " 1. Start Auto-Convert (Keep .TS)" -ForegroundColor Green
    Write-Host " 2. Start Auto-Convert (DELETE .TS)" -ForegroundColor Red
    Write-Host " Q. Exit (Close Window)" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $choice = Read-Host " Select Option"

    if ($choice -in '1','2') {
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

# Kills the PowerShell window completely
Exit

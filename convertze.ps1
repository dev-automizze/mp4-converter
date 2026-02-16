<#
.SYNOPSIS
    Convertze Automizze Studio (RTX 4080 - Final Polish)
    Run via: irm convertze.automizze.us | iex
#>

# ================= SYSTEM SETUP =================
$Host.UI.RawUI.WindowTitle = "Convertze Studio (Ordered)"

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

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "FFmpeg missing! Install it first." -ForegroundColor Red; Exit
}

# Function: Core Conversion
function Start-Conversion {
    param ([string]$TargetFolder, [string]$PresetName, [bool]$DeleteSource)

    # --- QUALITY SETTINGS ---
    if ($PresetName -eq "1080p") {
        $cq = 27; $desc = "BALANCED 1080p"
    } else {
        $cq = 29; $desc = "COMPACT 720p"
    }
    
    # --- THE MAGIC FIX: NATURAL SORT ---
    # This regex trick forces "Episode 2" to come before "Episode 10"
    $files = Get-ChildItem -Path $TargetFolder -Filter *.ts -Recurse | 
        Sort-Object { [regex]::Replace($_.Name, '\d+', { $args[0].Value.PadLeft(10, '0') }) }

    $totalFiles = $files.Count

    if ($totalFiles -eq 0) {
        Write-Host "No .ts files found!" -ForegroundColor Red; Start-Sleep 2; return
    }

    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " STARTING BATCH: $desc" -ForegroundColor Yellow
    Write-Host " Folder: $TargetFolder" -ForegroundColor Gray
    Write-Host " Files:  $totalFiles" -ForegroundColor Gray
    Write-Host " Order:  Alphabetical (Natural)" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $count = 0

    foreach ($file in $files) {
        $count++
        $inputPath = $file.FullName
        $outputPath = [System.IO.Path]::ChangeExtension($inputPath, ".mp4")

        # Visual Separator
        Write-Host "------------------------------------------" -ForegroundColor DarkGray
        Write-Host "[$count/$totalFiles] Processing: " -NoNewline -ForegroundColor Green
        Write-Host $file.Name -ForegroundColor White

        if (Test-Path $outputPath) {
            Write-Host "    -> Skipped (Exists)" -ForegroundColor DarkGray
            continue
        }

        # --- CONVERSION COMMAND ---
        $process = Start-Process -FilePath "ffmpeg" -ArgumentList `
            "-y -hide_banner -loglevel error -stats",
            "-fflags +genpts+discardcorrupt",
            "-hwaccel cuda -hwaccel_output_format cuda",
            "-i `"$inputPath`"",
            "-c:v hevc_nvenc -preset p7 -cq $cq -rc-lookahead 32",
            "-c:a copy",
            "`"$outputPath`"" -PassThru -Wait -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            # Calculate Size Difference
            $inSize = (Get-Item $inputPath).Length / 1MB
            $outSize = (Get-Item $outputPath).Length / 1MB
            
            # Show Result
            if ($outSize -lt $inSize) {
                Write-Host "    [OK] Done! Saved $([math]::Round($inSize - $outSize)) MB" -ForegroundColor Cyan
            } else {
                Write-Host "    [OK] Done! (+$([math]::Round($outSize - $inSize)) MB)" -ForegroundColor Yellow
            }

            # Deletion Logic
            if ($DeleteSource) {
                if ($outSize -gt 1) {
                    Remove-Item $inputPath -Force
                    Write-Host "    -> Original deleted." -ForegroundColor Red
                }
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
    Write-Host "    CONVERTZE STUDIO (Final Polish)       " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " 1. Convert 1080p (Balanced)" -ForegroundColor Green
    Write-Host " 2. Convert 720p  (Compact)" -ForegroundColor Green
    Write-Host " 3. Convert 1080p + DELETE .TS" -ForegroundColor Red
    Write-Host " 4. Convert 720p  + DELETE .TS" -ForegroundColor Red
    Write-Host " Q. Exit" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $choice = Read-Host " Select Option"

    if ($choice -in '1','2','3','4') {
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
                '1' { Start-Conversion $p "1080p" $false }
                '2' { Start-Conversion $p "720p"  $false }
                '3' { Start-Conversion $p "1080p" $true }
                '4' { Start-Conversion $p "720p"  $true }
            }
        }
    }
} until ($choice -eq 'Q')

<#
.SYNOPSIS
    Convertze Automizze Tool (RTX 4080 Edition - v2.0)
    Run via: irm convertze.automizze.us | iex
#>

# ================= SYSTEM SETUP =================
$Host.UI.RawUI.WindowTitle = "Convertze Studio (Powered by Automizze.)"
# Force strict FFmpeg check
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "FFmpeg missing! Please install it first." -ForegroundColor Red
    Exit
}

# Function: Better Folder Picker (Shows Mapped Drives!)
function Get-FolderSelection {
    Add-Type -AssemblyName System.Windows.Forms
    $shell = New-Object -ComObject Shell.Application
    # 17 = ssfDRIVES (My Computer) - Shows Mapped Drives
    $folder = $shell.BrowseForFolder(0, "Select your TV Show Folder (Z: Drive, etc)", 0, 17)
    if ($folder) { return $folder.Self.Path }
    return $null
}

# Function: The Core Conversion Logic
function Start-Conversion {
    param (
        [string]$TargetFolder,
        [string]$PresetName,
        [bool]$DeleteSource
    )

    # ---------------- SETTINGS ----------------
    # Tweak: Increased CQ slightly to prevent file bloating
    if ($PresetName -eq "1080p") {
        $cq = 24  # Balanced for 1080p (Prev: 23)
        $desc = "MAX FIDELITY (1080p)"
    } else {
        $cq = 27  # Perfect for 720p (Prev: 26)
        $desc = "OPTIMIZED SIZE (720p)"
    }
    # ------------------------------------------

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
    Write-Host " Folder: $TargetFolder" -ForegroundColor Gray
    Write-Host " Files:  $totalFiles episodes" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    # Start the Stopwatch
    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $count = 0

    foreach ($file in $files) {
        $count++
        $inputPath = $file.FullName
        $outputPath = [System.IO.Path]::ChangeExtension($inputPath, ".mp4")

        # Progress Bar in Main Window
        Write-Host "[$count/$totalFiles] Processing: " -NoNewline -ForegroundColor Green
        Write-Host $file.Name -ForegroundColor White

        if (Test-Path $outputPath) {
            Write-Host "    -> Skipped (Already exists)" -ForegroundColor DarkGray
            continue
        }

        # ---------------------------------------------------------
        # THE POPUP WINDOW COMMAND
        # We removed -NoNewWindow so it pops up visually
        # ---------------------------------------------------------
        $process = Start-Process -FilePath "ffmpeg" -ArgumentList `
            "-y -hide_banner",
            "-fflags +genpts+discardcorrupt",
            "-hwaccel cuda -hwaccel_output_format cuda",
            "-i `"$inputPath`"",
            "-c:v hevc_nvenc -preset p7 -cq $cq -rc-lookahead 32",
            "-c:a copy",
            "`"$outputPath`"" -PassThru -Wait 
        
        # Check result
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
    Write-Host " Q. Exit (Clear)" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $choice = Read-Host " Select Option"

    if ($choice -in '1','2','3','4') {
        # Select Folder using the NEW Picker
        Write-Host "Opening Folder Picker..." -ForegroundColor DarkGray
        $path = Get-FolderSelection

        if ($path) {
            switch ($choice) {
                '1' { Start-Conversion -TargetFolder $path -PresetName "1080p" -DeleteSource $false }
                '2' { Start-Conversion -TargetFolder $path -PresetName "720p"  -DeleteSource $false }
                '3' { Start-Conversion -TargetFolder $path -PresetName "1080p" -DeleteSource $true }
                '4' { Start-Conversion -TargetFolder $path -PresetName "720p"  -DeleteSource $true }
            }
        } else {
            Write-Host "Selection Cancelled." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }

} until ($choice -eq 'Q')

# Clean Exit
Clear-Host

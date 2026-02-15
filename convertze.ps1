<#
.SYNOPSIS
    Cloud-Hosted FFmpeg Automation Tool (The "Genius" Script)
    Run via: irm https://convertze.automizze.us | iex
#>

# ================= SETUP =================
$Host.UI.RawUI.WindowTitle = "Media Server Conversion Tool (RTX 4080 Edition)"
Clear-Host

# Function to Pick Folder using Windows GUI
function Get-FolderSelection {
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the TV Show or Season Folder"
    $FolderBrowser.ShowNewFolderButton = $false
    
    # Optional: Start at This PC
    $FolderBrowser.RootFolder = "MyComputer"

    if ($FolderBrowser.ShowDialog() -eq "OK") {
        return $FolderBrowser.SelectedPath
    } else {
        return $null
    }
}

# Function to Install FFmpeg
function Install-FFmpeg {
    Write-Host "Checking for FFmpeg..." -ForegroundColor Cyan
    if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
        Write-Host "FFmpeg is already installed!" -ForegroundColor Green
        return
    }

    Write-Host "FFmpeg not found. Installing via Winget..." -ForegroundColor Yellow
    winget install "Gyan.FFmpeg" --accept-source-agreements --accept-package-agreements
    
    # Refresh Path for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "Installation Complete! (You might need to restart the script if it fails to detect)." -ForegroundColor Green
}

# Function to Run Conversion
function Start-Conversion {
    param (
        [string]$TargetFolder,
        [string]$Quality,   # "1080p" or "720p"
        [bool]$DeleteSource # $true to delete .ts files
    )

    # settings based on preset
    if ($Quality -eq "1080p") {
        $cq = 23
        $desc = "MAX QUALITY (1080p/Source)"
    } else {
        $cq = 26
        $desc = "SPACE SAVER (720p Optimized)"
    }

    $files = Get-ChildItem -Path $TargetFolder -Filter *.ts -Recurse
    $total = $files.Count

    if ($total -eq 0) {
        Write-Host "No .ts files found in: $TargetFolder" -ForegroundColor Red
        return
    }

    Write-Host "Target: $TargetFolder" -ForegroundColor Cyan
    Write-Host "Mode: $desc" -ForegroundColor Yellow
    Write-Host "Files: $total" -ForegroundColor Cyan
    Write-Host "------------------------------------------------"

    foreach ($file in $files) {
        $inputPath = $file.FullName
        $outputPath = [System.IO.Path]::ChangeExtension($inputPath, ".mp4")

        if (Test-Path $outputPath) {
            Write-Host "Skipping (Exists): $($file.Name)" -ForegroundColor DarkGray
            continue
        }

        Write-Host "Converting: $($file.Name) ..." -NoNewline -ForegroundColor Green
        
        # THE CONVERSION COMMAND (RTX 4080 Optimized)
        $process = Start-Process -FilePath "ffmpeg" -ArgumentList `
            "-y -hide_banner -loglevel error",
            "-fflags +genpts+discardcorrupt",
            "-hwaccel cuda -hwaccel_output_format cuda",
            "-i `"$inputPath`"",
            "-c:v hevc_nvenc -preset p7 -cq $cq -rc-lookahead 32",
            "-c:a copy",
            "`"$outputPath`"" -PassThru -Wait -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host " [DONE]" -ForegroundColor Green
            
            # DELETION LOGIC (Only runs if requested AND successful)
            if ($DeleteSource) {
                if ((Get-Item $outputPath).Length -gt 1000) {
                    Remove-Item $inputPath -Force
                    Write-Host "   -> Original .ts deleted." -ForegroundColor Red
                } else {
                    Write-Host "   -> Safety Check: Output file too small. Keeping original." -ForegroundColor Magenta
                }
            }

        } else {
            Write-Host " [FAILED]" -ForegroundColor Red
        }
    }
    Write-Host "Job Complete!" -ForegroundColor Cyan
    Pause
}

# ================= MAIN MENU LOOP =================
do {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "   THE MEDIA CONVERTER (CLOUD EDITION)    " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "1. Convert (1080p/High Quality)" -ForegroundColor Green
    Write-Host "2. Convert (720p/Optimized)" -ForegroundColor Green
    Write-Host "3. Convert (1080p) + DELETE .TS" -ForegroundColor Red
    Write-Host "4. Convert (720p) + DELETE .TS" -ForegroundColor Red
    Write-Host "5. Install/Check FFmpeg" -ForegroundColor Yellow
    Write-Host "Q. Exit" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Choose an option"

    if ($choice -in '1','2','3','4') {
        # 1. Ask for Path (GUI or Type)
        Write-Host "`n[G] Use GUI Picker (Recommended)" -ForegroundColor Cyan
        Write-Host "[T] Type Path Manually" -ForegroundColor Cyan
        $pathMode = Read-Host "Select Mode"

        $selectedPath = $null
        if ($pathMode -eq 'T') {
            $selectedPath = Read-Host "Enter Path (e.g. Z:\Shows\Kamen)"
        } else {
            $selectedPath = Get-FolderSelection
        }

        # 2. Validation
        if (-not $selectedPath -or -not (Test-Path $selectedPath)) {
            Write-Host "Invalid Path or Cancelled!" -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }

        # 3. Execute
        switch ($choice) {
            '1' { Start-Conversion -TargetFolder $selectedPath -Quality "1080p" -DeleteSource $false }
            '2' { Start-Conversion -TargetFolder $selectedPath -Quality "720p"  -DeleteSource $false }
            '3' { Start-Conversion -TargetFolder $selectedPath -Quality "1080p" -DeleteSource $true }
            '4' { Start-Conversion -TargetFolder $selectedPath -Quality "720p"  -DeleteSource $true }
        }
    }
    elseif ($choice -eq '5') {
        Install-FFmpeg
        Pause
    }

} until ($choice -eq 'Q')

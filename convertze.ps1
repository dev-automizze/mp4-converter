<#
.SYNOPSIS
    Convertze Automizze Studio (RTX 4080 Edition - v4.0 Network Fix)
    Run via: irm convertze.automizze.us | iex
#>

# ================= SYSTEM SETUP =================
$Host.UI.RawUI.WindowTitle = "Convertze Studio v4.0 (Network Edition)"

# Function: Modern Folder Picker
function Get-FolderSelection {
    Add-Type -AssemblyName System.Windows.Forms
    $shell = New-Object -ComObject Shell.Application
    # 17 = My Computer (Attempt to show all drives)
    $folder = $shell.BrowseForFolder(0, "Select Media Folder", 0, 17)
    if ($folder) { return $folder.Self.Path }
    return $null
}

# Function: Connect Network Drive (The Fix)
function Connect-NetworkDrive {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host "      CONNECT TO SERVER (Admin Mode)      " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host "Since this script runs as Admin, it might not see your Z: drive." -ForegroundColor Gray
    Write-Host "Let's connect manually properly.`n" -ForegroundColor Gray
    
    $serverPath = Read-Host "Server Path (e.g. \\172.10.10.67\media)"
    $user = Read-Host "Username"
    $pass = Read-Host "Password" -AsSecureString
    $passPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))

    Write-Host "`nAttempting to connect..." -ForegroundColor Cyan
    
    # Delete existing connection to prevent conflicts
    net use $serverPath /delete /y 2>$null | Out-Null
    
    # Create new connection
    $proc = Start-Process "net" -ArgumentList "use `"$serverPath`" $passPlain /user:$user" -Wait -PassThru -NoNewWindow
    
    if ($proc.ExitCode -eq 0) {
        Write-Host "SUCCESS! Server is now connected." -ForegroundColor Green
        Write-Host "You can now use path: $serverPath" -ForegroundColor Cyan
    } else {
        Write-Host "Connection Failed. Check IP or Password." -ForegroundColor Red
    }
    Pause
}

# Function: Core Conversion
function Start-Conversion {
    param ([string]$TargetFolder, [string]$PresetName, [bool]$DeleteSource)

    # SETTINGS
    if ($PresetName -eq "1080p") { $cq = 24; $desc = "MAX FIDELITY (1080p)" } 
    else { $cq = 27; $desc = "OPTIMIZED SIZE (720p)" }

    # Validate Path with specific error
    if (-not (Test-Path $TargetFolder)) {
        Write-Host "ERROR: Cannot access path: $TargetFolder" -ForegroundColor Red
        Write-Host "Tip: Try Option 5 to connect to the server first." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        return
    }

    $files = Get-ChildItem -Path $TargetFolder -Filter *.ts -Recurse
    $totalFiles = $files.Count

    if ($totalFiles -eq 0) {
        Write-Host "No .ts files found in $TargetFolder" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " MISSION START: $PresetName" -ForegroundColor Yellow
    Write-Host " Path: $TargetFolder" -ForegroundColor Gray
    Write-Host " Files: $totalFiles" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $count = 0

    foreach ($file in $files) {
        $count++
        $inputPath = $file.FullName
        $outputPath = [System.IO.Path]::ChangeExtension($inputPath, ".mp4")

        Write-Host "[$count/$totalFiles] $file.Name" -NoNewline -ForegroundColor White

        if (Test-Path $outputPath) {
            Write-Host " -> Skipped" -ForegroundColor DarkGray
            continue
        }

        # POPUP WINDOW ACTION
        $process = Start-Process -FilePath "ffmpeg" -ArgumentList `
            "-y -hide_banner",
            "-fflags +genpts+discardcorrupt",
            "-hwaccel cuda -hwaccel_output_format cuda",
            "-i `"$inputPath`"",
            "-c:v hevc_nvenc -preset p7 -cq $cq -rc-lookahead 32",
            "-c:a copy",
            "`"$outputPath`"" -PassThru -Wait 
        
        if ($process.ExitCode -eq 0) {
            if ($DeleteSource) {
                if ((Get-Item $outputPath).Length -gt 1000) {
                    Remove-Item $inputPath -Force
                    Write-Host " -> Done (Original Deleted)" -ForegroundColor Cyan
                }
            } else {
                Write-Host " -> Done" -ForegroundColor Green
            }
        } else {
            Write-Host " -> FAILED" -ForegroundColor Red
        }
    }
    
    $swTotal.Stop()
    Write-Host "`nMISSION COMPLETE. Time: $($swTotal.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Yellow
    Pause
}

# ================= MAIN MENU =================
do {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "       CONVERTZE STUDIO (v4.0 Net)        " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " 1. Convert 1080p (High Quality)" -ForegroundColor Green
    Write-Host " 2. Convert 720p  (Optimized)" -ForegroundColor Green
    Write-Host " 3. Convert 1080p + DELETE .TS" -ForegroundColor Red
    Write-Host " 4. Convert 720p  + DELETE .TS" -ForegroundColor Red
    Write-Host " ---------------------------------" -ForegroundColor DarkGray
    Write-Host " 5. CONNECT NETWORK DRIVE (Fix)" -ForegroundColor Yellow
    Write-Host " Q. Exit" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $choice = Read-Host " Select Option"

    if ($choice -eq '5') {
        Connect-NetworkDrive
    }
    elseif ($choice -in '1','2','3','4') {
        Write-Host "`n [G] GUI Picker" -ForegroundColor Cyan
        Write-Host " [T] Type/Paste Path (Recommended for Network)" -ForegroundColor Cyan
        $m = Read-Host " Method?"
        
        $p = $null
        if ($m -eq "G") { $p = Get-FolderSelection }
        if ($m -eq "T") { $p = Read-Host " Paste Path (e.g. \\172.10.10.67\media)" }

        if ($p) {
            switch ($choice) {
                '1' { Start-Conversion $p "1080p" $false }
                '2' { Start-Conversion $p "720p"  $false }
                '3' { Start-Conversion $p "1080p" $true }
                '4' { Start-Conversion $p "720p"  $true }
            }
        }
    }
} until ($choice -eq 'Q')

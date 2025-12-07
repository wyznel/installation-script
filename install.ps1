# ================================
# WINDOWS 10/11 PROVISIONING TOOL
# Clone → Right Click → Run as Administrator
# ================================

# ---- TEMP EXECUTION POLICY BYPASS ----
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ---- ADMIN CHECK ----
$currIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currIdentity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting as Administrator..."
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ---- OS DETECTION ----
$osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
Write-Host "Detected OS: $osVersion`n"


# ---- LOGGING ----
$logFile = "$PSScriptRoot\install-log.txt"
Start-Transcript -Path $logFile -Append

# ---- WINGET BOOTSTRAP ----
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Winget not found. Installing App Installer..."
    $wingetInstaller = "https://aka.ms/getwinget"
    Start-Process $wingetInstaller
    Write-Host "After App Installer finishes, RE-RUN this script."
    Stop-Transcript
    exit
}

# =======================
# MASTER APP CATALOG
# =======================
$allApps = @(
    @{ Name = "Steam";          Id = "Valve.Steam" }
    @{ Name = "Epic Games";     Id = "EpicGames.EpicGamesLauncher" }
    @{ Name = "BattleNet".      Id = "Blizzard.BattleNet" }
    @{ Name = "EA App",         Id = "ElectronicArts.EADesktop"}
    @{ Name = "Ubisoft Connect" Id = "Ubisoft.Connect" } 
    @{ Name = "Spotify";        Id = "Spotify.Spotify" }
    @{ Name = "Notepad++";      Id = "Notepad++.Notepad++" }
    @{ Name = "Discord";        Id = "Discord.Discord" }
    @{ Name = "VLC";            Id = "VideoLAN.VLC" }
    @{ Name = "WinRAR";         Id = "RARLab.WinRAR" }
    @{ Name = "Java 21";        Id = "EclipseAdoptium.Temurin.21.JDK" }

    # Optional / Power User
    @{ Name = "MSI Afterburner" Id = "Guru3D.Afterburner" }
    @{ Name = "Git";            Id = "Git.Git" }
    @{ Name = "Python";         Id = "Python.Python.3.12" }
    @{ Name = "VS Code";        Id = "Microsoft.VisualStudioCode" }
    @{ Name = "Docker";         Id = "Docker.DockerDesktop" }
    @{ Name = "Node.js";        Id = "OpenJS.NodeJS" }
    @{ Name = "OpenVPN";        Id = "OpenVPNTechnologies.OpenVPN" }
)

# =======================
# DEFAULT RECOMMENDED SET
# =======================
$defaultApps = @(
    "Steam",
    "Epic Games",
    "BattleNet",
    "EA App",
    "Ubisoft Connect",
    "Spotify",
    "Notepad++",
    "Discord",
    "VLC",
    "WinRAR",
    "Java 21"
)


# =======================
# GPU HARDWARE DETECTION
# =======================
Write-Host "Detecting GPU..."

$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
$gpuName = $gpu.Name

Write-Host "Detected GPU: $gpuName"

$gpuDriverPackage = $null

if ($gpuName -match "NVIDIA") {
    Write-Host "NVIDIA GPU detected."
    $gpuDriverPackage = "NVIDIA.GeForceExperience"
}
elseif ($gpuName -match "AMD|Radeon") {
    Write-Host "AMD GPU detected."
    $gpuDriverPackage = "AdvancedMicroDevices.AMDSoftware"
}
elseif ($gpuName -match "Intel") {
    Write-Host "Intel GPU detected."
    $gpuDriverPackage = "Intel.GraphicsDriver"
}
else {
    Write-Warning "Unknown GPU detected. Skipping driver auto-install."
}

# =======================
# GPU DRIVER INSTALL
# =======================
if ($gpuDriverPackage) {
    Write-Host "Checking for GPU driver..."

    $gpuInstalled = winget list --id $gpuDriverPackage --exact 2>$null

    if ($gpuInstalled) {
        Write-Host "GPU driver already installed. Skipping."
    }
    else {
        Write-Host "Installing GPU driver..."
        winget install --id $gpuDriverPackage `
                       --exact `
                       --accept-package-agreements `
                       --accept-source-agreements `
                       --silent `
                       --source winget

        if ($LASTEXITCODE -eq 0) {
            Write-Host "GPU driver installed successfully."
        }
        else {
            Write-Warning "GPU driver installation failed."
        }
    }
}

# =======================
# MENU
# =======================
Clear-Host
Write-Host "==============================="
Write-Host "   WINDOWS SETUP INSTALLER"
Write-Host "==============================="
Write-Host "1. Install DEFAULT apps (recommended)"
Write-Host "2. Install DEFAULT + choose more"
Write-Host "3. FULLY CUSTOM install"
Write-Host ""

$choice = Read-Host "Select an option (1-3)"

$selectedApps = @()

switch ($choice) {
    "1" {
        $selectedApps = $allApps | Where-Object { $defaultApps -contains $_.Name }
    }

    "2" {
        $selectedApps = $allApps | Where-Object { $defaultApps -contains $_.Name }

        Write-Host "`nOptional Apps:"
        $optionalApps = $allApps | Where-Object { $defaultApps -notcontains $_.Name }

        for ($i = 0; $i -lt $optionalApps.Count; $i++) {
            Write-Host "$($i+1). $($optionalApps[$i].Name)"
        }

        $extras = Read-Host "Select extras (comma-separated) or press Enter to skip"

        if ($extras) {
            $extras.Split(",") | ForEach-Object {
                $index = ($_ - 1)
                if ($index -ge 0 -and $index -lt $optionalApps.Count) {
                    $selectedApps += $optionalApps[$index]
                }
            }
        }
    }

    "3" {
        for ($i = 0; $i -lt $allApps.Count; $i++) {
            Write-Host "$($i+1). $($allApps[$i].Name)"
        }

        $picks = Read-Host "Select apps (comma-separated)"

        if (-not $picks) {
            Write-Warning "No selection made."
            Stop-Transcript
            exit 1
        }

        $picks.Split(",") | ForEach-Object {
            $index = ($_ - 1)
            if ($index -ge 0 -and $index -lt $allApps.Count) {
                $selectedApps += $allApps[$index]
            }
        }
    }

    default {
        Write-Warning "Invalid selection."
        Stop-Transcript
        exit 1
    }
}

$selectedApps = $selectedApps | Sort-Object Name -Unique

# =======================
# INSTALL LOOP (SMART)
# =======================
foreach ($app in $selectedApps) {
    Write-Host "`nInstalling $($app.Name)..."

    # Skip if already installed
    $installed = winget list --id $app.Id --exact 2>$null
    if ($installed) {
        Write-Host "$($app.Name) already installed. Skipping."
        continue
    }

    winget install --id $app.Id `
                   --exact `
                   --accept-package-agreements `
                   --accept-source-agreements `
                   --silent `
                   --source winget

    if ($LASTEXITCODE -eq 0) {
        Write-Host "$($app.Name) installed successfully."
    } else {
        Write-Warning "$($app.Name) failed to install."
    }
}

Stop-Transcript

Write-Host "`n================================"
Write-Host "Setup complete."
Write-Host "Log saved to: $logFile"
Write-Host "A reboot is recommended."
Write-Host "================================"

Pause

# SIG # Begin signature block
# MIIFhQYJKoZIhvcNAQcCoIIFdjCCBXICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUvEZIX6COADLK/niVWiqNai0J
# DaigggMYMIIDFDCCAfygAwIBAgIQWf2dYM/pJ7lH0oNsWrBp/DANBgkqhkiG9w0B
# AQUFADAiMSAwHgYDVQQDDBdQb3dlclNoZWxsIENvZGUgU2lnbmluZzAeFw0yNTEy
# MDYyMzEzMTZaFw0yNjEyMDYyMzMzMTZaMCIxIDAeBgNVBAMMF1Bvd2VyU2hlbGwg
# Q29kZSBTaWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxpzW
# k8mMz+nu+Tz8wCQOJRKYTYjoGckrj7xtQCjWDn9cvMYbMB81d7C7ClJOZsCQSp+l
# +L4npFh6g2CZhZ/NEYIlBBsVERfZbd2/F84bzvw49cWqryR56YxvYrbjDWiMHb0P
# 2BKfuY5V/lGCekni+u+iXBExN4JoGXvPfvCbUbwYxbgHN0TQ7pSOgOqvPiJW7AWB
# 0E1c3m5qD+WtrTq5FC0mFBH8fIy8w6fejo0TtemfbSiWoDBpP5TPWQrIzPHdWbHw
# eMkjx8fK89nhk0tvD1qhZ94romQrG1aCvA04jaWoyJ09nrdrJHaDsVume/30he83
# Jh1UYHtfu0ejZDLS1QIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwHQYDVR0OBBYEFEzjqahzwsqZY3OHIu2QeC2bLPstMA0GCSqG
# SIb3DQEBBQUAA4IBAQBT68BJTXnFucf3dHaiWHjnphguX+bX95uJXaR5nIOEWsX4
# lGGBEBCJWDDC/23xKmTG/uLIWQ+LZTxWEf+gETbVtX7Xk/NCcKIX7XAiweFBXJAu
# xIFgNiSX/tF5iUB3vOGTooYN8adggJDJ8mc6z3+Klo9eK9NA/qChaAQ891vqguG0
# sOOkovMiRbJc3lbdUXi2ZrmiqRtE0ntbl+rf20huiZf5vZZkeTNkaYuPQBcY4kWu
# EvZQVYyw9Z30X0Q++tA+bLumf8dso7XDPBIn2S1b8Cg566ew3EZecceKJRbafcAs
# Ilg8lzJlWUTa6Ue/zwAxCzjI0H8AU4eHF3Vsj49RMYIB1zCCAdMCAQEwNjAiMSAw
# HgYDVQQDDBdQb3dlclNoZWxsIENvZGUgU2lnbmluZwIQWf2dYM/pJ7lH0oNsWrBp
# /DAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG
# 9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIB
# FTAjBgkqhkiG9w0BCQQxFgQUtT/vnkB9tBW9DkSZ3K1r/yXM66YwDQYJKoZIhvcN
# AQEBBQAEggEAmqCIutgy6OSrS4pGJPSu12DTsRaNdgJeBldVl3nO9PZ+ndQYyhzv
# ixhJ6T6zHGl4JquEc1o9ofBT5flchzWshMCrFtvX3pyYeEoMVkEAlTjWpRvVlP1s
# 9Krdc61vr7a49oiIqnLhVAua+RWjAJ8SmsBapwrSIzCSDekypRxdJAmkT+y0aaey
# yYid4TX4T92tafSYXZmlUfm4p/XZ5tnYSovj+d9ZwnlySzf9ik3SZBO/TPQz+s7Y
# 6jdKmWGJ7ukkrWA5yODDVs7qi2WdXgOLqSqPQbLsItvjMntppNm1jTIANfTOrrpl
# mRUm2XhP5TREDDNl3RGsImsVd5wLQ50M+Q==
# SIG # End signature block

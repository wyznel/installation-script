# win-setup.ps1
# Run in elevated PowerShell on Windows 11

#-----------------------
# Require admin
#-----------------------
$currIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Run this script as Administrator."
    exit 1
}

#-----------------------
# Check winget
#-----------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Update Windows and try again."
    exit 1
}

#-----------------------
# App list
#-----------------------
$apps = @(
    @{ Name = "Steam";                    Id = "Valve.Steam" }
    @{ Name = "Epic Games";               Id = "EpicGames.EpicGamesLauncher" }
    @{ Name = "Spotify";                  Id = "Spotify.Spotify" }
    @{ Name = "Visual Studio Code";       Id = "Microsoft.VisualStudioCode" }
    @{ Name = "IntelliJ IDEA Ultimate";   Id = "JetBrains.IntelliJIDEA.Ultimate" }
    @{ Name = "Python 3";                 Id = "Python.Python.3" }
    @{ Name = "Notepad++";                Id = "Notepad++.Notepad++" }
    @{ Name = "Discord";                  Id = "Discord.Discord" }
    @{ Name = "VLC Media Player";         Id = "VideoLAN.VLC" }
    @{ Name = "WinRAR";                   Id = "RARLab.WinRAR" }

    # Java 21 LTS – Eclipse Temurin
    @{ Name = "Java 21 (Temurin JDK)";    Id = "EclipseAdoptium.Temurin.21.JDK" }
)

#-----------------------
# Install loop
#-----------------------
foreach ($app in $apps) {
    $name = $app.Name
    $id   = $app.Id

    Write-Host "============================="
    Write-Host "Installing $name ($id)..."
    Write-Host "============================="

    try {
        winget install --id $id `
                       --exact `
                       --accept-package-agreements `
                       --accept-source-agreements `
                       --silent `
                       --source winget

        if ($LASTEXITCODE -eq 0) {
            Write-Host "$name installed successfully.`n"
        } else {
            Write-Warning "$name may not have installed correctly. winget exit code: $LASTEXITCODE`n"
        }
    }
    catch {
        Write-Warning "Failed to install $name. Error: $($_.Exception.Message)`n"
    }
}

Write-Host "Setup complete. A reboot is recommended."

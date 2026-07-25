#Requires -Version 5.1
<#
.SYNOPSIS
    Install Coda packages into a Python virtual environment.

.DESCRIPTION
    This script creates a Python virtual environment and installs Coda packages 
    from local wheel files. Supports Python 3.12 and 3.13.

.PARAMETER VenvPath
    Path where the virtual environment will be created.
    Defaults to ~/.coda-venv if not specified.

.PARAMETER NoShellConfig
    If specified, skips updating the PowerShell profile with PATH configuration.
    By default, the script updates the profile.

.EXAMPLE
    .\install_coda.ps1
    # Uses default path ~/.coda-venv and updates PowerShell profile

.EXAMPLE
    .\install_coda.ps1 -VenvPath "C:\MyVenv" -NoShellConfig
    # Uses custom path and skips profile update
#>

param(
    [string]$VenvPath = (Join-Path $HOME ".coda-venv"),
    [switch]$NoShellConfig
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SupportedVersions = @('3.13', '3.12')
$Packages = @('coda_core', 'coda_cli', 'coda_batch', 'coda_api', 'coda')

function Find-Python {
    param([string]$Version)
    
    # Build search paths
    $searchPaths = @(
        "python$Version",
        'python3',
        'python'
    )
    
    # Add Windows-specific paths only on Windows
    if ([System.Environment]::OSVersion.Platform -eq 'Win32NT' -or $IsWindows) {
        $searchPaths += @(
            "C:\Python$($Version.Replace('.', ''))\python.exe",
            "C:\Program Files\Python$Version\python.exe",
            "C:\Program Files\Python$($Version.Replace('.', ''))\python.exe",
            "C:\Program Files (x86)\Python$Version\python.exe",
            "C:\Program Files (x86)\Python$($Version.Replace('.', ''))\python.exe",
            "$env:APPDATA\Python\Python$($Version.Replace('.', ''))\python.exe",
            "$HOME\AppData\Local\Programs\Python\Python$($Version.Replace('.', ''))\python.exe"
        )
    } else {
        # macOS/Linux-specific paths
        $searchPaths += @(
            "/opt/homebrew/bin/python$Version",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python$Version",
            "/usr/local/bin/python3",
            "/usr/bin/python$Version",
            "/usr/bin/python3",
            "$HOME/.pyenv/shims/python$Version",
            "$HOME/.pyenv/shims/python3"
        )
    }
    
    # Add Windows Registry paths if on Windows
    if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
        try {
            $regPath = "HKLM:\SOFTWARE\Python\PythonCore\$Version\InstallPath"
            if (Test-Path $regPath) {
                $regPython = (Get-ItemProperty $regPath).'(Default)' | Join-Path -ChildPath 'python.exe'
                $searchPaths += $regPython
            }
        } catch {
            # Silently continue if registry lookup fails
        }
    }
    
    foreach ($path in $searchPaths) {
        try {
            # Check if path looks like a command name vs. full path
            $isCommandName = -not ($path -match '^[/\\]' -or $path -match '^[A-Z]:' -or $path -match '/$')
            
            if ($isCommandName) {
                $fullPath = (Get-Command $path -ErrorAction SilentlyContinue).Source
            } else {
                $fullPath = $path
            }
            
            if ($fullPath -and (Test-Path $fullPath)) {
                $detectedVersion = & $fullPath -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
                
                if ($detectedVersion -eq $Version) {
                    return $fullPath
                }
            }
        } catch {
            # Continue to next path
        }
    }
    
    return $null
}

function Find-Wheel {
    param([string]$PackageName)
    
    $wheels = @(Get-ChildItem -Path $ScriptDir -Filter "$PackageName-*.whl" -ErrorAction SilentlyContinue)
    
    if ($wheels.Count -gt 0) {
        return $wheels[0].FullName
    }
    
    return $null
}

function Assert-WheelsExist {
    $missingWheels = @()
    foreach ($package in $Packages) {
        if (-not (Find-Wheel -PackageName $package)) {
            $missingWheels += $package
        }
    }
    
    if ($missingWheels.Count -gt 0) {
        throw "Error: Could not find wheel files for: $($missingWheels -join ', ')`nExpected location: $ScriptDir"
    }
}

function Install-Wheels {
    param(
        [string]$VenvBin,
        [bool]$IsWindowsOS
    )
    
    $pipExe = if ($IsWindowsOS) {
        Join-Path -Path $VenvBin -ChildPath 'pip.exe'
    } else {
        Join-Path -Path $VenvBin -ChildPath 'pip'
    }
    
    foreach ($package in $Packages) {
        $wheel = Find-Wheel -PackageName $package
        Write-Host "Installing $(Split-Path -Leaf $wheel)..."
        
        & $pipExe install --find-links "$ScriptDir" "$wheel"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Error: Failed to install $package"
        }
    }
}

function Update-PowerShellProfile {
    param(
        [string]$VenvBin
    )
    
    # Detect which profile to use based on running PowerShell version
    $profilePath = if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell 7+ (cross-platform)
        if ($IsWindows) {
            Join-Path -Path $HOME -ChildPath 'Documents\PowerShell\profile.ps1'
        } else {
            Join-Path -Path $HOME -ChildPath '.config/powershell/profile.ps1'
        }
    } else {
        # Windows PowerShell 5.1
        Join-Path -Path $HOME -ChildPath 'Documents\WindowsPowerShell\profile.ps1'
    }
    
    # Validate and escape VenvBin for safe embedding into profile script
    if ($VenvBin -match "[`r`n]") {
        throw "Error: Virtual environment path cannot contain newline characters."
    }
    $venvPathForProfile = $VenvBin -replace "'", "''"
    
    $pathEntry = @'

# Added by coda installer
if ($env:PATH -notmatch [regex]::Escape('{0}')) {{
    $env:PATH = '{0}{1}' + $env:PATH
}}
'@ -f $venvPathForProfile, [System.IO.Path]::PathSeparator
    
    if (-not (Test-Path $profilePath)) {
        $profileDir = Split-Path -Parent $profilePath
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        
        Set-Content -Path $profilePath -Value $pathEntry -Encoding UTF8
        Write-Host "Created $profilePath with PATH entry."
    } elseif ((Get-Content $profilePath -Raw) -like '*Added by coda installer*') {
        Write-Host "$profilePath already contains coda PATH entry."
    } else {
        Add-Content -Path $profilePath -Value $pathEntry -Encoding UTF8
        Write-Host "Updated $profilePath with coda PATH entry."
    }
}

# Main script logic
try {
    Write-Host "Coda Installation Script"
    Write-Host "========================`n"
    
    Write-Host "Searching for Python $($SupportedVersions -join ' or ')..."
    
    $pythonExe = $null
    foreach ($version in $SupportedVersions) {
        $pythonExe = Find-Python -Version $version
        if ($pythonExe) {
            break
        }
    }
    
    if (-not $pythonExe) {
        $searchSummary = "Searched for: $($SupportedVersions -join ', ')`n"
        $searchSummary += "Common locations:`n"
        $searchSummary += "  - PATH (python, python3, python3.12, python3.13)`n"
        $searchSummary += "  - Windows: C:\Python312\, C:\Program Files\Python*\`n"
        $searchSummary += "  - macOS: /opt/homebrew/bin/, /usr/local/bin/`n"
        $searchSummary += "  - Linux: /usr/bin/, ~/.pyenv/shims/"
        
        throw "Error: Python 3.12 or 3.13 not found.`n`n$searchSummary`n`nPlease install one of these versions."
    }
    
    Write-Host "Found Python: $pythonExe"
    
    $detectedVersion = & $pythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
    Write-Host "Python version: $detectedVersion`n"
    
    if (Test-Path $VenvPath) {
        Write-Host "Virtual environment already exists at: $VenvPath"
    } else {
        Write-Host "Creating virtual environment at: $VenvPath"
        & $pythonExe -m venv $VenvPath
        
        if ($LASTEXITCODE -ne 0) {
            throw "Error: Failed to create virtual environment."
        }
    }
    
    $isOnWindows = $IsWindows -or ([System.Environment]::OSVersion.Platform -eq 'Win32NT')
    $venvBin = if ($isOnWindows) { 
        Join-Path -Path $VenvPath -ChildPath 'Scripts' 
    } else { 
        Join-Path -Path $VenvPath -ChildPath 'bin' 
    }
    
    Write-Host "Installing wheels..."
    Assert-WheelsExist
    Install-Wheels -VenvBin $venvBin -IsWindowsOS $isOnWindows
    
    if (-not $NoShellConfig) {
        Write-Host "`nUpdating PowerShell profile..."
        Update-PowerShellProfile -VenvBin $venvBin
    } else {
        Write-Host "`nShell configuration update skipped (-NoShellConfig specified)."
        Write-Host "To add coda to your PATH, add this line to your PowerShell profile:"
        Write-Host "  `$env:PATH = `"$venvBin`" + [System.IO.Path]::PathSeparator + `$env:PATH"
    }
    
    Write-Host "`n========================================"
    Write-Host "Installation completed successfully!"
    Write-Host "Virtual environment: $VenvPath"
    Write-Host "Executables: $venvBin"
    
    $activateScript = if ($isOnWindows) {
        Join-Path -Path (Join-Path -Path $VenvPath -ChildPath 'Scripts') -ChildPath 'Activate.ps1'
    } else {
        Join-Path -Path (Join-Path -Path $VenvPath -ChildPath 'bin') -ChildPath 'Activate.ps1'
    }
    
    Write-Host "`nTo activate the environment in your current shell, run:"
    Write-Host "  & `"$activateScript`""
    Write-Host "`nOr reload your PowerShell profile:"
    Write-Host "  . `$PROFILE.CurrentUserAllHosts"
    Write-Host "========================================"
    
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

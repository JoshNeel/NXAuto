
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('Install','Uninstall','Repair')]
    [string]$DeploymentType = 'Install',
    [Parameter(Mandatory=$false)]
    [ValidateSet('Interactive','Silent','NonInteractive')]
    [string]$DeployMode = 'Interactive',
    [Parameter(Mandatory=$false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory=$false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory=$false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = ''
    [string]$appName = 'SonicWall NetExtender'
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = 'XX/XX/20XX'
    [string]$appScriptAuthor = 'Jason Bergner'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = ''
    [string]$installTitle = 'SonicWall NetExtender'

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [int32]$mainExitCode = 0

    ## Variables: Script
    [string]$deployAppScriptFriendlyName = 'Deploy Application'
    [version]$deployAppScriptVersion = [version]'3.8.4'
    [string]$deployAppScriptDate = '26/01/2021'
    [hashtable]$deployAppScriptParameters = $psBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
    [string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
        If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
    }
    Catch {
        If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, Close SonicWall NetExtender With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'NEGui' -CloseAppsCountdown 60

        ## Show Progress Message
        Show-InstallationProgress

        ## Uninstall Any Existing Versions of SonicWall NetExtender (EXE)
        $AppList = Get-InstalledApplication -Name 'SonicWall NetExtender'        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString -notlike '*MsiExec.exe*')
        {
        $UninstPath = $App.UninstallString -replace '"', ''       
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."
        Execute-Process -Path $UninstPath -Parameters '/S'
        Start-Sleep -Seconds 10
        }
        }
        }

        ## Check For Pending Reboot
        #$Reboot = Get-PendingReboot
        #if($Reboot.IsSystemRebootPending -eq $True -or $Reboot.IsCBServicingRebootPending -eq $True -or $Reboot.IsWindowsUpdateRebootPending -eq $True -or $Reboot.IsSCCMClientRebootPending -eq $True -or $Reboot.IsFileRenameRebootPending -eq $True)
        #{
        ## A Reboot Is Pending, Cannot Proceed Without a Restart
        #Write-Log -Message "A system restart is required before the installation of $installTitle can proceed." -Severity 2
        #Show-InstallationPrompt -Message "A system restart is required before the installation of $installTitle can proceed, please reboot at your earliest convenience." -ButtonRightText 'OK'
        #Exit-Script -ExitCode 69004 #This code is to indicate a reboot is pending on this machine, and the installation cannot proceed.
        #}
  
        [string]$installPhase = 'Installation'

        If ($ENV:PROCESSOR_ARCHITECTURE -eq 'x86'){
        Write-Log -Message "Detected 32-bit OS Architecture." -Severity 1 -Source $deployAppScriptFriendlyName

        ## Install SonicWall NetExtender (32-bit)
        $MsiPath32 = Get-ChildItem -Path "$dirFiles" -Include NetExtender*x86*.msi -File -Recurse -ErrorAction SilentlyContinue
        $Transform32 = Get-ChildItem -Path "$dirFiles" -Include NetExtender*x86*.mst -File -Recurse -ErrorAction SilentlyContinue
        $ExePath32 = Get-ChildItem -Path "$dirFiles" -Include NXSetupU-x86*.exe -File -Recurse -ErrorAction SilentlyContinue

        If(($MsiPath32.Exists) -and ($Transform32.Exists))
        {
        Write-Log -Message "Found $($MsiPath32.FullName) and $($Transform32.FullName), now attempting to install $installTitle."
        Show-InstallationProgress "Installing SonicWall NetExtender. This may take some time. Please wait..."
        Execute-MSI -Action Install -Path "$MsiPath32" -AddParameters "TRANSFORMS=$Transform32"
        }

        ElseIf($MsiPath32.Exists)
        {
        Write-Log -Message "Found $($MsiPath32.FullName), now attempting to install $installTitle."
        Show-InstallationProgress "Installing SonicWall NetExtender. This may take some time. Please wait..."
        Execute-MSI -Action Install -Path "$MsiPath32" -AddParameters "ALLUSERS=1 SERVER=ServerXYZ DOMAIN=vpn.companyxyz.com"
        }  

        ElseIf($ExePath32.Exists)
        {
        Write-Log -Message "Found $($ExePath32.FullName), now attempting to install $installTitle."
        Show-InstallationProgress "Installing  SonicWall NetExtender. This may take some time. Please wait..."
        Execute-Process -Path "$ExePath32" -Parameters "/S" -WindowStyle Hidden
        Start-Sleep -Seconds 10
        }

        }
        Else
        {
        Write-Log -Message "Detected 64-bit OS Architecture" -Severity 1 -Source $deployAppScriptFriendlyName

        ## Install SonicWall NetExtender (64-bit)
        $MsiPath64 = Get-ChildItem -Path "$dirFiles" -Include NetExtender*x64*.msi -File -Recurse -ErrorAction SilentlyContinue
        $Transform64 = Get-ChildItem -Path "$dirFiles" -Include NetExtender*x64*.mst -File -Recurse -ErrorAction SilentlyContinue
        $ExePath64 = Get-ChildItem -Path "$dirFiles" -Include NXSetupU-x64*.exe -File -Recurse -ErrorAction SilentlyContinue

        If(($MsiPath64.Exists) -and ($Transform64.Exists))
        {
        Write-Log -Message "Found $($MsiPath64.FullName) and $($Transform64.FullName), now attempting to install $installTitle."
        Show-InstallationProgress "Installing SonicWall NetExtender. This may take some time. Please wait..."
        Execute-MSI -Action Install -Path "$MsiPath64" -AddParameters "TRANSFORMS=$Transform64"
        }

        ElseIf($MsiPath64.Exists)
        {
        Write-Log -Message "Found $($MsiPath64.FullName), now attempting to install $installTitle."
        Show-InstallationProgress "Installing SonicWall NetExtender. This may take some time. Please wait..."
        Execute-MSI -Action Install -Path "$MsiPath64" -AddParameters "ALLUSERS=1 SERVER=ServerXYZ DOMAIN=vpn.companyxyz.com"
        }  

        ElseIf($ExePath64.Exists)
        {
        Write-Log -Message "Found $($ExePath64.FullName), now attempting to install $installTitle."
        Show-InstallationProgress "Installing  SonicWall NetExtender. This may take some time. Please wait..."
        Execute-Process -Path "$ExePath64" -Parameters "/S" -WindowStyle Hidden
        Start-Sleep -Seconds 10
        }
        }

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

    }
    
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}

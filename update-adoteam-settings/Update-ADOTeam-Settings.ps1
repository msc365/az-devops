<#
.SYNOPSIS
    Updates team settings for a new project team as a self-service solution.
.DESCRIPTION
    Updates team settings, that comply with organization Azure DevOps governance. 
.PARAMETER Organization
    Name of the organization.
.PARAMETER ProjectName
    Name of the project where to create a team.
.PARAMETER TeamName
    Name of the team to create.
.PARAMETER TeamSettings
    Settings of the team to update in JSON format.
.PARAMETER ApiVersion
    The API version to use with the Invoke end point; default 7.1-preview.

.EXAMPLE
    .\Update-ADOTeam-Settings.ps1 `
        -Organization $env:MSC365_ORGANIZATION -ProjectName $env:MSC365_PROJECT_NAME `
        -TeamName $env:MSC365_TEAM_NAME -TeamSettings $settingsJson -Verbose

    The following local/pipeline variables must be set as part of the solution:

    $env:MSC365_ORGANIZATION = "msc365"
    $env:MSC365_PROJECT_NAME = "az-devops"
    $env:MSC365_TEAM_NAME = "Demo Team A"
    $env:MSC365_API_VERSION = "7.1-preview"
    $env:MSC365_PAT = "{PAT-GOES-HERE}"
    
    The following local/pipeline task environment variables must be set as part of the solution:

    $env:AZURE_DEVOPS_EXT_PAT = $env:MSC365_PAT
    $env:AZURE_DEVOPS_EXT_GIT_SOURCE_PASSWORD_OR_PAT = $env:MSC365_PAT
-----------------------------------------------------------------------------------------------------------------------------------
Script name : Update-DevOpsTeamSettings.ps1
Authors : Martin Swinkels (DevOps Engineer, MSc365.eu Netherlands)
Version : 1.230118.0-beta
Dependencies : az cli, az devops cli
-----------------------------------------------------------------------------------------------------------------------------------
Version Changes:
Date:       Version: Changed By:     Info:
-----------------------------------------------------------------------------------------------------------------------------------
DISCLAIMER
   THIS CODE IS SAMPLE CODE. THESE SAMPLES ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND.
   MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES
   OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK ARISING OUT OF THE USE OR
   PERFORMANCE OF THE SAMPLES REMAINS WITH YOU. IN NO EVENT SHALL MICROSOFT OR ITS SUPPLIERS BE LIABLE FOR
   ANY DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS
   INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR
   INABILITY TO USE THE SAMPLES, EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
   BECAUSE SOME STATES DO NOT ALLOW THE EXCLUSION OR LIMITATION OF LIABILITY FOR CONSEQUENTIAL OR
   INCIDENTAL DAMAGES, THE ABOVE LIMITATION MAY NOT APPLY TO YOU.
#>

[CmdletBinding()]
[OutputType([String])]
param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,
    [Parameter(Mandatory = $true)]
    [string]$TeamName,
    [Parameter(Mandatory = $true)]
    [string]$TeamSettings,
    [Parameter(Mandatory = $false)]
    [string]$ApiVersion = $env:MSC365_API_VERSION
)

# Store current prefernces
$currentWarningPreference = $WarningPreference
$currentVerbosePreference = $VerbosePreference
$currentDebugPreference = $DebugPreference

# Suppress warning messages that can't be avoided.
# $WarningPreference = 'SilentlyContinue'

# Suppress inquire debug message during local testing.
# $DebugPreference = 'Continue'
# Set VerbosePreference to Continue on debug mode.

if (${env:SYSTEM_DEBUG} -eq 'true') {
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'

    # Get-ChildItem -Path env: | Format-Table | Write-Output
}

$fn = "$($PSCmdlet.MyInvocation.MyCommand.Name)"
$st = Get-Date

Write-Verbose @"
    `r`n  Function...........: $fn
    `r  Started at ........: $($st.ToString('yyyy-MM-dd hh:mm:ss tt'))
    `r  VerbosePreference..: $VerbosePreference
    `r  DebugPreference....: $DebugPreference
    `r  WarningPreference..: $WarningPreference
"@

try {

    $validJson = "$($TeamSettings)" | Test-Json

    if (-not $validJson ) {
        throw "-TeamSettings input string is not in a valid JSON format."
    }

    # Configure defaults
    az devops configure --defaults `
        organization="https://dev.azure.com/$($Organization)" `
        project=$ProjectName

    Write-Verbose "`r`n  Initialized successfully."
    
    $config = az devops configure --list
    Write-Debug "`r`n  Config: $($config | ConvertTo-Json -Depth 99)"

    # Get project 
    # https://learn.microsoft.com/en-us/cli/azure/devops/project?view=azure-cli-latest#az-devops-project-show
    
    $project = az devops project show --project $ProjectName | ConvertFrom-Json
    Write-Verbose "`r`n  Found project successfully."
    Write-Debug ("`r`n  project: {0}" -f ($project | ConvertTo-Json -Depth 99))

    if (-not $null -eq $project) {
       
        $team = az devops team show --team $TeamName | ConvertFrom-Json
        Write-Verbose "`r`n  Found team successfully."
        Write-Debug ("`r`n  team: {0}" -f ($team | ConvertTo-Json -Depth 99))
        
        # Get team settings with az devops invoke
        # https://learn.microsoft.com/en-us/cli/azure/devops?view=azure-cli-latest#az-devops-invoke

        $settings = az devops invoke `
            --area work `
            --resource teamsettings `
            --route-parameters `
                project="$($project.id)" `
                team="$($team.id)" `
            --http-method GET `
            --api-version $ApiVersion `
            --output json | ConvertFrom-Json
        
        Write-Verbose "`r`n  Found current team settings successfully."
        Write-Debug ("`r`n  current teamsettings: {0}" -f ($settings | ConvertTo-Json -Depth 99))

        $infile = "body.json"
        Set-Content -Path $infile -Value $TeamSettings

        $newSettings = az devops invoke `
            --area work `
            --resource teamsettings `
            --route-parameters `
                project="$($project.id)" `
                team="$($team.id)" `
            --http-method PATCH `
            --in-file $infile `
            --api-version $ApiVersion `
            --output json | ConvertFrom-Json

        Remove-Item $infile -Force

        Write-Verbose "`r`n  Updated team settings successfully."
        Write-Debug ("`r`n  updated teamsettings: {0}" -f ($newSettings | ConvertTo-Json -Depth 99))      
    
        Write-Output -InputObject ($newSettings | ConvertTo-Json -Depth 99)
    }

    $et = Get-Date
    $rt = $et - $st  # Run Time
 
    # Format the output time
    if ($rt.TotalSeconds -lt 1) {
        $elapsed = "$($rt.TotalMilliseconds.ToString('#,0.0000')) Milliseconds"
    }
    elseif ($rt.TotalSeconds -gt 60) {
        $elapsed = "$($rt.TotalMinutes.ToString('#,0.0000')) Minutes"
    }
    else { 
        $elapsed = "$($rt.TotalSeconds.ToString('#,0.0000')) Seconds" 
    }
 
    Write-Verbose @"
        `r`n  Function...........: $fn
        `r  Finished at .......: $($et.ToString('yyyy-MM-dd hh:mm:ss tt'))
        `r  Elapsed time ......: $elapsed
"@ 

}
catch {
    Write-Verbose $_.Exception.Message
    throw $_.Exception.Message
}
finally {
    # Default preference values for PowerShell are:
    #   $WarningPreference = 'Continue'
    #   $VerbosePreference = 'SilentlyContinue'
    #   $DebugPreference = 'SilentlyContinue'

    # Restore preferences.
    $WarningPreference = $currentWarningPreference
    $VerbosePreference = $currentVerbosePreference
    $DebugPreference = $currentDebugPreference
}
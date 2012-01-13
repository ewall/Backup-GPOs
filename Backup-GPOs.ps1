<#

Backup-GPOs.ps1 -- by Eric Wallace <wallae@mmc.org>, December 2011

.SYNOPSIS

Automated backup of Group Policy objects.


.NOTES

This script must be run from an account with Domain Admins permissions on the target domain(s).


.PARAMETER domainLst

Domain name, or a list of domain names separated by commas only (no spaces!)


.PARAMETER searchTxt

A word or part of a word that should be in the GPO's display name. If you use this search option,
only the GPOs matching this term will be backed up.


.PARAMETER backupDir

Directory for saving the GPO backups. The folder structure will be created automatically.


.EXAMPLE

(Parameters can be listed in order, or by using optional named parameter flags shown in brackets.
Text must be in quotes if it contains spaces, otherwise quotes are unnecessary.)

Backup all GPOs from the current user's domain to the default location:
  .\Backup-GPOs.ps1

Backup all GPOs for multiple domains:
  .\Backup-GPOs.ps1 [-domainLst] mehealth.org,mmcf.mehealth.org,mhr.mehealth.org

Backup only GPOs with the word "test" in their name:
  .\Backup-GPOs.ps1 [-domainLst] mmcf.mehealth.org [-searchTxt] test
  
Backup defaults except to a specific directory (remember to use quotes if it contains spaces):
  .\Backup-GPOs.ps1 -backupDir C:\My_GPO_Backups
  
Use defaults, except cleanup backup folders older than 15 days:
  .\Backup-GPOs.ps1 -daysOld 15

Use defaults, except disable cleanup of old backup folders by specifying 0 days' retention (default):
  .\Backup-GPOs.ps1 -daysOld 0
  
All parameters specified positionally (note that here the search term is blank):
  .\Backup-GPOs.ps1 mmcf.mehealth.org "" C:\GPOBackups 15

#>

# configure via parameters
param  (
  [string]$domainLst    = ( [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() ).Name,
  [string]$searchTxt = "",
  [string]$backupDir = "C:\GPOBackups",
  [int]$daysOld = 0
)

# configure via default values
[boolean]$createReports = $true
[boolean]$cleanupBackups = $true
If ($daysOld -lt 1) { $cleanupBackups = $false }

### No user-serviceable parts beyond this point :P ###
$today = Get-Date -Format yyyy-MM-dd
$lastWrite = (Get-Date).AddDays(-$daysOld)
If (-Not (Test-Path $backupDir -PathType container)) { mkdir $backupDir | Out-Null }

# TODO: what to do with output?
"### Backup-GPOs.ps1 ###"
$gpm = New-Object -comObject GPMgmt.GPM
$k = $gpm.GetConstants()

# outer loop: each domain
$domainLst.Split(", ") | Foreach-Object {
  $domain = $_
  " - Domain: " + $domain

  # query GPOs
  $dom = $gpm.GetDomain($domain, "","")
  $sc = $gpm.CreateSearchCriteria() #empty criteria fetches all

  # custom search criteria
  If ($searchTxt -Ne "") {
    $sc.add($k.SearchPropertyGPODisplayName,$k.SearchOpContains, $searchTxt)
    " - GPO name contains: " + $searchTxt
  }

  # cleanup enabled?
  If ($cleanupBackups) {
    " - Removing backups older than " + $daysOld + " days"
  } Else {
    " - Do not cleanup old backups"
  }
  
  # inner loop-de-loop: each GPO
  $dom.SearchGPOs($sc) | ForEach-Object {
    # first-level folder structure
    $bupath = Join-Path $backupDir $domain
    If (-Not (Test-Path $bupath -PathType container)) {
      mkdir $bupath | Out-Null
    }

    # second-level folder structure
    $gponame = $_.DisplayName
    $bupath = Join-Path $bupath $gponame
    If (-Not (Test-Path $bupath -PathType container)) {
      mkdir $bupath | Out-Null
    }
    
    # cleanup older backups
    If ($cleanupBackups) {
      Get-ChildItem $bupath | `
        Where {$_.LastWriteTime -le "$lastWrite"} | `
        Remove-Item -Recurse -Force -EA:SilentlyContinue -WA:SilentlyContinue
    }
    
    # save report here
    If ($createReports) {
      $reportContent = $_.GenerateReport($k.ReportHTML)
      $reportFile = Join-Path $bupath ($gponame + '_' + $today + '.html')
      $reportContent.result | Out-File $reportFile
    }
    
    # third-level folder structure
    $bupath = Join-Path $bupath $today
    If (Test-Path $bupath -PathType container) {
      # note that if you've already run this today, this run will replace the earlier backup!
      Remove-Item -Recurse -Force $bupath
    }
    mkdir $bupath | Out-Null
    
    # actually do the backup
    $comment = 'Domain: ' + $domain + ' | GPO: ' + $gponame + ' | Date: ' + $today
    $result = $_.Backup( $bupath, $comment )
    $result.result # default pretty-print of COM object properties and values
    ""
  }

}

"Finished!"

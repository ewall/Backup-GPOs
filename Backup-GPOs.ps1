<#

Backup-GPOs.ps1 -- by Eric Wallace <wallae@mmc.org>, December 2011

.SYNOPSIS

Automated backup of Group Policy objects.

.REQUIREMENTS

This script must be run from an account with Domain Admins permissions on the target domain.

.PARAMETERS

# TODO: document parameters

.EXAMPLES

# TODO: document examples

#>

# configure via parameters
param  (
  [string]$domain    = ( [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() ).Name,
  [string]$searchTxt = "",
  [string]$backupDir = "C:\GPOBackups"
)

# configure via default values
[boolean]$createReports = $true

### No user-serviceable parts beyond this point :P ###
$today = Get-Date -Format yyyy-MM-dd
if (-Not (Test-Path $backupDir -PathType container)) { mkdir $backupDir | Out-Null }

# TODO: what to do with output?
"### Backup-GPOs.ps1 ###"
" - Domain: " + $domain

# query GPOs
$gpm = New-Object -comObject GPMgmt.GPM
$k = $gpm.GetConstants()
$dom = $gpm.GetDomain($domain, "","")
$sc = $gpm.CreateSearchCriteria() #empty criteria fetches all

# custom search criteria
If ($searchTxt -Ne "") {
  $sc.add($k.SearchPropertyGPODisplayName,$k.SearchOpContains, $searchTxt)
  " - GPO name contains: " + $searchTxt
}

# loop-de-loop
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

"Finished!"

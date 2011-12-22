<#

Backup-GPOs.ps1 -- by Eric Wallace <wallae@mmc.org>, December 2011

.SYNOPSIS

Automated backup of Group Policy objects.

.REQUIREMENTS

This script must be run from an account with Domain Admins permissions on the target domain.

#>

# configure via parameters or default values
param ( [string]$backupdir = "C:\GPOBackups", [boolean]$createreports = $true )

"### Backup All GPOs in this Domain ###"
"" #blank line

$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$domainname = $domain.Name
"Domain: " + $domainname
""

$today = Get-Date -Format yyyy-MM-dd
if (-not (Test-Path $backupdir -PathType container)) { mkdir $backupdir | Out-Null }
$backupdir = Join-Path $backupdir $today
if (Test-Path $backupdir -PathType container) {
  ### TODO: prompt, rmdir
} else {
  mkdir $backupdir | Out-Null
}
Set-Location $backupdir
"Directory: " + $backupdir

$gpm = New-Object -comObject GPMgmt.GPM
$k = $gpm.getconstants()
$dom = $gpm.getdomain($domainname,"","")
$sc = $gpm.CreateSearchCriteria() #empty criteria fetches all

$dom.SearchGPOs($sc) | % {
  $comment = $today + " backup of GPO: " + $_.DisplayName
  $result = $_.Backup( $backupdir, $comment )
  $comment + " results:"
  $result.result
  ""
}

if ($createreports) {
  "Creating HTML reports..."
  ""
  $bd = $gpm.GetBackupDir($backupdir)
  $bd.SearchBackups($sc) | % {
    $report = $_.GenerateReport($k.ReportHTML)
    $filename = $_.GPODisplayName + ".html"
    $filename
    $report.result | out-file $filename
    ""
  }
}
"Finished!"

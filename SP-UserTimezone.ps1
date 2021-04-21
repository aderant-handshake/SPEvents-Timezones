<#
    Must be run from SP Management Shell on the SharePoint Server 
#>
function Get-SPUserTimeZone() {
    <# Function to get the current SharePoint a time zone for a user. #>
    [Cmdletbinding()]
    param(
        [parameter(mandatory = $true, HelpMessage = "for example http://theportal.ourfirm.com")][String] $portalUrl,			
        [parameter(mandatory = $true, HelpMessage = "for example firm\jdoe")][String] $userLogin
    )
    $web = (Get-SPSite -Identity $portalUrl).RootWeb 
    $user = $web.SiteUsers | Where-Object { $_.userLogin -eq $userLogin }
    if ($user) {
        $tz = $user.RegionalSettings.TimeZone
        Write-Verbose "Current timezone setting for $($user.displayName): $($tz.ID) - $($tz.Description)"
        return $tz
    }
    else {
        Write-Error "Login not found for $userLogin"
    }
}

function Set-SPUserTimeZone() {
    <# Function  to SET user time zones #>
    [Cmdletbinding()]
    param(
        [parameter(mandatory = $true, HelpMessage = "for example http://theportal.ourfirm.com")][String] $portalUrl,			
        [parameter(mandatory = $true, HelpMessage = "for example firm\jx123456")][String] $userLogin,
        [parameter(mandatory = $true, HelpMessage = "10 = EST or 13=PST")][uint16] $timezoneID
    )
			
    $web = (Get-SPSite -Identity $portalUrl).RootWeb 
    $user = $web.SiteUsers | Where-Object { $_.userLogin -eq $userLogin }
    if ($user) {
        $currentTZ = $user.RegionalSettings.TimeZone
        Write-Verbose "Current timezone setting for $($user.displayname) : $($currentTZ.description)"
        
        $regSettings = new-object Microsoft.SharePoint.SPRegionalSettings($web, $true);
        $newTimeZone = $regSettings.TimeZones | Where-Object { $_.ID -eq "$timezoneID" }
        $regSettings.TimeZone.ID = $newTimeZone.ID
        $user.RegionalSettings = $regSettings
        $user.Update()
        $newTZ = $user.RegionalSettings.TimeZone
        Write-Verbose "New timezone setting for $($user.displayName) : $($newtz.Description)"
        return $newTZ
    }
    else {
        Write-Error "Login not found for $userLogin"
    }
}

function Get-SPTimeZones() {
    <# Function get all available SP Timezones by ID and Description #>
    [Cmdletbinding()]
    param(
        [parameter(mandatory = $true, HelpMessage = "for example http://theportal.ourfirm.com")][String] $portalUrl
    )
	$web = (Get-SPSite -Identity $portalUrl).RootWeb 		
    $r = new-object Microsoft.SharePoint.SPRegionalSettings($web, $true);
    return $r.TimeZones
}

<# sample code 
    Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue
    $portalUrl = 'https://intranet.yourfirm.net'
    Set-SPUserTimeZone -portalUrl $portalUrl -userLogin "firm\someusernetworkid"  -timezoneID 13

    Get-SPTimeZones -portalUrl https://portal2021.handshakedemo.com | Sort-Object -property ID | Format-Table id, description
#>
Import-Module ActiveDirectory

$SourceAccount = "account1" ###SteveJobs Original
$TargetAccount = "account2" #NewCEO to give permissions to 

# Domain containing the user accounts
$UserServer = "cho.corp.ryanair.com"

function Get-DomainFromDistinguishedName {
    param (
        [Parameter(Mandatory)]
        [string]$DistinguishedName
    )

    (
        [regex]::Matches($DistinguishedName, 'DC=([^,]+)') |
        ForEach-Object { $_.Groups[1].Value }
    ) -join '.'
}

# Get the source and target users
$SourceUser = Get-ADUser -Identity $SourceAccount `
    -Server $UserServer `
    -Properties MemberOf

$TargetUser = Get-ADUser -Identity $TargetAccount `
    -Server $UserServer `
    -Properties MemberOf

# Create a list of the target user's current direct memberships
$TargetGroups = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($GroupDN in $TargetUser.MemberOf) {
    [void]$TargetGroups.Add($GroupDN)
}

$Added   = @()
$Skipped = @()
$Failed  = @()

foreach ($GroupDN in $SourceUser.MemberOf) {

    # Derive the group's domain from its distinguished name
    $GroupDomain = Get-DomainFromDistinguishedName `
        -DistinguishedName $GroupDN

    try {
        # Resolve the group using the domain where the group exists
        $Group = Get-ADGroup -Identity $GroupDN `
            -Server $GroupDomain `
            -ErrorAction Stop

        if ($TargetGroups.Contains($GroupDN)) {
            Write-Host "Already a member: $($Group.Name)" -ForegroundColor Yellow
            $Skipped += $Group.Name
            continue
        }

        # Add the target user using the group's domain
        Add-ADGroupMember -Identity $Group.DistinguishedName `
            -Members $TargetUser `
            -Server $GroupDomain `
            -ErrorAction Stop

        Write-Host "Added: $($Group.Name)" -ForegroundColor Green

        $Added += $Group.Name
        [void]$TargetGroups.Add($GroupDN)
    }
    catch {
        Write-Warning "Failed: $GroupDN"
        Write-Warning $_.Exception.Message

        $Failed += [PSCustomObject]@{
            Group = $GroupDN
            Error = $_.Exception.Message
        }
    }
}

# Summary
Write-Host ""
Write-Host "Copy completed" -ForegroundColor Cyan
Write-Host "Source user : $($SourceUser.Name)"
Write-Host "Target user : $($TargetUser.Name)"
Write-Host "Source direct groups : $($SourceUser.MemberOf.Count)"
Write-Host "Added                : $($Added.Count)" -ForegroundColor Green
Write-Host "Already present       : $($Skipped.Count)" -ForegroundColor Yellow
Write-Host "Failed                 : $($Failed.Count)" -ForegroundColor Red

if ($Failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed groups:" -ForegroundColor Red
    $Failed | Format-Table -AutoSize
}

param(
    [switch]$WhatIf
)

Import-Module ActiveDirectory -ErrorAction Stop

$source = Get-ADGroup -Identity "Payroll" -ErrorAction Stop     # Original group
$target = Get-ADGroup -Identity "NewPayroll" -ErrorAction Stop  # New group

if ($source.DistinguishedName -eq $target.DistinguishedName) {
    throw "Source and destination groups must be different."
}

$sourceUsers = @(
    Get-ADGroupMember -Identity $source -ErrorAction Stop |
        Where-Object { $_.objectClass -eq "user" }
)

$targetMembers = @(
    Get-ADGroupMember -Identity $target -ErrorAction Stop |
        Select-Object -ExpandProperty DistinguishedName
)

foreach ($user in $sourceUsers) {
    if ($targetMembers -contains $user.DistinguishedName) {
        Write-Host "Already a member: $($user.SamAccountName)"
        continue
    }

    try {
        Add-ADGroupMember -Identity $target `
            -Members $user.DistinguishedName `
            -WhatIf:$WhatIf `
            -ErrorAction Stop

        if (-not $WhatIf) {
            Write-Host "Added: $($user.SamAccountName)"
        }
    }
    catch {
        Write-Warning "Failed to add $($user.SamAccountName): $($_.Exception.Message)"
    }
}

# Refresh both groups for verification
$sourceUsersAfter = @(
    Get-ADGroupMember -Identity $source -ErrorAction Stop |
        Where-Object { $_.objectClass -eq "user" }
)

$targetUsersAfter = @(
    Get-ADGroupMember -Identity $target -ErrorAction Stop |
        Where-Object { $_.objectClass -eq "user" }
)

Write-Host "`n--- Direct user membership counts ---"

@(
    [PSCustomObject]@{
        Group     = $source.Name
        UserCount = $sourceUsersAfter.Count
    }
    [PSCustomObject]@{
        Group     = $target.Name
        UserCount = $targetUsersAfter.Count
    }
) | Format-Table -AutoSize

# Check that every source user exists in the destination
$targetUserDNs = @(
    $targetUsersAfter | Select-Object -ExpandProperty DistinguishedName
)

$missingUsers = @(
    $sourceUsersAfter |
        Where-Object { $_.DistinguishedName -notin $targetUserDNs }
)

if ($WhatIf) {
    Write-Host "Preview only: no changes were made. Counts reflect current membership."
}

if ($missingUsers.Count -eq 0) {
    Write-Host "Verified: all current direct users in Payroll are members of NewPayroll." `
        -ForegroundColor Green
}
else {
    Write-Warning "Payroll users missing from NewPayroll: $($missingUsers.Count)"
    $missingUsers | Select-Object Name, SamAccountName | Format-Table -AutoSize
}

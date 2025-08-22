# Import the Active Directory module
Import-Module ActiveDirectory

# List of usernames to check
$users = @("smithc", "johndoe")

# List of groups to check
$groups = @("Finance", "HR", "Materials", "Admin")

# Get current user's desktop path
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$outputFile = Join-Path $desktopPath "GroupMembershipCheckResults.txt"

# Clear previous output if it exists
if (Test-Path $outputFile) {
    Clear-Content -Path $outputFile
}

# Check each user against each group
foreach ($user in $users) {
    $userExists = Get-ADUser -Identity $user -ErrorAction SilentlyContinue
    if (-not $userExists) {
        $msg = "❌ User '$user' does not exist."
        Write-Host $msg
        Add-Content -Path $outputFile -Value $msg
        continue
    }

    foreach ($group in $groups) {
        $groupExists = Get-ADGroup -Identity $group -ErrorAction SilentlyContinue
        if (-not $groupExists) {
            $msg = "❌ Group '$group' does not exist."
            Write-Host $msg
            Add-Content -Path $outputFile -Value $msg
            continue
        }

        $isMember = Get-ADGroupMember -Identity $group -Recursive -ErrorAction SilentlyContinue | Where-Object {
            $_.objectClass -eq 'user' -and $_.SamAccountName -eq $user
        }

        if ($isMember) {
            $msg = "✅ $user is a member of '$group'."
        } else {
            $msg = "❌ $user is NOT a member of '$group'."
        }

        Write-Host $msg
        Add-Content -Path $outputFile -Value $msg
    }
}

# Final message
Write-Host "`nCheck complete. Results saved to: $outputFile"

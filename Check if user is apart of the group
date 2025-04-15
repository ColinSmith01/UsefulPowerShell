# Import the Active Directory module
Import-Module ActiveDirectory

# Function to check if multiple users are members of the specified group
function Check-UsersInGroup {
    param (
        [string[]]$usernames,
        [string]$groupName
    )

    # Get all members of the specified group
    $groupMembers = Get-ADGroupMember -Identity $groupName | Where-Object { $_.objectClass -eq 'user' }

    foreach ($username in $usernames) {
        $user = $groupMembers | Where-Object { $_.SamAccountName -eq $username }

        if ($user) {
            Write-Output "$username is a member of the $groupName group."
        } else {
            Write-Output "$username is not a member of the $groupName group."
        }
    }
}

# Example usage

Check-UsersInGroup -usernames @("smithmary", "smithjohn", "smithcol")  -groupName "FamilyTree" #Change to relevant AD group youre checking

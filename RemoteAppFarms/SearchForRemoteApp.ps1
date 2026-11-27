#Search for an app called Banking 30.0.0 with 3 session hosts for it.
$Servers = @(
    'SessionHostServer1.cho.corp.ryanair.com'
    'SessionHostServer2.cho.corp.ryanair.com'
    'SessionHostServer3.cho.corp.ryanair.com'
)

foreach ($Server in $Servers) {
    Write-Host "`n===== $Server : Banking 30.0.0 =====" -ForegroundColor Cyan

    try {
        $Matches = @(
            Invoke-Command -ComputerName $Server -ErrorAction Stop -ScriptBlock {
                # Matches Windows or forward-slash paths.
                $Pattern = 'Banking[\\/]30\.0\.0\b'

                $Processes = Get-CimInstance Win32_Process -ErrorAction Stop |
                    Where-Object {
                        $_.SessionId -gt 0 -and (
                            $_.ExecutablePath -match $Pattern -or
                            $_.CommandLine -match $Pattern
                        )
                    }

                foreach ($Process in $Processes) {
                    $User = '[Owner unavailable]'

                    try {
                        $Owner = Invoke-CimMethod -InputObject $Process `
                            -MethodName GetOwner -ErrorAction Stop

                        if ($Owner.ReturnValue -eq 0) {
                            $User = "$($Owner.Domain)\$($Owner.User)"
                        }
                    }
                    catch {
                        # The process may have exited during the query.
                    }

                    [PSCustomObject]@{
                        User        = $User
                        SessionId   = $Process.SessionId
                        Process     = $Process.Name
                        PID         = $Process.ProcessId
                        Path        = $Process.ExecutablePath
                        CommandLine = $Process.CommandLine
                    }
                }
            }
        )

        if ($Matches.Count -eq 0) {
            Write-Host "No matching Banking 30.0.0 processes found." -ForegroundColor Yellow
        }
        else {
            $Matches |
                Sort-Object User, SessionId, Process |
                Select-Object User, SessionId, Process, PID, Path, CommandLine |
                Format-List |
                Out-Host
        }
    }
    catch {
        Write-Warning "Unable to query ${Server}: $($_.Exception.Message)"
    }
}

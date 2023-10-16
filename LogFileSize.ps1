$job = Start-Job -ScriptBlock {
    $volume = Get-Volume -DriveLetter C

    $start = Get-Date

    # System
    $firstSystemLog = (Get-WinEvent -LogName "System" | select TimeCreated -Last 1)
    $firstApplicationLog = (Get-WinEvent -LogName "Application" | select TimeCreated -Last 1)
    $firstSecurityLog = (Get-WinEvent -LogName "Security" | select TimeCreated -Last 1)

    $vals = @{
        Hostname = $env:computername
        ReportDate = (Get-Date).ToUniversalTime().toString("r")
        Logs = @{
            # System
            System = @{
                LogSize = $(Get-Item -Path "C:\Windows\System32\winevt\Logs\System.evtx" | Select Length).Length
                Logs = (Get-WinEvent -LogName "System").Count
                EarliestLog = $firstSystemLog.TimeCreated
                EarliestLogFormatted = $firstSystemLog.TimeCreated.ToUniversalTime().toString("r")
            }
            # Application
            Application = @{
                LogSize = $(Get-Item -Path "C:\Windows\System32\winevt\Logs\Application.evtx" | Select Length).Length
                Logs = (Get-WinEvent -LogName "Application").Count
                EarliestLog = $firstApplicationLog.TimeCreated
                EarliestLogFormatted = $firstApplicationLog.TimeCreated.ToUniversalTime().toString("r")
            }
            # Security
            Security = @{
                LogSize = $(Get-Item -Path "C:\Windows\System32\winevt\Logs\Security.evtx" | Select Length).Length
                Logs = (Get-WinEvent -LogName "System").Count
                EarliestLog = $firstSecurityLog.TimeCreated
                EarliestLogFormatted = $firstSecurityLog.TimeCreated.ToUniversalTime().toString("r")
            }      
        }
        #Drive information
        Drive = @{
            Size = $volume.Size
            SizeGB = $volume.Size/1GB
            SpaceRemaining = $volume.SizeRemaining
            SpaceRemainingGB = $volume.SizeRemaining/1GB
        }
    }

    #$logs = @('System', 'Application')
    $logs = @('System', 'Application', 'Security')
    foreach($ind in $logs){

        # Set total days
        $vals['Logs'][$ind].Add('DaysOfLogs', (NEW-TIMESPAN –Start $vals['Logs'][$ind]['EarliestLog'] –End (Get-Date)).Days)

        # Log size: MB and GB
        $vals['Logs'][$ind].Add('LogSizeMB', [math]::Round($vals['Logs'][$ind]['LogSize']/1MB,3))
        $vals['Logs'][$ind].Add('LogSizeGB', [math]::Round($vals['Logs'][$ind]['LogSize']/1GB,3))

        # Data per day
        $dataPerDay = [math]::Round($vals['Logs'][$ind]['LogSize']/ $vals['Logs'][$ind]['DaysOfLogs'])
        $vals['Logs'][$ind].Add('LogSizePerDayBytes', $dataPerDay)
        $vals['Logs'][$ind].Add('LogSizePerDayMB', [math]::Round($dataPerDay/1MB, 3))
        $vals['Logs'][$ind].Add('LogSizePerDayGB',[math]::Round($dataPerDay/1GB, 3))
    }

    # Logs retains
    $daysOfLogs = $( @($vals['Logs']['System']['DaysOfLogs'], $vals['Logs']['Application']['DaysOfLogs'], $vals['Logs']['Security']['DaysOfLogs']) | Measure-Object -Minimum).Minimum
    $vals['Logs'].Add('DaysOfLogsStored', $daysOfLogs)

    # Summary data per day
    $totalAmountPerDay = $vals['Logs']['System']['LogSizePerDayBytes'] + $vals['Logs']['Application']['LogSizePerDayBytes'] + $vals['Logs']['Security']['LogSizePerDayBytes']
    $vals['Logs'].Add('TotalLogPerDayBytes', $totalAmountPerDay)
    $vals['Logs'].Add('TotalLogPerDayMB', [math]::Round($totalAmountPerDay/1MB, 3))
    $vals['Logs'].Add('TotalLogPerDayGB', [math]::Round($totalAmountPerDay/1GB, 3))

    # Time to run task
    $vals.Add('TotalTimeToCheckLogsSeconds', (NEW-TIMESPAN –Start $start –End (Get-Date)).TotalSeconds)
    $vals.Add('TotalTimeToCheckLogsMinutes', (NEW-TIMESPAN –Start $start –End (Get-Date)).TotalMinutes)

    $vals | ConvertTo-Json
}

# Wait for the job to complete with a timeout. Timeout is in seconds. Currently set to 7200 (2 hours)
if (Wait-Job -Job $job -Timeout 7200) {
    # The job completed within the specified timeout
    Receive-Job $job
} else {
    # The job did not complete within the specified timeout, so we cancel it
    Write-Host "Job exceeded the timeout and will be canceled."
    Stop-Job -Job $job
}

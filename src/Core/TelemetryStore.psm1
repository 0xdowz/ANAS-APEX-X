# ANAS APEX X - Telemetry & History Store

class SessionRecord {
    [string]$SessionId
    [DateTime]$StartTime
    [DateTime]$EndTime
    [string]$Command
    [string]$Status
    [array]$Changes
    [hashtable]$Metrics

    SessionRecord([string]$command) {
        $this.SessionId = [Guid]::NewGuid().ToString()
        $this.StartTime = [DateTime]::UtcNow
        $this.Command = $command
        $this.Status = "In-Progress"
        $this.Changes = @()
        $this.Metrics = @{}
    }

    [void] Complete([string]$status, [array]$changes, [hashtable]$metrics) {
        $this.EndTime = [DateTime]::UtcNow
        $this.Status = $status
        $this.Changes = $changes
        $this.Metrics = $metrics
    }
}

class TelemetryStore {
    static [string]$StoreFilePath = ""
    static [object]$LockObject = [object]::new()
    static [SessionRecord]$CurrentSession = $null

    static [void] Initialize([string]$rootDir) {
        if (-not [string]::IsNullOrEmpty([TelemetryStore]::StoreFilePath)) {
            return
        }

        $logsFolder = Join-Path $rootDir "logs"
        if (-not (Test-Path $logsFolder)) {
            New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
        }

        [TelemetryStore]::StoreFilePath = Join-Path $logsFolder "telemetry.json"
        if (-not (Test-Path [TelemetryStore]::StoreFilePath)) {
            "[]" | Out-File -FilePath [TelemetryStore]::StoreFilePath -Encoding utf8 -Force
        }
    }

    static [SessionRecord] StartSession([string]$command) {
        [TelemetryStore]::CurrentSession = [SessionRecord]::new($command)
        return [TelemetryStore]::CurrentSession
    }

    static [void] EndCurrentSession([string]$status, [array]$changes, [hashtable]$metrics) {
        if ($null -eq [TelemetryStore]::CurrentSession) {
            return
        }

        [TelemetryStore]::CurrentSession.Complete($status, $changes, $metrics)
        [TelemetryStore]::SaveRecord([TelemetryStore]::CurrentSession)
        [TelemetryStore]::CurrentSession = $null
    }

    static [void] SaveRecord([SessionRecord]$record) {
        # Check bootstrapper path initialization
        if ([string]::IsNullOrEmpty([TelemetryStore]::StoreFilePath)) {
            # Go up two levels from src/Core to get root dir
            $scriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            [TelemetryStore]::Initialize($scriptDir)
        }

        [System.Threading.Monitor]::Enter([TelemetryStore]::LockObject)
        try {
            $history = @()
            if (Test-Path [TelemetryStore]::StoreFilePath) {
                try {
                    $json = Get-Content -Raw -Path [TelemetryStore]::StoreFilePath
                    if (-not [string]::IsNullOrEmpty($json)) {
                        $history = ConvertFrom-Json $json -ErrorAction Stop
                        if ($history -isnot [array]) {
                            $history = @($history)
                        }
                    }
                }
                catch {
                    # Reset corrupted log
                    $history = @()
                }
            }

            # Map the SessionRecord to a simple structure for JSON writing
            $recordMap = @{
                SessionId = $record.SessionId
                StartTime = $record.StartTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                EndTime = $record.EndTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                Command = $record.Command
                Status = $record.Status
                Changes = $record.Changes
                Metrics = $record.Metrics
            }

            $history += $recordMap
            $jsonOut = $history | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText([TelemetryStore]::StoreFilePath, $jsonOut)
        }
        finally {
            [System.Threading.Monitor]::Exit([TelemetryStore]::LockObject)
        }
    }

    static [array] GetHistory() {
        if ([string]::IsNullOrEmpty([TelemetryStore]::StoreFilePath)) {
            return @()
        }
        [System.Threading.Monitor]::Enter([TelemetryStore]::LockObject)
        try {
            if (-not (Test-Path [TelemetryStore]::StoreFilePath)) {
                return @()
            }
            $json = Get-Content -Raw -Path [TelemetryStore]::StoreFilePath
            if ([string]::IsNullOrEmpty($json)) {
                return @()
            }
            $history = ConvertFrom-Json $json
            if ($history -isnot [array]) {
                return @($history)
            }
            return $history
        }
        catch {
            return @()
        }
        finally {
            [System.Threading.Monitor]::Exit([TelemetryStore]::LockObject)
        }
    }

    static [void] ClearHistory() {
        [System.Threading.Monitor]::Enter([TelemetryStore]::LockObject)
        try {
            if (Test-Path [TelemetryStore]::StoreFilePath) {
                "[]" | Out-File -FilePath [TelemetryStore]::StoreFilePath -Encoding utf8 -Force
            }
        }
        finally {
            [System.Threading.Monitor]::Exit([TelemetryStore]::LockObject)
        }
    }
}

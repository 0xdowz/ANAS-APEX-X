using module "..\Core\EventBus.psm1"

# ANAS APEX X - Logger Module

class Context {
    static [bool]$Silent = $false
    static [bool]$Verbose = $false
    static [bool]$DryRun = $false
    static [bool]$Force = $false
    static [bool]$Interactive = $false
    static [bool]$Json = $false
}

enum LogLevel {
    DEBUG = 0
    INFO = 1
    SUCCESS = 2
    WARNING = 3
    ERROR = 4
    CRITICAL = 5
}

class ConsoleLogger {
    static [void] Write([hashtable]$logData) {
        # Check global silent and json overrides
        if ([Context]::Silent -or [Context]::Json) {
            return
        }

        $level = $logData.Level
        $message = $logData.Message
        $module = $logData.Module
        $duration = $logData.DurationMs

        # For debug, check if verbose is enabled
        if ($level -eq [LogLevel]::DEBUG -and -not [Context]::Verbose) {
            return
        }

        $timestamp = $logData.Timestamp.ToString("HH:mm:ss.fff")
        $moduleStr = if ([string]::IsNullOrEmpty($module)) { "" } else { "[$module] " }
        $durationStr = if ($null -ne $duration) { " (${duration}ms)" } else { "" }

        # Resolve int values for comparison
        $lvlVal = [int]$level
        if ($lvlVal -eq [int][LogLevel]::DEBUG) {
            Write-Host "[$timestamp] [DEBUG] $moduleStr$message$durationStr" -ForegroundColor Gray
        }
        elseif ($lvlVal -eq [int][LogLevel]::INFO) {
            Write-Host "i $moduleStr$message$durationStr" -ForegroundColor White
        }
        elseif ($lvlVal -eq [int][LogLevel]::SUCCESS) {
            Write-Host "v $moduleStr$message$durationStr" -ForegroundColor Green
        }
        elseif ($lvlVal -eq [int][LogLevel]::WARNING) {
            Write-Host "! $moduleStr$message$durationStr" -ForegroundColor Yellow
        }
        elseif ($lvlVal -eq [int][LogLevel]::ERROR) {
            Write-Host "x $moduleStr$message$durationStr" -ForegroundColor Red
        }
        elseif ($lvlVal -eq [int][LogLevel]::CRITICAL) {
            Write-Host " [CRITICAL] $moduleStr$message$durationStr" -ForegroundColor White -BackgroundColor DarkRed
        }
    }

    static [void] Header([string]$title) {
        if ([Context]::Silent -or [Context]::Json) { return }
        $sep = [string][char]0x2500 * 40
        Write-Host $sep -ForegroundColor Cyan
        Write-Host "  $($title.ToUpper())" -ForegroundColor White
        Write-Host $sep -ForegroundColor Cyan
    }

    static [void] Footer() {
        if ([Context]::Silent -or [Context]::Json) { return }
        $sep = [string][char]0x2500 * 40
        Write-Host $sep -ForegroundColor Cyan
    }

    static [void] Separator() {
        if ([Context]::Silent -or [Context]::Json) { return }
        $sep = [string][char]0x2500 * 40
        Write-Host $sep -ForegroundColor Gray
    }

    static [void] Row([string]$label, [string]$status, [string]$extra = "") {
        if ([Context]::Silent -or [Context]::Json) { return }
        $icon = "i"
        $color = "White"

        switch ($status.ToUpper()) {
            "SUCCESS" {
                $icon = "v"
                $color = "Green"
            }
            "WARNING" {
                $icon = "!"
                $color = "Yellow"
            }
            "FAILED" {
                $icon = "x"
                $color = "Red"
            }
            "SKIPPED" {
                $icon = "->"
                $color = "Gray"
            }
        }

        $extraStr = if ([string]::IsNullOrEmpty($extra)) { "" } else { " ($extra)" }
        Write-Host "  $icon $label$extraStr" -ForegroundColor $color
    }

    static [void] Table([string[]]$headers, [array]$rows) {
        if ([Context]::Silent -or [Context]::Json) { return }
        if ($rows.Count -eq 0) { return }

        # Calculate widths
        $widths = @{}
        for ($i = 0; $i -lt $headers.Count; $i++) {
            $widths[$i] = $headers[$i].Length
        }

        foreach ($row in $rows) {
            for ($i = 0; $i -lt $headers.Count; $i++) {
                $valStr = if ($null -eq $row[$i]) { "" } else { $row[$i].ToString() }
                if ($valStr.Length -gt $widths[$i]) {
                    $widths[$i] = $valStr.Length
                }
            }
        }

        # Build borders using Unicode characters
        $topBorder = [char]0x250c
        $headerLine = [char]0x2502
        $midBorder = [char]0x251c
        $botBorder = [char]0x2514

        for ($i = 0; $i -lt $headers.Count; $i++) {
            $width = $widths[$i] + 2
            $topBorder += [string][char]0x2500 * $width
            $midBorder += [string][char]0x2500 * $width
            $botBorder += [string][char]0x2500 * $width
            
            $padHeader = " " + $headers[$i] + (" " * ($width - $headers[$i].Length - 1))
            $headerLine += $padHeader

            if ($i -lt $headers.Count - 1) {
                $topBorder += [char]0x252c
                $headerLine += [char]0x2502
                $midBorder += [char]0x253c
                $botBorder += [char]0x2534
            } else {
                $topBorder += [char]0x2510
                $headerLine += [char]0x2502
                $midBorder += [char]0x2524
                $botBorder += [char]0x2518
            }
        }

        Write-Host $topBorder -ForegroundColor Gray
        Write-Host $headerLine -ForegroundColor White
        Write-Host $midBorder -ForegroundColor Gray

        foreach ($row in $rows) {
            $rowLine = [char]0x2502
            for ($i = 0; $i -lt $headers.Count; $i++) {
                $width = $widths[$i] + 2
                $valStr = if ($null -eq $row[$i]) { "" } else { $row[$i].ToString() }
                $padVal = " " + $valStr + (" " * ($width - $valStr.Length - 1))
                $rowLine += $padVal
                $rowLine += [char]0x2502
            }
            Write-Host $rowLine -ForegroundColor Gray
        }

        Write-Host $botBorder -ForegroundColor Gray
    }
}

class FileLogger {
    static [string]$LogFilePath = ""
    static [object]$LockObject = [object]::new()

    static [void] Initialize([string]$rootDir) {
        if (-not [string]::IsNullOrEmpty([FileLogger]::LogFilePath)) {
            return
        }

        $logsFolder = Join-Path $rootDir "logs"
        if (-not (Test-Path $logsFolder)) {
            New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
        }

        [FileLogger]::LogFilePath = Join-Path $logsFolder "apex.log"
    }

    static [void] Write([hashtable]$logData) {
        if ([string]::IsNullOrEmpty([FileLogger]::LogFilePath)) {
            $scriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            [FileLogger]::Initialize($scriptDir)
        }

        $timestamp = $logData.Timestamp.ToString("yyyy-MM-dd HH:mm:ss.fff")
        $level = $logData.Level.ToString()
        $module = if ([string]::IsNullOrEmpty($logData.Module)) { "SYSTEM" } else { $logData.Module.ToUpper() }
        $message = $logData.Message
        $duration = if ($null -ne $logData.DurationMs) { " [Duration: $($logData.DurationMs)ms]" } else { "" }

        $logLine = "[$timestamp] [$level] [$module] $message$duration`r`n"

        [System.Threading.Monitor]::Enter([FileLogger]::LockObject)
        try {
            [System.IO.File]::AppendAllText([FileLogger]::LogFilePath, $logLine)
        }
        catch {}
        finally {
            [System.Threading.Monitor]::Exit([FileLogger]::LockObject)
        }
    }
}

class JSONLogger {
    static [string]$LogFilePath = ""
    static [object]$LockObject = [object]::new()

    static [void] Initialize([string]$rootDir) {
        if (-not [string]::IsNullOrEmpty([JSONLogger]::LogFilePath)) {
            return
        }

        $logsFolder = Join-Path $rootDir "logs"
        if (-not (Test-Path $logsFolder)) {
            New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
        }

        [JSONLogger]::LogFilePath = Join-Path $logsFolder "apex.jsonl"
    }

    static [void] Write([hashtable]$logData) {
        if ([string]::IsNullOrEmpty([JSONLogger]::LogFilePath)) {
            $scriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            [JSONLogger]::Initialize($scriptDir)
        }

        $logObj = [PSCustomObject]@{
            timestamp   = $logData.Timestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            level       = $logData.Level.ToString()
            module      = $logData.Module
            message     = $logData.Message
            duration_ms = $logData.DurationMs
        }

        $jsonLine = ($logObj | ConvertTo-Json -Compress) + "`n"

        [System.Threading.Monitor]::Enter([JSONLogger]::LockObject)
        try {
            [System.IO.File]::AppendAllText([JSONLogger]::LogFilePath, $jsonLine)
        }
        catch {}
        finally {
            [System.Threading.Monitor]::Exit([JSONLogger]::LockObject)
        }
    }
}

class PerformanceMetric {
    [string]$Module
    [string]$Task
    [int]$DurationMs
    [DateTime]$Timestamp

    PerformanceMetric([string]$module, [string]$task, [int]$durationMs) {
        $this.Module = $module
        $this.Task = $task
        $this.DurationMs = $durationMs
        $this.Timestamp = [DateTime]::UtcNow
    }
}

class PerformanceLogger {
    static [System.Collections.Generic.List[PerformanceMetric]]$History = [System.Collections.Generic.List[PerformanceMetric]]::new()
    static [object]$LockObject = [object]::new()

    static [void] Record([string]$module, [string]$task, [int]$durationMs) {
        $metric = [PerformanceMetric]::new($module, $task, $durationMs)
        [System.Threading.Monitor]::Enter([PerformanceLogger]::LockObject)
        try {
            [PerformanceLogger]::History.Add($metric)
        }
        finally {
            [System.Threading.Monitor]::Exit([PerformanceLogger]::LockObject)
        }
    }

    static [array] GetMetrics() {
        [System.Threading.Monitor]::Enter([PerformanceLogger]::LockObject)
        try {
            return [PerformanceLogger]::History.ToArray()
        }
        finally {
            [System.Threading.Monitor]::Exit([PerformanceLogger]::LockObject)
        }
    }

    static [void] Clear() {
        [System.Threading.Monitor]::Enter([PerformanceLogger]::LockObject)
        try {
            [PerformanceLogger]::History.Clear()
        }
        finally {
            [System.Threading.Monitor]::Exit([PerformanceLogger]::LockObject)
        }
    }

    static [hashtable] GetSummary() {
        $metrics = [PerformanceLogger]::GetMetrics()
        if ($metrics.Count -eq 0) {
            return @{
                TotalOperations = 0
                TotalDurationMs = 0
                AverageDurationMs = 0
            }
        }

        $totalMs = 0
        $moduleStats = @{}

        foreach ($m in $metrics) {
            $totalMs += $m.DurationMs
            if (-not $moduleStats.ContainsKey($m.Module)) {
                $moduleStats[$m.Module] = @{
                    Count = 0
                    DurationMs = 0
                }
            }
            $moduleStats[$m.Module].Count++
            $moduleStats[$m.Module].DurationMs += $m.DurationMs
        }

        return @{
            TotalOperations = $metrics.Count
            TotalDurationMs = $totalMs
            AverageDurationMs = [Math]::Round($totalMs / $metrics.Count, 2)
            ModuleBreakdown = $moduleStats
        }
    }
}

class Logger {
    static [void] Log([LogLevel]$level, [string]$message, [string]$module, [Nullable[int]]$durationMs) {
        $logData = @{
            Timestamp = [DateTime]::UtcNow
            Level = $level
            Message = $message
            Module = $module
            DurationMs = $durationMs
        }

        [ConsoleLogger]::Write($logData)
        [FileLogger]::Write($logData)
        [JSONLogger]::Write($logData)
        
        if ($null -ne $durationMs) {
            [PerformanceLogger]::Record($module, $message, $durationMs)
        }
    }

    static [void] Debug([string]$message, [string]$module) {
        [Logger]::Log([LogLevel]::DEBUG, $message, $module, $null)
    }

    static [void] Info([string]$message, [string]$module) {
        [Logger]::Log([LogLevel]::INFO, $message, $module, $null)
    }

    static [void] Success([string]$message, [string]$module) {
        [Logger]::Log([LogLevel]::SUCCESS, $message, $module, $null)
    }

    static [void] Warning([string]$message, [string]$module) {
        [Logger]::Log([LogLevel]::WARNING, $message, $module, $null)
    }

    static [void] Error([string]$message, [string]$module) {
        [Logger]::Log([LogLevel]::ERROR, $message, $module, $null)
    }

    static [void] Critical([string]$message, [string]$module) {
        [Logger]::Log([LogLevel]::CRITICAL, $message, $module, $null)
    }

    static [void] Header([string]$title) {
        [ConsoleLogger]::Header($title)
    }

    static [void] Footer() {
        [ConsoleLogger]::Footer()
    }

    static [void] Separator() {
        [ConsoleLogger]::Separator()
    }
}

# Register to the Event Bus for fully-decoupled operations using dynamic execution
& ([ScriptBlock]::Create("[EventBus]::RegisterListener('Log', `$args[0])")) {
    param($evt)
    if ($null -ne $evt -and $null -ne $evt.Message) {
        $level = [LogLevel]::INFO
        if ($evt.Level) {
            $level = [LogLevel]$evt.Level
        }
        $module = "System"
        if ($evt.Module) {
            $module = $evt.Module
        }
        $duration = $null
        if ($evt.DurationMs) {
            $duration = [Nullable[int]]$evt.DurationMs
        }
        [Logger]::Log($level, $evt.Message, $module, $duration)
    }
}

# Subscribe to dynamic error tracking
& ([ScriptBlock]::Create("[EventBus]::RegisterListener('ErrorRaised', `$args[0])")) {
    param($evt)
    if ($null -ne $evt) {
        [Logger]::Log([LogLevel]::ERROR, "Exception raised in command '$($evt.Command)': $($evt.Error)", "CommandBus", $null)
    }
}

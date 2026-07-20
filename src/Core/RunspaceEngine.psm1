using module "..\Logger\Logger.psm1"

# ANAS APEX X - Asynchronous Runspace Engine

class RunspaceEngine {
    static [object] ExecuteAsync([scriptblock]$taskScript, [object]$argument) {
        # Initialize background PowerShell instance
        $ps = [powershell]::Create()
        $null = $ps.AddScript($taskScript)
        if ($null -ne $argument) {
            $null = $ps.AddArgument($argument)
        }

        # Begin asynchronous execution
        $handle = $ps.BeginInvoke()
        
        # Responsive spinner frames for console rendering
        $spinner = @("|", "/", "-", "\")
        $spinnerIdx = 0

        while (-not $handle.IsCompleted) {
            if (-not [Context]::Silent -and -not [Context]::Json) {
                $frame = $spinner[$spinnerIdx % $spinner.Count]
                Write-Host "`r  [$frame] Executing asynchronous task in background..." -NoNewline -ForegroundColor Cyan
                $spinnerIdx++
            }
            Start-Sleep -Milliseconds 100
        }

        if (-not [Context]::Silent -and -not [Context]::Json) {
            Write-Host "`r                                                       `r" -NoNewline
        }

        # Retrieve async execution result
        $result = $ps.EndInvoke($handle)
        
        # Check for errors in background runspace
        if ($ps.Streams.Error.Count -gt 0) {
            foreach ($err in $ps.Streams.Error) {
                [Logger]::Warning("Runspace background warning: $err", "RunspaceEngine")
            }
        }

        $ps.Dispose()
        return $result
    }
}

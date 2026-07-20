using module "..\Logger\Logger.psm1"

# ANAS APEX X - Command Bus (Rich CLI Router)

class CommandPayload {
    [string]$Command
    [string]$SubCommand
    [hashtable]$Arguments
    [bool]$Help
    [bool]$Json
    [bool]$Verbose
    [bool]$DryRun
    [bool]$Force
    [bool]$Interactive
    [bool]$Silent

    CommandPayload() {
        $this.Arguments = @{}
    }
}

class CommandBus {
    static [hashtable]$Handlers = @{}

    static [void] RegisterHandler([string]$command, [scriptblock]$handler) {
        [CommandBus]::Handlers[$command.ToLower()] = $handler
    }

    static [CommandPayload] Parse([string[]]$rawArgs) {
        $payload = [CommandPayload]::new()
        if ($null -eq $rawArgs -or $rawArgs.Count -eq 0) {
            $payload.Help = $true
            return $payload
        }

        $i = 0
        while ($i -lt $rawArgs.Count) {
            $arg = $rawArgs[$i]
            if ($arg.StartsWith("-")) {
                switch ($arg) {
                    { $_ -in "--help", "-h", "-?", "/?" } { $payload.Help = $true; break }
                    { $_ -in "--json", "-j" } { $payload.Json = $true; break }
                    "--verbose" { $payload.Verbose = $true; break }
                    "--dry-run" { $payload.DryRun = $true; break }
                    "--force" { $payload.Force = $true; break }
                    { $_ -in "--interactive", "-i" } { $payload.Interactive = $true; break }
                    "--silent" { $payload.Silent = $true; break }
                    default {
                        $key = $arg.TrimStart('-')
                        if ($i + 1 -lt $rawArgs.Count -and -not $rawArgs[$i + 1].StartsWith("-")) {
                            $payload.Arguments[$key] = $rawArgs[$i + 1]
                            $i++
                        } else {
                            $payload.Arguments[$key] = $true
                        }
                    }
                }
            } else {
                if ([string]::IsNullOrEmpty($payload.Command)) {
                    $payload.Command = $arg.ToLower()
                } elseif ([string]::IsNullOrEmpty($payload.SubCommand)) {
                    $payload.SubCommand = $arg.ToLower()
                } else {
                    if (-not $payload.Arguments.ContainsKey("positional")) {
                        $payload.Arguments["positional"] = [System.Collections.Generic.List[string]]::new()
                    }
                    $payload.Arguments["positional"].Add($arg)
                }
            }
            $i++
        }

        return $payload
    }

    static [void] Dispatch([string[]]$rawArgs) {
        $payload = [CommandBus]::Parse($rawArgs)

        [Context]::Silent = $payload.Silent
        [Context]::Verbose = $payload.Verbose
        [Context]::DryRun = $payload.DryRun
        [Context]::Force = $payload.Force
        [Context]::Interactive = $payload.Interactive
        [Context]::Json = $payload.Json

        # Handle global version check
        if ($payload.Command -eq "version") {
            [CommandBus]::ShowVersion($payload.Json)
            return
        }

        # Check for help command or flag with no command
        if ($payload.Help -and [string]::IsNullOrEmpty($payload.Command)) {
            [CommandBus]::ShowGlobalHelp()
            return
        }

        if ([string]::IsNullOrEmpty($payload.Command)) {
            [CommandBus]::ShowGlobalHelp()
            return
        }

        $handler = [CommandBus]::Handlers[$payload.Command]
        if ($null -ne $handler) {
            if ($payload.Help) {
                [CommandBus]::ShowCommandHelp($payload.Command)
                return
            }

            try {
                $handler.Invoke($payload)
            }
            catch {
                & ([ScriptBlock]::Create("[EventBus]::Publish('ErrorRaised', `$args[0])")) @{
                    Command = $payload.Command
                    Error = $_
                }
                throw $_
            }
        } else {
            Write-Host "Unknown command '$($payload.Command)'. Use 'apex --help' for details." -ForegroundColor Red
        }
    }

    static [void] ShowVersion([bool]$json) {
        $versionInfo = @{
            Application = "ANAS APEX X"
            Version = "2.0.0-release"
            Engine = "SQLite3 Native / RunspacePool Async"
            OSVersion = [System.Environment]::OSVersion.VersionString
            PowerShellVersion = $global:PSVersionTable.PSVersion.ToString()
        }

        if ($json) {
            Write-Host ($versionInfo | ConvertTo-Json -Compress)
        } else {
            $sep = [string][char]0x2500 * 52
            Write-Host $sep -ForegroundColor Cyan
            Write-Host "  ⚡ ANAS APEX X - Enterprise Windows Engine  " -ForegroundColor Yellow -NoNewline
            Write-Host "v2.0.0" -ForegroundColor Green
            Write-Host $sep -ForegroundColor Cyan
            Write-Host "  PowerShell Engine: $($versionInfo.PowerShellVersion)" -ForegroundColor Gray
            Write-Host "  Windows OS:        $($versionInfo.OSVersion)" -ForegroundColor Gray
            Write-Host "  Storage Engine:    SQLite3 Native (winsqlite3.dll)" -ForegroundColor Gray
            Write-Host $sep -ForegroundColor Cyan
        }
    }

    static [void] ShowGlobalHelp() {
        $sep = [string][char]0x2500 * 56
        Write-Host ""
        Write-Host $sep -ForegroundColor Cyan
        Write-Host "  ⚡ ANAS APEX X - Enterprise Windows Optimization Engine" -ForegroundColor Yellow
        Write-Host $sep -ForegroundColor Cyan
        Write-Host "Usage:" -ForegroundColor White
        Write-Host "  apex <command> [flags]" -ForegroundColor Green
        Write-Host ""
        Write-Host "Core Commands:" -ForegroundColor White
        Write-Host "  doctor       " -NoNewline -ForegroundColor Cyan
        Write-Host "Perform environment security & integrity checks" -ForegroundColor Gray
        Write-Host "  analyze      " -NoNewline -ForegroundColor Cyan
        Write-Host "Run system compliance and optimization audits" -ForegroundColor Gray
        Write-Host "  optimize     " -NoNewline -ForegroundColor Cyan
        Write-Host "Apply gaming and network optimization profiles" -ForegroundColor Gray
        Write-Host "  rollback     " -NoNewline -ForegroundColor Cyan
        Write-Host "Instantly revert all modifications from SQLite log" -ForegroundColor Gray
        Write-Host "  benchmark    " -NoNewline -ForegroundColor Cyan
        Write-Host "Measure network ICMP latency & disk R/W throughput" -ForegroundColor Gray
        Write-Host "  clean        " -NoNewline -ForegroundColor Cyan
        Write-Host "Clean temporary junk, crash dumps, and prefetch files" -ForegroundColor Gray
        Write-Host "  repair       " -NoNewline -ForegroundColor Cyan
        Write-Host "Repair TCP/IP network stack and flush DNS caches" -ForegroundColor Gray
        Write-Host "  version      " -NoNewline -ForegroundColor Cyan
        Write-Host "Display CLI version and environment diagnostics" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Global Flags:" -ForegroundColor White
        Write-Host "  --dry-run        " -NoNewline -ForegroundColor Yellow
        Write-Host "Pre-verify modifications without applying changes" -ForegroundColor Gray
        Write-Host "  --json, -j       " -NoNewline -ForegroundColor Yellow
        Write-Host "Render machine-readable JSON payload outputs" -ForegroundColor Gray
        Write-Host "  --silent         " -NoNewline -ForegroundColor Yellow
        Write-Host "Suppress console output rendering" -ForegroundColor Gray
        Write-Host "  --verbose        " -NoNewline -ForegroundColor Yellow
        Write-Host "Output verbose diagnostic execution logs" -ForegroundColor Gray
        Write-Host "  --help, -h       " -NoNewline -ForegroundColor Yellow
        Write-Host "Display CLI help information" -ForegroundColor Gray
        Write-Host $sep -ForegroundColor Cyan
        Write-Host ""
    }

    static [void] ShowCommandHelp([string]$command) {
        Write-Host "Usage details for command: $command" -ForegroundColor White
        Write-Host "  apex $command [flags]" -ForegroundColor Green
        Write-Host ""
        Write-Host "Use '--help' for global parameters." -ForegroundColor Gray
    }
}

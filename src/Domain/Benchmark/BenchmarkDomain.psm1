using module "..\..\Logger\Logger.psm1"

# ANAS APEX X - Benchmark Domain

class BenchmarkDomain {
    static [hashtable] Run() {
        [Logger]::Header("System Performance Benchmark")

        # 1. Run Ping Latency Test
        [Logger]::Info("Measuring ping latency to Cloudflare DNS (1.1.1.1)...", "BenchmarkDomain")
        $pingCloudflare = [BenchmarkDomain]::MeasurePing("1.1.1.1")
        
        [Logger]::Info("Measuring ping latency to Google DNS (8.8.8.8)...", "BenchmarkDomain")
        $pingGoogle = [BenchmarkDomain]::MeasurePing("8.8.8.8")

        # 2. Run Disk Speed Test
        [Logger]::Info("Running disk write/read throughput benchmark (10MB payload)...", "BenchmarkDomain")
        $diskStats = [BenchmarkDomain]::MeasureDiskSpeed()

        [Logger]::Separator()
        [Logger]::Info("Benchmark Results:", "BenchmarkDomain")
        [Logger]::Success("Cloudflare DNS Latency : $pingCloudflare", "BenchmarkDomain")
        [Logger]::Success("Google DNS Latency     : $pingGoogle", "BenchmarkDomain")
        [Logger]::Success("Disk Write Speed       : $([Math]::Round($diskStats.WriteSpeedMBs, 2)) MB/s", "BenchmarkDomain")
        [Logger]::Success("Disk Read Speed        : $([Math]::Round($diskStats.ReadSpeedMBs, 2)) MB/s", "BenchmarkDomain")
        [Logger]::Footer()

        return @{
            PingCloudflareMs = $pingCloudflare
            PingGoogleMs = $pingGoogle
            DiskWriteMBs = $diskStats.WriteSpeedMBs
            DiskReadMBs = $diskStats.ReadSpeedMBs
        }
    }

    static [string] MeasurePing([string]$address) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $ping = Test-Connection -ComputerName $address -Count 2 -ErrorAction SilentlyContinue
            $sw.Stop()
            if ($null -ne $ping) {
                # Sum the response times and divide
                $total = 0
                $count = 0
                foreach ($p in $ping) {
                    if ($null -ne $p.ResponseTime) {
                        $total += $p.ResponseTime
                        $count++
                    }
                }
                if ($count -gt 0) {
                    return "$([Math]::Round($total / $count, 1)) ms"
                }
            }
            # Fallback stopwatch timing if Test-Connection doesn't return response time (e.g. blocked/limited)
            return "Timed out / Slow"
        }
        catch {
            return "Failed to connect"
        }
    }

    static [hashtable] MeasureDiskSpeed() {
        # Create temp file path in logs directory
        $scriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $tempDir = Join-Path $scriptDir "logs/backups"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        $tempFile = Join-Path $tempDir "benchmark_test.tmp"

        # Initialize 10MB payload (10485760 bytes)
        $size = 10 * 1024 * 1024
        [byte[]]$data = [byte[]]::new($size)
        for ($i = 0; $i -lt $data.Length; $i++) {
            $data[$i] = 120
        }

        # Write test
        $swWrite = [System.Diagnostics.Stopwatch]::StartNew()
        [System.IO.File]::WriteAllBytes($tempFile, $data)
        $swWrite.Stop()
        $writeMs = $swWrite.ElapsedMilliseconds
        $writeSpeed = if ($writeMs -gt 0) { ($size / (1024 * 1024)) / ($writeMs / 1000.0) } else { 0.0 }

        # Read test
        $swRead = [System.Diagnostics.Stopwatch]::StartNew()
        $null = [System.IO.File]::ReadAllBytes($tempFile)
        $swRead.Stop()
        $readMs = $swRead.ElapsedMilliseconds
        $readSpeed = if ($readMs -gt 0) { ($size / (1024 * 1024)) / ($readMs / 1000.0) } else { 0.0 }

        # Cleanup
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }

        return @{
            WriteSpeedMBs = $writeSpeed
            ReadSpeedMBs = $readSpeed
        }
    }
}

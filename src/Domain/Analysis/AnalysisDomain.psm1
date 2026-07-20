using module "..\..\Logger\Logger.psm1"

# ANAS APEX X - Analysis Domain

class AnalysisResult {
    [string]$Domain
    [string]$Setting
    [string]$Status
    [string]$CurrentValue
    [string]$ExpectedValue

    AnalysisResult([string]$domain, [string]$setting, [string]$status, [string]$currentVal, [string]$expectedVal) {
        $this.Domain = $domain
        $this.Setting = $setting
        $this.Status = $status
        $this.CurrentValue = $currentVal
        $this.ExpectedValue = $expectedVal
    }
}

class AnalysisDomain {
    static [array] Run() {
        [Logger]::Header("System Optimization Analysis")

        $results = [System.Collections.Generic.List[AnalysisResult]]::new()

        # 1. Check Gaming: AllowAutoGameMode
        $resGameMode = [AnalysisDomain]::CheckRegistry(
            "Gaming",
            "HKCU:\Software\Microsoft\GameBar",
            "AllowAutoGameMode",
            1
        )
        $results.Add($resGameMode)

        # 2. Check Gaming: GameDVR_Enabled
        $resDVR1 = [AnalysisDomain]::CheckRegistry(
            "Gaming",
            "HKCU:\System\GameConfigStore",
            "GameDVR_Enabled",
            0
        )
        $results.Add($resDVR1)

        # 3. Check Gaming: AllowGameDVR
        $resDVR2 = [AnalysisDomain]::CheckRegistry(
            "Gaming",
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR",
            "AllowGameDVR",
            0
        )
        $results.Add($resDVR2)

        # 4. Check Network: NetworkThrottlingIndex
        $resThrottle = [AnalysisDomain]::CheckRegistry(
            "Network",
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile",
            "NetworkThrottlingIndex",
            4294967295
        )
        $results.Add($resThrottle)

        # 5. Check Network Interfaces (TCP No-Delay)
        $interfacesPath = "HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        $appliedInterfaces = 0
        $totalInterfaces = 0
        
        if (Test-Path $interfacesPath) {
            $subkeys = Get-ChildItem -Path $interfacesPath -Name
            $totalInterfaces = $subkeys.Count
            foreach ($guid in $subkeys) {
                $path = "HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                $ackFreq = Get-ItemProperty -Path $path -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                $noDelay = Get-ItemProperty -Path $path -Name "TCPNoDelay" -ErrorAction SilentlyContinue

                if ($null -ne $ackFreq -and $ackFreq.TcpAckFrequency -eq 1 -and
                    $null -ne $noDelay -and $noDelay.TCPNoDelay -eq 1) {
                    $appliedInterfaces++
                }
            }
        }

        $interfacesStatus = if ($totalInterfaces -eq 0) {
            "N/A"
        } elseif ($appliedInterfaces -eq $totalInterfaces) {
            "Applied"
        } else {
            "Missing"
        }
        $results.Add([AnalysisResult]::new(
            "Network",
            "TCP No-Delay (Nagle)",
            $interfacesStatus,
            "$appliedInterfaces/$totalInterfaces Interfaces",
            "All Interfaces"
        ))

        # Output to console table
        $headers = @("Domain", "Optimization Target", "Status", "Current Value", "Expected Value")
        $rows = [System.Collections.Generic.List[array]]::new()
        $appliedCount = 0
        $totalCount = $results.Count

        foreach ($r in $results) {
            $rows.Add(@($r.Domain, $r.Setting, $r.Status, $r.CurrentValue, $r.ExpectedValue))
            if ($r.Status -eq "Applied" -or $r.Status -eq "N/A") {
                $appliedCount++
            }
        }

        [ConsoleLogger]::Table($headers, $rows.ToArray())

        # Print overall stats
        $percentage = [Math]::Round(($appliedCount / $totalCount) * 100, 1)
        [Logger]::Info("Applied: $appliedCount / $totalCount optimizations ($percentage% Optimized).", "AnalysisDomain")
        [Logger]::Footer()

        return $results.ToArray()
    }

    # Helper method to check registry properties safely
    static [AnalysisResult] CheckRegistry([string]$domain, [string]$key, [string]$name, [object]$expected) {
        $status = "Missing"
        $currValStr = "None"
        
        if (Test-Path $key) {
            $item = Get-Item -Path $key
            $val = $item.GetValue($name)
            if ($null -ne $val) {
                # Compare as strings or numbers
                if ($val.ToString().ToLower() -eq $expected.ToString().ToLower()) {
                    $status = "Applied"
                }
                $currValStr = $val.ToString()
            }
        }

        return [AnalysisResult]::new($domain, $name, $status, $currValStr, $expected.ToString())
    }
}

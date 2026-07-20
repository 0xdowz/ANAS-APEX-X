using module "..\..\Logger\Logger.psm1"

# ANAS APEX X - Repair Domain

class RepairDomain {
    static [void] Run() {
        [Logger]::Header("System Network & Configuration Repair")
        
        $contextType = [Type]"Context"

        # 1. Flush DNS Cache
        if ($contextType::DryRun) {
            [Logger]::Info("[DRY-RUN] Would run: Clear-DnsClientCache / ipconfig /flushdns", "RepairDomain")
        } else {
            [Logger]::Info("Flushing DNS Client Cache...", "RepairDomain")
            try {
                Clear-DnsClientCache -ErrorAction Stop | Out-Null
                [Logger]::Success("DNS Cache flushed successfully.", "RepairDomain")
            }
            catch {
                # Fallback to ipconfig if Clear-DnsClientCache fails or is not available
                try {
                    $null = ipconfig /flushdns
                    [Logger]::Success("DNS Cache flushed successfully (via ipconfig).", "RepairDomain")
                }
                catch {
                    [Logger]::Error("Failed to flush DNS cache: $_", "RepairDomain")
                }
            }
        }

        # 2. Winsock Reset
        if ($contextType::DryRun) {
            [Logger]::Info("[DRY-RUN] Would run: netsh winsock reset", "RepairDomain")
        } else {
            [Logger]::Info("Performing Winsock Reset...", "RepairDomain")
            try {
                $process = Start-Process -FilePath "netsh" -ArgumentList "winsock reset" -NoNewWindow -PassThru -Wait
                if ($process.ExitCode -eq 0) {
                    [Logger]::Success("Winsock catalogs reset successfully.", "RepairDomain")
                } else {
                    [Logger]::Warning("Winsock reset returned exit code: $($process.ExitCode)", "RepairDomain")
                }
            }
            catch {
                [Logger]::Error("Failed to reset Winsock: $_", "RepairDomain")
            }
        }

        # 3. TCP/IP Stack Reset
        if ($contextType::DryRun) {
            [Logger]::Info("[DRY-RUN] Would run: netsh int ip reset", "RepairDomain")
        } else {
            [Logger]::Info("Performing TCP/IP Stack Reset...", "RepairDomain")
            try {
                $process = Start-Process -FilePath "netsh" -ArgumentList "int ip reset" -NoNewWindow -PassThru -Wait
                if ($process.ExitCode -eq 0) {
                    [Logger]::Success("TCP/IP stack reset successfully.", "RepairDomain")
                } else {
                    [Logger]::Warning("TCP/IP reset returned exit code: $($process.ExitCode)", "RepairDomain")
                }
            }
            catch {
                [Logger]::Error("Failed to reset TCP/IP stack: $_", "RepairDomain")
            }
        }

        [Logger]::Footer()
    }
}

using module "..\Logger\Logger.psm1"
using module "..\Core\StateManager.psm1"
using module ".\ProviderContract.psm1"
using module ".\RegistryProvider.psm1"

# ANAS APEX X - Network Provider Implementation

class NetworkProvider : BaseProvider {
    static [AuditResult] Audit([string]$target, [object]$expectedValue) {
        $throttlingPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $status = "Missing"
        $currVal = "Default"

        if (Test-Path $throttlingPath) {
            $val = (Get-ItemProperty -Path $throttlingPath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
            if ($null -ne $val) {
                $currVal = $val.ToString()
                if ($val.ToString() -eq $expectedValue.ToString()) {
                    $status = "Applied"
                }
            }
        }

        return [AuditResult]::new("NetworkProvider", "NetworkThrottlingIndex", $status, $currVal, $expectedValue.ToString())
    }

    static [void] Backup([string]$target, [string]$name = "") {
        $throttlingPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        [RegistryProvider]::Backup($throttlingPath, "NetworkThrottlingIndex")
    }

    static [void] DryRun([object]$payload) {
        [Logger]::Info("[DRY-RUN] Would apply Network TCP/IP optimization payload: $($payload.Name)", "NetworkProvider")
    }

    static [void] Apply([object]$payload) {
        $contextType = [Type]"Context"

        # 1. Record backup
        [NetworkProvider]::Backup("SystemProfile", "")

        # 2. DryRun check
        if ($contextType::DryRun) {
            [NetworkProvider]::DryRun($payload)
            return
        }

        # 3. Apply changes via RegistryProvider
        $throttlingPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        [RegistryProvider]::Apply(@{
            Key = $throttlingPath
            ValueName = "NetworkThrottlingIndex"
            Value = 4294967295
            Kind = "DWord"
        })

        # Apply TCP No-Delay to all active interfaces
        $interfacesPath = "HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        if (Test-Path $interfacesPath) {
            $subkeys = Get-ChildItem -Path $interfacesPath -Name
            foreach ($guid in $subkeys) {
                $key = "HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                [RegistryProvider]::Apply(@{ Key = $key; ValueName = "TcpAckFrequency"; Value = 1; Kind = "DWord" })
                [RegistryProvider]::Apply(@{ Key = $key; ValueName = "TCPNoDelay"; Value = 1; Kind = "DWord" })
            }
        }
    }

    static [void] Restore([object]$stateRecord) {
        [RegistryProvider]::Restore($stateRecord)
    }
}

using module "..\Logger\Logger.psm1"
using module "..\Core\StateManager.psm1"
using module ".\ProviderContract.psm1"

# ANAS APEX X - PowerCfg Provider Implementation

class PowerCfgProvider : BaseProvider {
    static [AuditResult] Audit([string]$schemeGuid, [object]$expectedState) {
        $activeOutput = powercfg /getactivescheme 2>&1
        $status = "Missing"
        $currVal = $activeOutput.ToString()

        if ($activeOutput -match $schemeGuid) {
            $status = "Applied"
        }

        return [AuditResult]::new("PowerCfgProvider", $schemeGuid, $status, $currVal, $expectedState.ToString())
    }

    static [void] Backup([string]$schemeGuid, [string]$name = "") {
        $activeOutput = powercfg /getactivescheme 2>&1
        $activeGuid = ""
        if ($activeOutput -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
            $activeGuid = $matches[1]
        }
        [StateManager]::RecordRegistry("HKLM:\SOFTWARE\PowerCfgActiveBackup", "ActiveSchemeGuid", $activeGuid, "String", $true)
    }

    static [void] DryRun([object]$payload) {
        [Logger]::Info("[DRY-RUN] Would set active Power Scheme to $($payload.SchemeGuid)", "PowerCfgProvider")
    }

    static [void] Apply([object]$payload) {
        $contextType = [Type]"Context"
        $schemeGuid = $payload.SchemeGuid

        # 1. Record state backup
        [PowerCfgProvider]::Backup($schemeGuid, "")

        # 2. DryRun check
        if ($contextType::DryRun) {
            [PowerCfgProvider]::DryRun($payload)
            return
        }

        # 3. Apply power scheme
        try {
            $res = powercfg /setactive $schemeGuid 2>&1
            [Logger]::Debug("Set active power scheme to $schemeGuid", "PowerCfgProvider")
        }
        catch {
            [Logger]::Error("Failed to set power scheme $schemeGuid : $_", "PowerCfgProvider")
            throw $_
        }
    }

    static [void] Restore([object]$stateRecord) {
        $origGuid = $stateRecord.OriginalVal
        if (-not [string]::IsNullOrEmpty($origGuid)) {
            powercfg /setactive $origGuid 2>&1 | Out-Null
            [Logger]::Debug("Restored power scheme to $origGuid", "PowerCfgProvider")
        }
    }
}

using module "..\Logger\Logger.psm1"

# ANAS APEX X - Provider Base Class and Audit Result Contract

class AuditResult {
    [string]$Provider
    [string]$Target
    [string]$Status
    [string]$CurrentValue
    [string]$ExpectedValue

    AuditResult([string]$provider, [string]$target, [string]$status, [string]$currentVal, [string]$expectedVal) {
        $this.Provider = $provider
        $this.Target = $target
        $this.Status = $status
        $this.CurrentValue = $currentVal
        $this.ExpectedValue = $expectedVal
    }
}

class BaseProvider {
    static [AuditResult] Audit([string]$target, [object]$expectedValue) {
        return [AuditResult]::new("BaseProvider", $target, "Unknown", "None", $expectedValue.ToString())
    }

    static [void] Backup([string]$target, [string]$name) {
    }

    static [void] Apply([object]$payload) {
    }

    static [void] Restore([object]$stateRecord) {
    }

    static [void] DryRun([object]$payload) {
    }
}

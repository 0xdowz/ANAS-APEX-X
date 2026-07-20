using module "..\Logger\Logger.psm1"
using module "..\Core\StateManager.psm1"
using module ".\ProviderContract.psm1"

# ANAS APEX X - Service Provider Implementation

class ServiceProvider : BaseProvider {
    static [AuditResult] Audit([string]$serviceName, [object]$expectedState) {
        $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        $status = "Missing"
        $currVal = "None"

        if ($null -ne $svc) {
            $currVal = "Status=" + $svc.Status.ToString() + ",StartType=" + $svc.StartType.ToString()
            if ($svc.Status.ToString().ToLower() -eq $expectedState.ToString().ToLower() -or
                $svc.StartType.ToString().ToLower() -eq $expectedState.ToString().ToLower()) {
                $status = "Applied"
            }
        }

        return [AuditResult]::new("ServiceProvider", $serviceName, $status, $currVal, $expectedState.ToString())
    }

    static [void] Backup([string]$serviceName, [string]$name = "") {
        $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -ne $svc) {
            [StateManager]::RecordService($serviceName, @{
                Status = $svc.Status.ToString()
                StartType = $svc.StartType.ToString()
            })
        }
    }

    static [void] DryRun([object]$payload) {
        [Logger]::Info("[DRY-RUN] Would configure service $($payload.ServiceName) : StartupType=$($payload.StartType), Status=$($payload.Status)", "ServiceProvider")
    }

    static [void] Apply([object]$payload) {
        $contextType = [Type]"Context"
        $serviceName = $payload.ServiceName
        $startType = $payload.StartType
        $status = $payload.Status

        # 1. Record backup state
        [ServiceProvider]::Backup($serviceName, "")

        # 2. DryRun check
        if ($contextType::DryRun) {
            [ServiceProvider]::DryRun($payload)
            return
        }

        # 3. Apply live change
        $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            [Logger]::Warning("Service '$serviceName' not found on system.", "ServiceProvider")
            return
        }

        try {
            if (-not [string]::IsNullOrEmpty($startType) -and $svc.StartType.ToString() -ne $startType) {
                Set-Service -Name $serviceName -StartupType $startType -ErrorAction SilentlyContinue | Out-Null
                [Logger]::Debug("Configured service $serviceName startup type to $startType", "ServiceProvider")
            }

            if ($status -eq "Stopped" -and $svc.Status -ne "Stopped") {
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue | Out-Null
                [Logger]::Debug("Stopped service $serviceName", "ServiceProvider")
            }
            elseif ($status -eq "Running" -and $svc.Status -ne "Running") {
                Start-Service -Name $serviceName -ErrorAction SilentlyContinue | Out-Null
                [Logger]::Debug("Started service $serviceName", "ServiceProvider")
            }
        }
        catch {
            [Logger]::Error("Failed to configure service $serviceName : $_", "ServiceProvider")
            throw $_
        }
    }

    static [void] Restore([object]$stateRecord) {
        [StateManager]::RollbackService($stateRecord)
    }

    # Backward compatibility helper
    static [void] Configure([string]$serviceName, [string]$startType, [string]$status) {
        [ServiceProvider]::Apply(@{
            ServiceName = $serviceName
            StartType = $startType
            Status = $status
        })
    }
}

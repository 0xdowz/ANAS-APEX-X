using module "..\Logger\Logger.psm1"
using module "..\Core\StateManager.psm1"
using module ".\ProviderContract.psm1"

# ANAS APEX X - Registry Provider Implementation

class RegistryProvider : BaseProvider {
    static [string] NormalizePath([string]$keyPath) {
        $path = $keyPath
        if ($path.StartsWith("HKEY_LOCAL_MACHINE")) {
            $path = $path.Replace("HKEY_LOCAL_MACHINE", "HKLM:")
        }
        elseif ($path.StartsWith("HKEY_CURRENT_USER")) {
            $path = $path.Replace("HKEY_CURRENT_USER", "HKCU:")
        }
        return $path
    }

    static [AuditResult] Audit([string]$keyPath, [string]$valueName, [object]$expectedValue) {
        $path = [RegistryProvider]::NormalizePath($keyPath)
        $status = "Missing"
        $currValStr = "None"
        
        if (Test-Path $path) {
            $item = Get-Item -Path $path
            $val = $item.GetValue($valueName)
            if ($null -ne $val) {
                if ($val.ToString().ToLower() -eq $expectedValue.ToString().ToLower()) {
                    $status = "Applied"
                }
                $currValStr = $val.ToString()
            }
        }

        return [AuditResult]::new("RegistryProvider", "${path}\${valueName}", $status, $currValStr, $expectedValue.ToString())
    }

    static [void] Backup([string]$keyPath, [string]$valueName) {
        $path = [RegistryProvider]::NormalizePath($keyPath)
        $existed = $false
        $origVal = $null
        $origKind = $null

        if (Test-Path $path) {
            $key = Get-Item -Path $path
            $origVal = $key.GetValue($valueName)
            if ($null -ne $origVal) {
                $existed = $true
                $origKind = $key.GetValueKind($valueName).ToString()
            }
        }

        [StateManager]::RecordRegistry($path, $valueName, $origVal, $origKind, $existed)
    }

    static [void] DryRun([object]$payload) {
        $path = [RegistryProvider]::NormalizePath($payload.Key)
        [Logger]::Info("[DRY-RUN] Would set registry $($path)\$($payload.ValueName) = $($payload.Value) ($($payload.Kind))", "RegistryProvider")
    }

    static [void] Apply([object]$payload) {
        $contextType = [Type]"Context"
        $keyPath = $payload.Key
        $valueName = if ($null -ne $payload.ValueName) { $payload.ValueName } else { $payload.Name }
        $value = $payload.Value
        $kind = $payload.Kind

        # 1. Record state backup
        [RegistryProvider]::Backup($keyPath, $valueName)

        # 2. DryRun Mode check
        if ($contextType::DryRun) {
            [RegistryProvider]::DryRun(@{ Key = $keyPath; ValueName = $valueName; Value = $value; Kind = $kind })
            return
        }

        # 3. Apply live write
        $path = [RegistryProvider]::NormalizePath($keyPath)
        try {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -Force | Out-Null
            }

            $regValueKind = [Microsoft.Win32.RegistryValueKind]::String
            if ($kind) {
                $regValueKind = [Microsoft.Win32.RegistryValueKind]::$kind
            }

            Set-ItemProperty -Path $path -Name $valueName -Value $value -Type $regValueKind -Force | Out-Null
            [Logger]::Debug("Set registry: ${path}\${valueName} = $value ($kind)", "RegistryProvider")
        }
        catch {
            [Logger]::Error("Failed to write registry ${path}\${valueName} : $_", "RegistryProvider")
            throw $_
        }
    }

    static [void] Restore([object]$stateRecord) {
        [StateManager]::RollbackRegistry($stateRecord)
    }

    # Backward compatibility helper
    static [void] Write([string]$keyPath, [string]$valueName, [object]$value, [string]$kind) {
        [RegistryProvider]::Apply(@{
            Key = $keyPath
            ValueName = $valueName
            Value = $value
            Kind = $kind
        })
    }
}

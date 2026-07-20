using module "..\Core\CommandBus.psm1"
using module "..\Logger\Logger.psm1"

# ANAS APEX X - Security & Integrity Engine

class SecurityEngine {
    static [bool] IsAdministrator() {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    static [hashtable] GetTPMStatus() {
        $status = @{
            Present = $false
            Ready = $false
        }
        try {
            $tpm = Get-CimInstance -Namespace "Root\CIMV2\Security\MicrosoftTpm" -ClassName "Win32_Tpm" -ErrorAction SilentlyContinue
            if ($null -ne $tpm) {
                $status.Present = $true
                # TpmHasBackupRelationship / IsActivated / IsEnabled check
                $status.Ready = $tpm.IsReady() -eq $true -or ($tpm.IsEnabled_InitialValue -and $tpm.IsActivated_InitialValue)
            }
        }
        catch {
            # CIM might fail if namespace does not exist (e.g., Server edition or old virtual machine)
        }
        return $status
    }

    static [bool] IsSecureBootEnabled() {
        try {
            $sb = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State" -Name "UEFISecureBootEnabled" -ErrorAction SilentlyContinue
            return $sb -eq 1
        }
        catch {
            return $false
        }
    }

    static [hashtable] GetBitLockerStatus() {
        $status = @{
            HasProtection = $false
            Volumes = @()
        }
        try {
            $volumes = Get-CimInstance -Namespace "Root\CIMV2\Security\MicrosoftVolumeEncryption" -ClassName "Win32_EncryptableVolume" -ErrorAction SilentlyContinue
            if ($null -ne $volumes) {
                foreach ($vol in $volumes) {
                    $protection = $vol.ProtectionStatus -eq 1
                    if ($protection) {
                        $status.HasProtection = $true
                    }
                    $status.Volumes += @{
                        DriveLetter = $vol.DriveLetter
                        Protected = $protection
                    }
                }
            }
        }
        catch {
            # Namespace encryption class might fail on non-Windows Client systems or VMs
        }
        return $status
    }

    static [bool] IsSystemRestoreEnabled() {
        try {
            # Check SystemRestore setting key
            $srPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
            if (Test-Path $srPath) {
                $disabled = Get-ItemPropertyValue -Path $srPath -Name "DisableSR" -ErrorAction SilentlyContinue
                if ($disabled -eq 0) {
                    return $true
                }
            }
        }
        catch {}
        return $false
    }

    static [hashtable] DetectAntiCheats() {
        $status = @{
            VanguardPresent = $false
            FaceitPresent = $false
        }

        # Check Vanguard service
        $vgk = Get-Service -Name "vgk" -ErrorAction SilentlyContinue
        if ($null -ne $vgk) {
            $status.VanguardPresent = $true
        }

        # Check FACEIT service / driver
        $faceit = Get-Service -Name "faceit" -ErrorAction SilentlyContinue
        if ($null -ne $faceit) {
            $status.FaceitPresent = $true
        }

        return $status
    }

    static [void] LogHelper([int]$level, [string]$message) {
        & ([ScriptBlock]::Create("[Logger]::Log(`$args[0], `$args[1], 'Security', `$null)")) $level $message
    }

    static [bool] VerifyEnvironment() {
        [SecurityEngine]::LogHelper(1, "Verifying environment security and integrity configurations...")

        $ok = $true

        # 1. Admin check (Hard requirement)
        if (-not [SecurityEngine]::IsAdministrator()) {
            [SecurityEngine]::LogHelper(5, "ANAS APEX X must be run as an Administrator. Access denied.")
            return $false
        }

        # 2. Secure Boot status
        if (-not [SecurityEngine]::IsSecureBootEnabled()) {
            [SecurityEngine]::LogHelper(3, "Secure Boot is disabled or unsupported. Modern games with Riot Vanguard/FACEIT require Secure Boot.")
        }

        # 3. TPM status
        $tpm = [SecurityEngine]::GetTPMStatus()
        if (-not $tpm.Present) {
            [SecurityEngine]::LogHelper(3, "TPM chip not detected. Ensure TPM is enabled in BIOS.")
        }

        # 4. Anti-cheats detection
        $anticheat = [SecurityEngine]::DetectAntiCheats()
        if ($anticheat.VanguardPresent) {
            [SecurityEngine]::LogHelper(1, "Riot Vanguard anti-cheat detected. Optimization Engine will dynamically restrict sensitive system modifications to prevent bans.")
        }
        if ($anticheat.FaceitPresent) {
            [SecurityEngine]::LogHelper(1, "FACEIT anti-cheat detected. Optimization Engine will dynamically restrict kernel modifications.")
        }

        # 5. System Restore Point availability warning
        if (-not [SecurityEngine]::IsSystemRestoreEnabled()) {
            [SecurityEngine]::LogHelper(3, "System Restore is disabled. It is highly recommended to enable System Restore before applying optimizations.")
        }

        return $ok
    }
}

# Register command handler for doctor
& ([ScriptBlock]::Create("[CommandBus]::RegisterHandler('doctor', `$args[0])")) {
    param($payload)
    
    & ([ScriptBlock]::Create("[ConsoleLogger]::Header('System Security Doctor')"))
    $res = [SecurityEngine]::VerifyEnvironment()
    if ($res) {
        & ([ScriptBlock]::Create("[Logger]::Success('Security audit completed. System is ready.', 'Security')"))
    } else {
        & ([ScriptBlock]::Create("[Logger]::Error('Security checks failed. Please run CLI as Administrator.', 'Security')"))
    }
    & ([ScriptBlock]::Create("[ConsoleLogger]::Footer()"))
}

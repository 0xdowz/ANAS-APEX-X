using module "..\..\Core\EventBus.psm1"
using module "..\..\Core\CommandBus.psm1"
using module "..\..\Logger\Logger.psm1"
using module "..\..\Security\SecurityEngine.psm1"

Describe "Security & Environment Integrity Engine" {
    It "Should verify admin privileges checker" {
        $admin = [SecurityEngine]::IsAdministrator()
        $admin.GetType().Name | Should Be "Boolean"
    }

    It "Should detect installed game anti-cheats" {
        $ac = [SecurityEngine]::DetectAntiCheats()
        $ac.ContainsKey("VanguardPresent") | Should Be $true
        $ac.ContainsKey("FaceitPresent") | Should Be $true
    }

    It "Should run verification check successfully" {
        $result = [SecurityEngine]::VerifyEnvironment()
        $result.GetType().Name | Should Be "Boolean"
    }
}

# Environment-dependent test: Physical/Virtual WMI TPM hardware querying
Describe "Security Environment Hardware Checks" -Tag "Integration", "Environment" {
    It "Should retrieve TPM status" {
        $tpm = [SecurityEngine]::GetTPMStatus()
        $tpm.ContainsKey("Present") | Should Be $true
        $tpm.ContainsKey("Ready") | Should Be $true
    }
}

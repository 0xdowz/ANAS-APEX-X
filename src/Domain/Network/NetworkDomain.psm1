using module "..\..\Logger\Logger.psm1"
using module "..\..\Core\StateManager.psm1"
using module "..\..\Core\RuleEngine.psm1"
using module "..\..\Providers\NetworkProvider.psm1"

# ANAS APEX X - Network Optimization Domain

class NetworkDomain {
    static [void] Optimize() {
        [Logger]::Header("Network Domain Optimization")

        # Resolve rules path dynamically
        $scriptDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $rulesFile = Join-Path $scriptDir "rules/network.json"

        try {
            # 1. Apply declarative Rule DSL from rules/network.json
            [RuleEngine]::ApplyRulesFromFile($rulesFile)

            # 2. Apply Network Interface provider tuning
            [NetworkProvider]::Apply(@{ Name = "InterfaceTCPNoDelay" })

            [StateManager]::Commit()
            [Logger]::Success("Network optimizations applied successfully via Rule DSL.", "NetworkDomain")
        }
        catch {
            [Logger]::Error("Failed to apply network optimizations: $_", "NetworkDomain")
        }
        finally {
            [Logger]::Footer()
        }
    }
}

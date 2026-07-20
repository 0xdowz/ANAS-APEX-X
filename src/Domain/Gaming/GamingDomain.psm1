using module "..\..\Logger\Logger.psm1"
using module "..\..\Core\StateManager.psm1"
using module "..\..\Core\RuleEngine.psm1"

# ANAS APEX X - Gaming Optimization Domain

class GamingDomain {
    static [void] Optimize() {
        [Logger]::Header("Gaming Domain Optimization")

        # Resolve rules path dynamically
        $scriptDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $rulesFile = Join-Path $scriptDir "rules/gaming.json"

        try {
            [RuleEngine]::ApplyRulesFromFile($rulesFile)
            [StateManager]::Commit()
            [Logger]::Success("Gaming optimizations applied successfully via Rule DSL.", "GamingDomain")
        }
        catch {
            [Logger]::Error("Failed to apply gaming optimizations: $_", "GamingDomain")
        }
        finally {
            [Logger]::Footer()
        }
    }
}

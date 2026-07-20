using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Core\RuleEngine.psm1"
using module "..\..\..\src\Providers\ProviderContract.psm1"
using module "..\..\..\src\Providers\RegistryProvider.psm1"

Describe "Rule DSL Engine Schema Parsing" {
    It "Should evaluate OSVersion constraints correctly" {
        $rule = [PSCustomObject]@{
            id = "RuleTestOS"
            name = "OS Build Constraint Test"
            constraints = @(
                @{
                    type = "OSVersion"
                    minBuild = 999999
                }
            )
            actions = @()
        }
        $evalResult = [RuleEngine]::EvaluateConstraints($rule.constraints)
        $evalResult | Should -Be $false
    }

    It "Should parse and apply registry rules" {
        $rule = [PSCustomObject]@{
            id = "RuleTestReg"
            name = "Test DSL Rule applying a registry key"
            description = "Test Description"
            constraints = @()
            actions = @(
                @{
                    type = "Registry"
                    key = "HKCU:\Software\ApexRuleTest"
                    value = "DslVal"
                    data = 1
                    kind = "DWord"
                }
            )
        }
        $rule.id | Should -Be "RuleTestReg"
        $rule.actions.Count | Should -Be 1

        [RuleEngine]::ApplyRule($rule)
    }

    It "Should parse and apply rules directly from external JSON DSL file" {
        $scriptDir = (Get-Item (Join-Path $PSScriptRoot "../../..")).FullName
        $gamingRuleFile = Join-Path $scriptDir "rules/gaming.json"

        Test-Path $gamingRuleFile | Should -Be $true

        [RuleEngine]::ApplyRulesFromFile($gamingRuleFile)
    }
}

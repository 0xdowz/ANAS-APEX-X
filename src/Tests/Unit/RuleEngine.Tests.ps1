using module "..\..\Core\EventBus.psm1"
using module "..\..\Core\CommandBus.psm1"
using module "..\..\Logger\Logger.psm1"
using module "..\..\Core\RuleEngine.psm1"
using module "..\..\Providers\ProviderContract.psm1"
using module "..\..\Providers\RegistryProvider.psm1"

Describe "Rule DSL Engine Schema Parsing" {
    It "Should evaluate OSVersion constraints correctly" {
        $ruleJson = @"
        {
            "id": "RuleTestOS",
            "name": "OS Build Constraint Test",
            "constraints": {
                "minOsBuild": 999999
            },
            "actions": []
        }
"@
        $rule = [RuleEngine]::ParseRuleJson($ruleJson)
        $evalResult = [RuleEngine]::EvaluateConstraints($rule)
        $evalResult | Should Be $false
    }

    It "Should parse and apply registry rules" {
        $ruleJson = @"
        {
            "id": "RuleTestReg",
            "name": "Test DSL Rule applying a registry key",
            "constraints": {},
            "actions": [
                {
                    "provider": "Registry",
                    "path": "HKCU:\\Software\\ApexRuleTest",
                    "name": "DslVal",
                    "value": 1,
                    "kind": "DWord"
                }
            ]
        }
"@
        $rule = [RuleEngine]::ParseRuleJson($ruleJson)
        $rule.id | Should Be "RuleTestReg"
        $rule.actions.Count | Should Be 1

        [RuleEngine]::ApplyRule($rule, $true)
    }

    It "Should parse and apply rules directly from external JSON DSL file" {
        $scriptDir = (Get-Item (Join-Path $PSScriptRoot "../..")).FullName
        $gamingRuleFile = Join-Path $scriptDir "rules/gaming.json"

        Test-Path $gamingRuleFile | Should Be $true

        [RuleEngine]::ApplyRulesFromFile($gamingRuleFile, $true)
    }
}

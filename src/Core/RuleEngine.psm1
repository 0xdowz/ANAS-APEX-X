using module "..\Logger\Logger.psm1"
using module "..\Providers\RegistryProvider.psm1"
using module "..\Providers\ServiceProvider.psm1"
using module ".\StateManager.psm1"
using module ".\CapabilityEngine.psm1"

# ANAS APEX X - Rule DSL Engine

class RuleEngine {
    static [bool] EvaluateConstraints([array]$constraints) {
        if ($null -eq $constraints) { return $true }
        
        foreach ($c in $constraints) {
            $type = $c.Type
            if ($type -eq "OSVersion") {
                $minBuild = 0
                if ($null -ne $c.MinBuild) {
                    $minBuild = [int]$c.MinBuild
                }
                
                $currentBuild = [CapabilityEngine]::GetOSInfo().Build
                if ($currentBuild -lt $minBuild) {
                    [Logger]::Warning("Constraint failed: OS Build ($currentBuild) is less than required ($minBuild).", "RuleEngine")
                    return $false
                }
            }
        }
        return $true
    }

    static [void] ApplyAction([object]$action) {
        $type = $action.Type
        if ($type -eq "Registry") {
            [RegistryProvider]::Write($action.Key, $action.Value, $action.Data, $action.Kind)
        }
        elseif ($type -eq "Service") {
            [ServiceProvider]::Configure($action.Name, $action.StartType, $action.Status)
        }
        else {
            [Logger]::Warning("Unknown action type: $type", "RuleEngine")
        }
    }

    static [void] ApplyRule([object]$rule) {
        [Logger]::Info("Evaluating rule: $($rule.Name) - $($rule.Description)", "RuleEngine")

        # 1. Check constraints
        if (-not [RuleEngine]::EvaluateConstraints($rule.Constraints)) {
            [Logger]::Warning("Skipping rule '$($rule.Name)' due to failed constraints.", "RuleEngine")
            return
        }

        # 2. Run Actions
        $actions = $rule.Actions
        if ($null -ne $actions) {
            if ($actions.GetType().Name -ne "Object[]") {
                $actions = @($actions)
            }
            foreach ($act in $actions) {
                [RuleEngine]::ApplyAction($act)
            }
        }
    }

    static [void] ApplyRulesFromFile([string]$filePath) {
        if (-not (Test-Path $filePath)) {
            [Logger]::Warning("Rule DSL file not found: $filePath", "RuleEngine")
            return
        }

        try {
            $jsonStr = Get-Content -Path $filePath -Raw
            if ([string]::IsNullOrEmpty($jsonStr)) { return }
            $rules = ConvertFrom-Json $jsonStr
            if ($null -ne $rules) {
                if ($rules.GetType().Name -ne "Object[]") {
                    $rules = @($rules)
                }
                foreach ($r in $rules) {
                    [RuleEngine]::ApplyRule($r)
                }
            }
        }
        catch {
            [Logger]::Error("Failed to parse Rule DSL file $filePath : $_", "RuleEngine")
            throw $_
        }
    }
}

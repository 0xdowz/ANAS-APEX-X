using module "..\..\Core\EventBus.psm1"
using module "..\..\Core\CommandBus.psm1"
using module "..\..\Logger\Logger.psm1"
using module "..\..\Domain\Analysis\AnalysisDomain.psm1"

Describe "System Optimization Analysis Domain" {
    It "Should check registry entries and output results array" {
        $testKey = "HKCU:\Software\ApexAnalysisTest"
        if (Test-Path $testKey) {
            Remove-Item -Path $testKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }

        # Value missing check
        $res1 = [AnalysisDomain]::CheckRegistry("TestDomain", $testKey, "MissingVal", 1)
        $res1.Status | Should -Be "Missing"
        $res1.CurrentValue | Should -Be "None"

        # Value matches check
        New-Item -Path $testKey -Force | Out-Null
        Set-ItemProperty -Path $testKey -Name "MatchVal" -Value 1 -Type DWord -Force | Out-Null

        $res2 = [AnalysisDomain]::CheckRegistry("TestDomain", $testKey, "MatchVal", 1)
        $res2.Status | Should -Be "Applied"
        $res2.CurrentValue | Should -Be "1"

        # Cleanup
        Remove-Item -Path $testKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

# Environment-dependent test: Live host system registry scan across HKLM / HKCU paths
Describe "System Optimization Live Analysis Scan" -Tag "Integration", "Environment" {
    It "Should execute overall analysis scan successfully" {
        $contextType = [Type]"Context"
        $contextType::Silent = $true

        $results = [AnalysisDomain]::Run()
        $results.Count | Should -BeGreaterThan 0
        $contextType::Silent = $false
    }
}

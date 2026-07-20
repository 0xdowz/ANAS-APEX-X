using module "..\..\Core\EventBus.psm1"
using module "..\..\Core\CommandBus.psm1"
using module "..\..\Logger\Logger.psm1"

Describe "Multi-Channel Logger System" {
    BeforeEach {
        [FileLogger]::Initialize($TestDrive)
        [JSONLogger]::Initialize($TestDrive)
    }

    It "Should write text records to log file" {
        $testMsg = "Test plain text message " + [Guid]::NewGuid().ToString()
        [Logger]::Info($testMsg, "TestModule")

        $logPath = [FileLogger]::LogFilePath
        Test-Path $logPath | Should -Be $true

        $content = Get-Content -Path $logPath -Raw
        $content | Should -Match $testMsg
    }

    It "Should write JSON lines records to structured log file" {
        $testMsg = "Test JSON message " + [Guid]::NewGuid().ToString()
        [Logger]::Success($testMsg, "TestModule")

        $jsonPath = [JSONLogger]::LogFilePath
        Test-Path $jsonPath | Should -Be $true

        $content = Get-Content -Path $jsonPath
        $lastLine = $content[-1]
        $obj = ConvertFrom-Json $lastLine
        $obj.message | Should -Be $testMsg
        $obj.level | Should -Be "SUCCESS"
    }

    It "Should log timing execution metrics via PerformanceLogger" {
        [PerformanceLogger]::Clear()
        [Logger]::Log([LogLevel]::INFO, "Doing heavy work", "DomainTest", 150)

        $metrics = [PerformanceLogger]::GetMetrics()
        $metrics.Count | Should -Be 1
        $metrics[0].DurationMs | Should -Be 150
        $metrics[0].Module | Should -Be "DomainTest"
        
        $summary = [PerformanceLogger]::GetSummary()
        $summary.TotalOperations | Should -Be 1
        $summary.TotalDurationMs | Should -Be 150
    }
}

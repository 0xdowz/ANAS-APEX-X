using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Domain\Benchmark\BenchmarkDomain.psm1"

# Environment-dependent test: Pinging external resolvers & raw disk I/O throughput
Describe "System Performance Benchmark Domain" -Tag "Integration", "Environment" {
    It "Should measure ping response time to Google/Cloudflare" {
        $ms = [BenchmarkDomain]::MeasurePing("8.8.8.8")
        $ms | Should Not BeNullOrEmpty
    }

    It "Should run disk speed measurements successfully" {
        $stats = [BenchmarkDomain]::MeasureDiskSpeed()
        $stats.ContainsKey("WriteSpeedMBs") | Should Be $true
        $stats.ContainsKey("ReadSpeedMBs") | Should Be $true
        $stats.WriteSpeedMBs | Should BeGreaterThan -1
        $stats.ReadSpeedMBs | Should BeGreaterThan -1
    }
}

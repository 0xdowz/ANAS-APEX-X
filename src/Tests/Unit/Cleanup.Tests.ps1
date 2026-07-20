using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Domain\Cleanup\CleanupDomain.psm1"

Describe "System Temp & Junk Cleanup Domain" {
    It "Should scan and delete temporary files in target directory" {
        # Use TestDrive for hermetic filesystem isolation
        $testDir = Join-Path $TestDrive "test_cleanup"
        if (-not (Test-Path $testDir)) {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        }

        $dummyFile = Join-Path $testDir "dummy.log"
        "Some sample dummy content to measure size freed" | Out-File -FilePath $dummyFile -Encoding utf8

        $initialSize = (Get-Item $dummyFile).Length

        # Run directory cleanup
        $freed = [CleanupDomain]::CleanDirectory($testDir)
        $freed | Should Be $initialSize

        # File should have been deleted
        Test-Path $dummyFile | Should Be $false
    }
}

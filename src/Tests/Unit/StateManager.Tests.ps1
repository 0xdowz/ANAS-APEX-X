using module "..\..\Core\EventBus.psm1"
using module "..\..\Core\CommandBus.psm1"
using module "..\..\Logger\Logger.psm1"
using module "..\..\Core\SQLiteDatabase.psm1"
using module "..\..\Core\StateManager.psm1"

Describe "StateManager Core Transaction and Rollback System (SQLite Engine)" {
    BeforeEach {
        [StateManager]::Initialize($TestDrive)
        [StateManager]::CurrentTransaction.Clear()
    }

    It "Should initialize and record registry state updates" {
        [StateManager]::RecordRegistry("HKCU:\Software\ApexTest", "TestVal", "Original", "String", $true)
        
        $current = [StateManager]::CurrentTransaction
        $current.Count | Should -Be 1
        $current[0].Path | Should -Be "HKCU:\Software\ApexTest"
        $current[0].OriginalVal | Should -Be "Original"
    }

    It "Should commit transaction logs to SQLite database" {
        $dbPath = [StateManager]::BackupPath

        [StateManager]::RecordRegistry("HKCU:\Software\ApexTest", "TestCommit", "Value", "String", $true)
        [StateManager]::Commit()

        # Transaction in-memory list should be cleared
        [StateManager]::CurrentTransaction.Count | Should -Be 0

        # SQLite Database file should exist inside TestDrive
        Test-Path $dbPath | Should -Be $true
        
        # Query transaction records from database
        $rows = [SQLiteDatabase]::ExecuteQuery("SELECT * FROM transaction_records WHERE name = 'TestCommit';")
        $rows.Count | Should -BeGreaterThan 0
        $rows[0].original_val | Should -Be "Value"
    }

    It "Should automatically migrate legacy JSON transaction logs to SQLite" {
        $legacyJsonDir = Join-Path $TestDrive "logs/backups"
        if (-not (Test-Path $legacyJsonDir)) {
            New-Item -ItemType Directory -Path $legacyJsonDir -Force | Out-Null
        }
        $legacyJson = Join-Path $legacyJsonDir "transaction_log.json"
        
        $dummyRecord = @(
            @{
                Type = "Registry"
                Path = "HKCU:\Software\ApexLegacyTest"
                Name = "LegacyKey"
                OriginalVal = "LegacyValue"
                OriginalKind = "String"
                Existed = $true
            }
        )
        $dummyRecord | ConvertTo-Json -Depth 5 | Out-File -FilePath $legacyJson -Encoding utf8

        # Initialize StateManager (triggers migration)
        [StateManager]::Initialize($TestDrive)

        # JSON file should be removed after migration
        Test-Path $legacyJson | Should -Be $false

        # Migrated record should exist in SQLite database
        $rows = [SQLiteDatabase]::ExecuteQuery("SELECT * FROM transaction_records WHERE name = 'LegacyKey';")
        $rows.Count | Should -BeGreaterThan 0
        $rows[0].original_val | Should -Be "LegacyValue"
    }
}

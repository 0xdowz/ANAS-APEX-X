using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Core\SQLiteDatabase.psm1"
using module "..\..\..\src\Core\StateManager.psm1"

Describe "StateManager Core Transaction and Rollback System (SQLite Engine)" {
    $RootPath = (Get-Item (Join-Path $PSScriptRoot "../../..")).FullName

    It "Should initialize and record registry state updates" {
        [StateManager]::Initialize($RootPath)
        
        # Clear transaction before testing
        [StateManager]::CurrentTransaction.Clear()
        [StateManager]::RecordRegistry("HKCU:\Software\ApexTest", "TestVal", "Original", "String", $true)
        
        $current = [StateManager]::CurrentTransaction
        $current.Count | Should Be 1
        $current[0].Path | Should Be "HKCU:\Software\ApexTest"
        $current[0].OriginalVal | Should Be "Original"
    }

    It "Should commit transaction logs to SQLite database" {
        [StateManager]::Initialize($RootPath)
        [StateManager]::CurrentTransaction.Clear()
        
        $dbPath = [StateManager]::BackupPath

        [StateManager]::RecordRegistry("HKCU:\Software\ApexTest", "TestCommit", "Value", "String", $true)
        [StateManager]::Commit()

        # Transaction in-memory list should be cleared
        [StateManager]::CurrentTransaction.Count | Should Be 0

        # SQLite Database file should exist
        Test-Path $dbPath | Should Be $true
        
        # Query transaction records from database
        $rows = [SQLiteDatabase]::ExecuteQuery("SELECT * FROM transaction_records WHERE name = 'TestCommit';")
        $rows.Count | Should BeGreaterThan 0
        $rows[0].original_val | Should Be "Value"
    }

    It "Should automatically migrate legacy JSON transaction logs to SQLite" {
        $legacyJson = Join-Path $RootPath "logs/backups/transaction_log.json"
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
        [StateManager]::Initialize($RootPath)

        # Legacy JSON file should be removed after migration
        Test-Path $legacyJson | Should Be $false

        # Migrated record should exist in SQLite database
        $rows = [SQLiteDatabase]::ExecuteQuery("SELECT * FROM transaction_records WHERE name = 'LegacyKey';")
        $rows.Count | Should BeGreaterThan 0
        $rows[0].original_val | Should Be "LegacyValue"
    }
}

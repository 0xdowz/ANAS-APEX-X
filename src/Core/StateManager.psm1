using module "..\Logger\Logger.psm1"
using module ".\CommandBus.psm1"
using module ".\SQLiteDatabase.psm1"

# ANAS APEX X - Transaction State Manager (Enterprise SQLite Engine)

class StateRecord {
    [string]$Type
    [string]$Path
    [string]$Name
    [object]$OriginalVal
    [string]$OriginalKind
    [bool]$Existed

    StateRecord() {}

    StateRecord([string]$type, [string]$path, [string]$name, [object]$origVal, [string]$origKind, [bool]$existed) {
        $this.Type = $type
        $this.Path = $path
        $this.Name = $name
        $this.OriginalVal = $origVal
        $this.OriginalKind = $origKind
        $this.Existed = $existed
    }
}

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUndefinedModuleMember', '')]
class StateManager {
    static [System.Collections.Generic.List[StateRecord]]$CurrentTransaction = [System.Collections.Generic.List[StateRecord]]::new()
    static [object]$LockObject = [object]::new()
    static [string]$BackupPath = ""

    static [void] Initialize([string]$rootDir) {
        $backupsDir = Join-Path $rootDir "logs/backups"
        if (-not (Test-Path $backupsDir)) {
            New-Item -ItemType Directory -Path $backupsDir -Force | Out-Null
        }
        
        [StateManager]::BackupPath = Join-Path $backupsDir "apex.db"
        & ([ScriptBlock]::Create("[SQLiteDatabase]::Initialize(`$args[0])")) ([StateManager]::BackupPath)

        # Automatic Migration: Convert legacy transaction_log.json if present
        $legacyJson = Join-Path $backupsDir "transaction_log.json"
        if (Test-Path $legacyJson) {
            [StateManager]::MigrateLegacyJson($legacyJson)
        }
    }

    static [void] MigrateLegacyJson([string]$jsonPath) {
        try {
            $jsonStr = Get-Content -Path $jsonPath -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrEmpty($jsonStr)) {
                Remove-Item -Path $jsonPath -Force -ErrorAction SilentlyContinue
                return
            }

            $records = ConvertFrom-Json $jsonStr
            if ($null -ne $records) {
                if ($records.GetType().Name -ne "Object[]") {
                    $records = @($records)
                }

                if ($records.Count -gt 0) {
                    $transId = "MIGRATED_" + [Guid]::NewGuid().ToString("N")
                    $ts = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    
                    $sqlTrans = "INSERT INTO transactions (transaction_id, timestamp, status) VALUES ('$transId', '$ts', 'COMMITTED');"
                    & ([ScriptBlock]::Create("[SQLiteDatabase]::ExecuteNonQuery(`$args[0])")) $sqlTrans | Out-Null

                    foreach ($rec in $records) {
                        $type = & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.Type
                        $path = & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.Path
                        $name = if ($null -ne $rec.Name) { & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.Name } else { "" }
                        
                        $origValStr = ""
                        if ($null -ne $rec.OriginalVal) {
                            if ($rec.OriginalVal.GetType().Name -eq "PSCustomObject" -or $rec.OriginalVal.GetType().Name -eq "Hashtable") {
                                $origValStr = & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) ($rec.OriginalVal | ConvertTo-Json -Compress)
                            } else {
                                $origValStr = & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.OriginalVal.ToString()
                            }
                        }

                        $origKind = if ($null -ne $rec.OriginalKind) { & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.OriginalKind } else { "" }
                        $existed = if ($rec.Existed) { 1 } else { 0 }

                        $sqlRec = "INSERT INTO transaction_records (transaction_id, type, path, name, original_val, original_kind, existed) VALUES ('$transId', '$type', '$path', '$name', '$origValStr', '$origKind', $existed);"
                        & ([ScriptBlock]::Create("[SQLiteDatabase]::ExecuteNonQuery(`$args[0])")) $sqlRec | Out-Null
                    }

                    [Logger]::Info("Successfully migrated $($records.Count) legacy JSON transaction records to SQLite database.", "StateManager")
                }
            }

            Remove-Item -Path $jsonPath -Force -ErrorAction SilentlyContinue
        }
        catch {
            [Logger]::Warning("Failed legacy JSON migration: $_", "StateManager")
        }
    }

    static [void] RecordRegistry([string]$keyPath, [string]$valueName, [object]$originalVal, [string]$originalKind, [bool]$existed) {
        $record = [StateRecord]::new("Registry", $keyPath, $valueName, $originalVal, $originalKind, $existed)
        [System.Threading.Monitor]::Enter([StateManager]::LockObject)
        try {
            [StateManager]::CurrentTransaction.Add($record)
        }
        finally {
            [System.Threading.Monitor]::Exit([StateManager]::LockObject)
        }
    }

    static [void] RecordService([string]$serviceName, [string]$originalState) {
        $record = [StateRecord]::new("Service", $serviceName, $null, $originalState, $null, $true)
        [System.Threading.Monitor]::Enter([StateManager]::LockObject)
        try {
            [StateManager]::CurrentTransaction.Add($record)
        }
        finally {
            [System.Threading.Monitor]::Exit([StateManager]::LockObject)
        }
    }

    static [void] Commit() {
        [System.Threading.Monitor]::Enter([StateManager]::LockObject)
        try {
            if ([StateManager]::CurrentTransaction.Count -eq 0) { return }
            if ([string]::IsNullOrEmpty([StateManager]::BackupPath)) {
                $scriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
                [StateManager]::Initialize($scriptDir)
            }

            $transId = [Guid]::NewGuid().ToString("N")
            $ts = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            
            $sqlTrans = "INSERT INTO transactions (transaction_id, timestamp, status) VALUES ('$transId', '$ts', 'COMMITTED');"
            & ([ScriptBlock]::Create("[SQLiteDatabase]::ExecuteNonQuery(`$args[0])")) $sqlTrans | Out-Null

            foreach ($rec in [StateManager]::CurrentTransaction) {
                $type = & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.Type
                $path = & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.Path
                $name = if ($null -ne $rec.Name) { & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.Name } else { "" }
                
                $origValStr = ""
                if ($null -ne $rec.OriginalVal) {
                    if ($rec.OriginalVal.GetType().Name -eq "PSCustomObject" -or $rec.OriginalVal.GetType().Name -eq "Hashtable") {
                        $origValStr = & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) ($rec.OriginalVal | ConvertTo-Json -Compress)
                    } else {
                        $origValStr = & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.OriginalVal.ToString()
                    }
                }

                $origKind = if ($null -ne $rec.OriginalKind) { & ([ScriptBlock]::Create("[SQLiteDatabase]::Escape(`$args[0])")) $rec.OriginalKind } else { "" }
                $existed = if ($rec.Existed) { 1 } else { 0 }

                $sqlRec = "INSERT INTO transaction_records (transaction_id, type, path, name, original_val, original_kind, existed) VALUES ('$transId', '$type', '$path', '$name', '$origValStr', '$origKind', $existed);"
                & ([ScriptBlock]::Create("[SQLiteDatabase]::ExecuteNonQuery(`$args[0])")) $sqlRec | Out-Null
            }

            [StateManager]::CurrentTransaction.Clear()
        }
        finally {
            [System.Threading.Monitor]::Exit([StateManager]::LockObject)
        }
    }

    static [void] Rollback() {
        [System.Threading.Monitor]::Enter([StateManager]::LockObject)
        try {
            if ([string]::IsNullOrEmpty([StateManager]::BackupPath)) {
                $scriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
                [StateManager]::Initialize($scriptDir)
            }

            if (-not (Test-Path ([StateManager]::BackupPath))) {
                [Logger]::Warning("No SQLite database found for rollback.", "StateManager")
                return
            }

            # Query records from SQLite database in LIFO order (record_id DESC)
            $sqlQuery = "SELECT record_id, transaction_id, type, path, name, original_val, original_kind, existed FROM transaction_records ORDER BY record_id DESC;"
            $rows = & ([ScriptBlock]::Create("[SQLiteDatabase]::ExecuteQuery(`$args[0])")) $sqlQuery

            if ($null -eq $rows -or $rows.Count -eq 0) {
                [Logger]::Warning("No recorded transaction entries found in SQLite database to rollback.", "StateManager")
                return
            }

            [Logger]::Info("Starting rollback of $($rows.Count) changes from SQLite database...", "StateManager")

            foreach ($r in $rows) {
                $recObj = [PSCustomObject]@{
                    Type = $r.type
                    Path = $r.path
                    Name = $r.name
                    OriginalVal = $r.original_val
                    OriginalKind = $r.original_kind
                    Existed = ($r.existed -eq "1" -or $r.existed -eq 1)
                }

                if ($recObj.Type -eq "Registry") {
                    [StateManager]::RollbackRegistry($recObj)
                }
                elseif ($recObj.Type -eq "Service") {
                    [StateManager]::RollbackService($recObj)
                }
            }

            # Clear transactions and records after successful rollback
            & ([ScriptBlock]::Create("[SQLiteDatabase]::ExecuteNonQuery(`$args[0])")) "DELETE FROM transaction_records;" | Out-Null
            & ([ScriptBlock]::Create("[SQLiteDatabase]::ExecuteNonQuery(`$args[0])")) "DELETE FROM transactions;" | Out-Null

            [Logger]::Success("Rollback completed successfully from SQLite database.", "StateManager")
        }
        finally {
            [System.Threading.Monitor]::Exit([StateManager]::LockObject)
        }
    }

    # Helper methods for rollback execution
    static [void] RollbackRegistry([object]$rec) {
        $path = $rec.Path
        $name = $rec.Name
        $existed = $rec.Existed
        $origVal = $rec.OriginalVal
        $origKind = $rec.OriginalKind

        try {
            if (-not $existed) {
                if (Test-Path $path) {
                    $item = Get-Item -Path $path
                    if ($null -ne $item.GetValue($name)) {
                        Remove-ItemProperty -Path $path -Name $name -Force | Out-Null
                        [Logger]::Debug("Restored: Deleted registry property ${path}\${name}", "StateManager")
                    }
                }
            }
            else {
                if (-not (Test-Path $path)) {
                    New-Item -Path $path -Force | Out-Null
                }

                $typedVal = $origVal
                if ($origKind -eq "DWord" -or $origKind -eq "QWord") {
                    $typedVal = [long]$origVal
                }
                
                $regValueKind = [Microsoft.Win32.RegistryValueKind]::String
                if ($origKind) {
                    $regValueKind = [Microsoft.Win32.RegistryValueKind]::$origKind
                }

                Set-ItemProperty -Path $path -Name $name -Value $typedVal -Type $regValueKind -Force | Out-Null
                [Logger]::Debug("Restored: Set registry property ${path}\${name} = $typedVal ($origKind)", "StateManager")
            }
        }
        catch {
            [Logger]::Error("Failed to rollback registry ${path}\${name} : $_", "StateManager")
        }
    }

    static [void] RollbackService([object]$rec) {
        $serviceName = $rec.Path
        $orig = $rec.OriginalVal

        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($null -eq $service) {
                [Logger]::Warning("Service '$serviceName' not found during rollback.", "StateManager")
                return
            }

            $origStatus = $null
            $origStartType = $null

            if ($null -ne $orig) {
                if ($orig.ToString().StartsWith("{")) {
                    try {
                        $parsed = ConvertFrom-Json $orig
                        $origStatus = $parsed.Status
                        $origStartType = $parsed.StartType
                    } catch {
                        $origStatus = $orig.ToString()
                    }
                } else {
                    $origStatus = $orig.ToString()
                }
            }

            if (-not [string]::IsNullOrEmpty($origStartType)) {
                Set-Service -Name $serviceName -StartupType $origStartType -ErrorAction SilentlyContinue | Out-Null
                [Logger]::Debug("Restored: Set service $serviceName startup type to $origStartType", "StateManager")
            }

            if ($origStatus -eq "Stopped" -and $service.Status -ne "Stopped") {
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue | Out-Null
                [Logger]::Debug("Restored: Stopped service $serviceName", "StateManager")
            }
            elseif ($origStatus -eq "Running" -and $service.Status -ne "Running") {
                Start-Service -Name $serviceName -ErrorAction SilentlyContinue | Out-Null
                [Logger]::Debug("Restored: Started service $serviceName", "StateManager")
            }
        }
        catch {
            [Logger]::Error("Failed to rollback service $serviceName : $_", "StateManager")
        }
    }
}

# Register the CLI rollback handler
& ([ScriptBlock]::Create("[CommandBus]::RegisterHandler('rollback', `$args[0])")) {
    param($payload)
    [StateManager]::Rollback()
}

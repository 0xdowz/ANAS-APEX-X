# ANAS APEX X - SQLite Database Driver (Enterprise Grade)

# Compile C# P/Invoke helper for winsqlite3.dll if not already loaded
if (-not ([System.Management.Automation.PSTypeName]"Apex.Storage.SQLiteHelper").Type) {
    $code = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace Apex.Storage {
    public class SQLiteHelper {
        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern int sqlite3_open16(string filename, out IntPtr db);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int sqlite3_close(IntPtr db);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern int sqlite3_prepare16_v2(IntPtr db, string zSql, int nByte, out IntPtr ppStmt, IntPtr pzTail);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int sqlite3_step(IntPtr stmt);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int sqlite3_finalize(IntPtr stmt);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int sqlite3_column_count(IntPtr stmt);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern IntPtr sqlite3_column_name16(IntPtr stmt, int N);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern IntPtr sqlite3_column_text16(IntPtr stmt, int iCol);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        public static extern int sqlite3_bind_text16(IntPtr stmt, int index, string val, int nBytes, IntPtr pFree);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int sqlite3_bind_int64(IntPtr stmt, int index, long val);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int sqlite3_bind_null(IntPtr stmt, int index);

        [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern int sqlite3_exec(IntPtr db, string sql, IntPtr callback, IntPtr arg, out IntPtr errmsg);

        public static int ExecuteNonQuery(string dbPath, string sql) {
            IntPtr db = IntPtr.Zero;
            try {
                int rc = sqlite3_open16(dbPath, out db);
                if (rc != 0) return rc;

                IntPtr errmsg = IntPtr.Zero;
                return sqlite3_exec(db, sql, IntPtr.Zero, IntPtr.Zero, out errmsg);
            }
            finally {
                if (db != IntPtr.Zero) {
                    sqlite3_close(db);
                }
            }
        }

        public static int ExecuteParameterizedNonQuery(string dbPath, string sql, object[] parameters) {
            IntPtr db = IntPtr.Zero;
            IntPtr stmt = IntPtr.Zero;
            try {
                int rc = sqlite3_open16(dbPath, out db);
                if (rc != 0) return rc;

                rc = sqlite3_prepare16_v2(db, sql, sql.Length * 2, out stmt, IntPtr.Zero);
                if (rc != 0) return rc;

                if (parameters != null) {
                    for (int i = 0; i < parameters.Length; i++) {
                        int pIndex = i + 1;
                        object pVal = parameters[i];
                        if (pVal == null) {
                            sqlite3_bind_null(stmt, pIndex);
                        } else if (pVal is long || pVal is int || pVal is bool) {
                            long lVal = Convert.ToInt64(pVal);
                            sqlite3_bind_int64(stmt, pIndex, lVal);
                        } else {
                            sqlite3_bind_text16(stmt, pIndex, pVal.ToString(), -1, IntPtr.Zero);
                        }
                    }
                }

                return sqlite3_step(stmt);
            }
            finally {
                if (stmt != IntPtr.Zero) sqlite3_finalize(stmt);
                if (db != IntPtr.Zero) sqlite3_close(db);
            }
        }

        public static List<Dictionary<string, string>> ExecuteQuery(string dbPath, string sql) {
            var results = new List<Dictionary<string, string>>();
            IntPtr db = IntPtr.Zero;
            IntPtr stmt = IntPtr.Zero;

            try {
                if (sqlite3_open16(dbPath, out db) != 0) return results;

                if (sqlite3_prepare16_v2(db, sql, sql.Length * 2, out stmt, IntPtr.Zero) == 0) {
                    int colCount = sqlite3_column_count(stmt);
                    string[] colNames = new string[colCount];
                    for (int i = 0; i < colCount; i++) {
                        IntPtr ptr = sqlite3_column_name16(stmt, i);
                        colNames[i] = Marshal.PtrToStringUni(ptr);
                    }

                    while (sqlite3_step(stmt) == 100) { // 100 = SQLITE_ROW
                        var row = new Dictionary<string, string>();
                        for (int i = 0; i < colCount; i++) {
                            IntPtr ptr = sqlite3_column_text16(stmt, i);
                            row[colNames[i]] = ptr != IntPtr.Zero ? Marshal.PtrToStringUni(ptr) : null;
                        }
                        results.Add(row);
                    }
                }
            }
            finally {
                if (stmt != IntPtr.Zero) sqlite3_finalize(stmt);
                if (db != IntPtr.Zero) sqlite3_close(db);
            }

            return results;
        }

        public static string Escape(string val) {
            if (val == null) return "";
            return val.Replace("'", "''");
        }
    }
}
"@
    Add-Type -TypeDefinition $code -ErrorAction Stop
}

class SQLiteDatabase {
    static [string]$DatabasePath = ""

    static [void] Initialize([string]$dbPath) {
        [SQLiteDatabase]::DatabasePath = $dbPath

        $dir = Split-Path -Parent $dbPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # Enable WAL mode & busy timeout for thread safety
        [SQLiteDatabase]::ExecuteNonQueryPath($dbPath, "PRAGMA journal_mode=WAL;") | Out-Null
        [SQLiteDatabase]::ExecuteNonQueryPath($dbPath, "PRAGMA busy_timeout=5000;") | Out-Null

        # Corruption Check
        $check = [SQLiteDatabase]::ExecuteQueryPath($dbPath, "PRAGMA quick_check;")
        if ($null -eq $check -or $check.Count -eq 0 -or $check[0]["quick_check"] -ne "ok") {
            # Backup corrupted file and recreate
            $timestamp = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmmss")
            $corruptedBackup = "$dbPath.corrupted_$timestamp"
            Move-Item -Path $dbPath -Destination $corruptedBackup -Force -ErrorAction SilentlyContinue
        }

        # Initialize schema tables
        $schemaSql = @"
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id TEXT PRIMARY KEY,
    timestamp TEXT NOT NULL,
    status TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS transaction_records (
    record_id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id TEXT NOT NULL,
    type TEXT NOT NULL,
    path TEXT NOT NULL,
    name TEXT,
    original_val TEXT,
    original_kind TEXT,
    existed INTEGER NOT NULL,
    FOREIGN KEY(transaction_id) REFERENCES transactions(transaction_id) ON DELETE CASCADE
);
"@
        [SQLiteDatabase]::ExecuteNonQueryPath($dbPath, $schemaSql) | Out-Null
    }

    static [int] ExecuteNonQuery([string]$sql) {
        return [SQLiteDatabase]::ExecuteNonQueryPath([SQLiteDatabase]::DatabasePath, $sql)
    }

    static [int] ExecuteNonQueryPath([string]$dbPath, [string]$sql) {
        $sb = [ScriptBlock]::Create('param($p, $s) [Apex.Storage.SQLiteHelper]::ExecuteNonQuery($p, $s)')
        return & $sb $dbPath $sql
    }

    static [int] ExecuteParameterized([string]$sql, [array]$parameters) {
        $sb = [ScriptBlock]::Create('param($p, $s, $params) [Apex.Storage.SQLiteHelper]::ExecuteParameterizedNonQuery($p, $s, $params)')
        return & $sb [SQLiteDatabase]::DatabasePath $sql (, $parameters)
    }

    static [array] ExecuteQuery([string]$sql) {
        return [SQLiteDatabase]::ExecuteQueryPath([SQLiteDatabase]::DatabasePath, $sql)
    }

    static [array] ExecuteQueryPath([string]$dbPath, [string]$sql) {
        $sb = [ScriptBlock]::Create('param($p, $s) [Apex.Storage.SQLiteHelper]::ExecuteQuery($p, $s)')
        $dictList = & $sb $dbPath $sql
        $output = [System.Collections.Generic.List[hashtable]]::new()
        if ($null -ne $dictList) {
            foreach ($dict in $dictList) {
                $ht = @{}
                foreach ($k in $dict.Keys) {
                    $ht[$k] = $dict[$k]
                }
                $output.Add($ht)
            }
        }
        return $output.ToArray()
    }

    static [string] Escape([string]$val) {
        $sb = [ScriptBlock]::Create('param($v) [Apex.Storage.SQLiteHelper]::Escape($v)')
        return & $sb $val
    }
}

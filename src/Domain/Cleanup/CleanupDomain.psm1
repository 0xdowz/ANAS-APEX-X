using module "..\..\Logger\Logger.psm1"

# ANAS APEX X - Cleanup Domain

class CleanupDomain {
    static [long] Run() {
        [Logger]::Header("System Temp & Junk Cleanup")

        $totalFreed = 0L

        # Define targets to clean
        $userTemp = [System.IO.Path]::GetTempPath()
        $systemTemp = "C:\Windows\Temp"
        $prefetch = "C:\Windows\Prefetch"
        
        $targets = @($userTemp, $systemTemp, $prefetch)

        foreach ($t in $targets) {
            if (Test-Path $t) {
                [Logger]::Info("Scanning target path: $t", "CleanupDomain")
                $freed = [CleanupDomain]::CleanDirectory($t)
                $totalFreed += $freed
            }
        }

        $mbFreed = [Math]::Round($totalFreed / (1024 * 1024), 2)
        [Logger]::Separator()
        [Logger]::Success("System cleanup finished.", "CleanupDomain")
        [Logger]::Success("Total space reclaimed: $mbFreed MB", "CleanupDomain")
        [Logger]::Footer()

        return $totalFreed
    }

    static [long] CleanDirectory([string]$dirPath) {
        $freedBytes = 0L
        
        try {
            $items = Get-ChildItem -Path $dirPath -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $itemSize = 0L
                try {
                    if (-not $item.PSIsContainer) {
                        $itemSize = $item.Length
                        Remove-Item -Path $item.FullName -Force -ErrorAction Stop | Out-Null
                        $freedBytes += $itemSize
                        [Logger]::Debug("Deleted file: $($item.FullName) ($([Math]::Round($itemSize/1024, 1)) KB)", "CleanupDomain")
                    } else {
                        # Measure folder size recursively
                        $subFiles = Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        foreach ($sf in $subFiles) {
                            if (-not $sf.PSIsContainer) { $itemSize += $sf.Length }
                        }
                        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop | Out-Null
                        $freedBytes += $itemSize
                        [Logger]::Debug("Deleted directory: $($item.FullName) ($([Math]::Round($itemSize/1024, 1)) KB)", "CleanupDomain")
                    }
                }
                catch {
                    # Locked files are expected, skip silently
                }
            }
        }
        catch {
            [Logger]::Warning("Failed to scan or clean some items in $dirPath : $_", "CleanupDomain")
        }

        return $freedBytes
    }
}

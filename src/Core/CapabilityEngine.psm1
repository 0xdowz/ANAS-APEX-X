# ANAS APEX X - Capability Engine

class OSInfo {
    [string]$Caption
    [string]$Version
    [int]$Build
    [bool]$IsServer

    OSInfo([string]$caption, [string]$version, [int]$build, [bool]$isServer) {
        $this.Caption = $caption
        $this.Version = $version
        $this.Build = $build
        $this.IsServer = $isServer
    }
}

class CapabilityEngine {
    static [OSInfo]$CachedOSInfo = $null

    static [OSInfo] GetOSInfo() {
        if ($null -ne [CapabilityEngine]::CachedOSInfo) {
            return [CapabilityEngine]::CachedOSInfo
        }

        # Query OS from Repository or directly (using Cache Engine fallback)
        try {
            $os = Get-CimInstance -ClassName "Win32_OperatingSystem" -ErrorAction SilentlyContinue
            if ($null -ne $os) {
                # ProductType: 1 = Client (Workstation), 2/3 = Server
                $isServer = $os.ProductType -ne 1
                $build = [int]$os.BuildNumber
                
                [CapabilityEngine]::CachedOSInfo = [OSInfo]::new(
                    $os.Caption,
                    $os.Version,
                    $build,
                    $isServer
                )
            }
        }
        catch {
            # Fallback to Environment
            $isServer = $false # assumption
            $build = [System.Environment]::OSVersion.Version.Build
            [CapabilityEngine]::CachedOSInfo = [OSInfo]::new(
                "Windows (Fallback)",
                [System.Environment]::OSVersion.Version.ToString(),
                $build,
                $isServer
            )
        }

        return [CapabilityEngine]::CachedOSInfo
    }

    static [bool] SupportsHAGS() {
        # Hardware-Accelerated GPU Scheduling is supported if the registry key exists
        # usually under HKLM:\System\CurrentControlSet\Control\GraphicsDrivers
        # HwSchMode: 1 = Disabled, 2 = Enabled
        $path = "HKLM:\System\CurrentControlSet\Control\GraphicsDrivers"
        if (Test-Path $path) {
            $val = Get-ItemProperty -Path $path -Name "HwSchMode" -ErrorAction SilentlyContinue
            if ($null -ne $val) {
                return $true
            }
        }
        return $false
    }

    static [bool] SupportsMMCSS() {
        # Check if Multimedia Class Scheduler Service exists
        $svc = Get-Service -Name "MMCSS" -ErrorAction SilentlyContinue
        return $null -ne $svc
    }

    static [bool] SupportsFeature([string]$featureName) {
        switch ($featureName.ToLower()) {
            "hags" { return [CapabilityEngine]::SupportsHAGS() }
            "mmcss" { return [CapabilityEngine]::SupportsMMCSS() }
            "win11" { return [CapabilityEngine]::GetOSInfo().Build -ge 22000 }
            "win10" { return [CapabilityEngine]::GetOSInfo().Build -ge 10240 }
            "server" { return [CapabilityEngine]::GetOSInfo().IsServer }
            default { return $false }
        }
        return $false
    }
}

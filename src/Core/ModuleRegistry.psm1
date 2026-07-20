# ANAS APEX X - Module Registry

class ModuleMetadata {
    [string]$Name
    [string]$Version
    [string]$Path
    [string[]]$Dependencies
    [hashtable]$Compatibility

    ModuleMetadata([string]$name, [string]$version, [string]$path, [string[]]$dependencies, [hashtable]$compatibility) {
        $this.Name = $name
        $this.Version = $version
        $this.Path = $path
        $this.Dependencies = $dependencies
        $this.Compatibility = $compatibility
    }
}

class ModuleRegistry {
    static [hashtable]$LoadedModules = @{}
    static [ModuleMetadata[]]$LoadOrder = @()

    static [void] Initialize([string]$rootDir) {
        $srcDir = Join-Path $rootDir "src"
        if (-not (Test-Path $srcDir)) {
            throw "Source directory not found: $srcDir"
        }

        # 1. Discover modules
        $discovered = @{}
        $subdirs = Get-ChildItem -Path $srcDir -Directory
        foreach ($subdir in $subdirs) {
            $manifestPath = Join-Path $subdir.FullName "Module.json"
            if (Test-Path $manifestPath) {
                try {
                    $json = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
                    $deps = @()
                    if ($json.Dependencies) {
                        $deps = [string[]]$json.Dependencies
                    }
                    $compat = @{}
                    if ($json.Compatibility) {
                        # Convert PSCustomObject to hashtable
                        foreach ($prop in $json.Compatibility.psobject.Properties) {
                            $compat[$prop.Name] = $prop.Value
                        }
                    }

                    $metadata = [ModuleMetadata]::new(
                        $json.Name,
                        $json.Version,
                        $subdir.FullName,
                        $deps,
                        $compat
                    )
                    $discovered[$json.Name] = $metadata
                }
                catch {
                    Write-Error "Failed to parse module manifest at ${manifestPath} : $_"
                }
            }
        }

        # 2. Resolve dependencies (Topological Sort)
        $visited = @{}
        $tempVisited = @{}
        $resolved = [System.Collections.Generic.List[ModuleMetadata]]::new()

        foreach ($modName in $discovered.Keys) {
            [ModuleRegistry]::Visit($modName, $discovered, $visited, $tempVisited, $resolved)
        }

        [ModuleRegistry]::LoadOrder = $resolved.ToArray()

        # 3. Import modules in resolved order
        foreach ($module in [ModuleRegistry]::LoadOrder) {
            if ($module.Name -eq "Core") {
                # Core components are imported manually in Apex.psm1 to avoid bootstrapping loops.
                [ModuleRegistry]::LoadedModules[$module.Name] = $module
                continue
            }

            # Import the module file (*.psm1) with the same name as the module folder
            $psm1Path = Join-Path $module.Path "$($module.Name).psm1"
            if (Test-Path $psm1Path) {
                try {
                    . $psm1Path
                    [ModuleRegistry]::LoadedModules[$module.Name] = $module
                }
                catch {
                    throw "Failed to load module '$($module.Name)' at ${psm1Path} : $_"
                }
            }
            else {
                # Fallback to importing all psm1 files in the module root if target psm1 doesn't match name
                $files = Get-ChildItem -Path $module.Path -Filter "*.psm1"
                foreach ($file in $files) {
                    try {
                        . $file.FullName
                    }
                    catch {
                        throw "Failed to load module script at $($file.FullName) : $_"
                    }
                }
                [ModuleRegistry]::LoadedModules[$module.Name] = $module
            }
        }
    }

    static [void] Visit(
        [string]$name, 
        [hashtable]$discovered, 
        [hashtable]$visited, 
        [hashtable]$tempVisited, 
        [System.Collections.Generic.List[ModuleMetadata]]$resolved
    ) {
        if ($visited[$name]) { return }
        if ($tempVisited[$name]) {
            throw "Circular dependency detected at module: $name"
        }

        if (-not $discovered[$name]) {
            throw "Missing module dependency: $name"
        }

        $tempVisited[$name] = $true

        $metadata = $discovered[$name]
        foreach ($dep in $metadata.Dependencies) {
            [ModuleRegistry]::Visit($dep, $discovered, $visited, $tempVisited, $resolved)
        }

        $tempVisited[$name] = $false
        $visited[$name] = $true
        $resolved.Add($metadata)
    }

    static [ModuleMetadata] GetModule([string]$name) {
        return [ModuleRegistry]::LoadedModules[$name]
    }
}

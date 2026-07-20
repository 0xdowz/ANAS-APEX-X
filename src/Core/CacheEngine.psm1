# ANAS APEX X - Cache Engine

class CacheItem {
    [object]$Value
    [DateTime]$Expiration

    CacheItem([object]$value, [DateTime]$expiration) {
        $this.Value = $value
        $this.Expiration = $expiration
    }

    [bool] IsExpired() {
        return [DateTime]::UtcNow -gt $this.Expiration
    }
}

class CacheEngine {
    static [hashtable]$Cache = @{}
    static [object]$LockObject = [object]::new()

    static [object] Get([string]$key) {
        [System.Threading.Monitor]::Enter([CacheEngine]::LockObject)
        try {
            $cacheKey = $key.ToLower()
            if ([CacheEngine]::Cache.ContainsKey($cacheKey)) {
                $item = [CacheEngine]::Cache[$cacheKey]
                if (-not $item.IsExpired()) {
                    return $item.Value
                }
                # Evict expired item
                [CacheEngine]::Cache.Remove($cacheKey)
            }
            return $null
        }
        finally {
            [System.Threading.Monitor]::Exit([CacheEngine]::LockObject)
        }
    }

    static [void] Set([string]$key, [object]$value, [TimeSpan]$ttl) {
        [System.Threading.Monitor]::Enter([CacheEngine]::LockObject)
        try {
            $cacheKey = $key.ToLower()
            $expiration = [DateTime]::UtcNow.Add($ttl)
            [CacheEngine]::Cache[$cacheKey] = [CacheItem]::new($value, $expiration)
        }
        finally {
            [System.Threading.Monitor]::Exit([CacheEngine]::LockObject)
        }
    }

    static [object] GetOrSet([string]$key, [scriptblock]$fetchScript, [TimeSpan]$ttl) {
        $cachedVal = [CacheEngine]::Get($key)
        if ($null -ne $cachedVal) {
            return $cachedVal
        }

        # Value not in cache, fetch it
        $freshVal = $fetchScript.Invoke()
        [CacheEngine]::Set($key, $freshVal, $ttl)
        return $freshVal
    }

    static [void] Evict([string]$key) {
        [System.Threading.Monitor]::Enter([CacheEngine]::LockObject)
        try {
            $cacheKey = $key.ToLower()
            if ([CacheEngine]::Cache.ContainsKey($cacheKey)) {
                [CacheEngine]::Cache.Remove($cacheKey)
            }
        }
        finally {
            [System.Threading.Monitor]::Exit([CacheEngine]::LockObject)
        }
    }

    static [void] Clear() {
        [System.Threading.Monitor]::Enter([CacheEngine]::LockObject)
        try {
            [CacheEngine]::Cache.Clear()
        }
        finally {
            [System.Threading.Monitor]::Exit([CacheEngine]::LockObject)
        }
    }
}

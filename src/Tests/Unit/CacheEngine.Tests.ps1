using module "..\..\..\src\Core\CacheEngine.psm1"

Describe "CacheEngine Temp Storage" {
    It "Should cache and retrieve values" {
        [CacheEngine]::Clear()
        [CacheEngine]::Set("myKey", "myValue", [TimeSpan]::FromMinutes(1))
        $val = [CacheEngine]::Get("myKey")
        $val | Should Be "myValue"
    }

    It "Should return null for missing or expired keys" {
        [CacheEngine]::Clear()
        [CacheEngine]::Set("shortKey", "quickValue", [TimeSpan]::FromMilliseconds(200))
        $val1 = [CacheEngine]::Get("shortKey")
        $val1 | Should Be "quickValue"

        # Wait for expiration
        Start-Sleep -Milliseconds 300
        $val2 = [CacheEngine]::Get("shortKey")
        $val2 | Should BeNullOrEmpty
    }

    It "Should fetch via GetOrSet when cache misses" {
        [CacheEngine]::Clear()
        $script:called = 0
        $fetch = {
            $script:called++
            return "dynamicValue"
        }

        $res1 = [CacheEngine]::GetOrSet("fetchKey", $fetch, [TimeSpan]::FromMinutes(1))
        $res2 = [CacheEngine]::GetOrSet("fetchKey", $fetch, [TimeSpan]::FromMinutes(1))

        $res1 | Should Be "dynamicValue"
        $res2 | Should Be "dynamicValue"
        $script:called | Should Be 1
    }

    It "Should evict cached items manually" {
        [CacheEngine]::Clear()
        [CacheEngine]::Set("evictKey", "value", [TimeSpan]::FromMinutes(1))
        [CacheEngine]::Evict("evictKey")
        $val = [CacheEngine]::Get("evictKey")
        $val | Should BeNullOrEmpty
    }
}

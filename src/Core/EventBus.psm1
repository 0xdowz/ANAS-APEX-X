# ANAS APEX X - Event Bus

class EventBus {
    static [hashtable]$Listeners = @{}

    static [void] RegisterListener([string]$eventName, [scriptblock]$callback) {
        $key = $eventName.ToLower()
        if (-not [EventBus]::Listeners.ContainsKey($key)) {
            [EventBus]::Listeners[$key] = [System.Collections.Generic.List[scriptblock]]::new()
        }
        [EventBus]::Listeners[$key].Add($callback)
    }

    static [void] Publish([string]$eventName, [object]$data) {
        $key = $eventName.ToLower()
        if ([EventBus]::Listeners.ContainsKey($key)) {
            foreach ($callback in [EventBus]::Listeners[$key]) {
                try {
                    # Execute callback asynchronously or sequentially
                    # In PowerShell, we can just execute it sequentially in the dynamic scope
                    $callback.Invoke($data)
                }
                catch {
                    # Suppress event-handling errors to avoid breaking the main pipeline execution
                    Write-Debug "Event listener for '$eventName' failed: $_"
                }
            }
        }
    }
}

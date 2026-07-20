using module "..\..\Core\EventBus.psm1"

Describe "EventBus Pub/Sub System" {
    BeforeEach {
        [EventBus]::Listeners.Clear()
    }

    AfterEach {
        [EventBus]::Listeners.Clear()
    }

    It "Should trigger registered listeners when publishing events" {
        $script:eventReceived = $false
        $script:eventData = $null

        [EventBus]::RegisterListener("OnTestEvent", {
            param($data)
            $script:eventReceived = $true
            $script:eventData = $data
        })

        [EventBus]::Publish("OnTestEvent", @{ Message = "Hello World" })

        $script:eventReceived | Should -Be $true
        $script:eventData.Message | Should -Be "Hello World"
    }

    It "Should allow multiple listeners for the same event" {
        $script:count = 0
        [EventBus]::RegisterListener("MultiEvent", { $script:count++ })
        [EventBus]::RegisterListener("MultiEvent", { $script:count++ })

        [EventBus]::Publish("MultiEvent", $null)
        $script:count | Should -Be 2
    }
}

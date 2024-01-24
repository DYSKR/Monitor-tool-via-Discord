$configFilePath = [System.IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "%Data.txt")


$administratorAccountName = "Administrator"
$processedEvents = @{}
$eventTimeThreshold = 0
function Get-StoredWebhookUrl {
    if (Test-Path $configFilePath) {
        return Get-Content $configFilePath
    } else {
        return $null
    }
}
function Save-WebhookUrlToFile {
    param (
        [string]$url
    )
    $url | Out-File $configFilePath
}



function Send-DiscordMessage {
    param (
        [string]$title,
        [string]$description
    )
    $discordPayload = @{
        embeds = @(
            @{
                title = $title
                description = $description
                color = 2067276
            }
        )
    }
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($discordPayload | ConvertTo-Json) -ContentType 'application/json'
    } catch {
        Write-Host "Error sending message to Discord check %Data file in Documents : $_" -ForegroundColor Red
    }
}
function IsValid-WebhookUrl {
    param (
        [string]$url
    )
    return $url -match "^https://discord.com/api/webhooks/[0-9]+/.+$"
}

function Write-Color {
    param (
        [string]$text,
        [ConsoleColor]$color = 'White'
    )
    $previousColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $color
    Write-Host $text
    $Host.UI.RawUI.ForegroundColor = $previousColor
}

function Is-NearDuplicateEvent {
    param (
        [string]$eventKey,
        [Hashtable]$processedEvents,
        [datetime]$eventTime
    )
    if ($processedEvents.ContainsKey($eventKey)) {
        $lastEventTime = $processedEvents[$eventKey]
        $timeDiff = New-TimeSpan -Start $lastEventTime -End $eventTime
        if ($timeDiff.TotalSeconds -lt $eventTimeThreshold) {
            return $true
        }
    }
    $processedEvents[$eventKey] = $eventTime
    return $false
}

function IsValid-IPAddress {
    param (
        [string]$ipAddress
    )
    $nullIP = $null
    return [System.Net.IPAddress]::TryParse($ipAddress, [ref]$nullIP)
}

function Get-GeoLocation {
    param (
        [string]$ipAddress
    )
    if (-not (IsValid-IPAddress -ipAddress $ipAddress)) {
        Write-Host "Invalid IP address format; Ensure that u put RDP IP in script$ipAddress"
        return @{
            "ip" = $ipAddress
            "city" = "-"
            "region" = "-"
            "country" = "-"
            "loc" = "-"
            "org" = "-"
            "timezone" = "-"
        }
    }

    $token = ""  #YOUR TOKEN HERE , ipinfo.io
    $apiUrl = "https://ipinfo.io/$ipAddress/json?token=$token"
    try {
        $response = Invoke-RestMethod -Uri $apiUrl
        return $response | Select-Object -Property ip, city, region, country, loc, org, timezone
    } catch {
        Write-Host "API Call Failed:" $_
        return @{
            "ip" = $ipAddress
            "city" = "-"
            "region" = "-"
            "country" = "-"
            "loc" = "-"
            "org" = "-"
            "timezone" = "-"
        }
    }
}


Write-Host ""  
Write-Host ""  

$testIp = "" #SERVER IP HERE
$location = Get-GeoLocation -ipAddress $testIp
Write-Color "Server Information" -color Green
Write-Host ""
Write-Color "IP: $($location.ip)" -color Red
Write-Color "City: $($location.city)" -color Red
Write-Color "Region: $($location.region)" -color Red
Write-Color "Country: $($location.country)" -color Red
Write-Color "Location: $($location.loc)" -color Red
Write-Color "Timezone: $($location.timezone)" -color Red
Write-Host ""

function CreateLogonKey {
    param (
        [string]$username,
        [string]$ipAddress,
        [datetime]$timeCreated
    )
    return "$username|$ipAddress"
}

function Handle-Event {
    param (
        [Object]$logEvent
    )
    $xml = [xml]$logEvent.ToXml()
    $targetUserName = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "TargetUserName" } | Select-Object -ExpandProperty '#text'
    $ipAddress = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "IpAddress" } | Select-Object -ExpandProperty '#text'
    $deviceName = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "WorkstationName" } | Select-Object -ExpandProperty '#text'
    $eventTime = $event.TimeCreated

    if (-not $deviceName) {
        $deviceName = "Unknown Device"
    }

    $geoLocation = Get-GeoLocation -ipAddress $ipAddress
    $logonKey = CreateLogonKey -username $targetUserName -ipAddress $ipAddress -timeCreated $eventTime

    if ($logonType -eq '3' -and $targetUserName -eq $administratorAccountName -and $ipAddress -ne '-') {
        if (-not (Is-NearDuplicateEvent -eventKey $logonKey -processedEvents $processedEvents -eventTime $eventTime)) {
            $title = "Logon Detected"
            $eventTimeFormatted = Get-Date $eventTime -Format "MM/dd/yyyy hh:mm tt"
            $description = "User: $targetUserName `r`nIP: $($ipAddress) `r`nCity: $($ipInfo.city) `r`nRegion: $($ipInfo.region) `r`nCountry: $($ipInfo.country) `r`nLoc: $($ipInfo.loc) `r`nOrg: $($ipInfo.org) `r`nTimezone: $($ipInfo.timezone) `r`nDevice: $($deviceName) `r`nTime: $eventTimeFormatted"

            Write-Color "Notification: $description" -color Yellow
            Send-DiscordMessage $title $description
        }
    }
}

Write-color "Press 1 to start the script, or any other key to exit." -color Magenta
$userInput = Read-Host
if ($userInput -ne '1') {
    exit
}



Start-Sleep -Seconds 2
Write-Host ""
Write-Host ""
$webhookUrl = Get-StoredWebhookUrl
if (-not $webhookUrl -or -not (IsValid-WebhookUrl -url $webhookUrl)) {
    do {
        Write-Host ">> Enter the Discord Webhook URL:" -ForegroundColor Yellow
        $webhookUrl = Read-Host
    } while (-not (IsValid-WebhookUrl -url $webhookUrl))
    Save-WebhookUrlToFile -url $webhookUrl
    Write-Host ">> YOU SHOULD RUN THE SCRIPT AGAIN NOW !" -ForegroundColor Red

    exit 2
}





Write-Host ""
Write-Color "Script started. Monitoring for network connections by $administratorAccountName." -color DarkCyan
Write-Host ""
Write-Host "Script is running successfully DO NOT CLOSE IT" -ForegroundColor DarkYellow


Send-DiscordMessage "Script Started" "Monitoring for network connections by $administratorAccountName"

while ($true) {
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = 4624
        StartTime = (Get-Date).AddSeconds(-10)
    } -ErrorAction SilentlyContinue

    foreach ($event in $events) {
        $xml = [xml]$event.ToXml()
        $logonType = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "LogonType" } | Select-Object -ExpandProperty '#text'
        $targetUserName = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "TargetUserName" } | Select-Object -ExpandProperty '#text'
        $ipAddress = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "IpAddress" } | Select-Object -ExpandProperty '#text'
        $deviceName = $xml.Event.EventData.Data | Where-Object { $_.Name -eq "WorkstationName" } | Select-Object -ExpandProperty '#text'
        $eventTime = $event.TimeCreated

        if (-not $deviceName) {
            $deviceName = "Unknown Device"
        }

        $logonKey = CreateLogonKey -username $targetUserName -ipAddress $ipAddress -timeCreated $eventTime

        if ($logonType -eq '3' -and $targetUserName -eq $administratorAccountName -and $ipAddress -ne '-') {
            if (-not (Is-NearDuplicateEvent -eventKey $logonKey -processedEvents $processedEvents -eventTime $eventTime)) {
                $ipInfo = Get-GeoLocation -ipAddress $ipAddress
                $title = "Logon Detected"
                
                $eventTimeFormatted = Get-Date $eventTime -Format "MM/dd/yyyy hh:mm tt"
                $description = "User: $targetUserName `r`nIP: $($ipAddress) `r`nCity: $($ipInfo.city) `r`nRegion: $($ipInfo.region) `r`nCountry: $($ipInfo.country) `r`nTimezone: $($ipInfo.timezone) `r`nDevice: $($deviceName) `r`nTime: $eventTimeFormatted"

                Write-Color "Notification: $description" -color Yellow
                Send-DiscordMessage $title $description
            }
        }
    }

    Start-Sleep -Seconds 10
}

Write-Color "Script ended." -color Red

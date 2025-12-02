<# Azure front-door custom domain fixer, @cp7crash#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Subscription
)

$ErrorActionPreference = 'Stop'

#------------------------------------------------------------------------------
# 0. Check Az modules exist at all (very light-touch)
#------------------------------------------------------------------------------

try {
    # If this fails, Az modules are not installed
    Get-Command Get-AzSubscription -ErrorAction Stop | Out-Null
}
catch {
    Write-Error "Az PowerShell modules not found. Install them with: Install-Module Az -Scope CurrentUser"
    return
}

#------------------------------------------------------------------------------
# 1. Ensure we are logged in (Connect-AzAccount)
#------------------------------------------------------------------------------

try {
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
}
catch {
    $ctx = $null
}

if (-not $ctx -or -not $ctx.Account) {
    Write-Host "You are not logged in to Azure in Az PowerShell. Running Connect-AzAccount..."
    Connect-AzAccount -ErrorAction Stop | Out-Null

    # Refresh context after login
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx -or -not $ctx.Account) {
        Write-Error "Connect-AzAccount did not create a usable Az context. Aborting."
        return
    }
}

#------------------------------------------------------------------------------
# 2. Subscription selection helper
#------------------------------------------------------------------------------

function Select-Subscription {
    param(
        [Parameter(Mandatory = $false)]
        [string]$InitialSubscription
    )

    if ($InitialSubscription) {
        $sub = Get-AzSubscription |
            Where-Object { $_.Name -eq $InitialSubscription -or $_.Id -eq $InitialSubscription }

        if ($sub) {
            return $sub
        }

        Write-Warning "Subscription '$InitialSubscription' not found. You'll be prompted to select one."
    }

    $subs = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

    if (-not $subs -or $subs.Count -eq 0) {
        Write-Error "No enabled subscriptions were found for the current account."
        exit 1
    }

    Write-Host "🌐 Choose a subscription:"
    Write-Host

    for ($i = 0; $i -lt $subs.Count; $i++) {
        $index = $i + 1
        Write-Host ("{0,2}. {1} ({2})" -f $index, $subs[$i].Name, $subs[$i].Id)
    }

    Write-Host
    $n = $null

    while ($true) {
        $inputVal = Read-Host 'Select subscription to query'
        if ([int]::TryParse($inputVal, [ref]$n)) {
            if ($n -ge 1 -and $n -le $subs.Count) {
                break
            }
        }
        Write-Host "Please enter a valid number between 1 and $($subs.Count)." -ForegroundColor Yellow
    }

    return $subs[$n - 1]
}

#------------------------------------------------------------------------------
# 3. Resolve and set subscription context
#------------------------------------------------------------------------------

$sub = Select-Subscription -InitialSubscription $Subscription
Set-AzContext -SubscriptionId $sub.Id | Out-Null

Write-Host
Write-Host "🎯 Using subscription $($sub.Name) [$($sub.Id)]"
Write-Host
Write-Host "🔎 Looking for Azure Front Door CDNs..."
Write-Host

#------------------------------------------------------------------------------
# 4. Get all Front Door Standard/Premium profiles
#------------------------------------------------------------------------------

try {
    $afdProfiles = Get-AzFrontDoorCdnProfile
}
catch {
    Write-Error "Get-AzFrontDoorCdnProfile failed. Make sure the 'Az.Cdn' module is installed (Install-Module Az.Cdn -Scope CurrentUser)."
    return
}

if (-not $afdProfiles -or $afdProfiles.Count -eq 0) {
    Write-Host "No Azure Front Door profiles found in this subscription."
    exit 0
}

#------------------------------------------------------------------------------
# 5. Iterate profiles and their managed-cert custom domains
#------------------------------------------------------------------------------

foreach ($profile in $afdProfiles) {
    $resourceGroup = $profile.ResourceGroupName
    $afdName       = $profile.Name

    Write-Host "  🚪 Azure Front Door $afdName in Resource Group $resourceGroup..."

    try {
        $customDomains = Get-AzFrontDoorCdnCustomDomain `
            -ResourceGroupName $resourceGroup `
            -ProfileName $afdName
    }
    catch {
        Write-Warning "     Could not list custom domains for profile '$afdName' in RG '$resourceGroup'. Skipping."
        Write-Host
        continue
    }

    if (-not $customDomains -or $customDomains.Count -eq 0) {
        Write-Host "     ℹ️  No custom domains found on this profile."
        Write-Host
        continue
    }

    $managedDomains = $customDomains |
        Where-Object { $_.TlsSetting.CertificateType -eq 'ManagedCertificate' }

    if (-not $managedDomains -or $managedDomains.Count -eq 0) {
        Write-Host "     ✅ No domains were found that need revalidating (no ManagedCertificate domains)."
        Write-Host
        continue
    }

    foreach ($domain in $managedDomains) {
        $domainName = $domain.HostName
        $state      = $domain.DomainValidationState

        # Property names vary a bit between versions, so try a few
        $expiry = $domain.ValidationPropertyExpirationDate
        if (-not $expiry) { $expiry = $domain.ValidationPropertiesExpirationDate }

        $token  = $domain.ValidationPropertyValidationToken
        if (-not $token) { $token = $domain.ValidationPropertiesValidationToken }

        $dnsZoneInfo = $domain.AzureDnsZone

        Write-Host "     🌐 $domainName = $state"

        # 5a. If Pending or PendingRevalidation, consider regenerating token
        if ($state -eq 'Pending' -or $state -eq 'PendingRevalidation') {
            $expiryDate = $null

            if ($expiry) {
                try {
                    $expiryDate = [datetime]$expiry
                }
                catch {
                    Write-Host "           ⚠️  Could not parse token expiry date: $expiry"
                }
            }

            Write-Host "           Checking whether we can use the current validation token..."

            if ($expiryDate) {
                Write-Host "           ⏲️  Token $token expires on $($expiryDate.ToString('yyyy-MM-dd'))"
            }
            else {
                Write-Host "           ⏲️  Token expiry date is unknown."
            }

            if ($expiryDate -and $expiryDate.Date -lt (Get-Date).Date) {
                Write-Host "           Existing validation token has expired."
                Write-Host "           Please wait whilst a new validation token is generated..."

                try {
                    Update-AzFrontDoorCdnCustomDomainValidationToken `
                        -ResourceGroupName $resourceGroup `
                        -ProfileName $afdName `
                        -CustomDomainName $domain.Name | Out-Null
                }
                catch {
                    Write-Error "           Failed to regenerate validation token for $domainName. Check Az.Cdn version and permissions."
                    continue
                }

                # Reload domain after token regeneration
                $domain = Get-AzFrontDoorCdnCustomDomain `
                    -ResourceGroupName $resourceGroup `
                    -ProfileName $afdName `
                    -Name $domain.Name

                $state  = $domain.DomainValidationState
                $expiry = $domain.ValidationPropertyExpirationDate
                if (-not $expiry) { $expiry = $domain.ValidationPropertiesExpirationDate }
                $token  = $domain.ValidationPropertyValidationToken
                if (-not $token) { $token = $domain.ValidationPropertiesValidationToken }
            }
            else {
                Write-Host "           Existing validation token is still valid."
            }
        }

        # 5b. If still Pending, check/update DNS TXT record
        if ($state -eq 'Pending') {
            if (-not $token) {
                Write-Host "           ⚠️  No validation token found on domain. Skipping DNS update."
                continue
            }

            if (-not $dnsZoneInfo -or -not $dnsZoneInfo.Id) {
                Write-Host "           ⚠️  No AzureDnsZone info on this domain. Skipping DNS update."
                continue
            }

            # Parse zone name and resource group from DNS zone Id
            $zoneIdParts = $dnsZoneInfo.Id -split '/'
            $rgIndex     = $zoneIdParts.IndexOf('resourceGroups')
            $dnsIndex    = $zoneIdParts.IndexOf('dnszones')

            if ($rgIndex -lt 0 -or $dnsIndex -lt 0) {
                Write-Host "           ⚠️  Unexpected DNS zone Id format: $($dnsZoneInfo.Id)"
                continue
            }

            $zoneRg   = $zoneIdParts[$rgIndex + 1]
            $zoneName = $zoneIdParts[$dnsIndex + 1]

            # Derive _dnsauth.<relative-to-zone>
            $relative = $domainName
            if ($relative.ToLower().EndsWith($zoneName.ToLower())) {
                $relative = $relative.Substring(0, $relative.Length - $zoneName.Length).TrimEnd('.')
            }

            if ([string]::IsNullOrWhiteSpace($relative)) {
                $recordSetName = '_dnsauth'
            }
            else {
                $recordSetName = "_dnsauth.$relative"
            }

            try {
                $recordSet = Get-AzDnsRecordSet `
                    -Name $recordSetName `
                    -RecordType TXT `
                    -ZoneName $zoneName `
                    -ResourceGroupName $zoneRg
            }
            catch {
                Write-Host "           ⚠️  TXT record set '$recordSetName' not found in zone '$zoneName' (RG: $zoneRg)."
                Write-Host "               You may need to create it manually with value '$token'."
                continue
            }

            $currentToken = $null
            if ($recordSet -and $recordSet.Records -and $recordSet.Records.Count -gt 0) {
                $currentToken = $recordSet.Records[0].Value[0]
            }

            Write-Host "           Checking DNS Record for validation token"
            Write-Host "           - Old value: $currentToken"
            Write-Host "           + New value: $token"
            Write-Host

            if ($currentToken -ne $token) {
                Write-Host "           Your DNS TXT Record will be automatically updated."

                if (-not $recordSet.Records -or $recordSet.Records.Count -eq 0) {
                    $txt = New-AzDnsRecordConfig -Value $token
                    $recordSet.Records.Add($txt) | Out-Null
                }
                else {
                    $recordSet.Records[0].Value[0] = $token
                }

                try {
                    $updated = Set-AzDnsRecordSet -RecordSet $recordSet
                    Write-Host "           ✅  DNS Record update: $($updated.Etag)"
                }
                catch {
                    Write-Error "           Failed to update DNS TXT record '$recordSetName' in zone '$zoneName' (RG: $zoneRg)."
                }
            }
            else {
                Write-Host "           ✅  Your DNS Record has already been updated. Nothing to do."
            }
        }
    }

    Write-Host
}

Write-Host "All profiles processed."

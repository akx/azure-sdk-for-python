function ShouldMarkValueAsSecret([string]$serviceDirectoryPrefix, [string]$key, [string]$value, [array]$allowedValues)
{
    $logOutputNonSecret = @(
        # Environment Variables
        "RESOURCEGROUP_NAME",
        # Deployment Outputs
        "CLIENT_ID",
        "TENANT_ID",
        "SUBSCRIPTION_ID",
        "RESOURCE_GROUP",
        "LOCATION",
        "ENVIRONMENT",
        "AZURE_AUTHORITY_HOST",
        "RESOURCE_MANAGER_URL",
        "SERVICE_MANAGEMENT_URL"
    )

    $suffix1 = $key -replace $serviceDirectoryPrefix, ""
    $suffix2 = $key -replace "AZURE_", ""
    $variants = @($key, $suffix1, $suffix2)
    Write-Host "non secret"
    Write-Host "$serviceDirectoryPrefix"
    Write-Host "$key $suffix1 $suffix2"
    Write-Host "$($allowedValues | ConvertTo-Json)"
    if ($variants | Where-Object { $logOutputNonSecret -contains $_ }) {
        Write-Host "false for variant"
        return $false
    }

    if ($allowedValues -contains $value) {
        Write-Host "false for allowed"
        return $false
    }

    return $true
}

function SetSubscriptionConfiguration([object]$subscriptionConfiguration)
{
    foreach($pair in $subscriptionConfiguration.GetEnumerator()) {
        if ($pair.Value -is [Hashtable]) {
            foreach($nestedPair in $pair.Value.GetEnumerator()) {
                # Mark values as secret so we don't print json blobs containing secrets in the logs.
                # Prepend underscore to the variable name, so we can still access the variable names via environment
                # variables if they get set subsequently.
                Write-Host "##vso[task.setvariable variable=_$($nestedPair.Name);issecret=true;]$($nestedPair.Value)"
            }
        } else {
            Write-Host "##vso[task.setvariable variable=_$($pair.Name);issecret=true;]$($pair.Value)"
        }
    }

    Write-Host ($subscriptionConfiguration | ConvertTo-Json)
    $serialized = $subscriptionConfiguration | ConvertTo-Json -Compress
    Write-Host "##vso[task.setvariable variable=SubscriptionConfiguration;]$serialized"
}

function UpdateSubscriptionConfiguration([object]$subscriptionConfigurationBase, [object]$subscriptionConfiguration)
{
      foreach ($pair in $subscriptionConfiguration.GetEnumerator()) {
          if ($pair.Value -is [Hashtable]) {
              if (!$subscriptionConfigurationBase.ContainsKey($pair.Name)) {
                  $subscriptionConfigurationBase[$pair.Name] = @{}
              }
              foreach($nestedPair in $pair.Value.GetEnumerator()) {
                  # Mark values as secret so we don't print json blobs containing secrets in the logs.
                  # Prepend underscore to the variable name, so we can still access the variable names via environment
                  # variables if they get set subsequently.
                  Write-Host "##vso[task.setvariable variable=_$($nestedPair.Name);issecret=true;]$($nestedPair.Value)"
                  $subscriptionConfigurationBase[$pair.Name][$nestedPair.Name] = $nestedPair.Value
              }
            } else {
                Write-Host "##vso[task.setvariable variable=_$($pair.Name);issecret=true;]$($pair.Value)"
                $subscriptionConfigurationBase[$pair.Name] = $pair.Value
            }
      }

      $serialized = $subscriptionConfigurationBase | ConvertTo-Json -Compress
      Write-Host ($subscriptionConfigurationBase | ConvertTo-Json)
      Write-Host "##vso[task.setvariable variable=SubscriptionConfiguration;]$serialized"
}
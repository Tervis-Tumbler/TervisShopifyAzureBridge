using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "Get_TervisDiscountList > Received request."

$TenantId = $env:AzureAppTenantId
$ClientId = $env:AzureAppClientId
$ClientSecret = $env:AzureAppClientSecret
$Uri = $env:SharePointDiscountListUri

$Body = @{
    'tenant' = $TenantId
    'client_id' = $ClientId
    'scope' = 'https://graph.microsoft.com/.default'
    'client_secret' = $ClientSecret
    'grant_type' = 'client_credentials'
}

$Params = @{
    'Uri' = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    'Method' = 'Post'
    'Body' = $Body
    'ContentType' = 'application/x-www-form-urlencoded'
}

try {
    $AuthResponse = Invoke-RestMethod @Params
    
    $Headers = @{
        'Authorization' = "Bearer $($AuthResponse.access_token)"
    }
    
    $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers
    $Status = [HttpStatusCode]::OK

    $Result = $Response.value.fields | 
        Where-Object Active -EQ $True |
        ForEach-Object {
            [PSCustomObject]@{
                discount_description = $_.Title
                type = $_.Type.toLower()
                amount = $_.Amount
                kind = $_.Kind.toLower()
                description_text = $_.Reason_x0020_Code_x0020_Descript
            }
        } |
        # Select-Object -Property `
            # "Title",
            # "Location",
            # "Type",
            # "Amount",
            # @{N="Description";E={$_."Reason_x0020_Code_x0020_Descript"}} | 
        ConvertTo-Json -Compress
    Write-Host "Get_TervisDiscountList > Retrieved $($Result.count) codes."
} catch {
    $Status = [HttpStatusCode]::BadRequest
    $Result = $_ | ConvertTo-Json -Compress
    Write-Host "Get_TervisDiscountList > $_"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $Result
    ContentType = "application/json"
})

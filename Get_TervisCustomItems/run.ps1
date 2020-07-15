using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "Get_TervisCustomItems > Received request."

# Interact with query parameters or the body of the request.
$Domain = $Request.Body.domain

try {
    $Result = @()
    $Result += Get-TervisShopifyPersFeeObjects -Domain $Domain
    $Result += Get-TervisShopifyShippingObjects -Domain $Domain
    $body = $Result | ConvertTo-Json -Compress
    $status = [HttpStatusCode]::OK
} catch {  
    $body = "{`"error`": `"$Error`"}"
    $status = [HttpStatusCode]::BadRequest
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
    ContentType = "application/json"
})
using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$BodyStr = $Request.Body | ConvertTo-Json
Write-Warning "Get_ShopifyProduct > Received request:`n$BodyStr"

# Interact with query parameters or the body of the request.

$Params = @{
    Domain = $Request.Body.domain
    LineItems = $Request.Body.line_items
}

# Write to the Azure Functions log stream.
Write-Warning "Get_ShopifyProduct > Received following params:`n$Params"

try {
    [array]$Result = $Params.LineItems | Get-ShopifyProductVariant -Domain $Params.Domain
    $body = ConvertTo-Json -Compress -InputObject $Result
    Write-Host $body
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
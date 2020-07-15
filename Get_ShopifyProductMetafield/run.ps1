using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$BodyStr = $Request.Body | ConvertTo-Json
Write-Host "Get_ShopifyProductMetafield > Received request:`n$BodyStr"

# Interact with query parameters or the body of the request.

$MetafieldParams = @{
    Domain = $Request.Body.domain
    ProductId = $Request.Body.productId
    Namespace = $Request.Body.namespace
    Key = $Request.Body.key
}

# Write to the Azure Functions log stream.
Write-Host "Get_ShopifyProductMetafield > Getting metafield data for product ID: $($MetafieldParams.ProductId)"

try {
    $Result = Get-ShopifyProductMetafieldValue @MetafieldParams
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
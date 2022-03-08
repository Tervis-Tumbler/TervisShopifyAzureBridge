function Invoke-ShopifyAPIFunction{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Body,
        [Parameter(Mandatory)]$Domain,
        $APIVersion = "2020-04"
    )
    $ShopifyAccessToken = Get-TervisShopifyAccessToken -Domain $Domain
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $URI = "https://$Domain.myshopify.com/admin/api/$APIVersion/graphql.json"
    $Headers = @{
        "X-Shopify-Access-Token" = "$ShopifyAccessToken"
        "Content-Type" = "application/graphql"
    }

    do {
        try {
            $Response = Invoke-RestMethod -Method POST -Headers $Headers -Uri $URI -Body $Body
            $Throttled = $Response.errors -and ($Response.errors[0].message -eq "Throttled")
            if ($Throttled) {
                $Response | Invoke-ShopifyAPIThrottle    
            } else {
                return $Response
            }
        } catch [System.Net.WebException] {
            $StatusCode = $_.Exception.Response.StatusCode
            if ($StatusCode -eq 503) {
                Write-Warning -Message "Received 503: Service Unavailabe. Retrying in 1 second"
                Start-Sleep -Seconds 1
            } elseif ($StatusCode -eq 504) {
                Write-Warning -Message "Received 504: Gateway Timeout. Retrying in 1 second"
                Start-Sleep -Seconds 1
            }
            else {
                throw $_
            }
        } catch {
            throw $_
        }
    } while ($Throttled -or ($StatusCode -in 503,504))
}

function Invoke-ShopifyAPIThrottle {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]$Response
    )
    process {
        $RequestedQueryCost = $Response.extensions.cost.requestedQueryCost
        $RestoreRate = $Response.extensions.cost.throttleStatus.restoreRate
        $CurrentlyAvailable = $Response.extensions.cost.throttleStatus.currentlyAvailable

        if ($CurrentlyAvailable -lt $RequestedQueryCost -and $RestoreRate -gt 0) {
            $SecondsToWait = [System.Math]::Ceiling( ($RequestedQueryCost - $CurrentlyAvailable) / $RestoreRate )
            Write-Warning "Throttling for $SecondsToWait second$(if ($SecondsToWait -gt 1) { "s" })"
            Start-Sleep -Seconds $SecondsToWait
        }
    }
}

function Get-TervisShopifyAccessToken {
    param (
        [Parameter(Mandatory)]$Domain
    )
    switch ($Domain) {
        "dlt-tervisstore"   { $env:ShopifyAccessToken_Delta }
        "sit-tervisstore"   { $env:ShopifyAccessToken_Epsilon }
        "tervisstore"       { $env:ShopifyAccessToken_Production }
        Default {}
    }
}

function Get-ShopifyProductMetafieldValue {
    param (
        [Parameter(Mandatory)]$Domain,
        [Parameter(Mandatory)]$ProductId,
        [Parameter(Mandatory)]$Namespace,
        [Parameter(Mandatory)]$Key
    )
    
    $GraphQLQuery = @"
        {
            product(
                id:"gid://shopify/Product/$ProductId"
            ) {
                metafield(
                    namespace: "$Namespace"
                    key: "$Key"
                ) {
                    value
                }
            }
        } 
"@
    $Response = Invoke-ShopifyAPIFunction -Body $GraphQLQuery -Domain $Domain
    
    return [PSCustomObject]@{
        productId = $ProductId
        namespace = $Namespace
        key = $Key
        value = $Response.data.product.metafield.value
    }
}

function Get-ShopifyProductVariant {
    param (
        [Parameter(Mandatory)]$Domain,
        [Parameter(Mandatory, ValueFromPipeline)]$LineItems
    )
        begin {
            $VariantList = @()
        }
        process {
            $VariantId = $LineItems.variant_id
            $GraphQLQuery = @"
            {
                productVariant(id: "gid://shopify/ProductVariant/$VariantId") {
                    sku
                }
            }
"@
        $Response = Invoke-ShopifyAPIFunction -Body $GraphQLQuery -Domain $Domain
        
        $VariantList += [PSCustomObject]@{
            variantId = $VariantId
            sku = $Response.data.productVariant.sku
        }
    }
    end {
        return $VariantList
    }
}

function Get-TervisShopifyPersFeeObjects {
    param (
        [Parameter(Mandatory)]$Domain
    )       
    $Products = @()
    $CurrentCursor = ""
    
    do {
        $QraphQLQuery = @"
        {
            productVariants (first: 2, query:"PERS+FEE") {
              edges {
                node {
                  product {
                    title
                  }
                  sku
                  legacyResourceId
                }
              }
            }
          }   
"@
        $Response = Invoke-ShopifyAPIFunction -Body $QraphQLQuery -Domain $Domain
        $CurrentCursor = $Response.data.productVariants.edges | Select-Object -Last 1 -ExpandProperty cursor -ErrorAction SilentlyContinue
        $Products += $Response.data.productVariants.edges.node
    } while ($Response.data.productVariants.pageInfo.hasNextPage)
    Write-Host "Get_TervisCustomItems > Found $($Products.count) Personalization Fee Objects."
    return $Products | ForEach-Object {
        [PSCustomObject]@{
            title = $_.product.title
            sku = $_.sku
            variantId = $_.legacyResourceId
        }
    }
}

function Get-TervisShopifyShippingObjects {
    param (
        [Parameter(Mandatory)]$Domain
    )
       
    $Products = @()
    $CurrentCursor = ""
    
    do {
        $QraphQLQuery = @"
        {
            productVariants (first: 5, query:"Shipping") {
              edges {
                node {
                  sku
                  legacyResourceId
                }
              }
            }
          }
"@
        $Response = Invoke-ShopifyAPIFunction -Body $QraphQLQuery -Domain $Domain
        $CurrentCursor = $Response.data.productVariants.edges | Select-Object -Last 1 -ExpandProperty cursor -ErrorAction SilentlyContinue
        $Products += $Response.data.productVariants.edges.node
    } while ($Response.data.productVariants.pageInfo.hasNextPage)
    Write-Host "Get_TervisCustomItems > Found $($Products.count) Shipping items"
    return $Products | ForEach-Object {
        [PSCustomObject]@{
            title = $_.sku
            variantId = $_.legacyResourceId
        }
    }
}
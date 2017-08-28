function Invoke-OAuth-Request
{ 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string]$URI,
        [ValidateSet('POST','GET')]
        [Parameter(Mandatory=$true)] [string]$Method,
        [Parameter(Mandatory=$false)] [hashtable]$Parameters,
        [Parameter(Mandatory=$true)] [string]$ConsumerKey,
        [Parameter(Mandatory=$true)] [string]$ConsumerSecret,
        [Parameter(Mandatory=$false)] [string]$Token,
        [Parameter(Mandatory=$false)] [string]$TokenSecret = ""
    )
  
    $oauth_nonce = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes([System.DateTime]::Now.Ticks.ToString()))
    $oauth_timestamp = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()

    $SignatureMap = @{}
    $SignatureMap.Add("oauth_consumer_key", $ConsumerKey)
    $SignatureMap.Add("oauth_nonce", $oauth_nonce)
    $SignatureMap.Add("oauth_signature_method", "HMAC-SHA1")
    $SignatureMap.Add("oauth_timestamp", $oauth_timestamp)
    if ($Token) {
        $SignatureMap.Add("oauth_token", $Token);
    }
    if ($Parameters) {
        $Parameters.GetEnumerator() | ForEach-Object {$SignatureMap.Add($_.Key, $_.Value)}
    }

    $signature = $Method + "&"
    $signature += [System.Uri]::EscapeDataString($URI) + "&"
    
    $first = $true
    $SignatureMap.GetEnumerator() | Sort-Object -Property Name | ForEach-Object {
        if ($first) {
            $first = $false
        } else {
            $signature += [System.Uri]::EscapeDataString('&')
        }
        $signature += [System.Uri]::EscapeDataString($_.Key + '=' + $_.Value)
    }

    $key = $ConsumerSecret + '&' + $TokenSecret
    $hmacsha1 = new-object System.Security.Cryptography.HMACSHA1;
    $hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($key); 
    $oauth_signature = [uri]::EscapeDataString([System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($signature))))

    $auth  = 'OAuth realm="",'
    $auth += 'oauth_consumer_key="' + $ConsumerKey + '",'
    if ($Token) {
        $auth += 'oauth_token="' + $oauth_token + '",'
    }
    $auth += 'oauth_signature_method="HMAC-SHA1",'
    $auth += 'oauth_timestamp="' + $oauth_timestamp + '",'
    $auth += 'oauth_nonce="' + $oauth_nonce + '",'
    $auth += 'oauth_signature="' + $oauth_signature + '"'

    Write-Output $signature
    Write-Output $auth

    $reply = Invoke-RestMethod -Uri $URI -Method $Method -Headers @{"Authorization"=$auth} -ContentType "application/x-www-form-urlencoded" -Body $Parameters

    return $reply
}

function Invoke-Browser {
    
    param (
        [Parameter(Mandatory=$true)] [string]$URI
    )

    Start-Process -FilePath  $URI
    
    Write-Host 'Web Browser was opened. Please authorize this application to access your account data' -ForegroundColor Yellow
    Write-Host -NoNewLine 'Press any key when ready...'  -ForegroundColor Yellow
    [Console]::ReadKey($True) | Out-Null
}
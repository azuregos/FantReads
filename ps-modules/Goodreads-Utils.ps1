function Invoke-OAuth-Request { 
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

function Request-OAuth-Access
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [String]$ApiKey,
        [Parameter(Mandatory=$true)] [String]$ApiSecret
    )

    #Reqest Request Token
    $uri = "http://www.goodreads.com/oauth/request_token"
    $reply = Invoke-OAuth-Request -Uri $uri -Method 'POST' -ConsumerKey $ApiKey -ConsumerSecret $ApiSecret

    $oauth_token = ($reply.Split('&') | Where-Object {$_.StartsWith("oauth_token=")}).Split('=')[1]
    $oauth_token_secret = ($reply.Split('&') | Where-Object {$_.StartsWith("oauth_token_secret=")}).Split('=')[1]

    #Authorize application
    Invoke-Browser -URI "http://www.goodreads.com/oauth/authorize?oauth_token=$($oauth_token)"

    #Reqest Acess Token
    $uri = "http://www.goodreads.com/oauth/access_token"
    $reply = Invoke-OAuth-Request -Uri $uri -Method 'POST' -ConsumerKey $ApiKey -ConsumerSecret $ApiSecret -Token $oauth_token -TokenSecret  $oauth_token_secret

    $tokens = @{}
    $tokens.Add("user_token", ($reply.Split('&') | Where-Object {$_.StartsWith("oauth_token=")}).Split('=')[1])
    $tokens.Add("user_secret", ($reply.Split('&') | Where-Object {$_.StartsWith("oauth_token_secret=")}).Split('=')[1])

    return $tokens
}

function Get-UserId { 

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string]$Key,
        [Parameter(Mandatory=$true)] [string]$Username
    )

    $id = -1

    try {
        $reply = Invoke-RestMethod -Uri "https://www.goodreads.com/user/show?key=$($Key)&username=$($Username)" -Method Get
        $id = $reply.GoodreadsResponse.user.id
    }
    catch {
        Write-Host "User $Username not found or API key is invalid" -ForegroundColor Red
        exit
    }
    
    Write-Host "Goodreads User ID: $id ($Username)" -ForegroundColor Green

    return $id
}

function Get-Godreads-Books {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string]$Key,
        [Parameter(Mandatory=$true)] [string]$UserId,
        [Parameter(Mandatory=$true)] [string]$Shelf
    )

    Write-Host "Reading books from '$Shelf': " -ForegroundColor Green -NoNewline

    $books = New-Object System.Collections.ArrayList
    $page = 1
    $cnt = 0

    Do
    {
        $ProgressPreference = 'SilentlyContinue' 
        $reply = Invoke-RestMethod -Uri "https://www.goodreads.com/review/list?v=2&id=$($UserId)&shelf=$($Shelf)&key=$($Key)&per_page=50&page=$($page)" -Method Get
        $ProgressPreference = 'Continue' 

        
        Foreach ($review in $reply.GoodreadsResponse.reviews.review)
        {
            $cnt++   
            Write-Progress -Activity "Reading Book" -PercentComplete (($cnt / $reply.GoodreadsResponse.reviews.total) * 100)
            
            $book = New-Object PSCustomObject
            $book | Add-Member -type NoteProperty -name "AuthorEN" -Value ($review.book.authors.author.name -Join ', ') 
            $book | Add-Member -type NoteProperty -name "TitleEN" -Value $review.book.title_without_series
            $book | Add-Member -type NoteProperty -name "Score" -Value $review.rating
            $books.Add($book) | Out-Null
        }

        $page++
    } while ($reply.GoodreadsResponse.reviews.end -lt $reply.GoodreadsResponse.reviews.total)

    Write-Progress -Activity "Reading Books" -Completed
    Write-Host "$($books.Count) Books Found" -ForegroundColor White

    return $books
}
function Get-UserId
{ 
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
        Write-Host "User $($Username) not found or API key is invalid" -ForegroundColor Red
        exit
    }
    
    return $id
}
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
        Write-Host "User $Username not found or API key is invalid" -ForegroundColor Red
        exit
    }
    
    Write-Host "Goodreads User ID: $id ($Username)" -ForegroundColor Green

    return $id
}

function Get-Godreads-Books
{ 
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
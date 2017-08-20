function Get-Books
{ 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]  [string]$URI,
        [Parameter(Mandatory=$false)] [boolean]$FollowPages = $true,
        [Parameter(Mandatory=$false)] [boolean]$UseJsonAPI = $true
    )

    Write-Host "Reading books from $($URI): " -ForegroundColor Green -NoNewline

    # Get starting Fantlab ratings page (unparsed)
    $pageRaw = Invoke-WebRequest -Uri $URI -TimeoutSec 10 -DisableKeepAlive  -Method Get -UseBasicParsing

    #Find Table with relevant data
    $tableStart = $pageRaw.RawContent.IndexOf("<table");
    $tableEnd = $pageRaw.RawContent.IndexOf("</table>");

    # Extract table 
    $tableRaw = $pageRaw.RawContent.Substring($tableStart, $tableEnd - $tableStart)

    #Parse table with HTML parser
    $tableHTML = New-Object -ComObject "HTMLFile";
    $tableHTML.IHTMLDocument2_write($tableRaw);

    #Extract rows
    $tableRows = ($tableHTML.getElementsByTagName('tr') | Where-Object {$_.parentNode.parentNode.className -eq "v9b"})

    #Extract records from rows
    $books = New-Object System.Collections.ArrayList
    foreach ($row in $tableRows)
    {
        $bookRecord = $row.getElementsByTagName('TD')
        $book = $null
        foreach ($record in $bookRecord)
        {
            if ($book)
            {
                $score = 0
                if ([int]::TryParse($record.innerText, [ref]$score))
                {
                    $book | Add-Member -type NoteProperty -name "Score" -Value $score
                    $books.Add($book) | Out-Null
                }
                $book = $null
                break;
            } else {
                if ($UseJsonAPI) {
                    $book = ReadBook $record.innerHTML
                } else {
                    $book = ParseBook $record.innerText
                }
            }
        }
    }

    Write-Host "$($books.Count) Books Found" -ForegroundColor White

    #Repeat for all other pages (books are displayed in blocks of 200)
    if ($FollowPages)
    {
        $pages = $pageRaw.Links | Where-Object {$_.href -And $_.href.IndexOf('markspage') -gt 0} | Select-Object -Property href -Unique
        
        Write-Verbose "Other Pages to process: $($pages.Count)"
        foreach ($page in $pages) 
        {
            $pageURI = "https://fantlab.ru" + $page.href;
            $moreBooks = Get-Books -URI $pageURI -FollowPages $false
            $books.AddRange($moreBooks)
        }
    }
    
    return $books
}

function ParseBook
{
    param ([string]$text)

    Write-Debug "Parsing book: $($text)"
    $book = New-Object PSCustomObject
    $startQuote = [char]0x00ab  # «
    $endQuote = [char]0x00bb    # »
    if (-Not $text.Contains($startQuote)) 
    {
        return $book
    }
    $parts = $text.Split('/').Trim() 
    switch ($parts.Count)
    {
        1 {  
            $strIdx = $parts.IndexOf('.') + 1
            $endIdx = $parts.IndexOf($startQuote) - 1
            $author = $parts.Substring($strIdx, $endIdx - $strIdx).Trim()
            $strIdx = $parts.IndexOf($startQuote) + 1
            $endIdx = $parts.IndexOf($endQuote) 
            $title =  $parts.Substring($strIdx, $endIdx - $strIdx).Trim()
            $book | Add-Member -type NoteProperty -name "AuthorRU" -Value $author
            $book | Add-Member -type NoteProperty -name "TitleRU" -Value $title
            $book | Add-Member -type NoteProperty -name "TitleEN" -Value "-"
         }
        2 {
            $strIdx = $parts[0].IndexOf('.') + 1
            $endIdx = $parts[0].IndexOf($startQuote) - 1
            $author = $parts[0].Substring($strIdx, $endIdx - $strIdx).Trim()
            $strIdx = $parts[0].IndexOf($startQuote) + 1
            $endIdx = $parts[0].IndexOf($endQuote) 
            $titleRu = $parts[0].Substring($strIdx, $endIdx - $strIdx).Trim()
            $strIdx = $parts[1].IndexOf($startQuote) + 1
            $endIdx = $parts[1].IndexOf($endQuote) 
            $titleEn = $parts[1].Substring($strIdx, $endIdx - $strIdx).Trim()
            $book | Add-Member -type NoteProperty -name "AuthorRU" -Value $author
            $book | Add-Member -type NoteProperty -name "TitleRU" -Value $titleRu
            $book | Add-Member -type NoteProperty -name "TitleEN" -Value $titleEn
         }
    }
    return $book
}

function ReadBook
{
    param ([string]$html)
    
    $book = New-Object PSCustomObject
    $strIdx = $html.IndexOf("/work") + 5
    If ($strIdx-5 -gt 0)
    {
        $endIdx = $html.IndexOf('"', $strIdx)
        $workId = $html.Substring($strIdx, $endIdx - $strIdx)
        Write-Verbose "Get information about work$($workId)"
        
        #Invoke JSON API: https://api.fantlab.ru/work/XXXX
        $apiURI = "https://api.fantlab.ru/work/$($workId)"
        $json = Invoke-RestMethod -Uri $apiURI -Method Get -TimeoutSec 10

        $book | Add-Member -type NoteProperty -name "AuthorRU" -Value $json.authors[0].name
        $book | Add-Member -type NoteProperty -name "TitleRU" -Value $json.work_name
        $book | Add-Member -type NoteProperty -name "AuthorEN" -Value $json.authors[0].name_orig
        $book | Add-Member -type NoteProperty -name "TitleEN" -Value $json.work_name_orig
        $book | Add-Member -type NoteProperty -name "Type" -Value $json.work_type_name
    }
    return $book
}

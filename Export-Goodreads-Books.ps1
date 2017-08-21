<#

.SYNOPSIS
    Export rated books from the goodreads.com site into a number of supported formats 

.DESCRIPTION
    This script will perform a series of HTTP requests to a goodreads.com website
    to collect a list of books rates by a user, specified in script parameters.
    No authentication is needed to collect data.

.PARAMETER Username
    A username for whom books will be exported. This is your Goodreads login.

.PARAMETER Key
    A developer key for using the Goodreads API. See https://www.goodreads.com/api/keys

.PARAMETER Bookshelf
    Goodreads book shelf to export from. 'read' is assumed by default. 

.PARAMETER OutputFormat
    The representation of the exported information. One of the: 'Table','JSON','XML','CSV' or 'Null'

.PARAMETER OutFile
    Write collected information to a file, specefied by this parameter.

.EXAMPLE
    Output all books for user user123 to console in Table format
    .\Export-Goodreads-Books.ps1 -Username user123 -Key XXXXXXXXXX

.EXAMPLE
    Output all books for user user123 to console in JSON format
    .\Export-Goodreads-Books.ps1 -Username user123 -OutputFormat JSON -Key XXXXXXXXXX

.EXAMPLE
    Write all books for user user123 to export.xlm in XML format
    .\Export-Goodreads-Books.ps1 -Username user123 -OutputFormat XML -OutFile ".\export.xlm" -Key XXXXXXXXXX

.NOTES
    Author: Pospishnyi Oleksandr
    Date:   Aug 20, 2017   

.LINK
    https://github.com/azuregos/FantReads
#>

param (
    [Parameter(Mandatory=$true, Position=0, 
    HelpMessage="Goodreads username (login)")]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory=$true, Position=1, 
    HelpMessage="Goodreads API Key")]
    [ValidateNotNullOrEmpty()]
    [string]$Key,

    [Parameter(Mandatory=$false)]
    [string]$Bookshelf = "read",

    [Parameter(Mandatory=$false)]  
    [ValidateSet('Table','JSON','XML','CSV', 'Null')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory=$false)] 
    [string]$OutFile
)

Import-Module .\ps-modules\Goodreads-Utils.ps1 -Force

$userId = Get-UserId -Username $Username -Key $Key

Write-Host "Goodreads User ID: $($userId)" -ForegroundColor Green

#READ https://www.goodreads.com/review/list?v=2&id=XXXX&shelf=XXXX&key=XXXXX

switch ($OutputFormat) {
    'Table' { $out = $books | Format-Table }
    'JSON'  { $out = $books | ConvertTo-Json }
    'XML'   { $out = $books | ConvertTo-Xml -As String }
    'CSV'   { $out = $books | ConvertTo-Csv}
    Default { $out = ""}
}

if ($OutFile) {
    Write-Verbose "Write to: $($OutFile)"
    $out | Out-File $OutFile
} else {
    Write-Verbose "Result:"
    Write-Output $out 
}

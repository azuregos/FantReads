<#

.SYNOPSIS
    Export rated books from the fantlab.ru site into a number of supported formats 

.DESCRIPTION
    This script will perform a series of HTTP requests to a fantlab.ru and api.fantlab.ru websites 
    to collect a list of books rates by a user, specified in script parameters.
    No authentication is needed to collect data.

.PARAMETER Username
    A username for whom books will be exported. 
    This is not a login name, but a user name seen in the URL on your profile page: http://fantlab.ru/userXXXX 
    'userXXXX' is an expected Username format for this script.

.PARAMETER OutputFormat
    The representation of the exported information. One of the: 'Table','JSON','XML','CSV' or 'Null'

.PARAMETER OutFile
    Write collected information to a file, specefied by this parameter.

.PARAMETER UseJsonAPI
    Use api.fantlab.ru API to retrieve additional indormation about books. 
    If set to false, only basic information will be exported: Author(RUS), Title(RUS and ENG), Score

.EXAMPLE
    Output all books for user User1234 to console in Table format
    .\Export-FL-Books.ps1 -Username User1234 

.EXAMPLE
    Output all books for user User1234 to console in JSON format
    .\Export-FL-Books.ps1 -Username User1234 -OutputFormat JSON

.EXAMPLE
    Write all books for user User1234 to export.xlm in XML format
    .\Export-FL-Books.ps1 -Username User1234 -OutputFormat XML -OutFile ".\export.xlm" 

.NOTES
    Author: Pospishnyi Oleksandr
    Date:   Aug 20, 2017   

.LINK
    https://github.com/azuregos/FantReads
#>

param (
    [Parameter(Mandatory=$true, Position=0, 
    HelpMessage="Fantlab.ru user to import data from (this is not a login name, but a real user name seen in the URL on your profile page")]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory=$false)]  
    [ValidateSet('Table','JSON','XML','CSV', 'Null')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory=$false)] 
    [string]$OutFile,

    [Parameter(Mandatory=$false)] 
    [boolean]$UseJsonAPI = $true
)

Import-Module .\ps-modules\Fantlab-Utils.ps1 -Force

$books = Get-Books -URI "https://fantlab.ru/$($Username)/marks" -UseJsonAPI $UseJsonAPI

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

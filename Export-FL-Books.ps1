param (
    [string]$Username
)

Import-Module .\ps-modules\Fantlab-Utils.ps1 -Force

Get-Books -URI 'https://fantlab.ru/$($Username)/marks'

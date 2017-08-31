function Read-Key
{
    if (-Not (Test-Path '.\api.key'))
    {
        Write-Host -ForegroundColor Red "'api.key' file was not found. Cannot proceed."
        Exit
    }
    $Keys = Get-Content -Path '.\api.key' | ConvertFrom-Json
    return $Keys
}

function Save-Key ([PSCustomObject]$Keys)
{
    $Keys | ConvertTo-Json | Out-File '.\api.key' 
}

function Read-Key
{
    $file = Join-Path $PSScriptRoot '..\api.key'
    if (-Not (Test-Path $file))
    {
        Write-Host -ForegroundColor Red "$($file) file was not found. Cannot proceed."
        Exit
    }
    $Keys = Get-Content -Path $file | ConvertFrom-Json
    return $Keys
}

function Save-Key ([PSCustomObject]$Keys)
{
    $file = Join-Path $PSScriptRoot '..\api.key'
    $Keys | ConvertTo-Json | Out-File $file
}

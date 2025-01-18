param (
    [string]$Repository = 'LocalDevPsRepo',
    [string]$NuGetApiKey
)

$publishModuleSplat = @{
    Path = "$((Get-Location).Path)/mcrcon"
    Repository = $Repository
    NuGetApiKey = $NuGetApiKey  # <--- currently just a string as this is meaningless to me because its a local repo.
}

publish-Module @publishModuleSplat
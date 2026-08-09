param(
  [Parameter(Mandatory = $true)]
  [string]$GitLinkUrl
)

$ErrorActionPreference = "Stop"

git remote remove gitlink 2>$null
git remote add gitlink $GitLinkUrl
git push -u gitlink main

Write-Host "Mirrored main to $GitLinkUrl"

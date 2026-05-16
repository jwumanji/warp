param(
    [string] $OriginRemote = 'origin',
    [string] $UpstreamRemote = 'upstream',
    [string] $UpstreamBranch = 'master',
    [string] $BaseBranch = 'master',
    [string] $FeatureBranch = 'custom/project-tabs',
    [switch] $Push,
    [switch] $CreateFeatureBranch,
    [switch] $SkipFeatureBranch,
    [string[]] $VerifyCommand = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    Write-Host "git $($Arguments -join ' ')" -ForegroundColor DarkGray
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Get-GitOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    $output = & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }

    @($output)
}

function Get-GitScalar {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    $output = @(Get-GitOutput -Arguments $Arguments)
    if ($output.Count -eq 0) {
        return ''
    }

    [string] $output[0]
}

function Test-GitRef {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Ref
    )

    & git rev-parse --verify --quiet $Ref *> $null
    $LASTEXITCODE -eq 0
}

function Assert-CleanWorktree {
    $status = @(Get-GitOutput @('status', '--porcelain'))
    if ($status.Count -gt 0) {
        $message = @(
            'Worktree is not clean. Commit, stash, or discard local changes before syncing.'
            ''
            ($status -join [Environment]::NewLine)
        ) -join [Environment]::NewLine
        throw $message
    }
}

function Invoke-VerifyCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Command
    )

    Write-Host "verify: $Command" -ForegroundColor DarkGray
    & pwsh -NoProfile -Command $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Verification command failed with exit code $LASTEXITCODE`: $Command"
    }
}

$repoRoot = Get-GitScalar @('rev-parse', '--show-toplevel')
Set-Location $repoRoot

$startingBranch = Get-GitScalar @('branch', '--show-current')
if ([string]::IsNullOrWhiteSpace($startingBranch)) {
    throw 'Cannot sync from a detached HEAD.'
}

try {
    Assert-CleanWorktree

    Invoke-Git @('config', 'rerere.enabled', 'true')
    Invoke-Git @('fetch', $OriginRemote, '--prune')
    Invoke-Git @('fetch', $UpstreamRemote, '--prune')

    Invoke-Git @('switch', $BaseBranch)
    Invoke-Git @('rebase', "$UpstreamRemote/$UpstreamBranch")
    if ($Push) {
        Invoke-Git @('push', $OriginRemote, $BaseBranch)
    }

    if (-not $SkipFeatureBranch) {
        if (Test-GitRef "refs/heads/$FeatureBranch") {
            Invoke-Git @('switch', $FeatureBranch)
        } elseif (Test-GitRef "refs/remotes/$OriginRemote/$FeatureBranch") {
            Invoke-Git @('switch', '--track', "$OriginRemote/$FeatureBranch")
        } elseif ($CreateFeatureBranch) {
            Invoke-Git @('switch', '-c', $FeatureBranch, "$UpstreamRemote/$UpstreamBranch")
        } else {
            throw "Feature branch '$FeatureBranch' does not exist. Pass -CreateFeatureBranch to create it."
        }

        Invoke-Git @('rebase', "$UpstreamRemote/$UpstreamBranch")

        foreach ($command in $VerifyCommand) {
            Invoke-VerifyCommand -Command $command
        }

        if ($Push) {
            Invoke-Git @('push', '--force-with-lease', $OriginRemote, $FeatureBranch)
        }
    }

    Write-Host 'Upstream sync completed.' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host 'Upstream sync stopped.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    Write-Host 'Current status:' -ForegroundColor Yellow
    & git status --short --branch
    exit 2
} finally {
    $currentBranch = (& git branch --show-current)
    if ($LASTEXITCODE -eq 0 -and $currentBranch -and $currentBranch -ne $startingBranch) {
        & git switch $startingBranch *> $null
    }
}

# git-shame by @cp7crash
param(
    [Parameter(Position = 0)]
    [string]$Path = (Get-Location).Path,
    [switch]$Detailed
)

# Normalize bare drive roots (e.g., "C:" -> "C:\") so they work the same as explicit roots.
if ($Path -match '^[a-zA-Z]:$') {
    $Path = "$Path\"
}

function GitAvailable {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: git is not installed or not on PATH." -ForegroundColor Red
        return $false
    }

    return $true
}

class RepoState {
    [string]$Path
    [string]$Name
    [int]$Staged
    [int]$Uncommitted
    [string[]]$Lines

    RepoState([string]$path) {
        $this.Path = $path
        $this.Name = Split-Path $path -Leaf

        $raw = git status --porcelain 2>$null

        if (-not $raw) {
            $this.Lines = @()
            $this.Uncommitted = 0
            $this.Staged = 0
            return
        }

        $this.Lines = @(
            $raw |
            ForEach-Object { $_.TrimEnd("`r") } |
            Where-Object { $_ -ne "" }
        )

        $this.Lines = @(
            $raw |
            ForEach-Object { if ($_ -ne $null) { $_.TrimEnd("`r") } } |
            Where-Object { $_ -and $_.Trim().Length -gt 0 }
        )

        $this.Uncommitted = $this.Lines.Count

        $this.Staged = @(
            $this.Lines | Where-Object {
                $_ -and $_.Length -gt 0 -and (
                    $_[0] -ne ' ' -and
                    $_[0] -ne '?' -and
                    $_[0] -ne '!'
                )
            }
        ).Count

        #Write-Host $this
    }

    [string] ToString() {
        return ($this | Format-List * | Out-String).Trim()
    }
}

function ShameProgress {
    param(
        [int]$RepoIndex,
        [int]$RepoCount,
        [int]$FileIndex,
        [int]$FileCount,
        [string]$RepoName
    )

    if ($RepoCount -le 0) { return }

    $repoPercent = [int](($RepoIndex / [double]$RepoCount) * 100)
    $repoStatus = "Repo $RepoIndex of $RepoCount ($RepoName)"

    Write-Progress -Id 1 -Activity "Scanning git repos" -Status $repoStatus -PercentComplete $repoPercent

    if ($FileCount -gt 0) {
        $filePercent = [int](($FileIndex / [double]$FileCount) * 100)
        $fileStatus = "Change $FileIndex of $FileCount in $RepoName"

        Write-Progress -Id 2 -ParentId 1 -Activity "Inspecting changes" -Status $fileStatus -PercentComplete $filePercent
    }
}

function GetRepos {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $repos = @()
    
    if (Test-Path (Join-Path $Path ".git")) {
        $repos += Get-Item $Path
    }
    
    $repos += Get-ChildItem -Path $Path -Directory -Recurse | Where-Object {
        Test-Path (Join-Path $_.FullName ".git")
    }
    
    return $repos
}

function GetShame {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    Push-Location $RepoPath
    try {
        # Run git status inside the repo so we get the right working tree
        $r = [RepoState]::new((Get-Location).Path)

        if ($r.Lines.Count -eq 0) {
            return $null
        }

        if ($Detailed) {
            ShowDetail $r
        }
       
        return $r
    }
    finally {
        Pop-Location
    }
}

function ShowDetail {
    param(
        [RepoState]$r
    )
   
    Write-Host ""
    Write-Host "SHAME! " -ForegroundColor Yellow -NoNewline
    Write-Host "for repo " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($r.Name) " -ForegroundColor Yellow -NoNewline
    Write-Host "@ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($r.Path)"

    $firstThree = $r.Lines | Select-Object -First 3
    foreach ($line in $firstThree) {
        if ($line) {
            Write-Host " > $line"
        }
    }

    if ($r.Lines.Count -gt 3) {
        $remaining = $r.Lines.Count - 3
        Write-Host "+$remaining others, " -NoNewline
    }

    Write-Host "uncommitted $($r.Uncommitted), staged $($r.Staged)"
    
}

function ShowSummary {
    param(
        [RepoState[]]$results
    )
     
    $results |
    Sort-Object Path |
    Select-Object Path, Staged, Uncommitted |
    Format-Table -AutoSize
}

function ShowShameLevel {
    param(
        [Parameter(Mandatory = $true)]
        [int]$totalRepos,
        [Parameter(Mandatory = $true)]
        [int]$totalChanges
    )

    $shameAmounts = @{
        1 = @(
            "Paragon of tidiness",
            "Commit Zen Master",
            "So clean GitHub could eat off you",
            "A walking lint roller",
            "Version control’s favourite child"
        )
        2 = @(
            "Slightly frayed around the edges",
            "A bit commit-lazy today, aren’t we?",
            "Tiny gremlin energy detected",
            "Hands mildly covered in code dust",
            "Not a disaster, but not bragging rights either"
        )
        3 = @(
            "Practising selective awareness again",
            "Your working tree has commitment issues",
            "This is the digital equivalent of leaving mugs everywhere",
            "Tiny chaos goblin with delusions of order",
            "Half-finished thoughts scattered like confetti"
        )
        4 = @(
            "You’re one untracked file away from a TED talk on regret",
            "This repo is crying quiet tears",
            "Your codebase wants joint custody",
            "Somewhere, a CI pipeline just sighed",
            "Git itself is questioning your life choices"
        )
        5 = @(
            "This isn’t a repo, it’s a hostage situation",
            "Your changes are filing a formal complaint",
            "This is archaeological evidence, not code",
            "Your undo history needs its own support group",
            "Congratulations, you’ve achieved Maximum Goblin Mode"
        )
    }

    WRite-Host ""
    Write-Host "git-shame " -ForegroundColor DarkGray -NoNewline
    Write-Host "state: " -NoNewline
    Write-Host "$totalRepos repos with shame, $totalChanges uncommitted changes" -ForegroundColor Cyan
    Write-Host "git-shame " -ForegroundColor DarkGray -NoNewline
    Write-Host "level: " -NoNewline

    if ($totalChanges -eq 0) {
        Write-Host "NONE (monk-level commit discipline!)" -ForegroundColor Green
        return
    }

    if ($totalChanges -le 10) {
        Write-Host "SOME (mildly grubby working tree)" -ForegroundColor Yellow
        return
    }

    Write-Host "MAJOR (you absolute devil; commit or stash already!!))" -ForegroundColor Red
    
}

# Main script logic

if (-not (GitAvailable)) {
    exit 1
}

$start = Get-Location
$scanType = if ($Detailed) { "detailed" } else { "summary" }
Write-Host "Starting git-shame $scanType scan at $Path" -ForegroundColor DarkGray

try {
    Push-Location $Path
    Write-Host "Scanning for git repos..." -ForegroundColor DarkGray -NoNewline
    $repos = GetRepos -Path $Path
    $results = @()

    Write-Output "found $($repos.Count)"
    Write-Output "Scanning for ways to shame you..."
    foreach ($repo in $repos) {
        $r = GetShame -RepoPath $repo.FullName
        if ($null -ne $r -and $r.Lines.Count -gt 0) {
            $results += $r
            if ($Detailed) {
                ShowDetail $r
            }
        }
    }

    if ($results.Count -eq 0) {
        Write-Host "No shame detected. All repos clean." -ForegroundColor Green
        return
    }

    if (-not $Detailed) {
        ShowSummary -results $results
    }

    ShowShameLevel -totalRepos $results.Count -totalChanges ($results | Measure-Object -Property Uncommitted -Sum).Sum
}
finally {
    Set-Location $start
}


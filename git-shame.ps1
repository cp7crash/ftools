# git-shame by @cp7crash
param(
    [Parameter(Position = 0)]
    [string]$Path = (Get-Location).Path,
    [switch]$Detailed
)

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
        $r = [RepoState]::new($RepoPath)
        
        if (-not $r.Status) {
            return $null
        }

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
        Write-Host "+$remaining others: " -NoNewline
    }

    Write-Host "uncommitted $($r.Uncommitted), staged $($r.Staged)"
    
}

function ShowShameLevel {
    param(
        [Parameter(Mandatory = $true)]
        [int]$totalChanges
    )

    if ($totalChanges -eq 0) {
        $label = "NO SHAME"
        $desc = "Monk-level commit discipline"
        $color = "Green"
    }
    elseif ($totalChanges -le 10) {
        $label = "SOME SHAME"
        $desc = "Mildly grubby working tree"
        $color = "Yellow"
    }
    else {
        $label = "MAJOR SHAME"
        $desc = "Full goblin mode; time to commit or stash"
        $color = "Red"
    }

    Write-Host "Shame level: $label - $desc" -ForegroundColor $color
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
        #$r = GetShame -RepoPath $repo.FullName
        Write-Output $repo
        $r = [RepoState]::new($repo)
        if ($r.Lines.Count -gt 0) {
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

    if (!Detailed) {
        $results |
        Sort-Object Repo |
        Select-Object Path, Repo, Staged, Uncommitted |
        Format-Table -AutoSize
    }

    $totalRepos = $results.Count
    $totalChanges = ($results | Measure-Object -Property Uncommitted -Sum).Sum

    Write-Host "$totalRepos repos with shame; $totalChanges uncommitted changes" -ForegroundColor Cyan
    ShowShameLevel -totalChanges $totalChanges
}
finally {
    Set-Location $start
}


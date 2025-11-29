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

$script:InaccessibleFolders = 0
$script:OneDriveRepos = @()

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

    $discoveryActivity = "Discovering git repos"
    Write-Progress -Id 3 -Activity $discoveryActivity -Status "Initializing..." -PercentComplete 0

    $repos = @()
    $checked = 0
    $found = 0
    $oneDriveFound = 0
    $direction = 1
    $progress = 0
    $progressIncrement = 5
    $updateIntervalMs = 250
    $lastUpdate = Get-Date
    $sinceLastUpdate = 0
    
    $candidate = Get-Item $Path
    $checked++
    if (Test-Path (Join-Path $Path ".git")) {
        $repos += $candidate
        $found++
    }
    
    $repoErrors = @()
    $repos += Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction SilentlyContinue -ErrorVariable +repoErrors | ForEach-Object {
        $checked++
        $sinceLastUpdate++
        if (Test-Path (Join-Path $_.FullName ".git")) {
            $found++
            $_
        }
        $now = Get-Date
        $shouldUpdate = ($now - $lastUpdate).TotalMilliseconds -ge $updateIntervalMs -or $sinceLastUpdate -ge 50
        if ($shouldUpdate) {
            $progress += $progressIncrement
            if ($progress -gt 100) { $progress = 0 }
            $lastUpdate = $now
            $sinceLastUpdate = 0

            Write-Progress -Id 3 -Activity $discoveryActivity -Status "Checked $checked folders, found $found repos ($oneDriveFound OneDrive, $($repoErrors.Count) denied)" -PercentComplete $progress
        }
    }

    Write-Progress -Id 3 -Activity $discoveryActivity -Status "Discovery complete ($found repos, OneDrive: $oneDriveFound, access denied: $($repoErrors.Count))" -PercentComplete 100 -Completed

    $script:InaccessibleFolders += ($repoErrors | Measure-Object).Count
    
    $oneDriveRoots = @($env:OneDrive, $env:OneDriveCommercial, $env:OneDriveConsumer) | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    if ($oneDriveRoots.Count -eq 0 -and $env:UserProfile) {
        $oneDriveRoots += (Join-Path $env:UserProfile "OneDrive")
    }
    $repos | ForEach-Object {
        $path = $_.FullName
        $isOneDrive = $false
        foreach ($root in $oneDriveRoots) {
            if ($path.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $isOneDrive = $true
                break
            }
        }

        if ($isOneDrive) {
            $oneDriveFound++
            $script:OneDriveRepos += $_
        }
        else {
            $_
        }
    }
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

    if ($script:OneDriveRepos.Count -gt 0) {
        Write-Host ""
        Write-Host "OneDrive git repos (skipped from scanning):" -ForegroundColor DarkGray
        $script:OneDriveRepos | Sort-Object FullName | ForEach-Object {
            Write-Host " - $($_.FullName)" -ForegroundColor Red
        }
    }
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
    
    Write-Host "Additional: OneDrive repos skipped: $($script:OneDriveRepos.Count), access denied folders: $script:InaccessibleFolders" -ForegroundColor DarkYellow
}

function ShowScanNotes {
    if ($script:OneDriveRepos.Count -gt 0) {
        $example = $script:OneDriveRepos | Select-Object -First 1
        Write-Host "Skipped $($script:OneDriveRepos.Count) git repos on OneDrive (e.g. $($example.FullName))" -ForegroundColor Yellow
    }

    if ($script:InaccessibleFolders -gt 0) {
        Write-Host "Could not access $script:InaccessibleFolders folder(s) during scan." -ForegroundColor DarkYellow
    }
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
    $repoIndex = 0
    foreach ($repo in $repos) {
        $repoIndex++
        ShameProgress -RepoIndex $repoIndex -RepoCount $repos.Count -FileIndex 0 -FileCount 0 -RepoName $repo.Name
        $r = GetShame -RepoPath $repo.FullName
        if ($null -ne $r -and $r.Lines.Count -gt 0) {
            $results += $r
            ShameProgress -RepoIndex $repoIndex -RepoCount $repos.Count -FileIndex $r.Lines.Count -FileCount $r.Lines.Count -RepoName $repo.Name
            if ($Detailed) {
                ShowDetail $r
            }
        }
    }
    if ($repos.Count -gt 0) {
        Write-Progress -Id 1 -Activity "Scanning git repos" -Status "Done" -PercentComplete 100
        Write-Progress -Id 2 -Activity "Inspecting changes" -Status "Done" -PercentComplete 100
    }

    if ($results.Count -eq 0) {
        Write-Host "No shame detected. All repos clean." -ForegroundColor Green
        ShowScanNotes
        return
    }

    if (-not $Detailed) {
        ShowSummary -results $results
    }

    ShowShameLevel -totalRepos $results.Count -totalChanges ($results | Measure-Object -Property Uncommitted -Sum).Sum
    ShowScanNotes
}
finally {
    Set-Location $start
}


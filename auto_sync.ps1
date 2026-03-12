# HomeHub AI Auto-Sync Script
#
# Usage:
# 1. Open PowerShell
# 2. Navigate to project root: cd "a:\Codings\HomeHUB.AI-main"
# 3. Run: .\auto_sync.ps1
#
# To run in background:
# Start-Job -FilePath ".\auto_sync.ps1" -Name "HomeHubSync"

$LogFile = "auto_sync.ps1.log"

function Write-SyncLog($Message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "[$timestamp] $Message"
    Write-Host $fullMessage
    $fullMessage | Out-File -FilePath $LogFile -Append
}

Write-SyncLog "Auto-sync started. Watching for changes every 10 seconds..."
Write-SyncLog "Press Ctrl+C to stop the process."

while ($true) {
    try {
        # Fetch updates from GitHub
        git fetch origin main | Out-Null
        
        # Check if we are behind
        $behindCount = (git rev-list HEAD..origin/main --count)
        if ($behindCount -gt 0) {
            Write-SyncLog "Local is behind by $behindCount commits. Pulling updates..."
            git pull origin main --rebase
        }

        # Check for local changes
        $status = git status --porcelain
        if ($status) {
            Write-SyncLog "Local changes detected. Syncing to GitHub..."
            git add .
            git commit -m "Auto-sync backup: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            git push origin main
            Write-SyncLog "Sync complete."
        }
    }
    catch {
        Write-SyncLog "ERROR during sync: $_"
    }

    Start-Sleep -Seconds 10
}

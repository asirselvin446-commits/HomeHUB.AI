Write-Host "Auto-sync started. Checking for changes every 10 seconds..."
Write-Host "Press Ctrl+C to stop the auto-sync."

while ($true) {
    # Fetch updates from GitHub
    Write-Host "Checking for updates from GitHub..."
    git pull origin main

    # Check if there are any changes
    $status = git status --porcelain
    if ($status) {
        Write-Host "Changes detected. Syncing to GitHub..."
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        git add .
        git commit -m "Auto-sync backup: $timestamp"
        git push origin main
        Write-Host "Sync complete. Continuing to watch for changes..."
    }
    Start-Sleep -Seconds 10
}

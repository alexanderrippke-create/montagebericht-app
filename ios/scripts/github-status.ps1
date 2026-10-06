param([long]$RunId = 0, [switch]$DownloadLogs)
$ErrorActionPreference = 'Stop'
$repositoryAPI = 'https://api.github.com/repos/alexanderrippke-create/montagebericht-app'
$headers = @{Accept='application/vnd.github+json'; 'User-Agent'='Montagebericht-iOS-Verification'}
if (!$RunId) {
    $runs = Invoke-RestMethod -Uri "$repositoryAPI/actions/runs?branch=ios-app&per_page=3" -Headers $headers
    $run = $runs.workflow_runs[0]
    $RunId = $run.id
} else { $run = Invoke-RestMethod -Uri "$repositoryAPI/actions/runs/$RunId" -Headers $headers }
$run | Select-Object id,status,conclusion,html_url,head_sha,created_at,updated_at | ConvertTo-Json
$jobs = Invoke-RestMethod -Uri "$repositoryAPI/actions/runs/$RunId/jobs" -Headers $headers
$jobs.jobs | ForEach-Object { "Job $($_.id): $($_.status) / $($_.conclusion)"; $_.steps | Select-Object name,status,conclusion,started_at | Format-Table -AutoSize }
if ($DownloadLogs -and $run.status -eq 'completed') {
    # Read the existing credential solely for this user's GitHub repository.
    # Never print, write or persist the credential.
    $credentialOutput = "protocol=https`nhost=github.com`npath=alexanderrippke-create/montagebericht-app.git`n`n" | git credential fill
    $credentialMap = @{}
    foreach ($line in $credentialOutput) {
        if ($line.Contains('=')) { $pair = $line.Split('=',2); $credentialMap[$pair[0]] = $pair[1] }
    }
    if (!$credentialMap['password']) { throw 'No existing GitHub credential available for downloading logs.' }
    $headers.Authorization = 'Bearer ' + $credentialMap['password']
    $logRoot = Join-Path $PSScriptRoot "../build/cloud-$RunId"
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    $archive = Join-Path $logRoot 'logs.zip'
    Invoke-WebRequest -Uri "$repositoryAPI/actions/runs/$RunId/logs" -Headers $headers -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $logRoot -Force
    Get-ChildItem -LiteralPath $logRoot -Recurse -Filter '*.txt' | ForEach-Object {
        Select-String -LiteralPath $_.FullName -Pattern 'error:|warning:|failed|Executed |TEST SUCCEEDED|BUILD SUCCEEDED' | Select-Object -Last 35 | ForEach-Object { $_.Line }
    }
    $headers.Remove('Authorization'); $credentialMap.Clear(); $credentialOutput = $null
}

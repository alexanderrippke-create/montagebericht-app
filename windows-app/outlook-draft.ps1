param([Parameter(Mandatory=$true)][string]$DataFile)
$ErrorActionPreference='Stop'
try {
 $draftData=Get-Content -LiteralPath $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json
 if(-not(Test-Path -LiteralPath $draftData.pdf)){throw 'Die PDF-Datei wurde nicht gefunden.'}
 $outlook=New-Object -ComObject Outlook.Application
 $mail=$outlook.CreateItem(0)
 $mail.To=$draftData.to
 $mail.Subject=$draftData.subject
 # Outlook zuerst seine Standardsignatur erzeugen lassen.
 $mail.Display()
 $editor=$mail.GetInspector.WordEditor
 $start=$editor.Range(0,0)
 $start.InsertBefore([string]$draftData.body + "`r`n`r`n")
 $null=$mail.Attachments.Add($draftData.pdf)
 $mail.Save()
 Write-Output 'DRAFT_READY'
} catch {Write-Error 'Der Outlook-Entwurf konnte nicht geöffnet werden. Dafür wird klassisches Outlook mit eingerichtetem Postfach benötigt.'; exit 1}

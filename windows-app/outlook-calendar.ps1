param([Parameter(Mandatory=$true)][string]$StartDate,[Parameter(Mandatory=$true)][string]$EndDate,[ValidateSet('Kalender','Iris Illian')][string]$CalendarName='Kalender')
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
try {
 $from=[datetime]::ParseExact($StartDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)
 $until=[datetime]::ParseExact($EndDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture).AddDays(1)
 if($until -le $from -or ($until-$from).Days -gt 93){throw 'Zeitraum ungültig'}
 $outlook=New-Object -ComObject Outlook.Application
 $namespace=$outlook.GetNamespace('MAPI')
 $script:matches=[Collections.Generic.List[object]]::new()
 function Find-Calendar($folders,$depth){if($depth -gt 12){return};foreach($folder in $folders){try{if($folder.DefaultItemType -eq 1 -and $folder.Name -eq $CalendarName){$script:matches.Add($folder)};if($folder.Folders.Count -gt 0){Find-Calendar $folder.Folders ($depth+1)}}catch{}}}
 Find-Calendar $namespace.Folders 0
 if($script:matches.Count -eq 0){throw ('Der Kalender „'+$CalendarName+'“ wurde im Outlook-Profil nicht gefunden. Bitte klassisches Outlook öffnen und den Kalender einbinden.')}
 $result=[Collections.Generic.List[object]]::new()
 foreach($folder in $script:matches){
  $items=$folder.Items;$items.Sort('[Start]');$items.IncludeRecurrences=$true
  $culture=[Globalization.CultureInfo]::CurrentCulture
  $filter="[Start] >= '"+$from.ToString('g',$culture)+"' AND [Start] < '"+$until.ToString('g',$culture)+"'"
  $selected=$items.Restrict($filter)
  foreach($item in $selected){if($result.Count -ge 500){break};if($item.Class -ne 26){continue};$itemStart=[datetime]$item.Start;if($itemStart -ge $until){break};if($itemStart -lt $from){continue};$result.Add([pscustomobject]@{summary=[string]$item.Subject;description=[string]$item.Body;location=[string]$item.Location;date=$itemStart.ToString('yyyy-MM-dd');time=$itemStart.ToString('HH:mm');calendar=[string]$folder.FolderPath})}
 }
 [pscustomobject]@{ok=$true;events=@($result.ToArray() | Sort-Object date,time);limited=($result.Count -ge 500)} | ConvertTo-Json -Depth 5 -Compress
} catch {[pscustomobject]@{ok=$false;message=$_.Exception.Message} | ConvertTo-Json -Compress;exit 1}

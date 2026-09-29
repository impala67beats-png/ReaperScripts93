# Small policies shared by the WPF launcher and its non-WPF regression checks.
function FitWindow($target,$work){
 # Fit only the restored size. A persistent MaxWidth/MaxHeight also caps Maximize.
 $fitHeight=[Math]::Max(100,$work.Height-24)
 $fitWidth=[Math]::Max(100,$work.Width-24)
 $target.MinHeight=[Math]::Min($target.MinHeight,$fitHeight)
 $target.MinWidth=[Math]::Min($target.MinWidth,$fitWidth)
 $target.Height=[Math]::Min($target.Height,$fitHeight)
 $target.Width=[Math]::Min($target.Width,$fitWidth)
}
function SamePath([string]$a,[string]$b){
 if(!$a -or !$b){return $false}
 return [string]::Equals($a.Replace('/','\').TrimEnd('\'),$b.Replace('/','\').TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)
}
function ReaperIdentity($process){
 if(!$process -or [int]$process.ProcessId -le 0 -or !$process.CreationDate){return ''}
 return ([string]$process.ProcessId+'|'+[string]$process.CreationDate)
}
function ReaperStillRunning($process){return ($null -ne $process -and !$process.HasExited)}
function ReaperLaunchRunning($opened,$target){return ((ReaperStillRunning $opened) -or (ReaperStillRunning $target))}
function ForwardReadySince([bool]$ready,[long]$now,[long]$previous){
 if(!$ready){return 0}
 if($previous -le 0){return $now}
 return $previous
}
function ForwardReady([long]$now,[long]$since){return $since -gt 0 -and $now-$since -ge 1500}
function ClientHiddenStart([string]$role,[string]$mode){return ($role -eq 'CLIENT' -and $mode -eq '-newinst')}
function ReaperPredatesHeartbeat($process,[double]$heartbeat){
 if($heartbeat -le 0){return $true}
 $created=[datetime]$process.CreationDate
 return ([DateTimeOffset]::new($created.ToUniversalTime()).ToUnixTimeMilliseconds() -lt ([Math]::Floor($heartbeat)+1)*1000)
}
function MatchingReaperProcesses([string]$exe,[string[]]$arguments,$processes){
 $selected=@()
 foreach($p in $processes){
  if(!$p.ExecutablePath){throw 'A running REAPER cannot be identified. Close that REAPER and retry.'}
  if(!(SamePath $p.ExecutablePath $exe)){continue}
  if(!$p.CommandLine){throw 'The selected REAPER is running with unreadable launch details. Close it and retry.'}
  $cfg=[regex]::Match($p.CommandLine,'(?i)(?:^|\s)(?:"-cfgfile"|-cfgfile)\s+(?:"([^"]+)"|(\S+))')
  if($cfg.Success){
   $value=if($cfg.Groups[1].Success){$cfg.Groups[1].Value}else{$cfg.Groups[2].Value}
   if(!(SamePath $value $arguments[2])){continue}
  }
  $selected+=,$p
 }
 return $selected
}
function ReaperArguments([string]$exe,[string[]]$arguments,$processes){
 $selected=@(MatchingReaperProcesses $exe $arguments $processes)
 if($selected.Count -gt 1){throw 'Several copies of the selected REAPER are running. Close the extra instances and retry.'}
 $result=@($arguments)
 $result[0]=if($selected.Count -eq 1){'-nonewinst'}else{'-newinst'}
 return $result
}
function ClientReconnectArguments([string]$role,[bool]$reconnect,[string[]]$arguments){
 $result=@($arguments)
 if($role -ne 'CLIENT' -or !$reconnect -or $result.Count -lt 5 -or $result[0] -ne '-nonewinst'){
  return $result
 }
 if(([string]$result[$result.Count-1]) -notmatch '(?i)\.lua$'){return $result}
 $projects=@()
 for($i=3;$i -lt $result.Count-1;$i++){
  if(([string]$result[$i]) -match '(?i)\.rpp$'){$projects+=,$i}
 }
 if($projects.Count -ne 1){return $result}
 $skip=[int]$projects[0]
 $filtered=@()
 for($i=0;$i -lt $result.Count;$i++){
  if($i -ne $skip){$filtered+=,[string]$result[$i]}
 }
 return $filtered
}
function CloseMustFinish([bool]$closing,[bool]$workerAlive,[double]$elapsed){
 return $closing -and (!$workerAlive -or $elapsed -ge 28)
}

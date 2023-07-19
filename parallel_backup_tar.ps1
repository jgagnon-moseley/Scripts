#Install-Module -Name ThreadJob

#TODO: Add \\ric-v-sql,\\ric-v-app09
Write-Host "THIS SCRIPT IS ONLY FOR POWERSHELL 7+"
#Run as a user with access to BUP and network drives.
#Do
#{
#    Write-Host "Connecting..."
#    Enable-NetAdapter -Name "SLOT 6 Port 1"
#    Start-Sleep -Seconds 1
#} Until (Test-NetConnection 10.1.1.1 -InformationLevel Quiet)
#Start-Sleep -Seconds 5
#Write-Host "Connected."
$test = $false
if ($test) {
	$zstdDir = "C:\\Users\\jgagnon\\Desktop\\zstd-v1.5.5-win64\\"
	$backupLocation = "C:\\Users\\jgagnon\\Desktop\\testBUP\\"
	$logsFolder = "C:\\Users\\jgagnon\\Desktop\\testBUPLogs\\"
} else {
	$backupLocation = "Q:\\BUP\\"
	$logsFolder = "Q:\\Logs\\"
	$zstdDir = "C:\\batch-main\\zstd-v1.5.5-win64\\"
}
$maxJobs = 20
$maxRoboCopyThreads = 128
Write-Host "Backing up to $backupLocation and logging $logsFolder"
$orgs = @("BAL2", "CHS2", "HBG2", "RDC2", "RIC2", "VAB3", "FFX3")
$Env:PATH += ";$zstdDir"

# CULL CHILDREN
$tfs = @{} #targetFolders
$tfKeys = @()
Write-Host "Collecting info..."
New-Item -Force -ItemType Directory -Path $($backupLocation + "Zip\\")

foreach ($org in $orgs)
{
	Write-Host $org
	$tfChildren = Get-ChildItem -Path @("\\moseleyarch.com\" + $org)
	foreach ($tfChild in $tfChildren)
	{
		$tfKey = $tfChild.FullName.Replace("\\moseleyarch.com","").Replace("\","-").Substring(1)
		$tfKeys += $tfKey
		$tfs.$tfKey = @{}
		$tfs.$tfKey.Source = $tfChild.FullName
		$tfs.$tfKey.Name = $tfChild.Name
		$tfs.$tfKey.FileDestination = $backupLocation + "File\\" + $org + "\\" + $tfs.$tfKey.Name + "\\"
		$tfs.$tfKey.ZipDestination = $backupLocation + "Zip\\" + $org + "-" + $tfs.$tfKey.Name.Replace(" ", "")
		$tfs.$tfKey.LogFolder = $logsFolder + $org + "\\" + $tfs.$tfKey.Name + "\\"
        $tfs.$tfKey.LogFile = $tfs.$tfKey.LogFolder + @(Get-Date -Format "HH_mm_ss") + ".log"
	}
	Write-Host $org + "Done"
}
#RANDOMIZER
#Hopefully spread the load across the NASes.
$tfKeys = $tfKeys | Sort-Object {Get-Random}

#LIMITER
if ($test) {
	$tfKeys = $tfKeys | Where {$_ -like "*Docs*" -or $_ -like "*Temp*"}
	$tfKeys = $tfKeys | Select -first 3
}
$queuedJobs = @()
Write-Host "Starting Jobs"

foreach ($tfKey in $tfKeys) 
{
	$job = $tfs[$tfKey]
    $queuedJobs += Start-ThreadJob -Name $tfKey -ScriptBlock {
        param($copyJob)
        Write-Host $copyJob.LogFolder
        $jobLogFolder = $copyJob.LogFolder
        New-Item -Force -Path $jobLogFolder -ItemType Directory
        
        robocopy $copyJob.Source $copyJob.FileDestination /MT:$maxRoboCopyThreads /r:30 /MIR /log:$($copyJob.LogFile)
	Write-Host "Done with " + $copyJob.FileDestination
	$fileDestTar = $copyJob.FileDestination.substring(0,$copyJob.FileDestination.length - 2)
	#Write-Host "Starting with " + $($copyJob.ZipDestination + ".tar")
	#https://stackoverflow.com/questions/2095088/error-when-calling-3rd-party-executable-from-powershell-when-using-an-ide	
	tar cf $($copyJob.ZipDestination + ".tar") $fileDestTar 2>&1 | %{ "$_" }
	#Write-Host "Trying to remove " + $copyJob.FileDestination
	rd /s /q $copyJob.FileDestination
	zstd.exe -T0 -f -9 $($copyJob.ZipDestination + ".tar") 2>&1 | %{ "$_" }

    } -ThrottleLimit $maxJobs -ArgumentList $job
}
#Get-WmiObject Win32_process -filter 'name = "robocopy.exe"' | ForEach-Object {$_.setPriority(128)}
foreach ($job in $queuedJobs)
{
    Receive-Job -Job $job -Wait
}

#Do
#{
##	Send-MailMessage -From 'Tape Server <it@moseleyarchitects.com>' -To @('John Gagnon <jgagnon@moseleyarchitects.com>', 'Patrick Covert <pcovert@moseleyarchitects.com>') -Subject 'T430 Archive Completed. Run Tape Backup Now.' -SmtpServer "moseleyarchitects-com.mail.protection.outlook.com"
	#Disable-NetAdapter -Name "SLOT 6 Port 1" -Confirm:$false  
#} While (Test-NetConnection 10.1.1.1 -InformationLevel Quiet)
#Write-Host "Disconnected."

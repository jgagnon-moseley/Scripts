#requires -runasadministrator
#This is a general guide for the mounting/unmounting of volume shadow copies. 


$symbolicLinkHostPath = "C:\VSSAccess\"

try 
{


#First you find the volume guid of the data of interest
$localDriveLettersObj = Get-PSDrive | Where-Object {$_.Provider.Name -eq "FileSystem" -and $_.DisplayRoot -notlike "*moseley*"} | Select-Object -Property @{Name = "DriveLetter"; Expression = {$_.Root.Substring(0,1)}}
$localDriveLettersStringArray = $localDriveLettersObj.DriveLetter
Write-Host "Available volumes for vss:"
Write-Host $($localDriveLettersStringArray -join ", ")
$driveLetter = ($(Read-Host -Prompt "What volume? (Expecting drive letter""C"" / ""J"")")).ToUpper()

$driveLetterWithColon = $driveLetter + ":"
#making directory for mounting later
New-Item -Path ($symbolicLinkHostPath + $driveLetter) -Force -ItemType Directory
Write-Host "Will be the place of the vss mount"
Write-Host ""
Write-Host "Loading shadow copies, this can take a while..."


$volumeName = (GWMI -class win32_volume | Where-Object {$_.DriveLetter -match ($driveLetterWithColon)} | Select DeviceID).DeviceID.ToString()

#List copies
#Getting all in an object
$volumeShadowCopies = Get-WmiObject Win32_shadowcopy | Where-Object {$_.VolumeName -eq $volumeName}
#Printing off each one at a date and time. With index so it can be selected
$index = 0
$volumeShadowCopies | fl -Property @{ Name = "InstallDateFormatted"; Expression = {$_.ConvertToDateTime($_.InstallDate)}}, @{ Name = "Index"; Expression = {$global:index;$global:index++}}

#selecting
$selectedShadowCopyIndex = Read-Host -Prompt "Input index of choice"
$selectedShadowCopy = $volumeShadowCopies[$selectedShadowCopyIndex]
$selectedShadowDateFormatted = $selectedShadowCopy.ConvertToDateTime($selectedShadowCopy.InstallDate).ToString("MM-dd-yyyy")
$selectedShadowMountFolder = $symbolicLinkHostPath + $driveLetter + "\" + $selectedShadowDateFormatted + "--" + $selectedShadowCopyIndex
#mounting
$d  = $selectedShadowCopy.DeviceObject + "\\"
cmd /c mklink /d "$selectedShadowMountFolder" "$d"

Read-Host -Prompt "Type anything to unmount"
#DOES NOT DELETE THE SHADOW COPY, ONLY UNLINKS 
(Get-Item  $selectedShadowMountFolder).Delete() 

}
finally
{
	Clear-Variable * -Scope Script -ErrorAction SilentlyContinue
	Clear-Variable index -Scope Global -ErrorAction SilentlyContinue
	Write-Host "ending"
}

#this is available if you need the GUID in object form
#$substringVolumeGUID = $volumeName.Substring($volumeName.IndexOf('{'), $volumeName.Length - $volumeName.IndexOf('{') - 1)
#$volumeGUID = [System.Guid]::Parse($substringVolumeGUID)

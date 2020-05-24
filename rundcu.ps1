<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.150
	 Created on:   	12/3/2019 12:20 PM
	 Created by:   	tausifkhan
	 Organization: 	FICO
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		Dell command update install and run it.
#>



if (![System.Environment]::Is64BitProcess)
{
	# start new PowerShell as x64 bit process, wait for it and gather exit code and standard error output
	$sysNativePowerShell = "$($PSHOME.ToLower().Replace("syswow64", "sysnative"))\powershell.exe"
	
	$pinfo = New-Object System.Diagnostics.ProcessStartInfo
	$pinfo.FileName = $sysNativePowerShell
	$pinfo.Arguments = "-ex bypass -file `"$PSCommandPath`""
	$pinfo.RedirectStandardError = $true
	$pinfo.RedirectStandardOutput = $true
	$pinfo.CreateNoWindow = $true
	$pinfo.UseShellExecute = $false
	$p = New-Object System.Diagnostics.Process
	$p.StartInfo = $pinfo
	$p.Start() | Out-Null
	
	$exitCode = $p.ExitCode
	
	$stderr = $p.StandardError.ReadToEnd()
	
	if ($stderr) { Write-Error -Message $stderr }
}
else
{
	$transcriptlog = "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1", ".log"))"
	
	# start logging to TEMP in file "scriptname".log
	Start-Transcript -Path $transcriptlog | Out-Null
	
	
	function Get-Architecture
	{
        <#
            .SYNOPSIS
                Get-Architecture
            
            .DESCRIPTION
                Returns whether the system architecture is 32-bit or 64-bit
            
            .EXAMPLE
                Get-Architecture
            
            .NOTES
                Additional information about the function.
        #>
		
		[CmdletBinding()]
		[OutputType([string])]
		param ()
		
		$OSArchitecture = (Get-WmiObject -Class Win32_OperatingSystem | Select-Object OSArchitecture).OSArchitecture
		Return $OSArchitecture
		#Returns 32-bit or 64-bit
	}
	
	function Get-DellCommandUpdateLocation
	{
        <#
            .SYNOPSIS
                Find dcu-cli.exe
            
            .DESCRIPTION
                Locate dcu-cli.exe as it may reside in %PROGRAMFILES% or %PROGRAMFILES(X86)%
            
        #>
		
		[CmdletBinding()]
		[OutputType([string])]
		param ()
		
		$Architecture = Get-Architecture
		If ($Architecture -eq "32-bit")
		{
			$File = Get-ChildItem -Path $env:ProgramFiles -Filter "dcu-cli.exe" -ErrorAction SilentlyContinue -Recurse
		}
		else
		{
			$File = Get-ChildItem -Path ${env:ProgramFiles(x86)} -Filter "dcu-cli.exe" -ErrorAction SilentlyContinue -Recurse
		}
		Return $File.FullName
	}
	
	#Find dcu-cli.exe
	$EXE = Get-DellCommandUpdateLocation
	$dclogfolder = $env:SystemDrive + '\' + 'DCUpdate'
	New-Item -ItemType Directory $dclogfolder -force
	$outlog = $dclogfolder + '\' + 'dellcuoutput.log'
	$scanlog = $dclogfolder + '\' + 'scanlog.log'
	$setlog = $dclogfolder + '\' + 'setdcu.log'
	if ((Get-CimInstance win32_bios).Manufacturer -match 'Dell')
	{
		if (($EXE -eq $null) -or ((Get-Item $EXE).VersionInfo.FileVersion -ne '3.1.1.44'))
		{
			###Code to download andinstallstuff starts here
			New-Item -path "registry::hklm\software\policies\microsoft\Internet Explorer\Main" -Force
			New-ItemProperty -path "registry::hklm\software\policies\microsoft\Internet Explorer\Main" -Name DisableFirstRunCustomize -PropertyType dword -Value 2
			
			Write-Host "Dell command update not installed"
			Invoke-WebRequest -Uri "https://dl.dell.com/FOLDER06228963M/4/Dell-Command-Update-Application_68GJ6_WIN_3.1.2_A00.EXE" -OutFile "$env:temp\DCU.exe" -UseBasicParsing -Verbose
			start-process -FilePath "$env:temp\DCU.exe" -ArgumentList '/s' -Wait
			Start-Sleep -Seconds 5
		}
		#elseif ((Get-Item $EXE).VersionInfo.FileVersionon -eq '3.1.0.64') {
		#$dcuversion = (Get-Item $EXE).VersionInfo.FileVersion
		$EXE = Get-DellCommandUpdateLocation
		Write-Host "*******************Dcu cli located at $EXE*****************"
		Write-Host "******************Set dell command update settings*********************"
		$a = "/configure -scheduleWeekly=Mon,11:45 -updateSeverity=recommended,critical -updatetype=driver,bios -updateDeviceCategory=network,storage,audio,video,input -scheduleAction=DownloadInstallAndNotify -autoSuspendBitLocker=enable -outputLog=$setlog"
		$set = Start-Process -FilePath $EXE -ArgumentList $a -WindowStyle Hidden -Wait -Passthru #| Out-Null
		$set.WaitForExit()
		
		Write-Host "******************Scanning for updates*********************"
		$b = "/scan -outputLog=$scanlog"
		$scan = Start-Process -FilePath $EXE -ArgumentList $b -WindowStyle Hidden -Wait -PassThru
		$scan.WaitForExit()
		
		Write-Host "******************Applying updates*************************"
		$c = "/applyUpdates -silent -outputLog=$outlog"
		$apply = Start-Process -FilePath $EXE -ArgumentList $c -WindowStyle Hidden -Wait -PassThru
		$apply.WaitForExit()
		Copy-Item $dclogfolder\*.log -Destination $env:TEMP -Force -Recurse
		Remove-Item $dclogfolder -Force -Recurse
		
	}
	else
	{
		Write-Host "This is not a dell workstation"
	}
	Stop-Transcript | Out-Null
}

exit $exitCode

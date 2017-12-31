param(
	[String]$buildNumber="1.1.0-dev12",
	[String]$branchName="master",
	[String]$gitCommitHash="unknownHash",
	[String]$octoProjectName="Azure Crypto",
	[String]$octoPackageSource,#="http://pmisa2440.fplu.fpl.com/octopus/nuget/packages",
	[String]$octoApiKey,#="API-FLRBYNHIX14CXBV82R6CH7BGYEY",
	[string]$octoServer,#="http://pmisa2440.fplu.fpl.com/octopus",
	[String]$octoChannel,#="Features Channel",
	[String]$nexusSource,#="http://neer-nexus:8084/nexus/service/local/nuget/Nuget.test/",
	[String]$nexusApiKey,#="6785b083-2697-3f8b-a734-27ee29b285ff",
	[Switch]$isBuildServer=$True)
cls

# '[p]sake is the same as 'psake' but $Error is not polluted
Remove-Module [p]sake

# Find psake's path

$psakeModule = (Get-ChildItem (".\Packages\psake*\tools\psake.psm1")).FullName | Sort-Object $_ | select -Last 1

Import-Module $psakeModule

Invoke-psake -buildFile .\BuildHelper\default.ps1 `
			 -taskList Clean `
			 -framework 4.6.1 `
			 -properties @{ 
				 "buildConfiguration" = "Release"
				 "buildPlatform" = "Any CPU"
			 } `
			 -parameters @{
				 "solutionFile" = "..\api.common.sln"
				 "buildNumber" = $buildNumber
				 "branchName" = $branchName
				 "gitCommitHash" = $gitCommitHash
				 "octoProjectName" = $octoProjectName
				 "octoPackageSource" = $octoPackageSource
				 "octoApiKey" = $octoApiKey
				 "octoServer" = $octoServer
				 "octoChannel" = $octoChannel
				 "nexusSource" = $nexusSource
				 "nexusApiKey" = $nexusApiKey
				 "isBuildServer" = $isBuildServer
			 }

Write-Host "Build exit code:" $LastExitCode
# Propogating the exit code so that build actually fail when there is a problem
exit $LastExitCode



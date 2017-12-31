Include ".\helpers.ps1"

properties {
	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory = "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"
	$thisDirectory = (Get-Item -Path ".\" -Verbose).FullName

	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$publishedApplicationsDirectory = "$temporaryOutputDirectory\_PublishedApplications"
	$publishedWebsitesDirectory = "$temporaryOutputDirectory\_PublishedWebsites"
	$publishedLibrariesDirectory = "$temporaryOutputDirectory\_PublishedLibraries\"

	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\Nunit"

	$testCoverageDirectory = "$outputDirectory\TestCoverage"
	$testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
	$testCoverageFilter = "-filter:+[Nextera.Hydra.SPP.*]* -[*.Tests]*"
	#$testCoverageFilter = "-filter:+[*]* -[RealTime.Automation.Process.*.Tests]*"
	$testCoverageExcludeByAttribute = "System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
	$testCoverageExcludeByFile = "*\*Designer.cs;*\*.g.cs;*\*.g.i.cs"

	$packagesOutputDirectory = "$outputDirectory\Packages"
	$applicationsOutputDirectory = "$packagesOutputDirectory\Applications"
	$librariesOutputDirectory = "$packagesOutputDirectory\Libraries"
	
	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$packagesPath = "$solutionDirectory\packages"
	$nunitExe = (Find-PackagePath $packagesPath "NUnit.ConsoleRunner" ) + "\Tools\nunit3-console.exe"
	$openCoverExe = (Find-PackagePath $packagesPath "OpenCover") + "\Tools\OpenCover.Console.exe"
	$reportGeneratorExe = (Find-PackagePath $packagesPath "ReportGenerator") + "\Tools\ReportGenerator.exe"
	$7ZipExe = (Find-PackagePath $packagesPath "7-Zip.CommandLine") + "\Tools\7za.exe"
	$nugetExe = (Find-PackagePath $packagesPath "NuGet.CommandLine") + "\Tools\NuGet.exe"
	$octoExe = (Find-PackagePath $packagesPath "OctopusTools") + "\Tools\Octo.exe"
	$openCover2nCoverXslt = $thisDirectory + "\opencover_to_ncover.xslt"
}

FormatTaskName "`r`n`r`n---------------Executing {0} Task ----------------------------"

task default -depends Test

task Init `
	-description "Initializes the build by removing previous artifacts and creating output directories" `
	-requiredVariables outputDirectory, temporaryOutputDirectory `
	{
	
	Assert -conditionToCheck ("Debug", "Release" -contains $buildConfiguration)`
		   -failureMessage "Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

	Assert -conditionToCheck ("x86", "x64", "Any CPU" -contains $buildPlatform)`
		   -failureMessage "Invalid build configuration '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

    # Check that all tools are available
    Write-Host "Checking that all required tools are available"

	Assert (Test-Path $nunitExe) "NUnit console couldn't be found"
	Assert (Test-Path $openCoverExe) "OpenCover console couldn't be found"
    Assert (Test-Path $reportGeneratorExe) "ReportGenerator console couldn't be found"
	Assert (Test-Path $7ZipExe) "7-Zip Command Line couldn't be found"
	Assert (Test-Path $nugetExe) "NuGet Command Line couldn't be found"

	# Remove previous build results
	if ( Test-Path $outputDirectory )
	{
		Write-Host "Removing output directory located at $outputDirectory"
		Remove-Item $outputDirectory -Force -Recurse
	}
	Write-Host "Creating output directory located at $outputDirectory"
	New-Item $outputDirectory -ItemType Directory | Out-Null

	Write-Host "Creating temporary directory located at $temporaryOutputDirectory"
	New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null

	Write-Host "Build Number: $buildNumber"
	Write-Host "Branch Name: $branchName"
	Write-Host "Git Commit Hash: $gitCommitHash"
	Write-Host "Octopus Project Name: $octoProjectName"
	Write-Host "Octopus Package Source: $octoPackageSource"
	Write-Host "Octopus Api Key: $octoApiKey"
	Write-Host "Octopus Server: $octoServer"
	Write-Host "Octopus Channel: $octoChannel"
	Write-Host "Nexus Source: $nexusSource"
	Write-Host "Nexus ApiKey: $nexusApiKey"
	Write-Host "Is Build Server: $isBuildServer"
}

task Compile `
	-depends Init `
	-description 'Compile the code' `
	-requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
	{

	Write-Host "Building the $solutionFile"
	Exec {
		msbuild $solutionFile "/p:Configuration=$buildConfiguration;platform=$buildPlatform;OutDir=$temporaryOutputDirectory;NuGetExePath=$nugetExe"
							  #"/p:AllowedReferenceRelatedFileExtensions=none"
							  #"/p:GenerateProjectSpecificOutputFolder=true"
							  #"/p:DebugSymbols=false" 
							  #"/p:DebugType=None"
	}
}

task TestNUnit `
	-depends Compile `
	-description "Run NUnit tests" `
	-precondition { return Test-Path $publishedNUnitTestsDirectory } `
	{
		$testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
										-publishedTestsDirectory $publishedNUnitTestsDirectory `
										-testResultsDirectory $NUnitTestResultsDirectory `
										-testCoverageDirectory $testCoverageDirectory

		Write-Host $testAssemblies
		# Rename the app.config to namespace.exe.config
		Get-ChildItem $publishedNUnitTestsDirectory | ForEach-Object {
			$configFile = Join-Path -Path $_.FullName -ChildPath app.config
			$newFile = Join-Path -Path $_.FullName -ChildPath ($_.Name+".dll.config") 
			Rename-Item  $configFile $newFile
		}

		 #Exec {
			# &$nunitExe $testAssemblies -result="$NUnitTestResultsDirectory\NUnit.xml"
		 #}

		 $targetArgs = "$testAssemblies -result=`"`"$NUnitTestResultsDirectory\NUnit.xml`"`""

		 # Run OpenCover, which in turn will run NUnit
		 Run-Tests -openCoverExe $openCoverExe `
				   -targetExe $nunitExe `
				   -targetArgs $targetArgs 	`
				   -coveragePath $testCoverageReportPath `
				   -filter $testCoverageFilter `
				   -excludebyattribute:$testCoverageExcludeByAttribute `
				   -excludebyfile:$testCoverageExcludeByFile
	} 	

task Test `
	-depends Compile, TestNunit `
	-description "Run Unit Tests" `
	{
		 if (Test-Path $testCoverageReportPath)
		 {
			 # Generate HTML test coverage report
			 Write-Host "`r`nGenerating HTML test coverage report"

			 Exec { &$reportgeneratorExe $testCoverageReportPath $testCoverageDirectory }

			 Write-Host "Parsing OpenCover results"

			 #Load teh coverage report as XML
			 $coverage = [xml](Get-Content -Path $testCoverageReportPath)

			 #Transform OpenCover to NCover
			 $xslTranform = New-Object System.Xml.Xsl.XslCompiledTransform
			 $xslTranform.Load($openCover2nCoverXslt)
			 $xslTranform.Transform( $testCoverageReportPath, $testCoverageDirectory + "\nCover.xml" )

			 $coverageSummary = $coverage.CoverageSession.Summary

			 # Report class coverage
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCCovered' value='$($coverageSummary.visitedClasses)']"
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCTotal' value='$($coverageSummary.numClasses)']"
			 Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageC' value='{0:N2}']" -f (($coverageSummary.visitedClasses / $coverageSummary.numClasses)*100))

			 # Report method coverage
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMCovered' value='$($coverageSummary.visitedMethods)']"
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMTotal' value='$($coverageSummary.numMethods)']"
			 Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageM' value='{0:N2}']" -f (($coverageSummary.visitedMethods / $coverageSummary.numMethods)*100))

			 # Report branch coverage
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBCovered' value='$($coverageSummary.visitedBranchPoints)']"
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBTotal' value='$($coverageSummary.numBranchPoints)']"
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageB' value='$($coverageSummary.branchCoverage)']"

			 # Report sequence coverage. TeamCity doesn't support Sequence point. We use Statement point instead
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSCovered' value='$($coverageSummary.visitedSequencePoints)']"
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSTotal' value='$($coverageSummary.numSequencePoints)']"
			 Write-Host "##teamcity[buildStatisticValue key='CodeCoverageS' value='$($coverageSummary.sequenceCoverage)']"
		 }
		 else
		 {
			 Write-Host "No coverage file found at: $testCoverageReportPath"
		 }
	 }

task Package `
    -depends Compile, Test `
    -description "Package applications" `
    -requiredVariables publishedWebsitesDirectory, publishedApplicationsDirectory, applicationsOutputDirectory, publishedLibrariesDirectory, librariesOutputDirectory `
    {
		# Merge published websites and published application paths
		$applications = @(Get-ChildItem $publishedApplicationsDirectory -ErrorAction SilentlyContinue)  + @(Get-ChildItem $publishedWebsitesDirectory -ErrorAction SilentlyContinue)
		# Add this if you have web projects inside the solution.
		# + @(Get-ChildItem $publishedWebsitesDirectory)
		Write-Host $applications.Length

		if ($applications.Length -gt 0 -and !(Test-Path $applicationsOutputDirectory))
		{
				New-Item $applicationsOutputDirectory -ItemType Directory | Out-Null
		}

		foreach($application in $applications)
		{
				$nuspecPath = $application.FullName + "\" + $application.Name + ".nuspec"
				#Write-Host $nuspecPath
				if (Test-Path $nuspecPath)
				{
					Write-Host "Packaging $($application.Name) as a NuGet package"
                           
					# Load the nuspec file as XML
					$nuspec = [xml](Get-Content -Path $nuspecPath)
					$metadata = $nuspec.package.metadata

						
					# Nuget doesn't suport semantic versioning. Ex: 2.0.0-alpha.1.11.28
					# Only semantic versioning 1.0 is supported. Ex: 2.0.0-aplha10
					$buildVersionSem = $buildNumber
					if ($branchName -ne "master")
					{
						$buildVersion = $buildNumber.split('.')
						$buildCount = $buildVersion[3]
						$concatenatedBranchName = $branchName.replace('/','-').Substring(0, [System.Math]::Min((20 - $buildCount.length), $branchName.length))
						$buildVersionSem =  "{0}.{1}.{2}-{3}{4}" -f $buildVersion[0],$buildVersion[1],$buildVersion[2],$concatenatedBranchName,$buildCount
					}

					# Edit the metadata
					$metadata.version = $metadata.version.Replace("[buildNumber]", $buildVersionSem)
					$metadata.releaseNotes = "Build Number: $buildNumber`r`nBranch Name$branchName`r`nCommit Hash:$gitCommitHash"
					# Save the nuspec file
					$nuspec.Save((Get-Item $nuspecPath))

					# package as NuGet package
					Exec { &$nugetExe pack $nuspecPath -OutputDirectory $applicationsOutputDirectory }
						
				}
				else
				{
					Write-Host "Packaging $($application.Name) as a zip file"
                     
					$archivePath = "$($applicationsOutputDirectory)\$($application.Name).zip"
					$inputDirectory = "$($application.FullName)\*"

					Exec { &$7ZipExe a -r -mx3 $archivePath $inputDirectory }
				}
			}
			# This should run only on build server.
			if ( $isBuildServer -and (Test-Path $applicationsOutputDirectory) ) 
			{
				# Loop through the application folder
				Get-ChildItem $applicationsOutputDirectory | ForEach-Object {
					Exec { &$nugetExe push $_.FullName -ApiKey $octoApiKey -source $octoPackageSource }
				}
				# Create a octopus release. For Seperate releases This needs tobe in the loop.
				Exec { &$octoExe create-release --project $octoProjectName --channel $octoChannel --version $buildVersionSem --packageversion $buildVersionSem --server $octoServer --apiKey $octoApiKey }
							
			}
		# Moving NuGet libraries to the packages directory
		if (Test-Path $publishedLibrariesDirectory)
		{
			if (! (Test-Path $librariesOutputDirectory))
			{
				MKdir $librariesOutputDirectory | Out-Null

				Get-ChildItem -Path $publishedLibrariesDirectory -Filter "*.nupkg" -Recurse | Move-Item -Destination $librariesOutputDirectory
				if ( $isBuildServer -and (Test-Path $librariesOutputDirectory)) 
				{
					# Push the libraries to nexus server
					Get-ChildItem $librariesOutputDirectory | ForEach-Object {
						Exec { &$nugetExe push $_.FullName -ApiKey $nexusApiKey -source $nexusSource }
					}
				}
			}
		}
    }


task Clean `
	-depends Compile, Test, Package `
	-description "Remove temporary files" `
	-requiredVariables temporaryOutputDirectory `
	{
		if (Test-Path $temporaryOutputDirectory)
		{
			Write-Host "Removing temporary output directory located at $temporaryOutputDirectory"

			Remove-Item $temporaryOutputDirectory -Force -Recurse
		}
	}

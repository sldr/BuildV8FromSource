Function Build-V8FromSource
{
<#
.SYNOPSIS
    Builds V8 from source.
.DESCRIPTION
    Builds V8 from source. You are expected to have already installed Visual Studio 2022 (VS2022) and depot_tools along with any configuration they require. NOTE: The depot_tools is allowed to be installed at C:\depot_tools or D:\depot_tools.
.EXAMPLE
    C:\PS> Build-V8FromSource

    This will build V8 from source.
#>
    [CmdletBinding()]
    Param (
        [switch]
        # Specifies that a git clone should not be preformed.
        ${Update},

        [switch]
        # Specifies that any modified git files are reverted to the original git content including submodules. This is normally the files that this script modifies, however any modified git file will be reverted. USE WITH CARE.
        $RevertGit
    )
    Begin {
        $ElapsedTotal = [System.Diagnostics.Stopwatch]::StartNew()
        filter timestamp {"$(Get-Date -Format o):$((Get-PSCallStack)[1].Command): $_"}
        "Starting" | timestamp | Write-Verbose
        ###########################
        # Global V8 Build Version #
        ###########################
        $V8Version="12.9.202.27"
        # Previous 12.8.374.27
        #######################################################
        # Global vars that should change based on total steps #
        #######################################################
        $TotalSteps = 15; # Fix this when adding steps
        $TotalSteps++; # Add one for last step to show not done.
        ############################################
        # Global vars that shouldn't need touching #
        ############################################
        $Activity = 'Building V8 From Source' # Used in Write-Progress -Activity $Activity
        $CurrentStep = 0; # Started at 0
        ##########
        # Step 1 #
        ##########
        # PowerShell Setup
        "PowerShell Setup" | timestamp | Write-Verbose
        $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        $CurrentStep++
        Write-Progress -Activity $Activity -Status 'PowerShell Setup' -CurrentOperation 'Fix -Debug' -PercentComplete ($CurrentStep / $TotalSteps * 100)
        # Fix -Debug turning on -Confirm bug documented at https://connect.microsoft.com/PowerShell/feedback/details/797451/write-debug-is-subject-to-confirm (Don't use Write-Debug till this step finished)
        if ($PSCmdlet.MyInvocation.BoundParameters["Debug"] -ne $null) {
            if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) { # turn it on
                $DebugPreference = 'Continue'
            } else { # turn it off
                $DebugPreference = 'SilentlyContinue'
            }
        } else { # use the parent value
            $DebugPreference = (Get-Variable DebugPreference -Scope 1 -ValueOnly)
        }
        # It is now safe to use Write-Debug now
        "Begin section" | timestamp | Write-Debug
        # Set $ErrorActionPreference to stop unless specified on command line
        if ($PSCmdlet.MyInvocation.BoundParameters["ErrorAction"] -ne $null) {
            if ($ErrorActionPreference -ne 'Stop') {
                "The ErrorAction was overridden from the command line and set to ($ErrorActionPreference) instead of Stop." | timestamp | Write-Warning
            }
        } else {
            $ErrorActionPreference = 'Stop'; # If not specified on the command line then the default is to Stop
        }
        "PowerShell Setup Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
        ##########
        # Step 2 #
        ##########
        # Defining functions
        "Defining functions" | timestamp | Write-Verbose
        $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        $CurrentStep++
        Write-Progress -Activity $Activity -Status 'Defining functions' -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
        # GetV8DebugArgs
        $FuncName = "GetV8DebugArgs"
        Write-Progress -Activity $Activity -Status 'Defining functions' -CurrentOperation $FuncName -PercentComplete ($CurrentStep / $TotalSteps * 100)
        Function GetV8DebugArgs
        {
@'
# Build arguments go here.
# See "gn args <out_dir> --list" for available build arguments.
symbol_level=2
icu_use_data_file=false
use_custom_libcxx=false
is_clang=true
is_component_build=true
is_debug=true
is_official_build=false
chrome_pgo_phase=0
enable_iterator_debugging=false
use_thin_lto=false
v8_static_library=false
v8_embedder_string="-EMB"
v8_use_external_startup_data=false
v8_enable_debugging_features=true
v8_enable_disassembler=true
v8_enable_object_print=true
v8_enable_pointer_compression=false
v8_generate_external_defines_header=true
v8_optimized_debug=false
v8_postmortem_support=true
v8_imminent_deprecation_warnings=false
v8_deprecation_warnings=false
cppgc_enable_young_generation=true
'@
        }
        # GetV8ReleaseArgs
        $FuncName = "GetV8ReleaseArgs"
        Write-Progress -Activity $Activity -Status 'Defining functions' -CurrentOperation $FuncName -PercentComplete ($CurrentStep / $TotalSteps * 100)
        Function GetV8ReleaseArgs
        {
@'
# Build arguments go here.
# See "gn args <out_dir> --list" for available build arguments.
symbol_level=2
icu_use_data_file=false
use_custom_libcxx=false
is_clang=true
is_component_build=true
is_debug=false
is_official_build=false
chrome_pgo_phase=0
enable_iterator_debugging=false
use_thin_lto=false
v8_static_library=false
v8_embedder_string="-EMB"
v8_use_external_startup_data=false
v8_enable_debugging_features=false
v8_enable_disassembler=true
v8_enable_object_print=true
v8_enable_pointer_compression=false
v8_generate_external_defines_header=true
v8_optimized_debug=true
v8_postmortem_support=true
v8_imminent_deprecation_warnings=false
v8_deprecation_warnings=false
cppgc_enable_young_generation=true
'@
        }
        "Defining functions Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
        ##########
        # Step 3 #
        ##########
        # Check Prerequisites
        "Check Prerequisites" | timestamp | Write-Verbose
        $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        $CurrentStep++
        Write-Progress -Activity $Activity -Status 'Check Prerequisites' -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
        "Check if VS2022 is installed" | timestamp | Write-Verbose
        $VSWhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe' # Per MS this doesn't change
        $InstallationPath = & $VSWhere -version '[17.0,18.0)' -latest -nologo -property installationPath
        if ($LASTEXITCODE -ne 0) {
            Throw "VS2022 may not be installed or vswhere.exe failed"
        }
        "Checking environmet variables" | timestamp | Write-Verbose
        if (!(Test-Path Env:\DEPOT_TOOLS_WIN_TOOLCHAIN)) {
            Throw "Missing environment variable DEPOT_TOOLS_WIN_TOOLCHAIN"
        }
        if (!(Test-Path Env:\GYP_MSVS_VERSION)) {
            Throw "Missing environment variable GYP_MSVS_VERSION"
        }
        "Checking path for Depot_Tools" | timestamp | Write-Verbose
        $FoundDepotTools = $false
        $env:Path.Split(';') | % {
            $DepotTools = $_
            if (($DepotTools -eq "C:\depot_tools") -or ($DepotTools -eq "D:\depot_tools")) {
                $FoundDepotTools = $true
            }
        }
        if (!$FoundDepotTools) {
            throw "The depot_tools directory is not in your path"
        }
        "Checking gclient" | timestamp | Write-Verbose
        cmd.exe /C "gclient 2>&1"
        if ($LASTEXITCODE -ne 0) {
            Throw "gclient failed"
        }
        "Checking Python" | timestamp | Write-Verbose
        $WherePython = Where.exe Python3
        if ($WherePython.Count -gt 1) {
            $WherePython = $WherePython[0]
        }
        if (($WherePython -ne "C:\depot_tools\python3.bat") -and ($WherePython -ne "D:\depot_tools\python3.bat")) {
            throw "While Python needs to be installed the [C|D]:\depot_tools\python3.bat should come up first with Where.exe Python3"
        }
        $PythonVersion = cmd.exe /C "Python3 --version 2>&1"
        if ($PythonVersion.Split('.')[0] -ne "Python 3") {
            throw "Python 3 is required (don't use Python 2 or Python 1)"
        }
        "Check Prerequisites Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
    }
    Process {
        "Process section" | timestamp | Write-Debug
    }
    End {
        "End section" | timestamp | Write-Debug
        if (!$Update -and !$RevertGit) {
            ##########
            # Step 4 #
            ##########
            # Removing old build directory
            "Removing old build directory" | timestamp | Write-Verbose
            $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
            $CurrentStep++
            Write-Progress -Activity $Activity -Status 'Removing old build directory' -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
            Remove-Item -ErrorAction Ignore -Recurse -Force C:\build
            if (Test-Path C:\build) {
                throw "Failed to delete C:\build directory"
            }
            New-Item -ItemType Directory C:\build | Out-Null
            "Removing old build directory Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
        }
        Push-Location C:\build
        try {
            if ($RevertGit) {
                ##########
                # Step 5 #
                ##########
                # Revert git
                "Revert git" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status 'Revert git' -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                cmd.exe /C "git -C .\v8\ checkout --force 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw 'revert git failed for "C:\build\v8\"'
                }
                cmd.exe /C "git -C .\v8\build\ checkout --force 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw 'revert git failed for "C:\build\v8\build\"'
                }
                Get-ChildItem -Attributes Directory -Path C:\build\v8\third_party\ | % { cmd.exe /C "git -C `"$($_.FullName)`" checkout --force 2>&1"; if ($LASTEXITCODE -ne 0) { Throw 'revert git failed for "' + $_.FullName + '"' } }
                "Revert git Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                "Finished in $($ElapsedTotal.Stop(); $ElapsedTotal.Elapsed.ToString())" | timestamp | Write-Verbose
                return;
            }
            if (!$Update) {
                ##########
                # Step 6 #
                ##########
                # Fetching V8
                "Fetching V8" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status 'Fetching V8' -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                cmd.exe /C "fetch v8 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "fetch v8 failed"
                }
                "Fetching V8 Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
            }
            Push-Location .\v8
            try {
                ##########
                # Step 7 #
                ##########
                # GITing version $V8Version of V8
                "GITing version $V8Version of V8" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status "GITing version $V8Version of V8" -CurrentOperation "git checkout" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                cmd.exe /C "git checkout tags/$V8Version 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "git checkout failed"
                }
                Write-Progress -Activity $Activity -Status "GITing version $V8Version of V8" -CurrentOperation "gclient sync" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Syncing to specific version of V8" | timestamp | Write-Verbose
                cmd.exe /C "gclient sync -D 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "gcclient sync failed"
                }
                "GITing version $V8Version of V8 Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                ##########
                # Step 8 #
                ##########
                # Adjust files pre-gen
                "Adjust files pre-gen" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                # BUILD.gn
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "BUILD.gn" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust BUILD.gn" | timestamp | Write-Verbose
                $FoundCppgcBaseConfig=$false
                $FoundActionGenV8Gn=$false
                $FoundSourceSetCppgcBase=$false
                $FoundConfigInternalConfigBase=$false
                $FoundConfigInternalConfig=$false
                (Get-Content BUILD.gn) |
                    Foreach-Object -process {
                        if ($_ -match '^config\("cppgc_base_config"\) {') {
                            $FoundCppgcBaseConfig=$true
                            $_
                        } elseif (($_ -match '^  if \(cppgc_is_standalone\) {') -and ($FoundCppgcBaseConfig)) {
                            $FoundCppgcBaseConfig=$false
                            '  if (cppgc_enable_young_generation) {'
                            '    defines += [ "CPPGC_YOUNG_GENERATION" ]'
                            '  }'
                            $_
                        } elseif ($_ -match '^}') {
                            $FoundCppgcBaseConfig=$false
                            $_
                        } elseif ($_ -match '^  action\("gen_v8_gn"\) {') {
                            $FoundActionGenV8Gn=$true
                            $_
                        } elseif (($_ -match '^    visibility = \[ ":\*" \]') -and ($FoundActionGenV8Gn)) {
                            $FoundActionGenV8Gn=$false
                            '    visibility = ['
                            '      ":*",'
                            '      "tools\v8windbg\:*"'
                            '    ]'
                        } elseif ($_ -match '^v8_source_set\("cppgc_base"\) {') {
                            $FoundSourceSetCppgcBase=$true
                            $_
                        } elseif (($_ -match '^}') -and ($FoundSourceSetCppgcBase)) {
                            $FoundSourceSetCppgcBase=$false
                            ''
                            '  if (v8_generate_external_defines_header) {'
                            '    sources += [ "$target_gen_dir/include/v8-gn.h" ]'
                            '    include_dirs = [ "$target_gen_dir/include" ]'
                            '    public_deps += [ ":gen_v8_gn" ]'
                            '  }'
                            $_
                        } elseif ($_ -match '^config\("internal_config_base"\) {') {
                            $FoundConfigInternalConfigBase=$true
                            $_
                        } elseif (($_ -match '^    "\$target_gen_dir",') -and ($FoundConfigInternalConfigBase)) {
                            $FoundConfigInternalConfigBase=$false
                            $_
                            '    "$target_gen_dir/include",'
                        } else {
                            $_
                        }
                    } |
                    Set-Content BUILD.gn -Force
                # build\config\win\BUILD.gn
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "build\config\win\BUILD.gn" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust build\config\win\BUILD.gn" | timestamp | Write-Verbose
                $FoundRuntimeLibrary=$false
                (Get-Content build\config\win\BUILD.gn) |
                    Foreach-Object -process {
                        if ($_ -match '^config\("runtime_library"\) {') {
                            $FoundRuntimeLibrary=$true
                            $_
                        } elseif (($_ -match '^    "_SCL_SECURE_NO_DEPRECATE",') -and ($FoundRuntimeLibrary)) {
                            $FoundRuntimeLibrary=$false
                            $_
                            '    "_SILENCE_CXX20_OLD_SHARED_PTR_ATOMIC_SUPPORT_DEPRECATION_WARNING",'
                        } else {
                            $_
                        }
                    } |
                    Set-Content build\config\win\BUILD.gn -Force
                # tools\v8windbg\BUILD.gn
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "tools\v8windbg\BUILD.gn" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust tools\v8windbg\BUILD.gn" | timestamp | Write-Verbose
                $FoundV8SoutceSetV8windbgTest=$false
                (Get-Content tools\v8windbg\BUILD.gn) |
                    Foreach-Object -process {
                        if ($_ -match '^v8_source_set\("v8windbg_test"\) {') {
                            $FoundV8SoutceSetV8windbgTest=$true
                            $_
                        } elseif (($_ -match '^}') -and ($FoundV8SoutceSetV8windbgTest)) {
                            $FoundV8SoutceSetV8windbgTest=$false
                            ''
                            '  sources += [ "../../out/Debug/gen/include/v8-gn.h" ]'
                            '  deps += [ "../..:gen_v8_gn" ]'
                            $_
                        } elseif ($_ -match '^config\("v8windbg_config"\) {') {
                            $_
                            '  configs = [ "../..:internal_config_base" ]'
                        } else {
                            $_
                        }
                    } |
                    Set-Content tools\v8windbg\BUILD.gn -Force
                # tools\gen-v8-gn.py
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "tools\gen-v8-gn.py" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust tools\gen-v8-gn.py" | timestamp | Write-Verbose
                $SkipLines = 0
                (Get-Content tools\gen-v8-gn.py) |
                    Foreach-Object -process {
                        if ($_ -match '^def generate_positive_definition\(out, define\):') {
                            $_
                            '  if define.find("=") >= 0:'
                            '    [define, value] = define.split("=")'
                            '    out.write('''''''
                            '#ifndef {define}'
                            '#define {define} {value}'
                            '#else'
                            '#if {define} != {value}'
                            '#error "{define} defined but not set to {value}"'
                            '#endif'
                            '#endif  // {define}'
                            '''''''.format(define=define, value=value))'
                            '  else:'
                            '    out.write('''''''
                            '#ifndef {define}'
                            '#define {define} 1'
                            '#else'
                            '#if {define} != 1'
                            '#error "{define} defined but not set to 1"'
                            '#endif'
                            '#endif  // {define}'
                            '''''''.format(define=define))'
                            $SkipLines = 9
                        } else {
                            if ($SkipLines -le 0) {
                                $_
                            } else {
                                $SkipLines--
                            }
                        }
                    } |
                    Set-Content tools\gen-v8-gn.py -Force
                # third_party\abseil-cpp\BUILD.gn
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "third_party\abseil-cpp\BUILD.gn" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\BUILD.gn" | timestamp | Write-Verbose
                $FoundFirstImport=$false
                $PathToAbseil = 'third_party\abseil-cpp\BUILD.gn'
                (Get-Content $PathToAbseil) |
                    Foreach-Object -process {
                        if (($_ -match '^import') -and !$FoundFirstImport) {
                            $FoundFirstImport=$true
                            'is_clang=false'
                            ''
                            $_
                        } else {
                            $_
                        }
                    } |
                    Set-Content $PathToAbseil
                # third_party\abseil-cpp\absl/meta/type_traits_test.cc
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "third_party\abseil-cpp\absl/meta/type_traits_test.cc" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\absl/meta/type_traits_test.cc" | timestamp | Write-Verbose
                $PathToAbseil = 'third_party\abseil-cpp\absl/meta/type_traits_test.cc'
                (Get-Content $PathToAbseil) |
                    Foreach-Object -process {
                        if ($_ -match '^class Trivial {') {
                            '#pragma GCC diagnostic ignored "-Wunused-private-field"'
                            $_
                        } else {
                            $_
                        }
                    } |
                    Set-Content $PathToAbseil
                # third_party\abseil-cpp\absl/strings/internal/str_split_internal.h
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "third_party\abseil-cpp\absl/strings/internal/str_split_internal.h" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\absl/strings/internal/str_split_internal.h" | timestamp | Write-Verbose
                $PathToAbseil = 'third_party\abseil-cpp\absl/strings/internal/str_split_internal.h'
                (Get-Content $PathToAbseil) |
                    Foreach-Object -process {
                        if ($_ -match '^^        v\.insert\(v\.end\(\), ar\.begin\(\), ar\.begin\(\) \+ index\);') {
                            '        v.insert(v.end(), ar.begin(), ar.begin() + (long long)index);'
                        } else {
                            $_
                        }
                    } |
                    Set-Content $PathToAbseil
                # third_party\abseil-cpp/absl/types/variant_test.cc
                Write-Progress -Activity $Activity -Status "Adjust files pre-gen" -CurrentOperation "third_party\abseil-cpp/absl/types/variant_test.cc" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp/absl/types/variant_test.cc" | timestamp | Write-Verbose
                $FirstLine=$false
                $PathToAbseil = 'third_party\abseil-cpp/absl/types/variant_test.cc'
                (Get-Content $PathToAbseil) |
                    Foreach-Object -process {
                        if (!$FirstLine) {
                            $FirstLine=$true
                            '#pragma GCC diagnostic ignored "-Wunused-function"'
                            $_
                        } else {
                            $_
                        }
                    } |
                    Set-Content $PathToAbseil
                "Adjust files pre-gen Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                ##########
                # Step 9 #
                ##########
                # Debug GEN
                "Debug GEN" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status "Debug GEN" -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                New-Item -ErrorAction Ignore -ItemType Directory C:\build\v8\out\Debug | Out-Null
                $DebugLines = GetV8DebugArgs
                Set-Content -Encoding Ascii -Path C:\build\v8\out\Debug\args.gn -Value $DebugLines
                cmd.exe /C "gn gen out\Debug 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "gn gen failed for Debug"
                }
                cmd.exe /C "gn args out\Debug --list >out\Debug.txt 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "gn args failed record generated arguments for Debug"
                }
                cmd.exe /C "gn desc out\Debug `":*`" 2>&1" *>out\DescDebug.txt
                if ($LASTEXITCODE -ne 0) {
                    Throw "gn desc out\Debug failed"
                }
                "Debug GEN Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                ###########
                # Step 10 #
                ###########
                # Release GEN
                "Release GEN" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status "Release GEN" -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                New-Item -ErrorAction Ignore -ItemType Directory C:\build\v8\out\Release | Out-Null
                $ReleaseLines = GetV8ReleaseArgs
                Set-Content -Encoding Ascii -Path C:\build\v8\out\Release\args.gn -Value $ReleaseLines
                cmd.exe /C "gn gen out\Release 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "gn gen failed for Release"
                }
                cmd.exe /C "gn args out\Release --list >out\Release.txt 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "gn args failed record generated arguments for Release"
                }
                cmd.exe /C "gn desc out\Release `":*`" 2>&1" *>out\DescRelease.txt
                if ($LASTEXITCODE -ne 0) {
                    Throw "gn desc out\Release failed"
                }
                "Release GEN Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                ###########
                # Step 11 #
                ###########
                # VisualStudio GEN
                "VisualStudio GEN" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status "VisualStudio GEN" -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                New-Item -ErrorAction Ignore -ItemType Directory C:\build\v8\out\VisualStudio | Out-Null
                $ReleaseLines = GetV8ReleaseArgs
                Set-Content -Encoding Ascii -Path C:\build\v8\out\VisualStudio\args.gn -Value $ReleaseLines
                cmd.exe /C "gn gen --ide=vs2022 out\VisualStudio 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "gn gen failed for VisualStudio"
                }
                "VisualStudio GEN Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                ###########
                # Step 12 #
                ###########
                # Adjust files post-gen
                "Adjust files post-gen" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                # third_party\abseil-cpp\absl\container\internal\raw_hash_set.h
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "third_party\abseil-cpp\absl\container\internal\raw_hash_set.h" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\absl\container\internal\raw_hash_set.h" | timestamp | Write-Verbose
                (Get-Content .\third_party\abseil-cpp\absl\container\internal\raw_hash_set.h) |
                    Foreach-Object -process {
                        if ($_ -match '^class HashSetResizeHelper {') {
                            'class ABSL_DLL HashSetResizeHelper {'
                        } elseif ($_ -match '^bool ShouldInsertBackwardsForDebug\(size_t capacity, size_t hash,') {
                            'ABSL_DLL bool ShouldInsertBackwardsForDebug(size_t capacity, size_t hash,'
                        } elseif ($_ -match '^size_t PrepareInsertAfterSoo\(size_t hash, size_t slot_size,') {
                            'ABSL_DLL size_t PrepareInsertAfterSoo(size_t hash, size_t slot_size,'
                        } elseif ($_ -match '^size_t PrepareInsertNonSoo\(CommonFields& common, size_t hash, FindInfo target,') {
                            'ABSL_DLL size_t PrepareInsertNonSoo(CommonFields& common, size_t hash, FindInfo target,'
                        } elseif ($_ -match '^void ClearBackingArray\(CommonFields& c, const PolicyFunctions& policy,') {
                            'ABSL_DLL void ClearBackingArray(CommonFields& c, const PolicyFunctions& policy,'
                        } elseif ($_ -match '^extern template FindInfo find_first_non_full\(const CommonFields&, size_t\);') {
                            'extern template ABSL_DLL FindInfo find_first_non_full(const CommonFields&, size_t);'
                        } elseif ($_ -match '^FindInfo find_first_non_full_outofline\(const CommonFields&, size_t\);') {
                            'ABSL_DLL FindInfo find_first_non_full_outofline(const CommonFields&, size_t);'
                        } elseif ($_ -match '^void EraseMetaOnly\(CommonFields& c, size_t index, size_t slot_size\);') {
                            'ABSL_DLL void EraseMetaOnly(CommonFields& c, size_t index, size_t slot_size);'
                        } elseif ($_ -match '^const void\* GetHashRefForEmptyHasher\(const CommonFields& common\);') {
                            'ABSL_DLL const void* GetHashRefForEmptyHasher(const CommonFields& common);'
                        } elseif ($_ -match '^    static constexpr PolicyFunctions value = {') {
                            '    static const PolicyFunctions value = {'
                        } else {
                            $_
                        }
                    } |
                    Set-Content .\third_party\abseil-cpp\absl\container\internal\raw_hash_set.h -Force
                # third_party\abseil-cpp\absl\container\internal\raw_hash_set.h
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "third_party\abseil-cpp\absl\container\internal\raw_hash_set.cc" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\absl\container\internal\raw_hash_set.cc" | timestamp | Write-Verbose
                (Get-Content .\third_party\abseil-cpp\absl\container\internal\raw_hash_set.cc) |
                    Foreach-Object -process {
                        if ($_ -match '^bool ShouldInsertBackwardsForDebug\(size_t capacity, size_t hash,') {
                            'ABSL_DLL bool ShouldInsertBackwardsForDebug(size_t capacity, size_t hash,'
                        } elseif ($_ -match '^size_t PrepareInsertAfterSoo\(size_t hash, size_t slot_size,') {
                            'ABSL_DLL size_t PrepareInsertAfterSoo(size_t hash, size_t slot_size,'
                        } elseif ($_ -match '^size_t PrepareInsertNonSoo\(CommonFields& common, size_t hash, FindInfo target,') {
                            'ABSL_DLL size_t PrepareInsertNonSoo(CommonFields& common, size_t hash, FindInfo target,'
                        } elseif ($_ -match '^void ClearBackingArray\(CommonFields& c, const PolicyFunctions& policy,') {
                            'ABSL_DLL void ClearBackingArray(CommonFields& c, const PolicyFunctions& policy,'
                        } elseif ($_ -match '^FindInfo find_first_non_full_outofline\(const CommonFields& common,') {
                            'ABSL_DLL FindInfo find_first_non_full_outofline(const CommonFields& common,'
                        } elseif ($_ -match '^void EraseMetaOnly\(CommonFields& c, size_t index, size_t slot_size\) {') {
                            'ABSL_DLL void EraseMetaOnly(CommonFields& c, size_t index, size_t slot_size) {'
                        } elseif ($_ -match '^const void\* GetHashRefForEmptyHasher\(const CommonFields& common\) {') {
                            'ABSL_DLL const void* GetHashRefForEmptyHasher(const CommonFields& common) {'
                        } else {
                            $_
                        }
                    } |
                    Set-Content .\third_party\abseil-cpp\absl\container\internal\raw_hash_set.cc -Force
                # third_party\abseil-cpp\absl\base\internal\throw_delegate.h
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "third_party\abseil-cpp\absl\base\internal\throw_delegate.h" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\absl\base\internal\throw_delegate.h" | timestamp | Write-Verbose
                (Get-Content .\third_party\abseil-cpp\absl\base\internal\throw_delegate.h) |
                    Foreach-Object -process {
                        if ($_ -match '^\[\[noreturn]] void ThrowStdOutOfRange\(const std::string& what_arg\);') {
                            '[[noreturn]] ABSL_DLL void ThrowStdOutOfRange(const std::string& what_arg);'
                        } elseif ($_ -match '^\[\[noreturn]] void ThrowStdOutOfRange\(const char\* what_arg\);') {
                            '[[noreturn]] ABSL_DLL void ThrowStdOutOfRange(const char* what_arg);'
                        } else {
                            $_
                        }
                    } |
                    Set-Content .\third_party\abseil-cpp\absl\base\internal\throw_delegate.h -Force
                # third_party\abseil-cpp\absl\base\internal\throw_delegate.cc
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "third_party\abseil-cpp\absl\base\internal\throw_delegate.cc" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\absl\base\internal\throw_delegate.cc" | timestamp | Write-Verbose
                (Get-Content .\third_party\abseil-cpp\absl\base\internal\throw_delegate.cc) |
                    Foreach-Object -process {
                        if ($_ -match '^void ThrowStdOutOfRange\(const std::string& what_arg\) {') {
                            'ABSL_DLL void ThrowStdOutOfRange(const std::string& what_arg) {'
                        } elseif ($_ -match '^void ThrowStdOutOfRange(const char* what_arg) {') {
                            'ABSL_DLL void ThrowStdOutOfRange(const char* what_arg) {'
                        } else {
                            $_
                        }
                    } |
                    Set-Content .\third_party\abseil-cpp\absl\base\internal\throw_delegate.cc -Force
                # third_party\abseil-cpp\absl\base\internal\raw_logging.h
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "third_party\abseil-cpp\absl\base\internal\raw_logging.h" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\absl\base\internal\raw_logging.h" | timestamp | Write-Verbose
                (Get-Content .\third_party\abseil-cpp\absl\base\internal\raw_logging.h) |
                    Foreach-Object -process {
                        if ($_ -match '^void RawLog\(absl::LogSeverity severity, const char\* file, int line,') {
                            'ABSL_DLL void RawLog(absl::LogSeverity severity, const char* file, int line,'
                        } else {
                            $_
                        }
                    } |
                    Set-Content .\third_party\abseil-cpp\absl\base\internal\raw_logging.h -Force
                # third_party\abseil-cpp\absl\base\internal\raw_logging.cc
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "third_party\abseil-cpp\absl\base\internal\raw_logging.cc" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\abseil-cpp\absl\base\internal\raw_logging.cc" | timestamp | Write-Verbose
                (Get-Content .\third_party\abseil-cpp\absl\base\internal\raw_logging.cc) |
                    Foreach-Object -process {
                        if ($_ -match '^void RawLog\(absl::LogSeverity severity, const char\* file, int line,') {
                            'ABSL_DLL void RawLog(absl::LogSeverity severity, const char* file, int line,'
                        } else {
                            $_
                        }
                    } |
                    Set-Content .\third_party\abseil-cpp\absl\base\internal\raw_logging.cc -Force
                # test/unittests/heap/cppgc/age-table-unittest.cc
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "test/unittests/heap/cppgc/age-table-unittest.cc" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust test/unittests/heap/cppgc/age-table-unittest.cc" | timestamp | Write-Verbose
                $PathToage_table_unittest = 'test/unittests/heap/cppgc/age-table-unittest.cc'
                (Get-Content $PathToage_table_unittest) |
                    Foreach-Object -process {
                        if ($_ -match '^   void\* heap_end = heap_start \+ api_constants::kCagedHeapReservationSize - 1;') {
                            '   void* heap_end = heap_start + api_constants::kCagedHeapDefaultReservationSize - 1;'
                        } elseif ($_ -match '^      api_constants::kCagedHeapReservationSize \* 4\);') {
                            '      api_constants::kCagedHeapDefaultReservationSize * 4);'
                        } else {
                            $_
                        }
                    } |
                    Set-Content $PathToage_table_unittest
                # third_party\icu\scripts\asm_to_inline_asm.py
                Write-Progress -Activity $Activity -Status "Adjust files post-gen" -CurrentOperation "third_party\icu\scripts\asm_to_inline_asm.py" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                "Adjust third_party\icu\scripts\asm_to_inline_asm.py" | timestamp | Write-Verbose
                $PathToasm_to_inline_asm = 'third_party\icu\scripts\asm_to_inline_asm.py'
                (Get-Content $PathToasm_to_inline_asm) |
                    Foreach-Object -process {
                        if ($_ -match '^[ \t]*with(.*)wb(.*)')
                        {
                            '  with open(in_filename, ''r'') as infile, open(out_filename, ''w'') as outfile:'
                        } elseif ($_ -match '^[ \t]*line = line.replace.*')
                        {
                            '      line = line.replace(''_icudt'', ''icudt'')'
                            $_
                        } else {
                            $_
                        }
                    } |
                    Set-Content $PathToasm_to_inline_asm
                "Adjust files post-gen Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                ###########
                # Step 13 #
                ###########
                # V8 Debug Build
                "V8 Debug Build" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status "V8 Debug Build" -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                cmd.exe /C "ninja -C out\Debug 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "ninja debug build failed"
                }
                "V8 Debug Build Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                ###########
                # Step 14 #
                ###########
                # V8 Release Build
                "V8 Release Build" | timestamp | Write-Verbose
                $Elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                $CurrentStep++
                Write-Progress -Activity $Activity -Status "V8 Release Build" -CurrentOperation "" -PercentComplete ($CurrentStep / $TotalSteps * 100)
                cmd.exe /C "ninja -C out\Release 2>&1"
                if ($LASTEXITCODE -ne 0) {
                    Throw "ninja release build failed"
                }
                "V8 Release Build Done in $($Elapsed.Stop(); $Elapsed.Elapsed.ToString())" | timestamp | Write-Verbose
                Write-Progress -Activity $Activity -Completed
                "Finished in $($ElapsedTotal.Stop(); $ElapsedTotal.Elapsed.ToString())" | timestamp | Write-Verbose
            }
            finally {
                Pop-Location
            }
        }
        finally {
            Pop-Location
        }
    }
}

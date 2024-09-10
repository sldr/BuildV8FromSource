$V8Version="11.6.189.22"
# Previous 11.5.150.16
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
v8_enable_webassembly=false
v8_generate_external_defines_header=true
v8_optimized_debug=false
v8_postmortem_support=true
v8_imminent_deprecation_warnings=false
v8_deprecation_warnings=false
cppgc_enable_young_generation=true
'@
}
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
v8_enable_webassembly=false
v8_generate_external_defines_header=true
v8_optimized_debug=true
v8_postmortem_support=true
v8_imminent_deprecation_warnings=false
v8_deprecation_warnings=false
cppgc_enable_young_generation=true
'@
}

filter timestamp {"$(Get-Date -Format o):$((Get-PSCallStack)[1].Command): $_"}

$PreviousVerbosePreference = $VerbosePreference
if ($VerbosePreference -eq "SilentlyContinue") {
    $VerbosePreference = "Continue"
}
try {
    "V8 Build Starting" | timestamp | Write-Verbose
    if ($Args.Count -gt 1) {
        throw 'Only supports 1 argument. Usage: "BuildV8FromSource.ps1 [update]"'
    }
    if (($Args.Count -eq 1) -and ($Args[0] -cne "update")) {
        throw 'Argument must be update. Usage: "BuildV8FromSource.ps1 [update]"'
    }
    "  Check if VS2022 is installed" | timestamp | Write-Verbose
    $VSWhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    $InstallationPath = & $VSWhere -version '[17.0,18.0)' -latest -nologo -property installationPath
    if ($LASTEXITCODE -ne 0) {
        Throw "VS2022 may not be installed or vswhere.exe failed"
    }
    "  Checking environmet variables" | timestamp | Write-Verbose
    if (!(Test-Path Env:\DEPOT_TOOLS_WIN_TOOLCHAIN)) {
        Throw "Missing environment variable DEPOT_TOOLS_WIN_TOOLCHAIN"
    }
    if (!(Test-Path Env:\GYP_MSVS_VERSION)) {
        Throw "Missing environment variable GYP_MSVS_VERSION"
    }
    "  Checking path for Depot_Tools" | timestamp | Write-Verbose
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
    "  Checking gclient" | timestamp | Write-Verbose
    cmd.exe /C "gclient 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Throw "gclient failed"
    }
    "  Checking Python" | timestamp | Write-Verbose
    $WherePython = Where.exe Python3
    if ($WherePython.Count -gt 1) {
        $WherePython = $WherePython[0]
    }
    if (($WherePython -ne "C:\depot_tools\python3.bat") -and ($WherePython -ne "D:\depot_tools\python3.bat")) {
        throw "While Python needs to be installed the [C|D]:\depot_tools\python.bat should come up first with Where.exe Python"
    }
    $PythonVersion = cmd.exe /C "Python3 --version 2>&1"
    if ($PythonVersion.Split('.')[0] -ne "Python 3") {
        throw "Python 2 is needed (don't use Python 3 or Python 1)"
    }
    if ($Args.Count -eq 0) {
        "Removing old build directory" | timestamp | Write-Verbose
        Remove-Item -ErrorAction Ignore -Recurse -Force C:\build
        if (Test-Path C:\build) {
            throw "Failed to delete C:\build directory"
        }
        New-Item -ItemType Directory C:\build | Out-Null
    }
    Push-Location C:\build
    try {
        if ($Args.Count -eq 0) {
            "Fetching V8" | timestamp | Write-Verbose
            cmd.exe /C "fetch v8 2>&1"
            if ($LASTEXITCODE -ne 0) {
                Throw "fetch v8 failed"
            }
        }
        Push-Location .\v8
        try {
            #
            # git checkout tags/$V8Version
            #
            "GITing version $V8Version of V8" | timestamp | Write-Verbose
            cmd.exe /C "git checkout tags/$V8Version 2>&1"
            if ($LASTEXITCODE -ne 0) {
                Throw "git checkout failed"
            }
            "Syncing to specific version of V8" | timestamp | Write-Verbose
            cmd.exe /C "gclient sync -D 2>&1"
            if ($LASTEXITCODE -ne 0) {
                Throw "gcclient sync failed"
            }
            #
            # BUILD.gn
            #
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
                    } elseif ($_ -match '^config\("internal_config"\) {') {
                        $FoundConfigInternalConfig=$true
                        $_
                    } elseif (($_ -match '^  defines = \[\]') -and ($FoundConfigInternalConfig)) {
                        $FoundConfigInternalConfig=$false
                        '  defines = ["_SILENCE_CXX20_OLD_SHARED_PTR_ATOMIC_SUPPORT_DEPRECATION_WARNING"]'
                    } else {
                        $_
                    }
                } |
                Set-Content BUILD.gn -Force
            #
            # tools\v8windbg\BUILD.gn
            #
            "Adjust v8 source set of target v8windbg_test in tools\v8windbg\BUILD.gn" | timestamp | Write-Verbose
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
            #
            # tools\gen-v8-gn.py
            #
            "Adjust Python script tools\gen-v8-gn.py" | timestamp | Write-Verbose
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
            #
            # Debug
            #
            "V8 Debug Setup" | timestamp | Write-Verbose
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
            #
            # Release
            #
            "V8 Release Setup" | timestamp | Write-Verbose
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
            #
            # VisualStudio (Note: This is not used to build it is used for all IDE features except building)
            #
            "V8 VisualStudio Setup" | timestamp | Write-Verbose
            New-Item -ErrorAction Ignore -ItemType Directory C:\build\v8\out\VisualStudio | Out-Null
            $ReleaseLines = GetV8ReleaseArgs
            Set-Content -Encoding Ascii -Path C:\build\v8\out\VisualStudio\args.gn -Value $ReleaseLines
            cmd.exe /C "gn gen --ide=vs2022 out\VisualStudio 2>&1"
            if ($LASTEXITCODE -ne 0) {
                Throw "gn gen failed for VisualStudio"
            }
            #
            # Fix age-table-unittest.cc
            #
            "Fix age-table-unittest.cc" | timestamp | Write-Verbose
            (Get-Content test/unittests/heap/cppgc/age-table-unittest.cc) |
                Foreach-Object -process {
                    if ($_ -match '^  void\* heap_end = heap_start \+ kCagedHeapReservationSize - 1;') {
                        '  void* heap_end = heap_start + api_constants::kCagedHeapDefaultReservationSize - 1;'
                    } elseif ($_ -match '^      api_constants::kCagedHeapReservationSize \* 4\);') {
                        '      api_constants::kCagedHeapDefaultReservationSize * 4);'
                    } else {
                        $_
                    }
                } |
                Set-Content test/unittests/heap/cppgc/age-table-unittest.cc -Force
            #
            # Fix asm_to_inline_asm.py
            #
            "Fix asm_to_inline_asm.py" | timestamp | Write-Verbose
            $PathToasm_to_inline_asm = 'C:\build\v8\third_party\icu\scripts\asm_to_inline_asm.py'
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
            #
            # Build Debug and Release
            #
            "V8 Debug Build" | timestamp | Write-Verbose
            cmd.exe /C "ninja -C out\Debug 2>&1"
            if ($LASTEXITCODE -ne 0) {
                Throw "ninja debug build failed"
            }
            "V8 Release Build" | timestamp | Write-Verbose
            cmd.exe /C "ninja -C out\Release 2>&1"
            if ($LASTEXITCODE -ne 0) {
                Throw "ninja release build failed"
            }
            "V8 Build Finished Successfully" | timestamp | Write-Verbose
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    $VerbosePreference = $PreviousVerbosePreference
}
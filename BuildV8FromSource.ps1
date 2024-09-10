$V8Version="11.5.150.16"
# Previous 10.4.132.20
Function GetV8DebugArgs
{
@'
# Build arguments go here.
# See "gn args <out_dir> --list" for available build arguments.
symbol_level=2
icu_use_data_file=false
use_custom_libcxx=false
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
use_cxx17=true
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
use_cxx17=true
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
    "Removing old build directory" | timestamp | Write-Verbose
    Remove-Item -ErrorAction Ignore -Recurse -Force C:\build
    if (Test-Path C:\build) {
        throw "Failed to delete C:\build directory"
    }
    New-Item -ItemType Directory C:\build | Out-Null
    Push-Location C:\build
    try {
        "Fetching V8" | timestamp | Write-Verbose
        cmd.exe /C "fetch v8 2>&1"
        if ($LASTEXITCODE -ne 0) {
            Throw "fetch v8 failed"
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
            # Add define of CPPGC_YOUNG_GENERATION in cppgc_base_config
            #
            "Add define of CPPGC_YOUNG_GENERATION in cppgc_base_config" | timestamp | Write-Verbose
            $FoundCppgcBaseConfig=$false
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
                    } else {
                        $_
                    }
                } |
                Set-Content BUILD.gn -Force
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
            cmd.exe /C "gn gen --ide=vs out\VisualStudio 2>&1"
            if ($LASTEXITCODE -ne 0) {
                Throw "gn gen failed for VisualStudio"
            }
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
            # Fix .\test\unittests\heap\shared-heap-unittest.cc
            #
            "Fix shared-heap-unittest.cc" | timestamp | Write-Verbose
            Push-Location .\test\unittests\heap
            try {
                (Get-Content shared-heap-unittest.cc) |
                    Foreach-Object -process {
                        if ($_ -match '^  using ThreadType = TestType::ThreadType;')
                        {
                            '  using ThreadType = typename TestType::ThreadType;'
                        } else {
                            $_
                        }
                    } |
                    Set-Content shared-heap-unittest.cc -Force
            }
            finally {
                Pop-Location
            }
            #
            # Fix .\include\v8-platform.h
            #
            "Fix v8-platform.h" | timestamp | Write-Verbose
            Push-Location .\include
            try {
                (Get-Content v8-platform.h) |
                    Foreach-Object -process {
                        if ($_ -match '^    return floor\(CurrentClockTimeMillis\(\)\);')
                        {
                            '    return static_cast<int64_t>(floor(CurrentClockTimeMillis()));'
                        } else {
                            $_
                        }
                    } |
                    Set-Content v8-platform.h -Force
            }
            finally {
                Pop-Location
            }
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
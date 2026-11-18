param(
    [string]$GameRoot = "D:/Software/GameApp/steam/steamapps/common/ProjectZomboid",
    [switch]$SkipPreview
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$ModRoot = Join-Path $Root "Contents\mods\EmberUI\42"
$LuaRoot = Join-Path $ModRoot "media\lua"
$BuildDir = Join-Path $Root "build"
$TestClassesDir = Join-Path $BuildDir "test-classes"
New-Item -ItemType Directory -Force -Path $TestClassesDir | Out-Null

$Java = Join-Path $GameRoot "jre64\bin\java.exe"
if (!(Test-Path -LiteralPath $Java)) { $Java = Join-Path $GameRoot "jre\bin\java.exe" }
if (!(Test-Path -LiteralPath $Java)) { $Java = "java" }

Write-Output "[EmberUI] 1/5 Auditing standalone isolation (zero host-mod leakage)..."
$leaks = Select-String -Path (Get-ChildItem -Path $LuaRoot -Recurse -Filter "*.lua" | Select-Object -ExpandProperty FullName) -Pattern "EmberRoutesProbe|EmberRoutes/|EmberRoutesJava"
if ($leaks) {
    $leaks | ForEach-Object { Write-Error "$($_.Path):$($_.LineNumber): $($_.Line)" }
    throw "[EmberUI] Standalone dependency audit FAILED."
}

Write-Output "[EmberUI] 2/5 Auditing CN/EN translation parity & placeholder discipline..."
& python (Join-Path $Root "tools\check_i18n.py")
if ($LASTEXITCODE -ne 0) { throw "[EmberUI] check_i18n.py failed" }

Write-Output "[EmberUI] Compiling test harness..."
$TestSources = @(Get-ChildItem -LiteralPath (Join-Path $Root "tests\java") -Filter "*.java" | Select-Object -ExpandProperty FullName)
& javac -encoding UTF-8 --release 17 -cp "$GameRoot\*" -d $TestClassesDir @TestSources
if ($LASTEXITCODE -ne 0) { throw "[EmberUI] javac test harness failed" }

Write-Output "[EmberUI] 3/5 Compiling EmberUI Lua files with Kahlua (debug=false and debug=true)..."
& $Java -cp "$TestClassesDir;$GameRoot\*" KahluaCompileTest $LuaRoot
if ($LASTEXITCODE -ne 0) { throw "[EmberUI] Kahlua compile check failed" }

Write-Output "[EmberUI] 4/5 Running standalone Kahlua unit test suite (emberui-core-test.lua)..."
& $Java -cp "$TestClassesDir;$GameRoot\*" KahluaEmberUITest "--repo-root=$Root" "--game-root=$GameRoot" "emberui-core-test.lua"
if ($LASTEXITCODE -ne 0) { throw "[EmberUI] emberui-core-test.lua failed" }

if (-not $SkipPreview) {
    Write-Output "[EmberUI] 5/5 Generating offline OpenGL visual gallery..."
    & (Join-Path $Root "tools\preview-ui.ps1") -GameRoot $GameRoot
    if ($LASTEXITCODE -ne 0) { throw "[EmberUI] preview-ui.ps1 failed" }
} else {
    Write-Output "[EmberUI] 5/5 Skipped OpenGL visual gallery (-SkipPreview)."
}

$ZipPath = Join-Path $BuildDir "EmberUI-1.1.0.zip"
if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
Compress-Archive -Path (Join-Path $Root "Contents\mods\EmberUI") -DestinationPath $ZipPath -Force
Write-Output "[EmberUI] BUILD_OK $ZipPath"

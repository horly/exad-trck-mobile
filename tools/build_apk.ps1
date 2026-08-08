[CmdletBinding()]
param(
    [ValidateSet('debug', 'release')]
    [string]$Mode = 'release',

    [string]$ApiBaseUrl = 'https://exadtracking.app/api/v1/mobile'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$configPath = Join-Path $projectRoot 'lib\core\config\app_config.dart'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$versionPattern = '(?m)^version:\s*(?<name>\d+\.\d+\.\d+)\+(?<build>\d+)\s*$'
$versionMatch = [regex]::Match($pubspec, $versionPattern)

if (-not $versionMatch.Success) {
    throw 'La version de pubspec.yaml doit respecter le format x.y.z+build.'
}

$versionName = $versionMatch.Groups['name'].Value
$nextBuildNumber = [int]$versionMatch.Groups['build'].Value + 1
$flutterArguments = @(
    'build'
    'apk'
    "--$Mode"
    "--build-name=$versionName"
    "--build-number=$nextBuildNumber"
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
    "--dart-define=APP_VERSION=$versionName"
    "--dart-define=APP_BUILD_NUMBER=$nextBuildNumber"
)

Write-Host "Génération EXAD Tracking Mobile $versionName+$nextBuildNumber ($Mode)..."

Push-Location $projectRoot
try {
    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) {
        throw "La génération Flutter a échoué avec le code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$updatedPubspec = [regex]::Replace(
    $pubspec,
    $versionPattern,
    "version: $versionName+$nextBuildNumber",
    1
)
[System.IO.File]::WriteAllText($pubspecPath, $updatedPubspec, $utf8NoBom)

$config = [System.IO.File]::ReadAllText($configPath)
$appVersionPattern = [regex]::new(
    "(?s)(static const appVersion = String\.fromEnvironment\(\s*'APP_VERSION',\s*defaultValue:\s*')[^']+(')"
)
$buildNumberPattern = [regex]::new(
    "(?s)(static const appBuildNumber = int\.fromEnvironment\(\s*'APP_BUILD_NUMBER',\s*defaultValue:\s*)\d+(,)"
)
$config = $appVersionPattern.Replace(
    $config,
    { param($match) $match.Groups[1].Value + $versionName + $match.Groups[2].Value },
    1
)
$config = $buildNumberPattern.Replace(
    $config,
    { param($match) $match.Groups[1].Value + $nextBuildNumber + $match.Groups[2].Value },
    1
)
[System.IO.File]::WriteAllText($configPath, $config, $utf8NoBom)

$flutterArtifact = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$Mode.apk"
$artifactName = "EXAD-Tracking-$versionName+$nextBuildNumber.apk"
$artifact = Join-Path (Split-Path $flutterArtifact -Parent) $artifactName
Copy-Item -LiteralPath $flutterArtifact -Destination $artifact -Force

Write-Host "APK généré : $artifact"
Write-Host "Version enregistrée : $versionName+$nextBuildNumber"

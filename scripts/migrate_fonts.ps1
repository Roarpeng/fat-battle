# Replace GoogleFonts.fraunces/figtree with AppFonts.display/body across lib/
# and fix imports (google_fonts -> forge_theme where needed)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$lib = Join-Path $root 'lib'

$files = Get-ChildItem -Recurse $lib -Filter *.dart |
    Select-String -Pattern 'GoogleFonts\.(fraunces|figtree)' -List |
    Select-Object -ExpandProperty Path

foreach ($f in $files) {
    $c = Get-Content $f -Raw -Encoding UTF8
    $c = $c -replace 'GoogleFonts\.fraunces\(', 'AppFonts.display('
    $c = $c -replace 'GoogleFonts\.figtree\(', 'AppFonts.body('

    # fix imports: keep google_fonts only if still referenced elsewhere
    $usesGoogleFonts = $c -match 'GoogleFonts\.'
    if (-not $usesGoogleFonts) {
        # compute relative import to theme/forge_theme.dart
        $rel = Split-Path -Parent $f
        $depth = ($rel.Substring($lib.Length).TrimStart('\') -split '\\' | Where-Object { $_ }).Count
        $prefix = '../' * $depth
        $c = $c -replace "import 'package:google_fonts/google_fonts\.dart';", "import '${prefix}theme/forge_theme.dart';"
    }
    Set-Content -Path $f -Value $c -Encoding UTF8 -NoNewline
    Write-Host "updated: $f"
}
Write-Host "done. files: $($files.Count)"

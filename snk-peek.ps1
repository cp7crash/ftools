
param(
    [string]$Path = $null
)


if (-not $Path) {
    Write-Host "snk-peek: Attempts to work out what's in an .snk (Strong Name Key) file"
    Write-Host "   usage: snk-peek.ps1 <path-to-snk-file>"
    Write-Host "      eg: .\snk-peek.ps1 mykey.snk"
    exit 1
}

if (-not (Test-Path $Path)) {
    Write-Host "ERROR: File not found: $Path" -ForegroundColor Red
    Write-Host "Please check the path and try again."
    exit 2
}

try {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
}
catch {
    Write-Host "ERROR: Unable to read file: $Path" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 3
}
$size = $bytes.Length

# PRIVATEKEYBLOB header
$hasPrivateHeader = ($bytes.Length -gt 0 -and $bytes[0] -eq 0x07)

if ($hasPrivateHeader) {
    Write-Host "Contains PRIVATE key (full keypair)" -ForegroundColor Green
    try {
        # Parse PRIVATEKEYBLOB format (Microsoft)
        $pos = 0
        $bType = $bytes[$pos]; $pos++   # 0x07
        $bVersion = $bytes[$pos]; $pos++
        $reserved = [BitConverter]::ToUInt16($bytes, $pos); $pos += 2
        $aiKeyAlg = [BitConverter]::ToUInt32($bytes, $pos); $pos += 4
        # RSAPUBKEY
        $magic = [BitConverter]::ToUInt32($bytes, $pos); $pos += 4
        $bitlen = [BitConverter]::ToUInt32($bytes, $pos); $pos += 4
        $pubexp = [BitConverter]::ToUInt32($bytes, $pos); $pos += 4
        $modlen = [int]($bitlen / 8)
        $modulus = $bytes[$pos..($pos + $modlen - 1)]; $pos += $modlen
        Write-Host "PRIVATEKEYBLOB details:" -ForegroundColor Cyan
        Write-Host ("  Key size   : {0} bits" -f $bitlen)
        Write-Host ("  Exponent   : 0x{0}" -f $pubexp.ToString("X"))
        Write-Host ("  Modulus    : {0}" -f ([BitConverter]::ToString($modulus)))
        # Optionally, parse D, P, Q, DP, DQ, InverseQ if desired
    }
    catch {
        Write-Host "Failed to parse PRIVATEKEYBLOB structure." -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}
elseif ($size -lt 400) {
    Write-Host "Likely PUBLIC-ONLY key (size < 400 bytes)" -ForegroundColor Yellow
}
else {
    Write-Host "Cannot confirm private key, but no PRIVATEKEYBLOB header found" -ForegroundColor Yellow
}

$ErrorActionPreference = 'Stop'
$previousConsoleEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    if (-not $env:DB_PASSWORD) { throw '请设置 DB_PASSWORD，连接方法见 README.md' }
    mvn -q -DskipTests compile exec:java
    if ($LASTEXITCODE -ne 0) { throw '程序运行失败' }
} finally {
    [Console]::OutputEncoding = $previousConsoleEncoding
    Pop-Location
}

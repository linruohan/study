#requires -Version 5.1
<#
.SYNOPSIS
  一键启动「文明重启」开发环境。
.DESCRIPTION
  顺序：Docker(PostgreSQL + MinIO) -> 数据库迁移 -> Fastify API -> Flutter 桌面应用。
  每一步都做健康检查，强依赖没起来会直接报错退出，
  避免出现「应用已经打开，服务器却还没起来」的情况。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1 -ServerOnly
#>
param(
  # 只启动服务端依赖，不打开 Flutter 应用。
  [switch]$ServerOnly,
  # 显式执行数据库迁移；默认不跑，避免未就绪的迁移文件挡住日常启动。
  [switch]$Migrate
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$ServerDir = Join-Path $Root 'server'
$AppDir = Join-Path $Root 'app'
$DbPort = 5432
$StoragePort = 9000
$ApiPort = 3000
$ApiHealthUrl = "http://127.0.0.1:$ApiPort/healthz"
$ApiLog = Join-Path $ServerDir '.dev-server.log'
$ApiErrorLog = Join-Path $ServerDir '.dev-server.error.log'

# 输出当前进行到哪一步。
function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

# 输出某一步已经就绪。
function Write-Ready([string]$Message) {
  Write-Host "    [就绪] $Message" -ForegroundColor Green
}

# 强依赖失败：红色报错并终止整个启动流程。
function Stop-Startup([string]$Message) {
  Write-Host "`n[启动失败] $Message" -ForegroundColor Red
  exit 1
}

# 判断命令是否存在（docker / node / npm / flutter）。
function Test-CommandExists([string]$Name) {
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# 检查本机端口是否能连通，用来确认 Docker 容器映射的服务真的可以被 Windows 访问。
function Test-TcpPort([int]$Port) {
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $async = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
    if (-not $async.AsyncWaitHandle.WaitOne(1500)) {
      return $false
    }
    $client.EndConnect($async)
    return $true
  } catch {
    return $false
  } finally {
    $client.Close()
  }
}

# 轮询等待端口就绪，超时返回 false，由调用方决定怎么报错。
function Wait-TcpPort([int]$Port, [int]$TimeoutSeconds) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-TcpPort $Port) {
      return $true
    }
    Start-Sleep -Seconds 2
  }
  return $false
}

# /healthz 只有在数据库和对象存储都正常时才返回 200，是最强的服务健康检查。
function Test-ApiHealth {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $ApiHealthUrl -TimeoutSec 5
    return $response.StatusCode -eq 200
  } catch {
    return $false
  }
}

# 等待 API 健康检查通过。
function Wait-ApiHealth([int]$TimeoutSeconds) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-ApiHealth) {
      return $true
    }
    Start-Sleep -Seconds 2
  }
  return $false
}

# 等待 Flutter Windows 桌面进程出现，避免 flutter run 失败却被当成启动成功。
function Wait-AppProcess([int]$TimeoutSeconds) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (Get-Process study_app -ErrorAction SilentlyContinue) {
      return $true
    }
    Start-Sleep -Seconds 2
  }
  return $false
}

# 打印日志末尾，失败时不用自己翻文件。
function Show-LogTail([string]$Path, [int]$Lines = 30) {
  if (Test-Path $Path) {
    Write-Host "    ---- $Path 最后 $Lines 行 ----" -ForegroundColor Yellow
    Get-Content $Path -Tail $Lines | ForEach-Object { Write-Host "    $_" }
  }
}

# ---------------------------------------------------------------------------
# 1. 前置检查：命令和配置文件缺了就没必要往下走。
# ---------------------------------------------------------------------------
Write-Step '检查本机命令与配置文件'
foreach ($command in @('docker', 'node', 'npm')) {
  if (-not (Test-CommandExists $command)) {
    Stop-Startup "找不到 $command，请先安装并加入 PATH。"
  }
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Stop-Startup 'Docker 已安装但未运行(docker info 失败),请先启动 Docker Desktop。'
}
if (-not $ServerOnly -and -not (Test-CommandExists 'flutter')) {
  Stop-Startup '找不到 flutter，请先安装 Flutter SDK 并加入 PATH（或使用 -ServerOnly 只启动服务端）。'
}
if (-not (Test-Path (Join-Path $ServerDir '.env'))) {
  Stop-Startup "缺少 server/.env，请先执行：copy $ServerDir\.env.example $ServerDir\.env"
}
Write-Ready 'docker / node / npm 与 server/.env 均正常'

# ---------------------------------------------------------------------------
# 2. Docker 里的 PostgreSQL 与 MinIO(server/docker-compose.yml)。
# ---------------------------------------------------------------------------
Write-Step '启动 Docker 中的 PostgreSQL 与 MinIO'

Push-Location $ServerDir
try {
  docker compose up -d
  if ($LASTEXITCODE -ne 0) {
    Stop-Startup 'docker compose up -d 失败,请检查 server/docker-compose.yml 与 Docker 状态。'
  }
} finally {
  Pop-Location
}

# 等待 postgres 容器 healthcheck 变为 healthy(镜像自带 pg_isready 检查)。
function Wait-ContainerHealthy([string]$Name, [int]$TimeoutSeconds) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $status = docker inspect --format '{{.State.Health.Status}}' $Name 2>$null
    if ($status -eq 'healthy') {
      return $true
    }
    Start-Sleep -Seconds 2
  }
  return $false
}

if (-not (Wait-ContainerHealthy 'study-postgres' 60)) {
  docker logs --tail 20 study-postgres
  Stop-Startup "study-postgres 在 60 秒内未变为 healthy,上面是它的日志。可先执行 docker compose ps 看容器状态。"
}
Write-Ready "PostgreSQL(study-postgres) healthy,127.0.0.1:$DbPort 可连接"

# MinIO 没有自带 healthcheck,用 S3 端口探测;首次拉镜像/初始化可能要一会儿。
if (Test-TcpPort $StoragePort) {
  Write-Ready "MinIO S3 127.0.0.1:$StoragePort 已在运行"
} elseif (Wait-TcpPort $StoragePort 120) {
  Write-Ready "MinIO S3 127.0.0.1:$StoragePort 可连接"
} else {
  docker logs --tail 20 study-minio
  Stop-Startup "MinIO S3 端口 $StoragePort 在 120 秒内未就绪,上面是它的日志。素材上传/预签名地址都依赖它,必须修好再启动。"
}

# ---------------------------------------------------------------------------
# 3. 服务端依赖；数据库迁移只在 -Migrate 时执行（脚本可重复执行，已执行的 SQL 会跳过）。
# ---------------------------------------------------------------------------
Write-Step '检查服务端依赖'
if (-not (Test-Path (Join-Path $ServerDir 'node_modules'))) {
  npm --prefix $ServerDir install
  if ($LASTEXITCODE -ne 0) {
    Stop-Startup 'npm install 失败，请先解决依赖安装问题。'
  }
}
Write-Ready 'node_modules 已就绪'
if ($Migrate) {
  Write-Step '执行数据库迁移'
  $migrateTsx = Join-Path $ServerDir 'node_modules\tsx\dist\cli.mjs'
  node $migrateTsx 'src/scripts/migrate.ts'
  if ($LASTEXITCODE -ne 0) {
    Stop-Startup "数据库迁移失败（退出码 $LASTEXITCODE）。请检查 server/.env 的 DATABASE_URL、数据库权限，以及迁移 SQL 与现有表的依赖关系。"
  }
  Write-Ready '数据库迁移完成'
}

# ---------------------------------------------------------------------------
# 4. Fastify API：已经在跑就复用，否则后台启动并等健康检查。
# ---------------------------------------------------------------------------
Write-Step "启动 Fastify API（端口 $ApiPort）"
if (Test-ApiHealth) {
  Write-Ready 'API 已在运行，跳过后台启动'
} else {
  if (Test-TcpPort $ApiPort) {
    Stop-Startup "端口 $ApiPort 已被占用，但 /healthz 未通过。请先停掉占用该端口的旧进程，或检查它的日志。"
  }
  $tsxCli = Join-Path $ServerDir 'node_modules\tsx\dist\cli.mjs'
  if (-not (Test-Path $tsxCli)) {
    Stop-Startup "找不到 tsx（$tsxCli），请先执行：npm --prefix $ServerDir install"
  }
  $apiProcess = Start-Process -FilePath (Get-Command node).Source `
    -ArgumentList $tsxCli, 'watch', 'src/index.ts' `
    -WorkingDirectory $ServerDir -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $ApiLog -RedirectStandardError $ApiErrorLog
  Write-Host "    API 后台进程 PID=$($apiProcess.Id)，日志：$ApiLog"
  if (-not (Wait-ApiHealth 60)) {
    Show-LogTail $ApiLog
    Show-LogTail $ApiErrorLog
    Stop-Startup 'API 启动后 60 秒内健康检查仍未通过（/healthz 会同时检查数据库与对象存储）。'
  }
  Write-Ready "API $ApiHealthUrl 返回 200（数据库 + 对象存储均正常）"
}

# 再等几秒复查一次，排除「刚通过健康检查就退出」的情况。
Start-Sleep -Seconds 5
if (-not (Test-ApiHealth)) {
  Show-LogTail $ApiLog
  Show-LogTail $ApiErrorLog
  Stop-Startup 'API 复查失败，进程可能已退出（常见原因是数据库连接被中断）。'
}
Write-Ready 'API 稳定性复查通过'

# ---------------------------------------------------------------------------
# 5. Flutter 桌面应用：确认服务都好了才打开。
# ---------------------------------------------------------------------------
if ($ServerOnly) {
  Write-Step 'ServerOnly 模式：不启动 Flutter 应用'
} else {
  Write-Step '检查 Flutter 依赖'
  # flutter 会把提示信息写到 stderr，先关掉 Stop 策略，避免被当成致命错误。
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  Push-Location $AppDir
  try {
    # 收集输出，成功时不刷屏，失败时再打印，方便定位问题。
    $pubOutput = flutter pub get 2>&1
    $pubGetExitCode = $LASTEXITCODE
  } finally {
    Pop-Location
    $ErrorActionPreference = $previousPreference
  }
  if ($pubGetExitCode -ne 0) {
    $pubOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    Stop-Startup "flutter pub get 失败（退出码 $pubGetExitCode），请先解决 Flutter 依赖问题。"
  }
  Write-Ready 'Flutter 依赖已就绪'

  Write-Step '启动 Flutter Windows 应用'
  if (-not (Test-ApiHealth)) {
    Stop-Startup '打开应用前复查 API 健康检查未通过，已停止启动 Flutter。请先根据前面的步骤检查 PostgreSQL、MinIO 和 API。'
  }
  if (Get-Process study_app -ErrorAction SilentlyContinue) {
    Write-Ready 'study_app 已在运行，跳过重复启动'
  } else {
    $flutterWindow = Start-Process -FilePath 'powershell.exe' `
      -ArgumentList '-NoProfile', '-NoExit', '-Command', "Set-Location -LiteralPath '$AppDir'; flutter run -d windows" `
      -WorkingDirectory $AppDir -PassThru
    Write-Host "    Flutter 启动窗口 PID=$($flutterWindow.Id)，首次编译可能需要几分钟，该窗口支持 r 热重载 / R 热重启。"
    if (-not (Wait-AppProcess 300)) {
      Stop-Startup 'Flutter 启动后 300 秒内未检测到 study_app 进程，请查看新开的 PowerShell 窗口中的编译或运行错误。'
    }
    Write-Ready 'study_app 进程已启动，且打开应用前 API 健康检查已通过'
  }
}

Write-Host "`n全部启动完成：API http://127.0.0.1:$ApiPort ，数据库与对象存储健康检查通过。" -ForegroundColor Green

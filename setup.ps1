# ============================================================
#  MyMiniCloud – Tran Van Huy & Ho Huu Duc
#  Setup & Test Script (Windows PowerShell)
#  Chay bang: .\setup.ps1
# ============================================================

$Divider  = "=" * 65
$Divider2 = "-" * 65

function Write-Header($text) {
    Write-Host ""
    Write-Host $Divider  -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host $Divider  -ForegroundColor Cyan
}
function Write-Step($num,$text) { Write-Host "`n[$num] $text" -ForegroundColor Yellow }
function Write-OK($t)   { Write-Host "  [OK]  $t" -ForegroundColor Green }
function Write-FAIL($t) { Write-Host "  [FAIL] $t" -ForegroundColor Red }
function Write-INFO($t) { Write-Host "  [INFO] $t" -ForegroundColor Gray }

function Test-Http($url, $label) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 8
        Write-OK "$label → HTTP $($r.StatusCode)"
        return $true
    } catch {
        Write-FAIL "$label → $_"
        return $false
    }
}

function Test-HttpContent($url, $label) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 8
        $preview = $r.Content.Substring(0, [Math]::Min(100,$r.Content.Length))
        Write-OK "$label → $preview"
        return $true
    } catch {
        Write-FAIL "$label → $_"
        return $false
    }
}

# ═══════════════════════════════════════════════════════════
# 0. Kiem tra Docker
# ═══════════════════════════════════════════════════════════
Write-Header "0. KIEM TRA DOCKER"

try {
    $v = docker --version 2>&1
    Write-OK "Docker: $v"
} catch {
    Write-FAIL "Docker chua duoc cai dat!"
    Write-INFO "Tai ve tai: https://www.docker.com/products/docker-desktop/"
    exit 1
}

try {
    docker info 2>&1 | Out-Null
    Write-OK "Docker Engine dang chay"
} catch {
    Write-FAIL "Docker Engine chua chay. Hay mo Docker Desktop truoc!"
    exit 1
}

# ═══════════════════════════════════════════════════════════
# 1. Don dep container cu
# ═══════════════════════════════════════════════════════════
Write-Header "1. DON DEP CONTAINER CU"

$containers = @(
    "web-frontend-server","web-frontend-server2",
    "application-backend-server","relational-database-server",
    "authentication-identity-server","object-storage-server",
    "internal-dns-server","monitoring-node-exporter-server",
    "monitoring-prometheus-server","monitoring-grafana-dashboard-server",
    "api-gateway-proxy-server"
)
foreach ($c in $containers) {
    docker rm -f $c 2>&1 | Out-Null
}
Write-OK "Da xoa het container cu cua du an"

# ═══════════════════════════════════════════════════════════
# 2. Build & Start
# ═══════════════════════════════════════════════════════════
Write-Header "2. BUILD & KHOI DONG HE THONG"

Write-Step "2.1" "Build image (co the mat 5-10 phut lan dau)..."
docker compose build --no-cache
if ($LASTEXITCODE -ne 0) { Write-FAIL "Build that bai!"; exit 1 }
Write-OK "Build thanh cong"

Write-Step "2.2" "Khoi dong tat ca container..."
docker compose up -d
if ($LASTEXITCODE -ne 0) { Write-FAIL "docker compose up that bai!"; exit 1 }
Write-OK "Tat ca container da khoi dong"

Write-Step "2.3" "Cho 20 giay de cac service san sang..."
for ($i = 20; $i -gt 0; $i--) {
    Write-Host "  Cho $i giay..." -NoNewline -ForegroundColor Gray
    Start-Sleep -Seconds 1
    Write-Host "`r" -NoNewline
}

Write-Step "2.4" "Trang thai container:"
docker compose ps

# ═══════════════════════════════════════════════════════════
# 3. Kiem thu 9 Server (5 diem co ban)
# ═══════════════════════════════════════════════════════════
Write-Header "3. KIEM THU 9 SERVER (5 DIEM CO BAN)"

# 1. Web Frontend Server 1
Write-Step "1/9" "Web Frontend Server 1 (port 8080) – Nginx"
Test-Http "http://localhost:8080/"       "Trang chu (Server 1)"
Test-Http "http://localhost:8080/blog/"  "Blog index (Server 1)"

# 1b. Web Frontend Server 2
Write-Step "1b" "Web Frontend Server 2 (port 8082) – Nginx Round Robin"
Test-Http "http://localhost:8082/"       "Trang chu (Server 2)"
Test-Http "http://localhost:8082/blog/"  "Blog index (Server 2)"

# 2. App Server
Write-Step "2/9" "Application Backend Server (port 8085) – Flask"
Test-HttpContent "http://localhost:8085/hello"    "/hello API"
Test-HttpContent "http://localhost/api/hello"     "/api/hello (qua proxy)"

# 3. Database
Write-Step "3/9" "Relational Database Server – MariaDB (port 3306)"
$db1 = docker exec relational-database-server mariadb -uroot -proot minicloud -e "SELECT * FROM notes;" 2>&1
if ($db1 -match "Hello from MariaDB") {
    Write-OK "minicloud.notes → co du lieu: OK"
} else {
    Write-FAIL "Khong the truy van minicloud.notes: $db1"
}
$db2 = docker exec relational-database-server mariadb -uroot -proot studentdb -e "SELECT * FROM students;" 2>&1
if ($db2 -match "SV001") {
    Write-OK "studentdb.students → co du lieu: OK"
} else {
    Write-FAIL "Khong the truy van studentdb.students: $db2"
}

# 4. Auth Server (Keycloak)
Write-Step "4/9" "Authentication Identity Server – Keycloak (port 8081)"
Write-INFO "Keycloak can 60-90 giay de khoi dong day du..."
try {
    $r = Invoke-WebRequest -Uri "http://localhost:8081" -UseBasicParsing -TimeoutSec 15
    Write-OK "Keycloak dang chay → HTTP $($r.StatusCode)"
    Write-INFO "  Mo trinh duyet: http://localhost:8081 | dang nhap: admin / admin"
} catch {
    Write-INFO "Keycloak chua san sang (co the can them thoi gian) → $_"
}

# 5. Object Storage (MinIO)
Write-Step "5/9" "Object Storage Server – MinIO (port 9000/9001)"
Test-Http "http://localhost:9001" "MinIO Console"
Write-INFO "  Dang nhap: minioadmin / minioadmin"

# 6. DNS Server
Write-Step "6/9" "Internal DNS Server – Bind9 (port 1053/UDP)"
$dns = docker exec internal-dns-server nslookup web-frontend-server.cloud.local 127.0.0.1 2>&1
if ($dns -match "10.10.10.10") {
    Write-OK "DNS phan giai web-frontend-server.cloud.local → 10.10.10.10"
} else {
    Write-INFO "DNS result: $dns"
}
$dns2 = docker exec internal-dns-server nslookup minio.cloud.local 127.0.0.1 2>&1
if ($dns2 -match "10.10.10.50") {
    Write-OK "DNS phan giai minio.cloud.local → 10.10.10.50"
} else {
    Write-INFO "minio DNS: $dns2"
}

# 7. Prometheus
Write-Step "7/9" "Monitoring Prometheus (port 9090)"
Test-Http "http://localhost:9090" "Prometheus UI"
Write-INFO "  Kiem tra Targets: http://localhost:9090/targets"

# 8. Grafana
Write-Step "8/9" "Monitoring Grafana Dashboard (port 3000)"
Test-Http "http://localhost:3000" "Grafana UI"
Write-INFO "  Dang nhap: admin / admin"

# 9. API Gateway / Reverse Proxy
Write-Step "9/9" "API Gateway Proxy Server – Nginx (port 80)"
Test-Http     "http://localhost/"          "/ → Web (Round Robin)"
Test-HttpContent "http://localhost/api/hello" "/api/hello → App"
Write-INFO "Load Balancing: Truy cap http://localhost/ nhieu lan, xem server xen ke"

# ═══════════════════════════════════════════════════════════
# 4. Kiem thu phan Mo rong (5 diem)
# ═══════════════════════════════════════════════════════════
Write-Header "4. KIEM THU MO RONG (5 DIEM)"

# EXT 1: Blog 3 bai viet
Write-Step "EXT-1" "Web: Blog ca nhan 3 bai viet"
foreach ($b in @("blog1.html","blog2.html","blog3.html")) {
    Test-Http "http://localhost:8080/blog/$b" "  /blog/$b"
}

# EXT 2: /student API tu JSON
Write-Step "EXT-2" "App: API /student (doc tu students.json)"
Test-HttpContent "http://localhost:8085/student"      "/student JSON"
Test-Http        "http://localhost:8085/student/view" "/student HTML template"

# EXT 3: /students-db tu MariaDB
Write-Step "EXT-3" "DB: API /students-db (doc tu MariaDB studentdb)"
Test-HttpContent "http://localhost:8085/students-db"      "/students-db JSON"
Test-Http        "http://localhost:8085/students-db/view" "/students-db HTML template"

# EXT 4: Keycloak Realm (chi mo browser, khong tu dong)
Write-Step "EXT-4" "Auth: Keycloak – Tao Realm + client + user"
Write-INFO "  Thuc hien thu cong:"
Write-INFO "  1. Mo http://localhost:8081 → admin/admin"
Write-INFO "  2. Tao Realm moi ten 'realm_sv001'"
Write-INFO "  3. Tao user sv01, sv02"
Write-INFO "  4. Tao client 'flask-app' (Access Type: public)"

# EXT 5: MinIO upload
Write-Step "EXT-5" "Storage: MinIO – Tao bucket va upload file"
Write-INFO "  1. Mo http://localhost:9001 → minioadmin/minioadmin"
Write-INFO "  2. Tao bucket 'profile-pics' va 'documents'"
Write-INFO "  3. Upload avatar.jpg va file PDF bao cao"

# EXT 6: DNS mo rong
Write-Step "EXT-6" "DNS: Ban ghi mo rong (minio, keycloak, app-backend)"
$dns3 = docker exec internal-dns-server nslookup keycloak.cloud.local 127.0.0.1 2>&1
if ($dns3 -match "10.10.10.40") { Write-OK "keycloak.cloud.local → 10.10.10.40" }
else { Write-INFO "keycloak DNS: $dns3" }
$dns4 = docker exec internal-dns-server nslookup grafana.cloud.local 127.0.0.1 2>&1
if ($dns4 -match "10.10.10.80") { Write-OK "grafana.cloud.local → 10.10.10.80" }
else { Write-INFO "grafana DNS: $dns4" }

# EXT 7: Prometheus scrape web
Write-Step "EXT-7" "Prometheus: Scrape target web-frontend-server"
Write-INFO "  Kiem tra tai: http://localhost:9090/targets"
Write-INFO "  Tim job 'web' → web-frontend-server:80"

# EXT 8: Grafana Dashboard
Write-Step "EXT-8" "Grafana: Dashboard System Health"
Write-INFO "  1. Mo http://localhost:3000 → admin/admin"
Write-INFO "  2. Add datasource: Prometheus → http://monitoring-prometheus-server:9090"
Write-INFO "  3. Import dashboard ID 1860 (Node Exporter Full)"
Write-INFO "  4. Tao dashboard ca nhan: CPU, Memory, Network"

# EXT 9: Route /student/ qua proxy
Write-Step "EXT-9" "Proxy: Route /student/ → backend"
Test-HttpContent "http://localhost/student/"          "/student/ qua proxy"
Test-Http        "http://localhost:8085/student/view" "/student/view HTML"

# EXT 10: Load Balancer Round Robin
Write-Step "EXT-10" "Load Balancer: Round Robin giua 2 Web Server"
Write-INFO "  Gui 6 request den http://localhost/ va quan sat luot phien:"
for ($i = 1; $i -le 6; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing -TimeoutSec 5
        $server = if ($r.Content -match "Server 2") { "Server 2 (Do)" } else { "Server 1 (Xanh)" }
        Write-OK "  Request $i → $server"
    } catch {
        Write-FAIL "  Request $i → $_"
    }
}

# ═══════════════════════════════════════════════════════════
# 5. Ping mang noi bo
# ═══════════════════════════════════════════════════════════
Write-Header "5. PING MANG NOI BO (cloud-net)"

$pingTargets = @(
    "web-frontend-server",
    "web-frontend-server2",
    "application-backend-server",
    "relational-database-server",
    "authentication-identity-server",
    "object-storage-server",
    "monitoring-prometheus-server",
    "monitoring-grafana-dashboard-server",
    "internal-dns-server"
)
foreach ($t in $pingTargets) {
    $result = docker exec api-gateway-proxy-server ping -c 1 -W 2 $t 2>&1
    if ($result -match "1 received" -or $result -match "bytes from") {
        Write-OK "Ping $t → THONG MANG"
    } else {
        Write-FAIL "Ping $t → THAT BAI"
    }
}

# ═══════════════════════════════════════════════════════════
# 6. Mo tat ca dashboard
# ═══════════════════════════════════════════════════════════
Write-Header "6. MO DASHBOARD TRONG TRINH DUYET"
Write-INFO "Dang mo cac URL..."
Start-Sleep -Seconds 1
Start-Process "http://localhost:8080"       # Web Server 1
Start-Process "http://localhost:8082"       # Web Server 2
Start-Process "http://localhost:8081"       # Keycloak
Start-Process "http://localhost:9001"       # MinIO
Start-Process "http://localhost:9090/targets" # Prometheus Targets
Start-Process "http://localhost:3000"       # Grafana
Write-OK "Da mo 6 tab trinh duyet"

# ═══════════════════════════════════════════════════════════
# 7. Tong ket
# ═══════════════════════════════════════════════════════════
Write-Header "TONG KET – BANG LINK TRUY CAP"
Write-Host ""
Write-Host "  Dich vu                       URL                              Ghi chu" -ForegroundColor White
Write-Host "  $Divider2" -ForegroundColor DarkGray
Write-Host "  Web Frontend Server 1         http://localhost:8080            Xanh duong" -ForegroundColor Green
Write-Host "  Web Frontend Server 2         http://localhost:8082            Do" -ForegroundColor Green
Write-Host "  App Server /hello             http://localhost:8085/hello" -ForegroundColor Green
Write-Host "  App Server /student           http://localhost:8085/student    JSON" -ForegroundColor Green
Write-Host "  App Server /student/view      http://localhost:8085/student/view  HTML" -ForegroundColor Green
Write-Host "  App Server /students-db       http://localhost:8085/students-db   JSON" -ForegroundColor Green
Write-Host "  App Server /students-db/view  http://localhost:8085/students-db/view" -ForegroundColor Green
Write-Host "  Auth (Keycloak)               http://localhost:8081            admin/admin" -ForegroundColor Green
Write-Host "  MinIO Console                 http://localhost:9001            minioadmin/minioadmin" -ForegroundColor Green
Write-Host "  Prometheus                    http://localhost:9090" -ForegroundColor Green
Write-Host "  Prometheus Targets            http://localhost:9090/targets" -ForegroundColor Green
Write-Host "  Grafana                       http://localhost:3000            admin/admin" -ForegroundColor Green
Write-Host "  Reverse Proxy                 http://localhost                 Round Robin" -ForegroundColor Green
Write-Host "  Proxy /api/hello              http://localhost/api/hello" -ForegroundColor Green
Write-Host "  Proxy /student/               http://localhost/student/" -ForegroundColor Green
Write-Host ""
Write-Host "  Lenh huu ich:" -ForegroundColor Yellow
Write-Host "    docker compose logs -f <ten-service>   # Xem log realtime" -ForegroundColor Gray
Write-Host "    docker compose restart <service>        # Restart mot service" -ForegroundColor Gray
Write-Host "    docker compose down                     # Dung he thong (giu data)" -ForegroundColor Gray
Write-Host "    docker compose down -v                  # Dung va xoa data" -ForegroundColor Gray
Write-Host ""
Write-Host $Divider -ForegroundColor Cyan
Write-Host "  TranVanHuy_HoHuuDuc_miniclouddemo – SAN SANG!" -ForegroundColor Cyan
Write-Host $Divider -ForegroundColor Cyan

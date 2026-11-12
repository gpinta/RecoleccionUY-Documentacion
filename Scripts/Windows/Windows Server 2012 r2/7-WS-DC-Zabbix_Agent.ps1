#requires -version 4.0

<#
.SYNOPSIS
    Instala y configura Zabbix Agent 7.0 en los controladores de dominio.

.DESCRIPCION
    Configura el agente clasico Zabbix en Windows Server 2012 R2,
    firewall local TCP/10050, auditoria de eventos y exportacion
    YAML para importar manualmente en Zabbix 7.0.

    Conserva instalaciones existentes del agente y no modifica
    AD, LDAP, DNS, DHCP, GPO ni las politicas de cuentas.

.REQUISITOS
    - Windows Server 2012 R2 x64.
    - PowerShell 4.0 o superior, ejecutado como Administrador.
    - MSI oficial Zabbix Agent 7.0.32 descargado manualmente
      y verificado (solo para una instalacion nueva).
    - RL-MON-01 disponible en 192.168.20.20.

.NOTAS
    Configurar las variables de la seccion 1, sin parametros externos.
    Ejecutar por separado en WS-DC-01 y WS-DC-02.
    El YAML se importa manualmente mediante Zabbix Web.
    La auditoria local puede ser reemplazada por GPO.
    El acceso al puerto 10050 debe comprobarse desde RL-MON-01.
#>

$ErrorActionPreference = 'Stop'


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

# Modificar estas variables si cambian las rutas o IP del proyecto.
$AgentHostname = $env:COMPUTERNAME
$MsiPath = 'C:\Temp\zabbix_agent-7.0.32-windows-amd64-openssl.msi'
$ZabbixServer = '192.168.20.20'

$ExpectedHash = 'A50CB30F367868260BB849CC597D460473938B4719F1D41956B9C5CD781778DC'

$ExpectedIPs = @{
    'WS-DC-01' = '192.168.10.20'
    'WS-DC-02' = '192.168.10.21'
}

$ExpectedIP = $ExpectedIPs[$AgentHostname]

$RuleName = 'RecoleccionUY Zabbix Agent 10050 - Monitor Only'
$ServiceName = 'Zabbix Agent'
$ConfigPath = 'C:\Program Files\Zabbix Agent\zabbix_agentd.conf'

$OutDir = Join-Path -Path $env:ProgramData -ChildPath 'RecoleccionUY-Zabbix'
$ExportPath = Join-Path -Path $OutDir -ChildPath ($AgentHostname + '-zabbix-import.yaml')


# ============================================================
# 2. FUNCIONES AUXILIARES
# ============================================================

function Stop-Fail {
    param([string]$Message)
    throw $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host ('[INFO] ' + $Message)
}

function Write-Ok {
    param([string]$Message)
    Write-Host ('[OK] ' + $Message)
}

function Test-ValidIPv4 {
    param([string]$IPAddress)

    $Parsed = $null

    if ($IPAddress -notmatch '^([0-9]{1,3}\.){3}[0-9]{1,3}$') {
        return $false
    }

    if (-not [System.Net.IPAddress]::TryParse($IPAddress, [ref]$Parsed)) {
        return $false
    }

    return ($Parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork)
}


# ============================================================
# 3. VERIFICAR SERVIDOR Y REQUISITOS
# ============================================================

function Assert-Environment {
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)

    if (-not $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Stop-Fail 'Ejecutar PowerShell como Administrador.'
    }

    if ($env:COMPUTERNAME -ine $AgentHostname) {
        Stop-Fail ('El servidor real es ' + $env:COMPUTERNAME + ' y no ' + $AgentHostname)
    }

    $OperatingSystem = Get-WmiObject -Class Win32_OperatingSystem

    if ($OperatingSystem.Version -notlike '6.3.*' -or $OperatingSystem.ProductType -eq 1) {
        Stop-Fail ('Se requiere Windows Server 2012 R2. Detectado: ' + $OperatingSystem.Caption)
    }

    if (-not [Environment]::Is64BitOperatingSystem) {
        Stop-Fail 'El MSI requiere Windows x64.'
    }

    if (-not (Test-ValidIPv4 -IPAddress $ZabbixServer)) {
        Stop-Fail ('ZabbixServer no es una IPv4 valida: ' + $ZabbixServer)
    }

    if (-not (Get-NetIPAddress -AddressFamily IPv4 -IPAddress $ExpectedIP -ErrorAction SilentlyContinue)) {
        Stop-Fail ('IP esperada no asignada a este controlador: ' + $ExpectedIP)
    }

    if (Get-Service -Name 'Zabbix Agent 2' -ErrorAction SilentlyContinue) {
        Stop-Fail 'Existe Zabbix Agent 2; revisar instalacion antes de continuar.'
    }

    if (-not (Test-Path -LiteralPath $OutDir -PathType Container)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }

    Write-Ok ('Servidor validado: ' + $AgentHostname + ' (' + $ExpectedIP + ')')
}


# ============================================================
# 4. INSTALAR AGENTE SI NO EXISTE
# ============================================================

function Install-AgentIfRequired {
    $Existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($Existing) {
        Write-Info 'Zabbix Agent existente: no se modifica ni actualiza el MSI.'
        return
    }

    if (-not (Test-Path -LiteralPath $MsiPath -PathType Leaf)) {
        Stop-Fail ('No existe el MSI descargado manualmente: ' + $MsiPath)
    }

    if ([IO.Path]::GetFileName($MsiPath) -cne 'zabbix_agent-7.0.32-windows-amd64-openssl.msi') {
        Stop-Fail 'El nombre del MSI no corresponde a la version autorizada.'
    }

    if ((Get-FileHash -LiteralPath $MsiPath -Algorithm SHA256).Hash -ine $ExpectedHash) {
        Stop-Fail 'No coincide el SHA-256 del MSI.'
    }

    if ((Get-AuthenticodeSignature -FilePath $MsiPath).Status -ne 'Valid') {
        Stop-Fail 'La firma digital del MSI no es valida.'
    }

    $LogPath = Join-Path $OutDir 'zabbix-agent-msi.log'
    $ResolvedMsi = (Resolve-Path -LiteralPath $MsiPath).Path

    $Arguments = @(
        '/i',
        ('"' + $ResolvedMsi + '"'),
        '/qn',
        '/norestart',
        ('SERVER=' + $ZabbixServer),
        ('SERVERACTIVE=' + $ZabbixServer),
        ('HOSTNAME=' + $AgentHostname),
        'LISTENPORT=10050',
        'SKIP=fw',
        '/l*v',
        ('"' + $LogPath + '"')
    )

    $Result = Start-Process `
        -FilePath "$env:windir\System32\msiexec.exe" `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru

    if ($Result.ExitCode -notin @(0, 3010)) {
        Stop-Fail ('Instalacion MSI fallida: ' + $Result.ExitCode + '. Log: ' + $LogPath)
    }

    if ($Result.ExitCode -eq 3010) {
        Write-Warning 'El MSI solicita reinicio. Coordinar mantenimiento del controlador.'
    }

    Write-Ok 'Zabbix Agent instalado correctamente.'
}


# ============================================================
# 5. CONFIGURAR AGENTE Y SERVICIO
# ============================================================

function Set-AgentConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        Stop-Fail ('No existe ' + $ConfigPath + '. Revisar instalacion existente.')
    }

    $Content = [IO.File]::ReadAllText($ConfigPath)
    $Updated = $Content

    foreach ($Entry in @(
        @('Server', $ZabbixServer),
        @('ServerActive', $ZabbixServer),
        @('Hostname', $AgentHostname)
    )) {
        $Key = $Entry[0]
        $Value = $Entry[1]

        $Pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=.*(?:\r?\n|$)'

        # Consolidar duplicados activos sin alterar otras directivas.
        $Updated = [regex]::Replace($Updated, $Pattern, '')
        $Updated = $Updated.TrimEnd([char[]]"`r`n") + "`r`n" + $Key + '=' + $Value + "`r`n"
    }

    if ($Content -cne $Updated) {
        $Backup = Join-Path $OutDir ('zabbix_agentd.conf.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak')

        Copy-Item -LiteralPath $ConfigPath -Destination $Backup -ErrorAction Stop
        [IO.File]::WriteAllText(
            $ConfigPath,
            $Updated,
            (New-Object System.Text.ASCIIEncoding)
        )

        Write-Ok ('Configuracion actualizada. Respaldo: ' + $Backup)
        return $true
    }

    Write-Info 'Configuracion del agente sin cambios.'
    return $false
}

function Start-OrRestartAgent {
    param([bool]$Changed)

    $Agent = Get-Service -Name $ServiceName -ErrorAction Stop

    if ($Changed -and $Agent.Status -eq 'Running') {
        Restart-Service -Name $ServiceName -ErrorAction Stop
    }
    elseif ($Agent.Status -ne 'Running') {
        Start-Service -Name $ServiceName -ErrorAction Stop
    }

    $Agent = Get-Service -Name $ServiceName -ErrorAction Stop

    if ($Agent.Status -ne 'Running') {
        Stop-Fail 'El servicio de Zabbix Agent no ha iniciado correctamente.'
    }

    Write-Ok 'Servicio Zabbix Agent en ejecucion.'
}


# ============================================================
# 6. CONFIGURAR FIREWALL LOCAL
# ============================================================

function Ensure-AgentFirewall {
    $Rules = @(Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)

    if ($Rules.Count -gt 1) {
        Stop-Fail 'Existen reglas duplicadas con el mismo nombre. Revisar manualmente.'
    }

    if ($Rules.Count -eq 0) {
        New-NetFirewallRule `
            -DisplayName $RuleName `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 10050 `
            -RemoteAddress $ZabbixServer `
            -Profile Any `
            -Action Allow `
            -Enabled True | Out-Null

        Write-Ok 'Regla firewall TCP/10050 creada para RL-MON-01.'
        return
    }

    $Rule = $Rules[0]
    $AddressFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $Rule
    $PortFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $Rule

    if (
        $Rule.Enabled -ne 'True' -or
        $Rule.Direction -ne 'Inbound' -or
        $Rule.Action -ne 'Allow' -or
        $PortFilter.Protocol -ne 'TCP' -or
        @($PortFilter.LocalPort).Count -ne 1 -or
        @($PortFilter.LocalPort)[0] -ne '10050' -or
        @($AddressFilter.RemoteAddress).Count -ne 1 -or
        @($AddressFilter.RemoteAddress)[0] -ne $ZabbixServer
    ) {
        Stop-Fail 'La regla existente es incompatible; no se sobrescribe.'
    }

    Write-Ok 'Regla existente de Zabbix verificada.'
}


# ============================================================
# 7. CONFIGURAR AUDITORIA WINDOWS
# ============================================================

function Enable-RequiredAudit {
    # GUIDs de subcategorias independientes del idioma.
    $Subcategories = @(
        @('{0CCE9215-69AE-11D9-BED3-505054503030}', 'Logon', '/failure:enable'),
        @('{0CCE9217-69AE-11D9-BED3-505054503030}', 'Account Lockout', '/success:enable'),
        @('{0CCE9235-69AE-11D9-BED3-505054503030}', 'User Account Management', '/success:enable'),
        @('{0CCE9242-69AE-11D9-BED3-505054503030}', 'Kerberos Authentication Service', '/failure:enable')
    )

    foreach ($Subcategory in $Subcategories) {
        $Arguments = @('/set', ('/subcategory:' + $Subcategory[0]), $Subcategory[2])
        & auditpol.exe @Arguments | Out-Host

        if ($LASTEXITCODE -ne 0) {
            Stop-Fail ('No se pudo configurar auditoria: ' + $Subcategory[1])
        }
    }

    Write-Ok 'Subcategorias de auditoria configuradas.'
    Write-Warning 'Una GPO del dominio puede reemplazar la auditoria local.'
}


# ============================================================
# 8. EXPORTAR CONFIGURACION PARA ZABBIX 7.0
# ============================================================

function Export-EmbeddedYaml {
    # Esta exportacion es solo un archivo local; no importa hosts.
    $Yaml = @'
zabbix_export:
  version: '7.0'
  host_groups:
  - uuid: d1ea627b4ee04333b84290bb7f9b50a2
    name: Recolección UY / Windows
  hosts:
  - host: __HOST__
    name: __HOST__
    templates:
    - name: Windows by Zabbix agent
    groups:
    - name: Recolección UY / Windows
    interfaces:
    - ip: __IP__
      interface_ref: if1
    items:
    - name: Windows - Eventos Seguridad y cuentas
      type: ZABBIX_ACTIVE
      key: eventlog[Security,,,,^(4625|4740|4771|4720|4726)$,30,skip]
      delay: 30s
      history: 14d
      value_type: LOG
      trends: '0'
      triggers:
      - expression: logeventid(/__HOST__/eventlog[Security,,,,^(4625|4740|4771|4720|4726)$,30,skip],,"^4740$")=1
        recovery_mode: NONE
        name: Windows Security - Evento 4740
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[Security,,,,^(4625|4740|4771|4720|4726)$,30,skip],,"^4720$")=1
        recovery_mode: NONE
        name: Windows Security - Evento 4720
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[Security,,,,^(4625|4740|4771|4720|4726)$,30,skip],,"^4726$")=1
        recovery_mode: NONE
        name: Windows Security - Evento 4726
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
    - name: Windows - Eventos Hardware, disco y reinicios
      type: ZABBIX_ACTIVE
      key: eventlog[System,,,,^(7|11|51|153|41|6008)$,30,skip]
      delay: 30s
      history: 14d
      value_type: LOG
      trends: '0'
      triggers:
      - expression: logeventid(/__HOST__/eventlog[System,,,,^(7|11|51|153|41|6008)$,30,skip],,"^7$")=1
        recovery_mode: NONE
        name: Windows System - Evento 7
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[System,,,,^(7|11|51|153|41|6008)$,30,skip],,"^11$")=1
        recovery_mode: NONE
        name: Windows System - Evento 11
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[System,,,,^(7|11|51|153|41|6008)$,30,skip],,"^51$")=1
        recovery_mode: NONE
        name: Windows System - Evento 51
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[System,,,,^(7|11|51|153|41|6008)$,30,skip],,"^153$")=1
        recovery_mode: NONE
        name: Windows System - Evento 153
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[System,,,,^(7|11|51|153|41|6008)$,30,skip],,"^41$")=1
        recovery_mode: NONE
        name: Windows System - Evento 41
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[System,,,,^(7|11|51|153|41|6008)$,30,skip],,"^6008$")=1
        recovery_mode: NONE
        name: Windows System - Evento 6008
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
    - name: Windows - Eventos AD DS y replicacion
      type: ZABBIX_ACTIVE
      key: eventlog[Directory Service,,,,^(1863|1083|1311|1865|1925|1988|2042)$,30,skip]
      delay: 30s
      history: 14d
      value_type: LOG
      trends: '0'
      triggers:
      - expression: logeventid(/__HOST__/eventlog[Directory Service,,,,^(1863|1083|1311|1865|1925|1988|2042)$,30,skip],,"^1863$")=1
        recovery_mode: NONE
        name: Windows Directory Service - Evento 1863
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[Directory Service,,,,^(1863|1083|1311|1865|1925|1988|2042)$,30,skip],,"^1083$")=1
        recovery_mode: NONE
        name: Windows Directory Service - Evento 1083
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[Directory Service,,,,^(1863|1083|1311|1865|1925|1988|2042)$,30,skip],,"^1311$")=1
        recovery_mode: NONE
        name: Windows Directory Service - Evento 1311
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[Directory Service,,,,^(1863|1083|1311|1865|1925|1988|2042)$,30,skip],,"^1865$")=1
        recovery_mode: NONE
        name: Windows Directory Service - Evento 1865
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[Directory Service,,,,^(1863|1083|1311|1865|1925|1988|2042)$,30,skip],,"^1925$")=1
        recovery_mode: NONE
        name: Windows Directory Service - Evento 1925
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[Directory Service,,,,^(1863|1083|1311|1865|1925|1988|2042)$,30,skip],,"^1988$")=1
        recovery_mode: NONE
        name: Windows Directory Service - Evento 1988
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[Directory Service,,,,^(1863|1083|1311|1865|1925|1988|2042)$,30,skip],,"^2042$")=1
        recovery_mode: NONE
        name: Windows Directory Service - Evento 2042
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
    - name: Windows - Eventos DNS Server
      type: ZABBIX_ACTIVE
      key: eventlog[DNS Server,,,,^(4013|4000|4004|4015)$,30,skip]
      delay: 30s
      history: 14d
      value_type: LOG
      trends: '0'
      triggers:
      - expression: logeventid(/__HOST__/eventlog[DNS Server,,,,^(4013|4000|4004|4015)$,30,skip],,"^4013$")=1
        recovery_mode: NONE
        name: Windows DNS Server - Evento 4013
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[DNS Server,,,,^(4013|4000|4004|4015)$,30,skip],,"^4000$")=1
        recovery_mode: NONE
        name: Windows DNS Server - Evento 4000
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[DNS Server,,,,^(4013|4000|4004|4015)$,30,skip],,"^4004$")=1
        recovery_mode: NONE
        name: Windows DNS Server - Evento 4004
        priority: WARNING
        type: MULTIPLE
        manual_close: 'YES'
      - expression: logeventid(/__HOST__/eventlog[DNS Server,,,,^(4013|4000|4004|4015)$,30,skip],,"^4015$")=1
        recovery_mode: NONE
        name: Windows DNS Server - Evento 4015
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
    - name: Windows - Eventos DFSR SYSVOL
      type: ZABBIX_ACTIVE
      key: eventlog[DFS Replication,,,,^(2213)$,30,skip]
      delay: 30s
      history: 14d
      value_type: LOG
      trends: '0'
      triggers:
      - expression: logeventid(/__HOST__/eventlog[DFS Replication,,,,^(2213)$,30,skip],,"^2213$")=1
        recovery_mode: NONE
        name: Windows DFS Replication - Evento 2213
        priority: HIGH
        type: MULTIPLE
        manual_close: 'YES'
    inventory_mode: DISABLED

'@

    $Yaml = $Yaml.Replace('__HOST__', $AgentHostname).Replace('__IP__', $ExpectedIP)

    [IO.File]::WriteAllText(
        $ExportPath,
        $Yaml,
        (New-Object System.Text.UTF8Encoding($false))
    )

    Write-Ok ('YAML creado: ' + $ExportPath)
    Write-Warning 'Importar manualmente en Zabbix Web y revisar hosts existentes.'
}


# ============================================================
# 9. VERIFICACION FINAL
# ============================================================

function Confirm-Agent {
    $Agent = Get-Service -Name $ServiceName -ErrorAction Stop

    if ($Agent.Status -ne 'Running') {
        Stop-Fail 'Zabbix Agent no esta en ejecucion.'
    }

    $Listener = Get-NetTCPConnection `
        -State Listen `
        -LocalPort 10050 `
        -ErrorAction SilentlyContinue

    if (-not $Listener) {
        Write-Warning 'No se detecto escucha TCP/10050.'
    }

    $Connected = Test-NetConnection `
        -ComputerName $ZabbixServer `
        -Port 10051 `
        -InformationLevel Quiet `
        -WarningAction SilentlyContinue

    if (-not $Connected) {
        Write-Warning 'No se establecio conexion hacia Zabbix TCP/10051.'
    }

    Write-Ok ('Agente verificado en ' + $AgentHostname)
    Write-Info ('Archivo YAML: ' + $ExportPath)
}


# ============================================================
# 10. EJECUCION PRINCIPAL
# ============================================================

try {
    Assert-Environment
    Install-AgentIfRequired

    $Changed = Set-AgentConfig
    Start-OrRestartAgent -Changed $Changed

    Ensure-AgentFirewall
    Enable-RequiredAudit
    Export-EmbeddedYaml
    Confirm-Agent

    Write-Ok 'Proceso finalizado. Importar YAML manualmente en Zabbix Web.'
}
catch {
    Write-Error ('[ERROR] ' + $_.Exception.Message)
    exit 1
}

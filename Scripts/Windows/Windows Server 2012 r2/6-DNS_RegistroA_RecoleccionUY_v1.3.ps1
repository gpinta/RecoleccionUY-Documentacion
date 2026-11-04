<#
.SYNOPSIS
    Creacion y actualizacion de registros DNS A para Recoleccion UY.

.DESCRIPCION
    Verifica la existencia de la zona DNS configurada y crea o actualiza
    los registros A necesarios para Recoleccion UY.

    Registros administrados:

      recoleccion.neltek.uy
      admin-recoleccion.neltek.uy
      camiones-recoleccion.neltek.uy

    Los tres apuntan al proxy RL-PROXY-01 configurado en $ProxyServerIP.

.REQUISITOS
    - Ejecutar como Administrador.
    - Rol DNS Server instalado.
    - Modulo DnsServer disponible.
    - Zona DNS neltek.uy existente.

.NOTAS
    Compatible con Windows Server 2012 R2.
#>


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

$ZoneName = "neltek.uy"

$ProxyServerIP = "192.168.50.20"


$Records = @(
    @{
        Name = "recoleccion"
        IP   = $ProxyServerIP
    },
    @{
        Name = "admin-recoleccion"
        IP   = $ProxyServerIP
    },
    @{
        Name = "camiones-recoleccion"
        IP   = $ProxyServerIP
    }
)


# ============================================================
# 2. INICIO
# ============================================================

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Recoleccion UY - Configuracion DNS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Zona DNS      : $ZoneName"
Write-Host "Servidor Proxy: $ProxyServerIP"

Write-Host ""


# ============================================================
# 3. VERIFICAR EJECUCION COMO ADMINISTRADOR
# ============================================================

try {

    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        $CurrentIdentity
    )

    $IsAdministrator = $CurrentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $IsAdministrator) {

        Write-Host "[ERROR] El script debe ejecutarse como Administrador." -ForegroundColor Red
        exit 1
    }

    Write-Host "[OK] PowerShell ejecutado como Administrador." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible verificar los privilegios administrativos." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 4. CARGAR MODULO DNS SERVER
# ============================================================

try {

    Import-Module DnsServer -ErrorAction Stop

    Write-Host "[OK] Modulo DnsServer cargado." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible cargar el modulo DnsServer." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 5. VERIFICAR ZONA DNS
# ============================================================

Write-Host ""
Write-Host "----- Verificacion de zona DNS -----" -ForegroundColor Cyan

try {

    $ZoneParameters = @{
        Name        = $ZoneName
        ErrorAction = "Stop"
    }

    $Zone = Get-DnsServerZone @ZoneParameters

    Write-Host "[OK] Zona encontrada: $ZoneName" -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No existe o no se puede consultar la zona DNS: $ZoneName" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 6. CREAR / ACTUALIZAR REGISTROS DNS A
# ============================================================

Write-Host ""
Write-Host "----- Registros DNS A -----" -ForegroundColor Cyan


foreach ($Record in $Records) {

    $Name = $Record.Name
    $IP   = $Record.IP

    Write-Host ""
    Write-Host "Procesando: $Name.$ZoneName"


    # --------------------------------------------------------
    # Buscar registros A existentes
    # --------------------------------------------------------

    # Consultar los registros A de la zona y filtrar por
    # nombre exacto. Asi, un nombre inexistente no oculta
    # errores de consulta del servidor DNS.

    try {
        $QueryParameters = @{
            ZoneName    = $ZoneName
            RRType      = "A"
            ErrorAction = "Stop"
        }

        $ExistingRecords = @(
            Get-DnsServerResourceRecord @QueryParameters |
                Where-Object { $_.HostName -eq $Name }
        )
    }
    catch {
        Write-Host "[ERROR] No fue posible consultar los registros DNS A." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }


    # --------------------------------------------------------
    # Mantener el A correcto y eliminar solo los A obsoletos
    # --------------------------------------------------------

    $CorrectRecord = $false

    foreach ($Existing in $ExistingRecords) {
        try {
            $ExistingIP = $Existing.RecordData.IPv4Address.IPAddressToString
        }
        catch {
            Write-Host "[ERROR] No fue posible leer un registro A existente de $Name.$ZoneName." -ForegroundColor Red
            throw
        }

        if ($ExistingIP -eq $IP) {
            $CorrectRecord = $true
            Write-Host "[OK] Registro existente: $Name.$ZoneName -> $IP" -ForegroundColor Green
        }
    }

    # --------------------------------------------------------
    # Crear nuevo registro A
    # --------------------------------------------------------

    # Agregar primero la IP correcta. Nunca retirar registros
    # antiguos si la creacion o comprobacion falla.

    if (-not $CorrectRecord) {
        try {
            $AddParameters = @{
                Name        = $Name
                ZoneName    = $ZoneName
                IPv4Address = $IP
                ErrorAction = "Stop"
            }

            Add-DnsServerResourceRecordA @AddParameters

            Write-Host "[CREADO] $Name.$ZoneName -> $IP" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] No se pudo crear el registro DNS:" -ForegroundColor Red
            Write-Host "        $Name.$ZoneName -> $IP" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            throw
        }
    }

    # Confirmar directamente en la zona que la IP correcta
    # existe ANTES de eliminar los registros obsoletos.

    try {
        $ConfirmedRecords = @(
            Get-DnsServerResourceRecord @QueryParameters |
                Where-Object { $_.HostName -eq $Name }
        )

        $ConfirmedIPs = @(
            $ConfirmedRecords |
                ForEach-Object { $_.RecordData.IPv4Address.IPAddressToString }
        )

        if ($ConfirmedIPs -notcontains $IP) {
            throw "La zona DNS no confirma la IP $IP para $Name.$ZoneName."
        }
    }
    catch {
        Write-Host "[ERROR] No fue posible confirmar el registro DNS correcto." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }

    # --------------------------------------------------------
    # Retirar solo los registros A obsoletos
    # --------------------------------------------------------

    foreach ($Existing in $ConfirmedRecords) {
        $ExistingIP = $Existing.RecordData.IPv4Address.IPAddressToString

        if ($ExistingIP -eq $IP) {
            continue
        }

        try {
            Write-Host "[ACTUALIZANDO] Eliminando IP anterior: $ExistingIP" -ForegroundColor Yellow

            $RemoveParameters = @{
                ZoneName    = $ZoneName
                InputObject = $Existing
                Force       = $true
                ErrorAction = "Stop"
            }

            Remove-DnsServerResourceRecord @RemoveParameters
            Write-Host "[ELIMINADO] $Name.$ZoneName -> $ExistingIP" -ForegroundColor Yellow
        }
        catch {
            Write-Host "[ERROR] No se pudo eliminar el registro DNS anterior." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            throw
        }
    }
}


# ============================================================
# 7. VERIFICACION DNS
# ============================================================

$VerificationErrors = 0

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Verificacion DNS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""


foreach ($Record in $Records) {

    $Name = $Record.Name
    $ExpectedIP = $Record.IP

    $FQDN = "$Name.$ZoneName"


    Write-Host "Verificando: $FQDN"


    try {

        $ResolveParameters = @{
            Name        = $FQDN
            Server      = "127.0.0.1"
            Type        = "A"
            ErrorAction = "Stop"
        }

        $Resolution = Resolve-DnsName @ResolveParameters


        $ResolvedIPs = @(
            $Resolution |
                Where-Object {
                    $_.Type -eq "A"
                } |
                Select-Object -ExpandProperty IPAddress
        )


        if ($ResolvedIPs.Count -eq 1 -and $ResolvedIPs[0] -eq $ExpectedIP) {

            Write-Host "[OK] $FQDN -> $ExpectedIP" -ForegroundColor Green
        }
        else {

            Write-Host "[ADVERTENCIA] $FQDN no resuelve a la IP esperada." -ForegroundColor Yellow
            Write-Host "Esperado : $ExpectedIP" -ForegroundColor Yellow
            Write-Host "Detectado: $($ResolvedIPs -join ', ')" -ForegroundColor Yellow
            $VerificationErrors++
        }
    }
    catch {

        Write-Host "[ERROR] No fue posible resolver $FQDN." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        $VerificationErrors++
    }


    Write-Host ""
}


# ============================================================
# 8. VERIFICACION DIRECTA EN LA ZONA
# ============================================================

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Registros configurados" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""


foreach ($Record in $Records) {

    $Name = $Record.Name


    $QueryParameters = @{
        ZoneName    = $ZoneName
        RRType      = "A"
        ErrorAction = "Stop"
    }

    try {
        $ConfiguredRecords = @(
            Get-DnsServerResourceRecord @QueryParameters |
                Where-Object { $_.HostName -eq $Name }
        )
    }
    catch {
        Write-Host "[ERROR] No fue posible consultar $Name.$ZoneName." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        $VerificationErrors++
        continue
    }


    if ($ConfiguredRecords.Count -gt 0) {

        foreach ($ConfiguredRecord in $ConfiguredRecords) {

            $ConfiguredIP = $ConfiguredRecord.RecordData.IPv4Address.IPAddressToString

            Write-Host "$Name.$ZoneName -> $ConfiguredIP"

            if ($ConfiguredIP -ne $Record.IP) {
                Write-Host "[ERROR] Registro A con IP inesperada." -ForegroundColor Red
                $VerificationErrors++
            }
        }
    }
    else {

        Write-Host "[ERROR] No se encontro $Name.$ZoneName en la zona." -ForegroundColor Red
        $VerificationErrors++
    }
}


# ============================================================
# 9. FIN
# ============================================================

if ($VerificationErrors -gt 0) {
    Write-Host ""
    Write-Host "[ERROR] La verificacion DNS detecto $VerificationErrors problema(s)." -ForegroundColor Red
    exit 1
}


Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " CONFIGURACION DNS FINALIZADA" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
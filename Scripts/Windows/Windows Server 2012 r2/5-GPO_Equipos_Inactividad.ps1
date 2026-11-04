<#
.SYNOPSIS
    Configura politicas de inactividad para equipos Windows
    de Recoleccion UY.

.DESCRIPCION
    Crea y configura la GPO:

        GPO_REC_Equipos_Inactividad

    Puede vincularse a:

        OU=Clientes
        OU=Servidores
        OU=Domain Controllers

    Configura:

        - Bloqueo del equipo despues de 10 minutos
          de inactividad.

        - Apagado del monitor despues de 15 minutos
          de inactividad.

    NO configura:

        - Hibernacion.
        - Suspension.
        - Contrasenas.
        - Usuarios.
        - RDP.
        - Excepciones.

    El script es reejecutable.

    Si la GPO ya existe:
        - Se reutiliza.
        - Las configuraciones habilitadas se actualizan.

    Si un enlace ya existe:
        - No se vuelve a crear.

.REQUISITOS
    - Active Directory operativo.
    - DNS operativo.
    - Replicacion AD/SYSVOL operativa.
    - Modulo ActiveDirectory.
    - Modulo GroupPolicy.
    - OUs de Recoleccion UY creadas.
    - Ejecutar con privilegios administrativos.

.NOTAS
    Ejecutar preferentemente desde WS-DC-01.

    No es necesario ejecutarlo tambien en WS-DC-02.

    Compatible con Windows Server 2012 R2.
#>


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

$DomainName = "neltek.uy"

$DomainDN = "DC=neltek,DC=uy"


# ============================================================
# 2. OUs
# ============================================================

$OUClientes = "OU=Clientes,OU=Equipos,OU=RecoleccionUY,$DomainDN"

$OUServidores = "OU=Servidores,OU=Equipos,OU=RecoleccionUY,$DomainDN"

$OUDomainControllers = "OU=Domain Controllers,$DomainDN"


# ============================================================
# 3. GPO
# ============================================================

$GPOName = "GPO_REC_Equipos_Inactividad"


# ============================================================
# 4. INTERRUPTORES
# ============================================================

#
# $true  = configurar / procesar
# $false = omitir
#
# IMPORTANTE:
#
# $false NO elimina configuraciones existentes.
#

$ConfigurarBloqueoInactividad = $true

$ConfigurarApagadoMonitor = $true

$VincularAClientes = $true

$VincularAServidores = $true

$VincularADomainControllers = $false


# ============================================================
# 5. TIEMPOS
# ============================================================

#
# 600 segundos = 10 minutos
# 900 segundos = 15 minutos
#

$BloqueoInactividadSegundos = 600

$ApagadoMonitorSegundos = 900


# ============================================================
# 6. RUTAS DE REGISTRO UTILIZADAS POR LA GPO
# ============================================================

$InactivityRegistryKey = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

$InactivityValueName = "InactivityTimeoutSecs"


# Power Management
#
# Subgrupo:
# Video and Display Settings
#
# GUID:
# 7516B95F-F776-4464-8C53-06167F40CC99
#
# Configuracion:
# Turn off display after
#
# GUID:
# 3C0BC021-C8A8-4E07-A973-6B14CBCB2B7E
#

$DisplayPowerKey = "HKLM\Software\Policies\Microsoft\Power\PowerSettings\7516B95F-F776-4464-8C53-06167F40CC99\3C0BC021-C8A8-4E07-A973-6B14CBCB2B7E"


# ============================================================
# 7. INICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Recoleccion UY - GPO Equipos Inactividad" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Dominio : $DomainName"
Write-Host "GPO     : $GPOName"
Write-Host ""

Write-Host "Configuracion:"
Write-Host "  Bloqueo : $BloqueoInactividadSegundos segundos"
Write-Host "  Monitor : $ApagadoMonitorSegundos segundos"
Write-Host ""


# ============================================================
# 8. VERIFICAR EJECUCION COMO ADMINISTRADOR
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
# 9. CARGAR ACTIVE DIRECTORY
# ============================================================

try {

    Import-Module ActiveDirectory -ErrorAction Stop

    Write-Host "[OK] Modulo ActiveDirectory cargado." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible cargar ActiveDirectory." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 10. CARGAR GROUP POLICY
# ============================================================

try {

    Import-Module GroupPolicy -ErrorAction Stop

    Write-Host "[OK] Modulo GroupPolicy cargado." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible cargar GroupPolicy." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 11. VERIFICAR DOMINIO
# ============================================================

try {

    $CurrentDomain = Get-ADDomain -ErrorAction Stop

    if ($CurrentDomain.DNSRoot -ne $DomainName) {

        Write-Host "[ERROR] Dominio incorrecto." -ForegroundColor Red
        Write-Host ""
        Write-Host "Esperado : $DomainName"
        Write-Host "Detectado: $($CurrentDomain.DNSRoot)"

        exit 1
    }

    Write-Host "[OK] Dominio verificado: $DomainName" -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible verificar el dominio." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 12. FUNCION: VERIFICAR OU
# ============================================================

function Test-OUExists {

    param(
        [Parameter(Mandatory=$true)]
        [string]$OUPath
    )

    try {

        $Parameters = @{
            Identity    = $OUPath
            ErrorAction = "Stop"
        }

        $OU = Get-ADOrganizationalUnit @Parameters

        return $true
    }
    catch {

        return $false
    }
}


# ============================================================
# 13. VERIFICAR OUs NECESARIAS
# ============================================================

Write-Host ""
Write-Host "----- Verificacion de OUs -----" -ForegroundColor Cyan


if ($VincularAClientes) {

    $TestParameters = @{
        OUPath = $OUClientes
    }

    if (-not (Test-OUExists @TestParameters)) {

        Write-Host "[ERROR] No existe:" -ForegroundColor Red
        Write-Host "        $OUClientes"

        exit 1
    }

    Write-Host "[OK] OU Clientes encontrada." -ForegroundColor Green
}


if ($VincularAServidores) {

    $TestParameters = @{
        OUPath = $OUServidores
    }

    if (-not (Test-OUExists @TestParameters)) {

        Write-Host "[ERROR] No existe:" -ForegroundColor Red
        Write-Host "        $OUServidores"

        exit 1
    }

    Write-Host "[OK] OU Servidores encontrada." -ForegroundColor Green
}


if ($VincularADomainControllers) {

    $TestParameters = @{
        OUPath = $OUDomainControllers
    }

    if (-not (Test-OUExists @TestParameters)) {

        Write-Host "[ERROR] No existe:" -ForegroundColor Red
        Write-Host "        $OUDomainControllers"

        exit 1
    }

    Write-Host "[OK] OU Domain Controllers encontrada." -ForegroundColor Green
}


# ============================================================
# 14. CREAR / OBTENER GPO
# ============================================================

Write-Host ""
Write-Host "----- GPO -----" -ForegroundColor Cyan


try {

    $GetGPOParameters = @{
        Name        = $GPOName
        Domain      = $DomainName
        ErrorAction = "SilentlyContinue"
    }

    $GPO = Get-GPO @GetGPOParameters


    if ($GPO) {

        Write-Host "[EXISTE] GPO: $GPOName" -ForegroundColor Yellow
    }
    else {

        $NewGPOParameters = @{
            Name        = $GPOName
            Domain      = $DomainName
            Comment     = "Bloqueo por inactividad y apagado de pantalla para equipos Windows de Recoleccion UY."
            ErrorAction = "Stop"
        }

        $GPO = New-GPO @NewGPOParameters

        Write-Host "[CREADA] GPO: $GPOName" -ForegroundColor Green
    }
}
catch {

    Write-Host "[ERROR] No fue posible crear o verificar la GPO." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 15. BLOQUEO DEL EQUIPO POR INACTIVIDAD
# ============================================================

#
# Computer Configuration
#   Windows Settings
#     Security Settings
#       Local Policies
#         Security Options
#
# Interactive logon:
# Machine inactivity limit
#
# Registro:
#
# HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System
#
# InactivityTimeoutSecs
#

if ($ConfigurarBloqueoInactividad) {

    Write-Host ""
    Write-Host "----- Bloqueo por inactividad -----" -ForegroundColor Cyan

    try {

        $Parameters = @{
            Name        = $GPOName
            Domain      = $DomainName
            Key         = $InactivityRegistryKey
            ValueName   = $InactivityValueName
            Type        = "DWord"
            Value       = $BloqueoInactividadSegundos
            ErrorAction = "Stop"
        }

        Set-GPRegistryValue @Parameters | Out-Null


        Write-Host "[OK] Bloqueo por inactividad configurado." -ForegroundColor Green
        Write-Host "     Tiempo: $BloqueoInactividadSegundos segundos"
    }
    catch {

        Write-Host "[ERROR] No fue posible configurar el bloqueo." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        exit 1
    }
}
else {

    Write-Host "[OMITIDO] Bloqueo por inactividad." -ForegroundColor DarkYellow
}


# ============================================================
# 16. APAGADO DEL MONITOR
# ============================================================

#
# Power Management
#
# Video and Display Settings
#
# Turn off display after
#
# ACSettingIndex = corriente
# DCSettingIndex = bateria
#

if ($ConfigurarApagadoMonitor) {

    Write-Host ""
    Write-Host "----- Apagado del monitor -----" -ForegroundColor Cyan

    try {

        $ACParameters = @{
            Name        = $GPOName
            Domain      = $DomainName
            Key         = $DisplayPowerKey
            ValueName   = "ACSettingIndex"
            Type        = "DWord"
            Value       = $ApagadoMonitorSegundos
            ErrorAction = "Stop"
        }

        Set-GPRegistryValue @ACParameters | Out-Null


        $DCParameters = @{
            Name        = $GPOName
            Domain      = $DomainName
            Key         = $DisplayPowerKey
            ValueName   = "DCSettingIndex"
            Type        = "DWord"
            Value       = $ApagadoMonitorSegundos
            ErrorAction = "Stop"
        }

        Set-GPRegistryValue @DCParameters | Out-Null


        Write-Host "[OK] Apagado del monitor configurado." -ForegroundColor Green
        Write-Host "     AC: $ApagadoMonitorSegundos segundos"
        Write-Host "     DC: $ApagadoMonitorSegundos segundos"
    }
    catch {

        Write-Host "[ERROR] No fue posible configurar el monitor." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        exit 1
    }
}
else {

    Write-Host "[OMITIDO] Apagado del monitor." -ForegroundColor DarkYellow
}


# ============================================================
# 17. FUNCION: CREAR ENLACE GPO
# ============================================================

function Add-GPOLinkIfNeeded {

    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetOU
    )

    try {

        $InheritanceParameters = @{
            Target      = $TargetOU
            Domain      = $DomainName
            ErrorAction = "Stop"
        }

        $Inheritance = Get-GPInheritance @InheritanceParameters


        $ExistingLink = $Inheritance.GpoLinks |
            Where-Object {
                $_.DisplayName -eq $GPOName
            }


        if ($ExistingLink) {

            Write-Host "[EXISTE] Enlace:" -ForegroundColor Yellow
            Write-Host "         $GPOName"
            Write-Host "         -> $TargetOU"

            return
        }


        $LinkParameters = @{
            Name        = $GPOName
            Target      = $TargetOU
            Domain      = $DomainName
            LinkEnabled = "Yes"
            ErrorAction = "Stop"
        }

        New-GPLink @LinkParameters | Out-Null


        Write-Host "[CREADO] Enlace:" -ForegroundColor Green
        Write-Host "         $GPOName"
        Write-Host "         -> $TargetOU"
    }
    catch {

        Write-Host "[ERROR] No fue posible crear el enlace." -ForegroundColor Red
        Write-Host "        $TargetOU"
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ============================================================
# 18. VINCULAR A CLIENTES
# ============================================================

if ($VincularAClientes) {

    Write-Host ""
    Write-Host "----- Enlace OU Clientes -----" -ForegroundColor Cyan

    try {

        $Parameters = @{
            TargetOU = $OUClientes
        }

        Add-GPOLinkIfNeeded @Parameters
    }
    catch {

        exit 1
    }
}
else {

    Write-Host "[OMITIDO] Enlace a OU=Clientes." -ForegroundColor DarkYellow
}


# ============================================================
# 19. VINCULAR A SERVIDORES
# ============================================================

if ($VincularAServidores) {

    Write-Host ""
    Write-Host "----- Enlace OU Servidores -----" -ForegroundColor Cyan

    try {

        $Parameters = @{
            TargetOU = $OUServidores
        }

        Add-GPOLinkIfNeeded @Parameters
    }
    catch {

        exit 1
    }
}
else {

    Write-Host "[OMITIDO] Enlace a OU=Servidores." -ForegroundColor DarkYellow
}


# ============================================================
# 20. VINCULAR A DOMAIN CONTROLLERS
# ============================================================

if ($VincularADomainControllers) {

    Write-Host ""
    Write-Host "----- Enlace OU Domain Controllers -----" -ForegroundColor Cyan

    try {

        $Parameters = @{
            TargetOU = $OUDomainControllers
        }

        Add-GPOLinkIfNeeded @Parameters
    }
    catch {

        exit 1
    }
}
else {

    Write-Host ""
    Write-Host "[OMITIDO] Enlace a OU=Domain Controllers." -ForegroundColor DarkYellow
}


# ============================================================
# 21. VERIFICAR GPO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VERIFICACION" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


try {

    $GPOParameters = @{
        Name        = $GPOName
        Domain      = $DomainName
        ErrorAction = "Stop"
    }

    $FinalGPO = Get-GPO @GPOParameters


    Write-Host "GPO:"
    Write-Host "  Nombre : $($FinalGPO.DisplayName)"
    Write-Host "  ID     : $($FinalGPO.Id)"
}
catch {

    Write-Host "[ERROR] No fue posible verificar la GPO." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 22. VERIFICAR BLOQUEO POR INACTIVIDAD
# ============================================================

if ($ConfigurarBloqueoInactividad) {

    Write-Host ""
    Write-Host "Bloqueo por inactividad:" -ForegroundColor Cyan

    try {

        $Parameters = @{
            Name        = $GPOName
            Domain      = $DomainName
            Key         = $InactivityRegistryKey
            ValueName   = $InactivityValueName
            ErrorAction = "Stop"
        }

        $InactivityResult = Get-GPRegistryValue @Parameters


        Write-Host "  Valor configurado : $($InactivityResult.Value)"
        Write-Host "  Valor esperado    : $BloqueoInactividadSegundos"


        if ($InactivityResult.Value -eq $BloqueoInactividadSegundos) {

            Write-Host "[OK] Bloqueo por inactividad verificado." -ForegroundColor Green
        }
        else {

            Write-Host "[ADVERTENCIA] El valor no coincide con lo esperado." -ForegroundColor Yellow
        }
    }
    catch {

        Write-Host "[ERROR] No fue posible verificar el bloqueo por inactividad." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


# ============================================================
# 23. VERIFICAR APAGADO DEL MONITOR
# ============================================================

if ($ConfigurarApagadoMonitor) {

    Write-Host ""
    Write-Host "Apagado del monitor:" -ForegroundColor Cyan


    try {

        $ACParameters = @{
            Name        = $GPOName
            Domain      = $DomainName
            Key         = $DisplayPowerKey
            ValueName   = "ACSettingIndex"
            ErrorAction = "Stop"
        }

        $ACResult = Get-GPRegistryValue @ACParameters


        $DCParameters = @{
            Name        = $GPOName
            Domain      = $DomainName
            Key         = $DisplayPowerKey
            ValueName   = "DCSettingIndex"
            ErrorAction = "Stop"
        }

        $DCResult = Get-GPRegistryValue @DCParameters


        Write-Host "  AC configurado : $($ACResult.Value)"
        Write-Host "  DC configurado : $($DCResult.Value)"
        Write-Host "  Esperado       : $ApagadoMonitorSegundos"


        if (
            $ACResult.Value -eq $ApagadoMonitorSegundos -and
            $DCResult.Value -eq $ApagadoMonitorSegundos
        ) {

            Write-Host "[OK] Apagado del monitor verificado." -ForegroundColor Green
        }
        else {

            Write-Host "[ADVERTENCIA] Los valores del monitor no coinciden con lo esperado." -ForegroundColor Yellow
        }
    }
    catch {

        Write-Host "[ERROR] No fue posible verificar el apagado del monitor." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


# ============================================================
# 24. VERIFICAR ENLACES
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VERIFICACION DE ENLACES" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


if ($VincularAClientes) {

    try {

        $Parameters = @{
            Target      = $OUClientes
            Domain      = $DomainName
            ErrorAction = "Stop"
        }

        $Inheritance = Get-GPInheritance @Parameters

        $Link = $Inheritance.GpoLinks |
            Where-Object {
                $_.DisplayName -eq $GPOName
            }

        if ($Link) {

            Write-Host "[OK] Enlace OU=Clientes." -ForegroundColor Green
        }
        else {

            Write-Host "[ERROR] No se encontro enlace en OU=Clientes." -ForegroundColor Red
        }
    }
    catch {

        Write-Host "[ERROR] No fue posible verificar OU=Clientes." -ForegroundColor Red
    }
}


if ($VincularAServidores) {

    try {

        $Parameters = @{
            Target      = $OUServidores
            Domain      = $DomainName
            ErrorAction = "Stop"
        }

        $Inheritance = Get-GPInheritance @Parameters

        $Link = $Inheritance.GpoLinks |
            Where-Object {
                $_.DisplayName -eq $GPOName
            }

        if ($Link) {

            Write-Host "[OK] Enlace OU=Servidores." -ForegroundColor Green
        }
        else {

            Write-Host "[ERROR] No se encontro enlace en OU=Servidores." -ForegroundColor Red
        }
    }
    catch {

        Write-Host "[ERROR] No fue posible verificar OU=Servidores." -ForegroundColor Red
    }
}


if ($VincularADomainControllers) {

    try {

        $Parameters = @{
            Target      = $OUDomainControllers
            Domain      = $DomainName
            ErrorAction = "Stop"
        }

        $Inheritance = Get-GPInheritance @Parameters

        $Link = $Inheritance.GpoLinks |
            Where-Object {
                $_.DisplayName -eq $GPOName
            }

        if ($Link) {

            Write-Host "[OK] Enlace OU=Domain Controllers." -ForegroundColor Green
        }
        else {

            Write-Host "[ERROR] No se encontro enlace en OU=Domain Controllers." -ForegroundColor Red
        }
    }
    catch {

        Write-Host "[ERROR] No fue posible verificar OU=Domain Controllers." -ForegroundColor Red
    }
}


# ============================================================
# 25. FIN
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " CONFIGURACION FINALIZADA" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""

Write-Host "GPO:"
Write-Host "  $GPOName"

Write-Host ""
Write-Host "Configuracion:"


if ($ConfigurarBloqueoInactividad) {

    Write-Host "  Bloqueo : $BloqueoInactividadSegundos segundos"
}
else {

    Write-Host "  Bloqueo : no modificado"
}


if ($ConfigurarApagadoMonitor) {

    Write-Host "  Monitor : $ApagadoMonitorSegundos segundos"
}
else {

    Write-Host "  Monitor : no modificado"
}


Write-Host ""
Write-Host "Alcance:" -ForegroundColor Cyan


if ($VincularAClientes) {

    Write-Host "  [SI] OU=Clientes"
}
else {

    Write-Host "  [NO] OU=Clientes"
}


if ($VincularAServidores) {

    Write-Host "  [SI] OU=Servidores"
}
else {

    Write-Host "  [NO] OU=Servidores"
}


if ($VincularADomainControllers) {

    Write-Host "  [SI] OU=Domain Controllers"
}
else {

    Write-Host "  [NO] OU=Domain Controllers"
}


Write-Host ""
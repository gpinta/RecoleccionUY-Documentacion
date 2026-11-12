<#
.SYNOPSIS
    Configuracion local de un controlador de dominio de Recoleccion UY.

.DESCRIPCION
    Configura aspectos locales del servidor Windows:

      - DNS cliente de la interfaz.
      - RDP.
      - NLA.
      - Servicio TermService.
      - Reglas integradas de RDP.
      - Regla REC-RDP-Administracion.

.REQUISITOS
    Active Directory y DNS ya deben estar configurados.

    WS-DC-01 y WS-DC-02 deben encontrarse operativos
    y replicando correctamente.

.NOTAS
    Antes de ejecutar este script debe configurarse:

        $ServerIP
        $DNSServers

    segun el servidor correspondiente.

    Compatible con Windows Server 2012 R2.
#>


# ============================================================
# 1. CONFIGURACION LOCAL
# ============================================================

#
# WS-DC-01:
#
# $ServerIP = "192.168.10.20"
#
# $DNSServers = @(
#     "192.168.10.20",
#     "192.168.10.21"
# )
#
#
# WS-DC-02:
#
# $ServerIP = "192.168.10.21"
#
# $DNSServers = @(
#     "192.168.10.21",
#     "192.168.10.20"
# )
#


# ------------------------------------------------------------
# CONFIGURACION ACTUAL
# ------------------------------------------------------------
#
# Ajustar antes de ejecutar en cada servidor.
# ------------------------------------------------------------

$ServerIP = "192.168.10.20"

$DNSServers = @(
    "192.168.10.20",
    "192.168.10.21"
)


# ============================================================
# 2. CONFIGURACION RDP
# ============================================================

$RDPRemoteAddress = "192.168.10.0/24"


# ============================================================
# 3. INICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Recoleccion UY - Configuracion local WS-DC" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "IP local esperada : $ServerIP"
Write-Host "Servidores DNS     : $($DNSServers -join ', ')"
Write-Host "Origen RDP         : $RDPRemoteAddress"

Write-Host ""


# ============================================================
# 4. VERIFICAR EJECUCION COMO ADMINISTRADOR
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
# 5. CARGAR MODULO ACTIVE DIRECTORY
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
# 6. VERIFICAR DOMINIO
# ============================================================

try {

    $CurrentDomain = Get-ADDomain -ErrorAction Stop

    Write-Host "[OK] Dominio detectado: $($CurrentDomain.DNSRoot)" -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible consultar Active Directory." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 7. FUNCION: ANIDAR GRUPOS
# ============================================================

function Add-GroupToGroupIfNeeded {

    param(
        [Parameter(Mandatory=$true)]
        [string]$ChildGroup,

        [Parameter(Mandatory=$true)]
        [string]$ParentGroup
    )

    try {

        $ChildParameters = @{
            Identity    = $ChildGroup
            ErrorAction = "Stop"
        }

        $Child = Get-ADGroup @ChildParameters


        $ParentParameters = @{
            Identity    = $ParentGroup
            ErrorAction = "Stop"
        }

        $Parent = Get-ADGroup @ParentParameters


        $MemberParameters = @{
            Identity    = $Parent
            Recursive   = $false
            ErrorAction = "Stop"
        }

        $Membership = Get-ADGroupMember @MemberParameters |
            Where-Object {
                $_.DistinguishedName -eq $Child.DistinguishedName
            }


        if ($Membership) {

            Write-Host "[EXISTE] $ChildGroup -> $($Parent.Name)" -ForegroundColor Yellow
        }
        else {

            $AddParameters = @{
                Identity    = $Parent
                Members     = $Child
                ErrorAction = "Stop"
            }

            Add-ADGroupMember @AddParameters

            Write-Host "[AGREGADO] $ChildGroup -> $($Parent.Name)" -ForegroundColor Green
        }
    }
    catch {

        Write-Host "[ERROR] No se pudo agregar $ChildGroup a $ParentGroup." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ============================================================
# 8. VERIFICAR INTERFAZ E IP
# ============================================================

Write-Host ""
Write-Host "----- Verificacion de interfaz de red -----" -ForegroundColor Cyan

try {

    $ActiveIPv4 = Get-NetIPConfiguration |
        Where-Object {

            $_.IPv4Address -and
            $_.NetAdapter.Status -eq "Up" -and
            $_.NetAdapter.HardwareInterface -eq $true

        } |
        Where-Object {

            $_.IPv4Address.IPAddress -eq $ServerIP

        } |
        Select-Object -First 1


    if (-not $ActiveIPv4) {

        Write-Host "[ERROR] No existe una interfaz fisica activa con la IP $ServerIP." -ForegroundColor Red

        Write-Host ""
        Write-Host "Interfaces IPv4 detectadas:" -ForegroundColor Yellow

        Get-NetIPConfiguration |
            Where-Object {
                $_.IPv4Address
            } |
            Select-Object InterfaceAlias,
                @{
                    Name       = "IPv4"
                    Expression = {
                        $_.IPv4Address.IPAddress
                    }
                } |
            Format-Table -AutoSize

        throw "La IP configurada en ServerIP no coincide con ninguna interfaz activa."
    }


    $InterfaceAlias = $ActiveIPv4.InterfaceAlias

    Write-Host "[OK] Interfaz detectada: $InterfaceAlias" -ForegroundColor Green
    Write-Host "[OK] IP detectada      : $ServerIP" -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No se pudo verificar la interfaz de red." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 9. CONFIGURAR DNS DEL CONTROLADOR DE DOMINIO
# ============================================================

Write-Host ""
Write-Host "----- Configuracion DNS local del DC -----" -ForegroundColor Cyan

try {

    $DNSParameters = @{
        InterfaceAlias  = $InterfaceAlias
        ServerAddresses = $DNSServers
        ErrorAction     = "Stop"
    }

    Set-DnsClientServerAddress @DNSParameters


    ipconfig /flushdns | Out-Null
    ipconfig /registerdns | Out-Null


    Restart-Service Netlogon -ErrorAction Stop


    Write-Host "[OK] DNS de $InterfaceAlias configurado." -ForegroundColor Green
    Write-Host "     DNS: $($DNSServers -join ', ')" -ForegroundColor Green


    $ProfileParameters = @{
        InterfaceAlias = $InterfaceAlias
        ErrorAction    = "SilentlyContinue"
    }

    $Profile = Get-NetConnectionProfile @ProfileParameters


    if ($Profile) {

        Write-Host "Perfil de red detectado: $($Profile.NetworkCategory)"

        if ($Profile.NetworkCategory -ne "DomainAuthenticated") {

            Write-Host "[ADVERTENCIA] El perfil aun no figura como DomainAuthenticated." -ForegroundColor Yellow
            Write-Host "              Puede tardar unos segundos despues del cambio de DNS." -ForegroundColor Yellow
        }
        else {

            Write-Host "[OK] Perfil de red: DomainAuthenticated." -ForegroundColor Green
        }
    }
    else {

        Write-Host "[ADVERTENCIA] No fue posible determinar el perfil de red." -ForegroundColor Yellow
    }
}
catch {

    Write-Host "[ERROR] No se pudo configurar o verificar DNS local." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    throw
}


# ============================================================
# 10. CONFIGURACION RDP
# ============================================================

Write-Host ""
Write-Host "----- Configuracion Remote Desktop -----" -ForegroundColor Cyan


# ------------------------------------------------------------
# 10.1 VERIFICAR GRUPO ADMINISTRATIVO
# ------------------------------------------------------------

try {

    $RDPAdminGroupParameters = @{
        Identity    = "GG_REC_Server_Admins_Windows"
        ErrorAction = "Stop"
    }

    $RDPAdminGroup = Get-ADGroup @RDPAdminGroupParameters

    Write-Host "[OK] Grupo GG_REC_Server_Admins_Windows encontrado." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No existe GG_REC_Server_Admins_Windows en Active Directory." -ForegroundColor Red
    Write-Host "        Ejecute primero el script de configuracion de Active Directory." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    throw
}


# ------------------------------------------------------------
# 10.2 AGREGAR GRUPO A REMOTE DESKTOP USERS
# ------------------------------------------------------------

try {

    $RDPGroupParameters = @{
        ChildGroup  = "GG_REC_Server_Admins_Windows"
        ParentGroup = "S-1-5-32-555"
    }

    Add-GroupToGroupIfNeeded @RDPGroupParameters
}
catch {

    Write-Host "[ERROR] No fue posible configurar Remote Desktop Users." -ForegroundColor Red

    throw
}


# ------------------------------------------------------------
# 10.3 HABILITAR RDP
# ------------------------------------------------------------

try {

    $RDPRegistryParameters = @{
        Path        = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
        Name        = "fDenyTSConnections"
        Value       = 0
        ErrorAction = "Stop"
    }

    Set-ItemProperty @RDPRegistryParameters

    Write-Host "[OK] RDP habilitado." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible habilitar RDP." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    throw
}


# ------------------------------------------------------------
# 10.4 HABILITAR NLA
# ------------------------------------------------------------

try {

    $NLARegistryParameters = @{
        Path        = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
        Name        = "UserAuthentication"
        Value       = 1
        ErrorAction = "Stop"
    }

    Set-ItemProperty @NLARegistryParameters

    Write-Host "[OK] NLA habilitado." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible habilitar NLA." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    throw
}


# ------------------------------------------------------------
# 10.5 VERIFICAR TERMSERVICE
# ------------------------------------------------------------

try {

    $RDPService = Get-Service -Name "TermService" -ErrorAction Stop


    if ($RDPService.Status -ne "Running") {

        Start-Service -Name "TermService" -ErrorAction Stop

        Write-Host "[OK] TermService iniciado." -ForegroundColor Green
    }
    else {

        Write-Host "[EXISTE] TermService ya esta ejecutandose." -ForegroundColor Yellow
    }
}
catch {

    Write-Host "[ERROR] No fue posible iniciar o verificar TermService." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    throw
}


# ============================================================
# 11. FIREWALL RDP
# ============================================================

Write-Host ""
Write-Host "----- Configuracion Firewall RDP -----" -ForegroundColor Cyan


# ------------------------------------------------------------
# 11.1 DESHABILITAR REGLAS RDP INTEGRADAS
# ------------------------------------------------------------

$BuiltInRDPRules = @(
    "RemoteDesktop-UserMode-In-TCP",
    "RemoteDesktop-UserMode-In-UDP",
    "RemoteDesktop-Shadow-In-TCP"
)


foreach ($RuleName in $BuiltInRDPRules) {

    try {

        $RuleParameters = @{
            Name        = $RuleName
            ErrorAction = "SilentlyContinue"
        }

        $Rule = Get-NetFirewallRule @RuleParameters


        if ($Rule) {

            if ($Rule.Enabled -eq "True") {

                $DisableParameters = @{
                    Name        = $RuleName
                    ErrorAction = "Stop"
                }

                Disable-NetFirewallRule @DisableParameters

                Write-Host "[DESHABILITADA] $RuleName" -ForegroundColor Green
            }
            else {

                Write-Host "[YA DESHABILITADA] $RuleName" -ForegroundColor Yellow
            }
        }
        else {

            Write-Host "[NO EXISTE] $RuleName" -ForegroundColor DarkYellow
        }
    }
    catch {

        Write-Host "[ERROR] No se pudo procesar la regla $RuleName." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ------------------------------------------------------------
# 11.2 CREAR O ACTUALIZAR REGLA PROPIA RDP
# ------------------------------------------------------------

$RDPFirewallRuleName = "REC-RDP-Administracion"


try {

    $ExistingRuleParameters = @{
        Name        = $RDPFirewallRuleName
        ErrorAction = "SilentlyContinue"
    }

    $ExistingRDPFirewallRule = Get-NetFirewallRule @ExistingRuleParameters


    if ($ExistingRDPFirewallRule) {

        Write-Host "[EXISTE] Regla $RDPFirewallRuleName." -ForegroundColor Yellow


        # ----------------------------------------------------
        # Verificar protocolo y puerto
        # ----------------------------------------------------

        $PortFilter = $ExistingRDPFirewallRule |
            Get-NetFirewallPortFilter


        $RuleNeedsRecreation = $false


        if ($PortFilter.Protocol -ne "TCP") {

            $RuleNeedsRecreation = $true
        }


        if ($PortFilter.LocalPort -ne "3389") {

            $RuleNeedsRecreation = $true
        }


        if ($RuleNeedsRecreation) {

            Write-Host "[INFO] La regla existente no coincide con TCP/3389." -ForegroundColor Yellow
            Write-Host "[INFO] La regla sera recreada." -ForegroundColor Yellow


            $RemoveRuleParameters = @{
                Name        = $RDPFirewallRuleName
                ErrorAction = "Stop"
            }

            Remove-NetFirewallRule @RemoveRuleParameters


            $NewRuleParameters = @{
                Name          = $RDPFirewallRuleName
                DisplayName   = "REC - RDP - Administracion"
                Description   = "Permite RDP administrativo al controlador de dominio"
                Direction     = "Inbound"
                Action        = "Allow"
                Protocol      = "TCP"
                LocalPort     = "3389"
                RemoteAddress = $RDPRemoteAddress
                Profile       = "Domain"
                Enabled       = "True"
                ErrorAction   = "Stop"
            }

            New-NetFirewallRule @NewRuleParameters | Out-Null


            Write-Host "[RECREADA] Regla Firewall RDP." -ForegroundColor Green
        }
        else {

            # ------------------------------------------------
            # Actualizar propiedades principales
            # ------------------------------------------------

            $RuleUpdateParameters = @{
                Name        = $RDPFirewallRuleName
                Enabled     = "True"
                Direction   = "Inbound"
                Action      = "Allow"
                Profile     = "Domain"
                ErrorAction = "Stop"
            }

            Set-NetFirewallRule @RuleUpdateParameters


            # ------------------------------------------------
            # Actualizar origen permitido
            # ------------------------------------------------

            $AddressFilter = $ExistingRDPFirewallRule |
                Get-NetFirewallAddressFilter


            $AddressUpdateParameters = @{
                RemoteAddress = $RDPRemoteAddress
                ErrorAction   = "Stop"
            }

            $AddressFilter |
                Set-NetFirewallAddressFilter @AddressUpdateParameters


            Write-Host "[ACTUALIZADA] Regla Firewall RDP." -ForegroundColor Green
        }
    }
    else {

        $NewRuleParameters = @{
            Name          = $RDPFirewallRuleName
            DisplayName   = "REC - RDP - Administracion"
            Description   = "Permite RDP administrativo al controlador de dominio"
            Direction     = "Inbound"
            Action        = "Allow"
            Protocol      = "TCP"
            LocalPort     = "3389"
            RemoteAddress = $RDPRemoteAddress
            Profile       = "Domain"
            Enabled       = "True"
            ErrorAction   = "Stop"
        }

        New-NetFirewallRule @NewRuleParameters | Out-Null

        Write-Host "[CREADA] Regla Firewall RDP." -ForegroundColor Green
    }
}
catch {

    Write-Host "[ERROR] No se pudo crear o actualizar la regla RDP." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    throw
}


# ============================================================
# 12. VERIFICACION DNS
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VERIFICACION DNS" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object {
        $_.ServerAddresses.Count -gt 0
    } |
    Format-Table InterfaceAlias, ServerAddresses -AutoSize


Get-NetConnectionProfile |
    Format-Table InterfaceAlias, Name, NetworkCategory -AutoSize


# ============================================================
# 13. VERIFICACION RDP
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VERIFICACION RDP" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


$RDPPropertyParameters = @{
    Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    Name = "fDenyTSConnections"
}

$RDPEnabled = (
    Get-ItemProperty @RDPPropertyParameters
).fDenyTSConnections


$NLAPropertyParameters = @{
    Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
    Name = "UserAuthentication"
}

$NLAEnabled = (
    Get-ItemProperty @NLAPropertyParameters
).UserAuthentication


Write-Host "fDenyTSConnections : $RDPEnabled"
Write-Host "UserAuthentication : $NLAEnabled"
Write-Host "TermService         : $((Get-Service TermService).Status)"


if ($RDPEnabled -eq 0) {

    Write-Host "[OK] RDP esta habilitado." -ForegroundColor Green
}
else {

    Write-Host "[ADVERTENCIA] RDP no aparece habilitado." -ForegroundColor Yellow
}


if ($NLAEnabled -eq 1) {

    Write-Host "[OK] NLA esta habilitado." -ForegroundColor Green
}
else {

    Write-Host "[ADVERTENCIA] NLA no aparece habilitado." -ForegroundColor Yellow
}


# ============================================================
# 14. VERIFICAR REGLAS INTEGRADAS
# ============================================================

Write-Host ""
Write-Host "Reglas integradas RDP:"


foreach ($RuleName in $BuiltInRDPRules) {

    $RuleParameters = @{
        Name        = $RuleName
        ErrorAction = "SilentlyContinue"
    }

    $Rule = Get-NetFirewallRule @RuleParameters


    if ($Rule) {

        Write-Host "$RuleName : $($Rule.Enabled)"
    }
    else {

        Write-Host "$RuleName : No encontrada"
    }
}


# ============================================================
# 15. VERIFICAR REGLA PERSONALIZADA RDP
# ============================================================

$FirewallParameters = @{
    Name        = $RDPFirewallRuleName
    ErrorAction = "SilentlyContinue"
}

$FirewallRDP = Get-NetFirewallRule @FirewallParameters


if ($FirewallRDP) {

    $FirewallPort = $FirewallRDP |
        Get-NetFirewallPortFilter

    $FirewallAddress = $FirewallRDP |
        Get-NetFirewallAddressFilter


    Write-Host ""
    Write-Host "Regla REC-RDP-Administracion:"

    Write-Host "Estado : $($FirewallRDP.Enabled)"
    Write-Host "Accion : $($FirewallRDP.Action)"
    Write-Host "Perfil : $($FirewallRDP.Profile)"
    Write-Host "Puerto : $($FirewallPort.LocalPort)"
    Write-Host "Origen : $($FirewallAddress.RemoteAddress)"


    if (
        $FirewallRDP.Enabled -eq "True" -and
        $FirewallRDP.Action -eq "Allow" -and
        $FirewallPort.LocalPort -eq "3389"
    ) {

        Write-Host "[OK] Regla RDP personalizada correctamente configurada." -ForegroundColor Green
    }
    else {

        Write-Host "[ADVERTENCIA] La regla RDP no coincide completamente con la configuracion esperada." -ForegroundColor Yellow
    }
}
else {

    Write-Host ""
    Write-Host "[ERROR] No existe la regla REC-RDP-Administracion." -ForegroundColor Red
}


# ============================================================
# 16. VERIFICAR PUERTO TCP 3389
# ============================================================

try {

    $TCPParameters = @{
        LocalPort   = 3389
        State       = "Listen"
        ErrorAction = "SilentlyContinue"
    }

    $RDPListening = Get-NetTCPConnection @TCPParameters


    if ($RDPListening) {

        Write-Host ""
        Write-Host "[OK] TCP/3389 esta escuchando." -ForegroundColor Green
    }
    else {

        Write-Host ""
        Write-Host "[ADVERTENCIA] TCP/3389 no esta escuchando." -ForegroundColor Yellow
    }
}
catch {

    Write-Host ""
    Write-Host "[ADVERTENCIA] No fue posible consultar TCP/3389." -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}


# ============================================================
# 17. RESUMEN
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " RESUMEN" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Write-Host "Servidor IP : $ServerIP"
Write-Host "Interfaz    : $InterfaceAlias"
Write-Host "DNS         : $($DNSServers -join ', ')"
Write-Host "RDP origen  : $RDPRemoteAddress"
Write-Host ""


# ============================================================
# 18. FIN
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " CONFIGURACION LOCAL FINALIZADA" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
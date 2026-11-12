<#
.SYNOPSIS
    Gestiona los origenes autorizados para conectarse por RDP
    mediante la regla:

        REC-RDP-Administracion

.DESCRIPCION
    Permite:

        1. Ver origenes permitidos.
        2. Agregar origen permitido.
        3. Eliminar origen permitido.
        4. Bloquear todos temporalmente.
        5. Habilitar origenes almacenados.
        6. Salir.

    Caracteristicas:

        - Permite IPv4 individuales.
        - Permite redes CIDR.
        - Permite formato IP/Mascara.
        - La eliminacion se realiza seleccionando por numero.
        - Si se elimina el ultimo origen, la regla queda
          deshabilitada de forma segura.
        - "Bloquear todos" guarda una copia independiente
          de los origenes antes de deshabilitar la regla.
        - La copia puede restaurarse posteriormente.

.REQUISITOS
    - Windows Server 2012 R2.
    - PowerShell ejecutado como Administrador.
    - Modulo NetSecurity.
    - Debe existir la regla REC-RDP-Administracion.

.NOTAS
    El valor 127.0.0.1 se utiliza internamente como marcador
    seguro cuando no existen origenes autorizados.

    Nunca se muestra como origen autorizado y la regla permanece
    deshabilitada mientras se utiliza dicho marcador.
#>


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

$RuleName = "REC-RDP-Administracion"

$DataDirectory = Join-Path `
    -Path $env:ProgramData `
    -ChildPath "RecoleccionUY"

$BlockedOriginsFile = Join-Path `
    -Path $DataDirectory `
    -ChildPath "RDP-BlockedOrigins.json"

# Marcador interno utilizado cuando no existen origenes.
# La regla siempre debe permanecer deshabilitada en este estado.

$EmptyRemoteAddress = "127.0.0.1"


# ============================================================
# 2. FUNCION: VERIFICAR ADMINISTRADOR
# ============================================================

function Test-IsAdministrator {

    try {

        $CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        $PrincipalParameters = @{
            TypeName     = "System.Security.Principal.WindowsPrincipal"
            ArgumentList = $CurrentIdentity
        }

        $CurrentPrincipal = New-Object @PrincipalParameters

        $AdministratorRole = `
            [System.Security.Principal.WindowsBuiltInRole]::Administrator

        return $CurrentPrincipal.IsInRole($AdministratorRole)
    }
    catch {

        return $false
    }
}


# ============================================================
# 3. FUNCION: OBTENER REGLA RDP
# ============================================================

function Get-RDPRule {

    $Parameters = @{
        Name        = $RuleName
        ErrorAction = "Stop"
    }

    return Get-NetFirewallRule @Parameters
}


# ============================================================
# 4. FUNCION: OBTENER FILTRO DE DIRECCIONES
# ============================================================

function Get-RDPAddressFilter {

    $Rule = Get-RDPRule

    return $Rule |
        Get-NetFirewallAddressFilter -ErrorAction Stop
}


# ============================================================
# 5. FUNCION: OBTENER ORIGENES REALES CONFIGURADOS
# ============================================================

function Get-ConfiguredRemoteAddresses {

    $AddressFilter = Get-RDPAddressFilter

    $Addresses = @(
        $AddressFilter.RemoteAddress
    )


    $Result = @()


    foreach ($Address in $Addresses) {

        if ([string]::IsNullOrWhiteSpace($Address)) {

            continue
        }


        # No mostrar el marcador interno.

        if ($Address -eq $EmptyRemoteAddress) {

            continue
        }


        $Result += $Address
    }


    return @(
        $Result |
            Sort-Object -Unique
    )
}


# ============================================================
# 6. FUNCION: VALIDAR IPv4
# ============================================================

function Test-ValidIPv4 {

    param(
        [Parameter(Mandatory=$true)]
        [string]$IPAddress
    )


    $ParsedIP = $null


    if (
        -not [System.Net.IPAddress]::TryParse(
            $IPAddress,
            [ref]$ParsedIP
        )
    ) {

        return $false
    }


    if (
        $ParsedIP.AddressFamily -ne
        [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {

        return $false
    }


    return $true
}


# ============================================================
# 7. FUNCION: VALIDAR MASCARA IPv4
# ============================================================

function Test-ValidSubnetMask {

    param(
        [Parameter(Mandatory=$true)]
        [string]$SubnetMask
    )


    if (-not (Test-ValidIPv4 -IPAddress $SubnetMask)) {

        return $false
    }


    try {

        $Bytes = (
            [System.Net.IPAddress]::Parse($SubnetMask)
        ).GetAddressBytes()


        $BinaryMask = ""


        foreach ($Byte in $Bytes) {

            $BinaryMask += [Convert]::ToString($Byte, 2).PadLeft(8, "0")
        }


        if ($BinaryMask -notmatch '^1*0*$') {

            return $false
        }


        return $true
    }
    catch {

        return $false
    }
}


# ============================================================
# 8. FUNCION: VALIDAR ORIGEN
# ============================================================

function Test-ValidRemoteAddress {

    param(
        [Parameter(Mandatory=$true)]
        [string]$Address
    )


    if ([string]::IsNullOrWhiteSpace($Address)) {

        return $false
    }


    $Address = $Address.Trim()


    # --------------------------------------------------------
    # IPv4 individual
    # --------------------------------------------------------

    if (Test-ValidIPv4 -IPAddress $Address) {

        return $true
    }


    # --------------------------------------------------------
    # IPv4 CIDR
    # Ejemplo:
    # 192.168.20.0/24
    # --------------------------------------------------------

    if ($Address -match '^([^/]+)/(\d{1,2})$') {

        $NetworkAddress = $Matches[1]

        $PrefixLength = 0


        if (-not (Test-ValidIPv4 -IPAddress $NetworkAddress)) {

            return $false
        }


        if (
            -not [int]::TryParse(
                $Matches[2],
                [ref]$PrefixLength
            )
        ) {

            return $false
        }


        if ($PrefixLength -lt 0 -or $PrefixLength -gt 32) {

            return $false
        }


        return $true
    }


    # --------------------------------------------------------
    # IPv4 / Mascara
    # Ejemplo:
    # 192.168.20.0/255.255.255.0
    # --------------------------------------------------------

    if ($Address -match '^([^/]+)/([^/]+)$') {

        $NetworkAddress = $Matches[1]

        $SubnetMask = $Matches[2]


        if (-not (Test-ValidIPv4 -IPAddress $NetworkAddress)) {

            return $false
        }


        if (-not (Test-ValidSubnetMask -SubnetMask $SubnetMask)) {

            return $false
        }


        return $true
    }


    return $false
}


# ============================================================
# 9. FUNCION: CREAR DIRECTORIO DE DATOS
# ============================================================

function Initialize-DataDirectory {

    if (-not (Test-Path -LiteralPath $DataDirectory)) {

        $Parameters = @{
            Path        = $DataDirectory
            ItemType    = "Directory"
            Force       = $true
            ErrorAction = "Stop"
        }

        New-Item @Parameters |
            Out-Null
    }
}


# ============================================================
# 10. FUNCION: GUARDAR ORIGENES BLOQUEADOS
# ============================================================

function Save-BlockedOrigins {

    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$AddressList
    )


    Initialize-DataDirectory


    $CleanList = @(
        $AddressList |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            Sort-Object -Unique
    )


    if ($CleanList.Count -eq 0) {

        if (Test-Path -LiteralPath $BlockedOriginsFile) {

            Remove-Item `
                -LiteralPath $BlockedOriginsFile `
                -Force `
                -ErrorAction Stop
        }


        return
    }


    $Json = ConvertTo-Json `
        -InputObject $CleanList


    Set-Content `
        -LiteralPath $BlockedOriginsFile `
        -Value $Json `
        -Encoding UTF8 `
        -Force `
        -ErrorAction Stop
}


# ============================================================
# 11. FUNCION: OBTENER ORIGENES BLOQUEADOS
# ============================================================

function Get-BlockedOrigins {

    if (-not (Test-Path -LiteralPath $BlockedOriginsFile)) {

        return @()
    }


    try {

        $Content = Get-Content `
            -LiteralPath $BlockedOriginsFile `
            -Raw `
            -ErrorAction Stop


        if ([string]::IsNullOrWhiteSpace($Content)) {

            return @()
        }


        $StoredAddresses = @(
            $Content |
                ConvertFrom-Json
        )


        return @(
            $StoredAddresses |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                } |
                Sort-Object -Unique
        )
    }
    catch {

        throw "No fue posible leer la copia de origenes bloqueados."
    }
}


# ============================================================
# 12. FUNCION: ELIMINAR COPIA DE BLOQUEO
# ============================================================

function Remove-BlockedOriginsFile {

    if (Test-Path -LiteralPath $BlockedOriginsFile) {

        Remove-Item `
            -LiteralPath $BlockedOriginsFile `
            -Force `
            -ErrorAction Stop
    }
}


# ============================================================
# 13. FUNCION: CONFIGURAR REMOTEADDRESS
# ============================================================

function Set-RDPRemoteAddresses {

    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$AddressList,

        [Parameter(Mandatory=$false)]
        [bool]$EnableRule = $true
    )


    $CleanList = @(
        $AddressList |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            Sort-Object -Unique
    )


    # --------------------------------------------------------
    # LISTA VACIA
    # --------------------------------------------------------

    if ($CleanList.Count -eq 0) {

        # Primero deshabilitamos la regla.

        $DisableParameters = @{
            Name        = $RuleName
            ErrorAction = "Stop"
        }

        Disable-NetFirewallRule @DisableParameters


        # Luego sustituimos cualquier origen anterior por
        # un marcador seguro.

        $AddressFilter = Get-RDPAddressFilter


        $FilterParameters = @{
            RemoteAddress = $EmptyRemoteAddress
            ErrorAction   = "Stop"
        }


        $AddressFilter |
            Set-NetFirewallAddressFilter @FilterParameters |
            Out-Null


        # Verificacion final.

        $VerificationRule = Get-RDPRule


        if ([string]$VerificationRule.Enabled -eq "True") {

            throw "La regla continua habilitada."
        }


        return
    }


    # --------------------------------------------------------
    # CONFIGURAR LISTA
    # --------------------------------------------------------

    $AddressFilter = Get-RDPAddressFilter


    $FilterParameters = @{
        RemoteAddress = $CleanList
        ErrorAction   = "Stop"
    }


    $AddressFilter |
        Set-NetFirewallAddressFilter @FilterParameters |
        Out-Null


    # --------------------------------------------------------
    # HABILITAR O DESHABILITAR SEGUN CORRESPONDA
    # --------------------------------------------------------

    if ($EnableRule) {

        $EnableParameters = @{
            Name        = $RuleName
            ErrorAction = "Stop"
        }

        Enable-NetFirewallRule @EnableParameters
    }
    else {

        $DisableParameters = @{
            Name        = $RuleName
            ErrorAction = "Stop"
        }

        Disable-NetFirewallRule @DisableParameters
    }
}


# ============================================================
# 14. FUNCION: MOSTRAR ESTADO
# ============================================================

function Show-RDPStatus {

    try {

        $Rule = Get-RDPRule

        $PortFilter = $Rule |
            Get-NetFirewallPortFilter -ErrorAction Stop


        $ConfiguredAddresses = @(
            Get-ConfiguredRemoteAddresses
        )


        $BlockedAddresses = @(
            Get-BlockedOrigins
        )


        Write-Host ""
        Write-Host "========================================================" -ForegroundColor Cyan
        Write-Host " ESTADO ACTUAL RDP" -ForegroundColor Cyan
        Write-Host "========================================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "Servidor  : $env:COMPUTERNAME"
        Write-Host "Regla     : $RuleName"
        Write-Host "Estado    : $($Rule.Enabled)"
        Write-Host "Perfil    : $($Rule.Profile)"
        Write-Host "Accion    : $($Rule.Action)"
        Write-Host "Direccion : $($Rule.Direction)"
        Write-Host "Protocolo : $($PortFilter.Protocol)"
        Write-Host "Puerto    : $($PortFilter.LocalPort)"

        Write-Host ""


        if ([string]$Rule.Enabled -eq "True") {

            Write-Host "Origenes AUTORIZADOS actualmente:" -ForegroundColor Yellow
            Write-Host ""


            if ($ConfiguredAddresses.Count -eq 0) {

                Write-Host "  Ninguno." -ForegroundColor Green
            }
            else {

                $Index = 1


                foreach ($Address in $ConfiguredAddresses) {

                    Write-Host "  $Index. $Address" -ForegroundColor Green

                    $Index++
                }
            }
        }
        else {

            Write-Host "Origenes AUTORIZADOS actualmente:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Ninguno." -ForegroundColor Green
            Write-Host ""

            Write-Host "[INFO] La regla RDP esta deshabilitada." -ForegroundColor Yellow


            if ($BlockedAddresses.Count -gt 0) {

                Write-Host ""
                Write-Host "Origenes guardados para restauracion:" -ForegroundColor Cyan
                Write-Host ""


                $Index = 1


                foreach ($Address in $BlockedAddresses) {

                    Write-Host "  $Index. $Address"

                    $Index++
                }


                Write-Host ""
                Write-Host "Estos origenes NO tienen acceso actualmente." -ForegroundColor DarkYellow
            }
        }


        Write-Host ""
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible obtener el estado." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
    }
}


# ============================================================
# 15. FUNCION: AGREGAR ORIGEN
# ============================================================

function Add-AllowedRemoteAddress {

    Write-Host ""
    Write-Host "----- Agregar origen permitido -----" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Formatos aceptados:"
    Write-Host ""
    Write-Host "  IPv4       : 192.168.20.50"
    Write-Host "  CIDR       : 192.168.20.0/24"
    Write-Host "  IP/Mascara : 192.168.20.0/255.255.255.0"
    Write-Host ""


    $NewAddress = Read-Host "Ingrese el origen"


    if ([string]::IsNullOrWhiteSpace($NewAddress)) {

        Write-Host ""
        Write-Host "[ERROR] Debe ingresar un origen." -ForegroundColor Red

        return
    }


    $NewAddress = $NewAddress.Trim()


    if (-not (Test-ValidRemoteAddress -Address $NewAddress)) {

        Write-Host ""
        Write-Host "[ERROR] El origen ingresado no es valido." -ForegroundColor Red

        return
    }


    try {

        $Rule = Get-RDPRule

        $CurrentAddresses = @(
            Get-ConfiguredRemoteAddresses
        )


        $BlockedAddresses = @(
            Get-BlockedOrigins
        )


        # Si existe una lista temporal bloqueada,
        # se utiliza como base para no perderla.

        if ($BlockedAddresses.Count -gt 0) {

            $BaseAddresses = $BlockedAddresses
        }
        else {

            $BaseAddresses = $CurrentAddresses
        }


        if ($BaseAddresses -contains $NewAddress) {

            Write-Host ""
            Write-Host "[EXISTE] El origen ya se encuentra configurado." -ForegroundColor Yellow
            Write-Host "         $NewAddress"

            return
        }


        Write-Host ""
        Write-Host "Se agregara:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  $NewAddress"
        Write-Host ""


        $Confirmation = Read-Host "Confirma agregar este origen? (S/N)"


        if ($Confirmation -notmatch '^[Ss]$') {

            Write-Host ""
            Write-Host "[CANCELADO] No se realizaron cambios." -ForegroundColor Yellow

            return
        }


        $UpdatedAddresses = @(
            $BaseAddresses + $NewAddress |
                Sort-Object -Unique
        )


        $SetParameters = @{
            AddressList = $UpdatedAddresses
            EnableRule  = $true
        }

        Set-RDPRemoteAddresses @SetParameters


        # Si habia una lista temporal, ya fue restaurada
        # junto con el nuevo origen.

        Remove-BlockedOriginsFile


        Write-Host ""
        Write-Host "[OK] Origen agregado correctamente." -ForegroundColor Green
        Write-Host "[AGREGADO] $NewAddress" -ForegroundColor Green
        Write-Host "[OK] Regla RDP habilitada." -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible agregar el origen." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


# ============================================================
# 16. FUNCION: ELIMINAR ORIGEN
# ============================================================

function Remove-AllowedRemoteAddress {

    Write-Host ""
    Write-Host "----- Eliminar origen permitido -----" -ForegroundColor Cyan
    Write-Host ""


    try {

        $Rule = Get-RDPRule

        $BlockedAddresses = @(
            Get-BlockedOrigins
        )


        # Si existe una lista de bloqueo temporal,
        # se permite editar esa lista.

        if ($BlockedAddresses.Count -gt 0) {

            $Addresses = $BlockedAddresses
            $EditingBlockedList = $true
        }
        else {

            $Addresses = @(
                Get-ConfiguredRemoteAddresses
            )

            $EditingBlockedList = $false
        }


        if ($Addresses.Count -eq 0) {

            Write-Host "[INFO] No existen origenes para eliminar." -ForegroundColor Yellow

            return
        }


        Write-Host "Origenes disponibles:" -ForegroundColor Yellow
        Write-Host ""


        for ($Index = 0; $Index -lt $Addresses.Count; $Index++) {

            $DisplayNumber = $Index + 1

            Write-Host "  $DisplayNumber. $($Addresses[$Index])"
        }


        Write-Host ""


        $Selection = Read-Host "Seleccione el numero del origen a eliminar"


        $SelectedNumber = 0


        if (
            -not [int]::TryParse(
                $Selection,
                [ref]$SelectedNumber
            )
        ) {

            Write-Host ""
            Write-Host "[ERROR] Debe ingresar un numero valido." -ForegroundColor Red

            return
        }


        if (
            $SelectedNumber -lt 1 -or
            $SelectedNumber -gt $Addresses.Count
        ) {

            Write-Host ""
            Write-Host "[ERROR] La seleccion esta fuera de rango." -ForegroundColor Red

            return
        }


        $SelectedIndex = $SelectedNumber - 1

        $RemoveAddress = $Addresses[$SelectedIndex]


        Write-Host ""
        Write-Host "Se eliminara:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  $RemoveAddress"
        Write-Host ""


        if ($Addresses.Count -eq 1) {

            Write-Host "[ADVERTENCIA] Este es el ultimo origen." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Despues de eliminarlo no quedara ningun origen autorizado." -ForegroundColor Yellow
            Write-Host "La regla RDP quedara deshabilitada." -ForegroundColor Yellow
            Write-Host ""
        }


        $Confirmation = Read-Host "Confirma la eliminacion? (S/N)"


        if ($Confirmation -notmatch '^[Ss]$') {

            Write-Host ""
            Write-Host "[CANCELADO] No se realizaron cambios." -ForegroundColor Yellow

            return
        }


        $UpdatedAddresses = @()


        for ($Index = 0; $Index -lt $Addresses.Count; $Index++) {

            if ($Index -ne $SelectedIndex) {

                $UpdatedAddresses += $Addresses[$Index]
            }
        }


        # ----------------------------------------------------
        # EDITANDO LISTA BLOQUEADA
        # ----------------------------------------------------

        if ($EditingBlockedList) {

            if ($UpdatedAddresses.Count -eq 0) {

                Remove-BlockedOriginsFile

                $SetParameters = @{
                    AddressList = @()
                    EnableRule  = $false
                }

                Set-RDPRemoteAddresses @SetParameters
            }
            else {

                Save-BlockedOrigins `
                    -AddressList $UpdatedAddresses


                # La regla continua bloqueada.
                # No se habilita en esta operacion.

                $SetParameters = @{
                    AddressList = @()
                    EnableRule  = $false
                }

                Set-RDPRemoteAddresses @SetParameters
            }
        }

        # ----------------------------------------------------
        # EDITANDO LISTA ACTIVA
        # ----------------------------------------------------

        else {

            if ($UpdatedAddresses.Count -eq 0) {

                $SetParameters = @{
                    AddressList = @()
                    EnableRule  = $false
                }

                Set-RDPRemoteAddresses @SetParameters
            }
            else {

                $SetParameters = @{
                    AddressList = $UpdatedAddresses
                    EnableRule  = $true
                }

                Set-RDPRemoteAddresses @SetParameters
            }
        }


        Write-Host ""
        Write-Host "[OK] Origen eliminado correctamente." -ForegroundColor Green
        Write-Host "[ELIMINADO] $RemoveAddress" -ForegroundColor Green


        if ($UpdatedAddresses.Count -eq 0) {

            Write-Host "[OK] No quedan origenes autorizados." -ForegroundColor Green
            Write-Host "[OK] Regla RDP deshabilitada." -ForegroundColor Green
        }
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible eliminar el origen." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


# ============================================================
# 17. FUNCION: BLOQUEAR TODOS
# ============================================================

function Block-AllRemoteAddresses {

    Write-Host ""
    Write-Host "----- Bloquear todos los origenes -----" -ForegroundColor Red
    Write-Host ""


    try {

        $Rule = Get-RDPRule


        if ([string]$Rule.Enabled -ne "True") {

            Write-Host "[INFO] La regla ya esta deshabilitada." -ForegroundColor Yellow


            $ExistingBackup = @(
                Get-BlockedOrigins
            )


            if ($ExistingBackup.Count -gt 0) {

                Write-Host "[INFO] Ya existe una lista guardada para restauracion." -ForegroundColor Yellow
            }


            return
        }


        $CurrentAddresses = @(
            Get-ConfiguredRemoteAddresses
        )


        if ($CurrentAddresses.Count -eq 0) {

            Write-Host "[INFO] No existen origenes autorizados." -ForegroundColor Yellow

            return
        }


        Write-Host "Se bloquearan temporalmente:" -ForegroundColor Yellow
        Write-Host ""


        foreach ($Address in $CurrentAddresses) {

            Write-Host "  - $Address"
        }


        Write-Host ""
        Write-Host "La lista sera guardada para poder restaurarla." -ForegroundColor Cyan
        Write-Host ""


        $Confirmation = Read-Host "Confirma bloquear todos los origenes? (S/N)"


        if ($Confirmation -notmatch '^[Ss]$') {

            Write-Host ""
            Write-Host "[CANCELADO] No se realizaron cambios." -ForegroundColor Yellow

            return
        }


        # Guardar primero la lista.
        # Solo despues se modifica el firewall.

        Save-BlockedOrigins `
            -AddressList $CurrentAddresses


        $SetParameters = @{
            AddressList = @()
            EnableRule  = $false
        }

        Set-RDPRemoteAddresses @SetParameters


        Write-Host ""
        Write-Host "[OK] Todos los origenes fueron bloqueados." -ForegroundColor Green
        Write-Host "[OK] Regla RDP deshabilitada." -ForegroundColor Green
        Write-Host "[OK] Lista guardada para restauracion." -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible bloquear los origenes." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


# ============================================================
# 18. FUNCION: HABILITAR ORIGENES ALMACENADOS
# ============================================================

function Enable-StoredRemoteAddresses {

    Write-Host ""
    Write-Host "----- Habilitar origenes almacenados -----" -ForegroundColor Cyan
    Write-Host ""


    try {

        $StoredAddresses = @(
            Get-BlockedOrigins
        )


        if ($StoredAddresses.Count -eq 0) {

            Write-Host "[INFO] No existe una lista bloqueada para restaurar." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Utilice la opcion 2 para agregar un nuevo origen." -ForegroundColor Yellow

            return
        }


        Write-Host "Se restauraran los siguientes origenes:" -ForegroundColor Cyan
        Write-Host ""


        foreach ($Address in $StoredAddresses) {

            Write-Host "  - $Address"
        }


        Write-Host ""


        $Confirmation = Read-Host "Confirma restaurar y habilitar estos origenes? (S/N)"


        if ($Confirmation -notmatch '^[Ss]$') {

            Write-Host ""
            Write-Host "[CANCELADO] No se realizaron cambios." -ForegroundColor Yellow

            return
        }


        $SetParameters = @{
            AddressList = $StoredAddresses
            EnableRule  = $true
        }

        Set-RDPRemoteAddresses @SetParameters


        # Solo eliminar backup despues de restaurar correctamente.

        Remove-BlockedOriginsFile


        Write-Host ""
        Write-Host "[OK] Origenes restaurados correctamente." -ForegroundColor Green
        Write-Host "[OK] Regla RDP habilitada." -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible restaurar los origenes." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


# ============================================================
# 19. COMPROBACIONES INICIALES
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Recoleccion UY - Gestion de acceso RDP" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


if (-not (Test-IsAdministrator)) {

    Write-Host "[ERROR] Debe ejecutar PowerShell como Administrador." -ForegroundColor Red

    exit 1
}


Write-Host "[OK] Privilegios administrativos verificados." -ForegroundColor Green


try {

    Import-Module NetSecurity -ErrorAction Stop

    Write-Host "[OK] Modulo NetSecurity cargado." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible cargar NetSecurity." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


try {

    $InitialRule = Get-RDPRule

    Write-Host "[OK] Regla encontrada: $RuleName" -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No existe la regla:" -ForegroundColor Red
    Write-Host "        $RuleName" -ForegroundColor Red

    exit 1
}


try {

    $PortFilter = $InitialRule |
        Get-NetFirewallPortFilter -ErrorAction Stop


    if ([string]$InitialRule.Direction -ne "Inbound") {

        throw "La regla no es Inbound."
    }


    if ([string]$InitialRule.Action -ne "Allow") {

        throw "La regla no tiene Action=Allow."
    }


    if ([string]$PortFilter.Protocol -ne "TCP") {

        throw "La regla no utiliza TCP."
    }


    if ([string]$PortFilter.LocalPort -ne "3389") {

        throw "La regla no utiliza el puerto 3389."
    }


    Write-Host "[OK] Regla validada: TCP/3389 - Inbound - Allow." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] La regla no tiene la configuracion esperada." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


try {

    Initialize-DataDirectory
}
catch {

    Write-Host "[ERROR] No fue posible preparar el directorio de datos." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 20. MENU PRINCIPAL
# ============================================================

do {

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host " Recoleccion UY - Gestion de acceso RDP" -ForegroundColor Cyan
    Write-Host " $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "1. Ver origenes permitidos"
    Write-Host "2. Agregar origen permitido"
    Write-Host "3. Eliminar origen permitido"
    Write-Host "4. Bloquear todos los origenes"
    Write-Host "5. Habilitar origenes almacenados"
    Write-Host "6. Salir"
    Write-Host ""


    $Option = Read-Host "Seleccione una opcion"


    switch ($Option) {

        "1" {

            Show-RDPStatus
        }


        "2" {

            Add-AllowedRemoteAddress
        }


        "3" {

            Remove-AllowedRemoteAddress
        }


        "4" {

            Block-AllRemoteAddresses
        }


        "5" {

            Enable-StoredRemoteAddresses
        }


        "6" {

            Write-Host ""
            Write-Host "Saliendo del gestor RDP." -ForegroundColor Green
        }


        default {

            Write-Host ""
            Write-Host "[ERROR] Opcion invalida." -ForegroundColor Red
        }
    }

}
while ($Option -ne "6")


# ============================================================
# 21. FIN
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " GESTION RDP FINALIZADA" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
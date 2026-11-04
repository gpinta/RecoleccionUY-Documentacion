<#
.SYNOPSIS
    Configura la politica de contrasenas del dominio neltek.uy
    y administra la expiracion de contrasenas para cuentas
    de servicio y cuentas privilegiadas de Recoleccion UY.

.DESCRIPCION
    Configura la politica predeterminada de contrasenas:

        - Longitud minima: 12 caracteres
        - Historial: 12 contrasenas
        - Edad maxima: 90 dias
        - Edad minima: 1 dia
        - Complejidad: habilitada
        - Cifrado reversible: deshabilitado
        - Bloqueo tras 5 intentos fallidos
        - Duracion del bloqueo: 15 minutos
        - Reinicio del contador: 15 minutos

    Tambien administra:

        OU=CuentasServicio
        OU=CuentasPrivilegiadas

    Para estas OUs se puede indicar independientemente:

        PasswordNeverExpires = $true

    o:

        PasswordNeverExpires = $false

    IMPORTANTE:

    En las variables:

        $ServiceAccountsPasswordNeverExpires
        $PrivilegedAccountsPasswordNeverExpires

    $true:
        establece PasswordNeverExpires = True

    $false:
        establece PasswordNeverExpires = False

    A diferencia de otros interruptores utilizados en el proyecto,
    $false aqui NO significa "no modificar".

    Significa que el script configura explicitamente:

        PasswordNeverExpires = False

    El script:

        - NO cambia contrasenas existentes.
        - NO solicita contrasenas.
        - NO muestra contrasenas.
        - NO crea usuarios.
        - NO crea grupos.
        - NO crea OUs.
        - NO crea GPOs.
        - NO crea Fine-Grained Password Policies.

.REQUISITOS
    - Active Directory operativo.
    - Modulo ActiveDirectory disponible.
    - OUs de Recoleccion UY creadas.
    - Ejecutar con privilegios suficientes.

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
# 2. OUs ESPECIALES
# ============================================================

$OUCuentasServicio = "OU=CuentasServicio,OU=RecoleccionUY,$DomainDN"

$OUCuentasPrivilegiadas = "OU=CuentasPrivilegiadas,OU=RecoleccionUY,$DomainDN"


# ============================================================
# 3. POLITICA DE CONTRASENAS DEL DOMINIO
# ============================================================

$MinPasswordLength = 12

$PasswordHistoryCount = 12

$MinPasswordAgeDays = 1

$MaxPasswordAgeDays = 90

$ComplexityEnabled = $true

$ReversibleEncryptionEnabled = $false


# ============================================================
# 4. BLOQUEO DE CUENTA
# ============================================================

$LockoutThreshold = 5

$LockoutDurationMinutes = 15

$LockoutObservationWindowMinutes = 15


# ============================================================
# 5. EXPIRACION DE CUENTAS ESPECIALES
# ============================================================

#
# IMPORTANTE:
#
# $true
#     -> PasswordNeverExpires = True
#
# $false
#     -> PasswordNeverExpires = False
#
# ------------------------------------------------------------
#
# CONFIGURACION ACTUAL DE LABORATORIO:
#
# Cuentas de servicio:
#     PasswordNeverExpires = True
#
# Cuentas privilegiadas:
#     PasswordNeverExpires = True
#
# ------------------------------------------------------------
#
# CONFIGURACION RECOMENDADA PARA PRODUCCION:
#
# $ServiceAccountsPasswordNeverExpires = $true
#
# $PrivilegedAccountsPasswordNeverExpires = $false
#
# ============================================================

$ServiceAccountsPasswordNeverExpires = $true

$PrivilegedAccountsPasswordNeverExpires = $true


# ============================================================
# 6. INICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Recoleccion UY - Politica de Contrasenas" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# 7. VERIFICAR EJECUCION COMO ADMINISTRADOR
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
# 8. CARGAR ACTIVE DIRECTORY
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
# 9. VERIFICAR DOMINIO
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
# 10. FUNCION: VERIFICAR OU
# ============================================================

function Test-OUExists {

    param(
        [Parameter(Mandatory=$true)]
        [string]$OUPath
    )

    try {

        $OUParameters = @{
            Identity    = $OUPath
            ErrorAction = "Stop"
        }

        $OU = Get-ADOrganizationalUnit @OUParameters

        return $true
    }
    catch {

        return $false
    }
}


# ============================================================
# 11. VERIFICAR OUs
# ============================================================

Write-Host ""
Write-Host "----- Verificacion de OUs -----" -ForegroundColor Cyan
Write-Host ""


$ServiceOUTestParameters = @{
    OUPath = $OUCuentasServicio
}

if (-not (Test-OUExists @ServiceOUTestParameters)) {

    Write-Host "[ERROR] No existe la OU de cuentas de servicio:" -ForegroundColor Red
    Write-Host ""
    Write-Host "  $OUCuentasServicio"

    exit 1
}

Write-Host "[OK] OU CuentasServicio encontrada." -ForegroundColor Green


$PrivilegedOUTestParameters = @{
    OUPath = $OUCuentasPrivilegiadas
}

if (-not (Test-OUExists @PrivilegedOUTestParameters)) {

    Write-Host "[ERROR] No existe la OU de cuentas privilegiadas:" -ForegroundColor Red
    Write-Host ""
    Write-Host "  $OUCuentasPrivilegiadas"

    exit 1
}

Write-Host "[OK] OU CuentasPrivilegiadas encontrada." -ForegroundColor Green


# ============================================================
# 12. OBTENER POLITICA ACTUAL
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " POLITICA ACTUAL DEL DOMINIO" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


try {

    $CurrentPolicyParameters = @{
        Identity    = $DomainName
        ErrorAction = "Stop"
    }

    $CurrentPolicy = Get-ADDefaultDomainPasswordPolicy @CurrentPolicyParameters


    Write-Host "Longitud minima             : $($CurrentPolicy.MinPasswordLength)"
    Write-Host "Historial                   : $($CurrentPolicy.PasswordHistoryCount)"
    Write-Host "Edad minima                 : $($CurrentPolicy.MinPasswordAge)"
    Write-Host "Edad maxima                 : $($CurrentPolicy.MaxPasswordAge)"
    Write-Host "Complejidad                 : $($CurrentPolicy.ComplexityEnabled)"
    Write-Host "Cifrado reversible          : $($CurrentPolicy.ReversibleEncryptionEnabled)"
    Write-Host "Intentos antes de bloqueo   : $($CurrentPolicy.LockoutThreshold)"
    Write-Host "Duracion del bloqueo        : $($CurrentPolicy.LockoutDuration)"
    Write-Host "Ventana de observacion      : $($CurrentPolicy.LockoutObservationWindow)"
}
catch {

    Write-Host "[ERROR] No fue posible obtener la politica actual." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 13. MOSTRAR CONFIGURACION DESEADA
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " CONFIGURACION DESEADA" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Politica de contrasenas:"
Write-Host ""

Write-Host "  Longitud minima            : $MinPasswordLength"
Write-Host "  Historial                  : $PasswordHistoryCount"
Write-Host "  Edad minima                : $MinPasswordAgeDays dia(s)"
Write-Host "  Edad maxima                : $MaxPasswordAgeDays dia(s)"
Write-Host "  Complejidad                : $ComplexityEnabled"
Write-Host "  Cifrado reversible         : $ReversibleEncryptionEnabled"
Write-Host "  Bloqueo                    : $LockoutThreshold intentos"
Write-Host "  Duracion bloqueo           : $LockoutDurationMinutes minutos"
Write-Host "  Reinicio contador          : $LockoutObservationWindowMinutes minutos"

Write-Host ""
Write-Host "Cuentas de servicio:"
Write-Host ""
Write-Host "  PasswordNeverExpires       : $ServiceAccountsPasswordNeverExpires"

Write-Host ""
Write-Host "Cuentas privilegiadas:"
Write-Host ""
Write-Host "  PasswordNeverExpires       : $PrivilegedAccountsPasswordNeverExpires"

Write-Host ""


# ============================================================
# 14. OBTENER CUENTAS ESPECIALES
# ============================================================

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " CUENTAS DETECTADAS" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


# ------------------------------------------------------------
# CUENTAS DE SERVICIO
# ------------------------------------------------------------

try {

    $ServiceAccountParameters = @{
        SearchBase  = $OUCuentasServicio
        SearchScope = "Subtree"
        Filter      = "*"
        Properties  = @(
            "PasswordNeverExpires",
            "Enabled"
        )
        ErrorAction = "Stop"
    }

    $ServiceAccounts = @(
        Get-ADUser @ServiceAccountParameters
    )
}
catch {

    Write-Host "[ERROR] No fue posible consultar CuentasServicio." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ------------------------------------------------------------
# CUENTAS PRIVILEGIADAS
# ------------------------------------------------------------

try {

    $PrivilegedAccountParameters = @{
        SearchBase  = $OUCuentasPrivilegiadas
        SearchScope = "Subtree"
        Filter      = "*"
        Properties  = @(
            "PasswordNeverExpires",
            "Enabled"
        )
        ErrorAction = "Stop"
    }

    $PrivilegedAccounts = @(
        Get-ADUser @PrivilegedAccountParameters
    )
}
catch {

    Write-Host "[ERROR] No fue posible consultar CuentasPrivilegiadas." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 15. MOSTRAR CUENTAS DETECTADAS
# ============================================================

Write-Host "Cuentas de servicio:" -ForegroundColor Cyan


if ($ServiceAccounts.Count -eq 0) {

    Write-Host "  Ninguna." -ForegroundColor Yellow
}
else {

    foreach ($Account in ($ServiceAccounts | Sort-Object SamAccountName)) {

        Write-Host "  - $($Account.SamAccountName)"
    }
}


Write-Host ""
Write-Host "Cuentas privilegiadas:" -ForegroundColor Cyan


if ($PrivilegedAccounts.Count -eq 0) {

    Write-Host "  Ninguna." -ForegroundColor Yellow
}
else {

    foreach ($Account in ($PrivilegedAccounts | Sort-Object SamAccountName)) {

        Write-Host "  - $($Account.SamAccountName)"
    }
}


# ============================================================
# 16. CONFIRMACION
# ============================================================

Write-Host ""

$Confirmation = Read-Host "Aplicar esta configuracion al dominio $DomainName? (S/N)"


if ($Confirmation -notmatch '^[Ss]$') {

    Write-Host ""
    Write-Host "[CANCELADO] No se realizaron cambios." -ForegroundColor Yellow
    Write-Host ""

    exit 0
}


# ============================================================
# 17. CONVERTIR TIEMPOS
# ============================================================

try {

    $MinPasswordAgeParameters = @{
        Days = $MinPasswordAgeDays
    }

    $MinPasswordAge = New-TimeSpan @MinPasswordAgeParameters


    $MaxPasswordAgeParameters = @{
        Days = $MaxPasswordAgeDays
    }

    $MaxPasswordAge = New-TimeSpan @MaxPasswordAgeParameters


    $LockoutDurationParameters = @{
        Minutes = $LockoutDurationMinutes
    }

    $LockoutDuration = New-TimeSpan @LockoutDurationParameters


    $LockoutObservationParameters = @{
        Minutes = $LockoutObservationWindowMinutes
    }

    $LockoutObservationWindow = New-TimeSpan @LockoutObservationParameters
}
catch {

    Write-Host "[ERROR] No fue posible convertir los valores de tiempo." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 18. CONFIGURAR POLITICA DEL DOMINIO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " CONFIGURANDO POLITICA DEL DOMINIO" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


try {

    $PasswordPolicyParameters = @{
        Identity                      = $DomainName
        MinPasswordLength             = $MinPasswordLength
        PasswordHistoryCount          = $PasswordHistoryCount
        MinPasswordAge                = $MinPasswordAge
        MaxPasswordAge                = $MaxPasswordAge
        ComplexityEnabled             = $ComplexityEnabled
        ReversibleEncryptionEnabled   = $ReversibleEncryptionEnabled
        LockoutThreshold              = $LockoutThreshold
        LockoutDuration               = $LockoutDuration
        LockoutObservationWindow      = $LockoutObservationWindow
        ErrorAction                   = "Stop"
    }

    Set-ADDefaultDomainPasswordPolicy @PasswordPolicyParameters


    Write-Host "[OK] Politica de contrasenas configurada." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible configurar la politica." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 19. CONFIGURAR CUENTAS DE SERVICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " CUENTAS DE SERVICIO" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


if ($ServiceAccounts.Count -eq 0) {

    Write-Host "[INFO] No existen cuentas de servicio." -ForegroundColor Yellow
}
else {

    foreach ($Account in ($ServiceAccounts | Sort-Object SamAccountName)) {

        Write-Host "Cuenta: $($Account.SamAccountName)"
        Write-Host "  Estado actual : $($Account.PasswordNeverExpires)"
        Write-Host "  Estado deseado: $ServiceAccountsPasswordNeverExpires"


        if ($Account.PasswordNeverExpires -eq $ServiceAccountsPasswordNeverExpires) {

            Write-Host "  [OK] No requiere cambios." -ForegroundColor Green
        }
        else {

            try {

                $ServiceControlParameters = @{
                    Identity             = $Account
                    PasswordNeverExpires = $ServiceAccountsPasswordNeverExpires
                    ErrorAction          = "Stop"
                }

                Set-ADAccountControl @ServiceControlParameters


                Write-Host "  [MODIFICADO] PasswordNeverExpires = $ServiceAccountsPasswordNeverExpires" -ForegroundColor Green
            }
            catch {

                Write-Host "  [ERROR] No fue posible modificar la cuenta." -ForegroundColor Red
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        Write-Host ""
    }
}


# ============================================================
# 20. CONFIGURAR CUENTAS PRIVILEGIADAS
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " CUENTAS PRIVILEGIADAS" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


if ($PrivilegedAccounts.Count -eq 0) {

    Write-Host "[INFO] No existen cuentas privilegiadas." -ForegroundColor Yellow
}
else {

    foreach ($Account in ($PrivilegedAccounts | Sort-Object SamAccountName)) {

        Write-Host "Cuenta: $($Account.SamAccountName)"
        Write-Host "  Estado actual : $($Account.PasswordNeverExpires)"
        Write-Host "  Estado deseado: $PrivilegedAccountsPasswordNeverExpires"


        if ($Account.PasswordNeverExpires -eq $PrivilegedAccountsPasswordNeverExpires) {

            Write-Host "  [OK] No requiere cambios." -ForegroundColor Green
        }
        else {

            try {

                $PrivilegedControlParameters = @{
                    Identity             = $Account
                    PasswordNeverExpires = $PrivilegedAccountsPasswordNeverExpires
                    ErrorAction          = "Stop"
                }

                Set-ADAccountControl @PrivilegedControlParameters


                Write-Host "  [MODIFICADO] PasswordNeverExpires = $PrivilegedAccountsPasswordNeverExpires" -ForegroundColor Green
            }
            catch {

                Write-Host "  [ERROR] No fue posible modificar la cuenta." -ForegroundColor Red
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        Write-Host ""
    }
}


# ============================================================
# 21. VERIFICAR POLITICA RESULTANTE
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VERIFICACION FINAL - POLITICA" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


try {

    $FinalPolicyParameters = @{
        Identity    = $DomainName
        ErrorAction = "Stop"
    }

    $FinalPolicy = Get-ADDefaultDomainPasswordPolicy @FinalPolicyParameters


    Write-Host "Longitud minima             : $($FinalPolicy.MinPasswordLength)"
    Write-Host "Historial                   : $($FinalPolicy.PasswordHistoryCount)"
    Write-Host "Edad minima                 : $($FinalPolicy.MinPasswordAge)"
    Write-Host "Edad maxima                 : $($FinalPolicy.MaxPasswordAge)"
    Write-Host "Complejidad                 : $($FinalPolicy.ComplexityEnabled)"
    Write-Host "Cifrado reversible          : $($FinalPolicy.ReversibleEncryptionEnabled)"
    Write-Host "Intentos antes de bloqueo   : $($FinalPolicy.LockoutThreshold)"
    Write-Host "Duracion del bloqueo        : $($FinalPolicy.LockoutDuration)"
    Write-Host "Ventana de observacion      : $($FinalPolicy.LockoutObservationWindow)"
}
catch {

    Write-Host "[ERROR] No fue posible verificar la politica final." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}


# ============================================================
# 22. VERIFICAR CUENTAS DE SERVICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VERIFICACION - CUENTAS DE SERVICIO" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


try {

    $FinalServiceAccountParameters = @{
        SearchBase  = $OUCuentasServicio
        SearchScope = "Subtree"
        Filter      = "*"
        Properties  = @(
            "PasswordNeverExpires",
            "Enabled"
        )
        ErrorAction = "Stop"
    }

    $FinalServiceAccounts = @(
        Get-ADUser @FinalServiceAccountParameters
    )


    if ($FinalServiceAccounts.Count -eq 0) {

        Write-Host "No existen cuentas de servicio." -ForegroundColor Yellow
    }
    else {

        foreach ($Account in ($FinalServiceAccounts | Sort-Object SamAccountName)) {

            Write-Host "Cuenta: $($Account.SamAccountName)"
            Write-Host "  Activa               : $($Account.Enabled)"
            Write-Host "  PasswordNeverExpires : $($Account.PasswordNeverExpires)"
            Write-Host ""
        }
    }
}
catch {

    Write-Host "[ERROR] No fue posible verificar las cuentas de servicio." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}


# ============================================================
# 23. VERIFICAR CUENTAS PRIVILEGIADAS
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VERIFICACION - CUENTAS PRIVILEGIADAS" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


try {

    $FinalPrivilegedAccountParameters = @{
        SearchBase  = $OUCuentasPrivilegiadas
        SearchScope = "Subtree"
        Filter      = "*"
        Properties  = @(
            "PasswordNeverExpires",
            "Enabled"
        )
        ErrorAction = "Stop"
    }

    $FinalPrivilegedAccounts = @(
        Get-ADUser @FinalPrivilegedAccountParameters
    )


    if ($FinalPrivilegedAccounts.Count -eq 0) {

        Write-Host "No existen cuentas privilegiadas." -ForegroundColor Yellow
    }
    else {

        foreach ($Account in ($FinalPrivilegedAccounts | Sort-Object SamAccountName)) {

            Write-Host "Cuenta: $($Account.SamAccountName)"
            Write-Host "  Activa               : $($Account.Enabled)"
            Write-Host "  PasswordNeverExpires : $($Account.PasswordNeverExpires)"
            Write-Host ""
        }
    }
}
catch {

    Write-Host "[ERROR] No fue posible verificar las cuentas privilegiadas." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}


# ============================================================
# 24. VALIDACION FINAL
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " VALIDACION DE CONFIGURACION" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


$PolicyCorrect = $true


if ($FinalPolicy) {

    if ($FinalPolicy.MinPasswordLength -ne $MinPasswordLength) {

        Write-Host "[ERROR] MinPasswordLength no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($FinalPolicy.PasswordHistoryCount -ne $PasswordHistoryCount) {

        Write-Host "[ERROR] PasswordHistoryCount no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($FinalPolicy.MinPasswordAge -ne $MinPasswordAge) {

        Write-Host "[ERROR] MinPasswordAge no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($FinalPolicy.MaxPasswordAge -ne $MaxPasswordAge) {

        Write-Host "[ERROR] MaxPasswordAge no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($FinalPolicy.ComplexityEnabled -ne $ComplexityEnabled) {

        Write-Host "[ERROR] ComplexityEnabled no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($FinalPolicy.ReversibleEncryptionEnabled -ne $ReversibleEncryptionEnabled) {

        Write-Host "[ERROR] ReversibleEncryptionEnabled no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($FinalPolicy.LockoutThreshold -ne $LockoutThreshold) {

        Write-Host "[ERROR] LockoutThreshold no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($FinalPolicy.LockoutDuration -ne $LockoutDuration) {

        Write-Host "[ERROR] LockoutDuration no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($FinalPolicy.LockoutObservationWindow -ne $LockoutObservationWindow) {

        Write-Host "[ERROR] LockoutObservationWindow no coincide." -ForegroundColor Red
        $PolicyCorrect = $false
    }


    if ($PolicyCorrect) {

        Write-Host "[OK] La politica del dominio coincide con la configuracion esperada." -ForegroundColor Green
    }
}
else {

    Write-Host "[ADVERTENCIA] No fue posible realizar la validacion automatica de la politica." -ForegroundColor Yellow

    $PolicyCorrect = $false
}


# ============================================================
# 25. FIN
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " CONFIGURACION FINALIZADA" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Politica del dominio:"
Write-Host ""

Write-Host "  Longitud minima    : $MinPasswordLength"
Write-Host "  Historial          : $PasswordHistoryCount"
Write-Host "  Expiracion         : $MaxPasswordAgeDays dias"
Write-Host "  Edad minima        : $MinPasswordAgeDays dia(s)"
Write-Host "  Complejidad        : $ComplexityEnabled"
Write-Host "  Bloqueo            : $LockoutThreshold intentos"
Write-Host "  Duracion bloqueo   : $LockoutDurationMinutes minutos"
Write-Host "  Reinicio contador  : $LockoutObservationWindowMinutes minutos"

Write-Host ""
Write-Host "Cuentas especiales:"
Write-Host ""

Write-Host "  Servicio:"
Write-Host "    PasswordNeverExpires = $ServiceAccountsPasswordNeverExpires"

Write-Host ""

Write-Host "  Privilegiadas:"
Write-Host "    PasswordNeverExpires = $PrivilegedAccountsPasswordNeverExpires"

Write-Host ""
Write-Host "IMPORTANTE:" -ForegroundColor Yellow
Write-Host ""
Write-Host "El script NO cambio ninguna contrasena existente."
Write-Host ""
Write-Host "Las nuevas contrasenas o futuros cambios deberan cumplir"
Write-Host "la politica de contrasenas configurada."
Write-Host ""
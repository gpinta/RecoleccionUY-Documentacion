<#
.SYNOPSIS
    Gestiona excepciones directas de equipos para:

        GPO_REC_Equipos_Inactividad

.DESCRIPCION
    Permite excluir cuentas de EQUIPO existentes de Active Directory
    de la aplicacion de la GPO:

        GPO_REC_Equipos_Inactividad

    NO crea:

        - Grupos.
        - Usuarios.
        - Equipos.
        - OUs.
        - GPOs.
        - Objetos auxiliares.

    La exclusion se implementa directamente sobre los permisos
    de la GPO mediante:

        Deny -> Apply Group Policy

    aplicado directamente a la cuenta de equipo seleccionada.

    Opciones:

        1. Listar equipos excluidos.
        2. Agregar equipo a exclusiones.
        3. Quitar equipo de exclusiones.
        4. Verificar un equipo.
        5. Salir.

.REQUISITOS
    Debe existir previamente:

        GPO_REC_Equipos_Inactividad

    Requiere:

        - Active Directory operativo.
        - Modulo ActiveDirectory.
        - Modulo GroupPolicy.
        - Permisos administrativos suficientes.

.NOTAS
    La GPO contiene Computer Configuration.

    Por ese motivo este script administra unicamente
    excepciones de EQUIPOS.

    Compatible con Windows Server 2012 R2.
#>


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

$DomainName = "neltek.uy"

$DomainDN = "DC=neltek,DC=uy"

$GPOName = "GPO_REC_Equipos_Inactividad"


# ============================================================
# 2. GUID: APPLY GROUP POLICY
# ============================================================

#
# Derecho extendido de Active Directory:
#
# Apply Group Policy
#
# GUID oficial:
#
# edacfd8f-ffb3-11d1-b41d-00a0c968f939
#

$ApplyGroupPolicyGuid = [Guid]"edacfd8f-ffb3-11d1-b41d-00a0c968f939"


# ============================================================
# 3. INICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Recoleccion UY - Excepciones GPO Inactividad" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Dominio : $DomainName"
Write-Host "GPO     : $GPOName"
Write-Host ""


# ============================================================
# 4. VERIFICAR EJECUCION COMO ADMINISTRADOR
# ============================================================

try {

    $CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

    $PrincipalParameters = @{
        TypeName     = "System.Security.Principal.WindowsPrincipal"
        ArgumentList = $CurrentIdentity
    }

    $CurrentPrincipal = New-Object @PrincipalParameters

    $AdministratorRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

    $IsAdministrator = $CurrentPrincipal.IsInRole($AdministratorRole)


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
# 5. CARGAR ACTIVE DIRECTORY
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
# 6. CARGAR GROUP POLICY
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
# 7. VERIFICAR DOMINIO
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
# 8. VERIFICAR GPO
# ============================================================

try {

    $GPOParameters = @{
        Name        = $GPOName
        Domain      = $DomainName
        ErrorAction = "Stop"
    }

    $GPO = Get-GPO @GPOParameters


    Write-Host "[OK] GPO encontrada: $GPOName" -ForegroundColor Green
    Write-Host "     ID: $($GPO.Id)"
}
catch {

    Write-Host "[ERROR] No existe o no se puede consultar la GPO:" -ForegroundColor Red
    Write-Host "        $GPOName"
    Write-Host ""
    Write-Host "Ejecute primero el script AD_GPO_Equipos_Inactividad.ps1." -ForegroundColor Yellow
    Write-Host ""

    exit 1
}


# ============================================================
# 9. RUTA ACTIVE DIRECTORY DE LA GPO
# ============================================================

$GPOGuid = $GPO.Id.ToString().ToUpper()

$GPOADPath = "AD:\CN={$GPOGuid},CN=Policies,CN=System,$DomainDN"


Write-Host ""
Write-Host "Ruta AD de la GPO:" -ForegroundColor Cyan
Write-Host "  $GPOADPath"
Write-Host ""


# ============================================================
# 10. VERIFICAR PSDrive AD
# ============================================================

try {

    $ADDrive = Get-PSDrive -Name "AD" -ErrorAction Stop

    Write-Host "[OK] PSDrive AD disponible." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No se encuentra el proveedor AD: de Active Directory." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 11. VERIFICAR ACCESO A LA ACL
# ============================================================

try {

    $ACLParameters = @{
        Path        = $GPOADPath
        ErrorAction = "Stop"
    }

    $TestACL = Get-Acl @ACLParameters


    Write-Host "[OK] ACL de la GPO accesible." -ForegroundColor Green
}
catch {

    Write-Host "[ERROR] No fue posible acceder a la ACL de la GPO." -ForegroundColor Red
    Write-Host ""
    Write-Host "Ruta:"
    Write-Host "  $GPOADPath"
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}


# ============================================================
# 12. FUNCION: OBTENER ACL ACTUAL
# ============================================================

function Get-CurrentGPOAcl {

    $Parameters = @{
        Path        = $GPOADPath
        ErrorAction = "Stop"
    }

    return Get-Acl @Parameters
}


# ============================================================
# 13. FUNCION: OBTENER SID DE UNA ACE
# ============================================================

function Get-ACESID {

    param(
        [Parameter(Mandatory=$true)]
        $ACE
    )


    try {

        $SIDType = [System.Security.Principal.SecurityIdentifier]

        $SID = $ACE.IdentityReference.Translate($SIDType)

        return $SID
    }
    catch {

        return $null
    }
}


# ============================================================
# 14. FUNCION: COMPROBAR SI UNA ACE ES EXCLUSION
# ============================================================

function Test-IsApplyGroupPolicyDeny {

    param(
        [Parameter(Mandatory=$true)]
        $ACE
    )


    $DenyType = [System.Security.AccessControl.AccessControlType]::Deny

    $ExtendedRight = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight


    $IsDeny = (
        $ACE.AccessControlType -eq $DenyType
    )


    $HasExtendedRight = (
        ($ACE.ActiveDirectoryRights -band $ExtendedRight) -ne 0
    )


    $IsApplyGroupPolicy = (
        $ACE.ObjectType -eq $ApplyGroupPolicyGuid
    )


    # Solo se consideran reglas creadas directamente
    # sobre la GPO. No se modifican reglas heredadas.

    $IsDirectRule = (
        $ACE.IsInherited -eq $false
    )


    return (
        $IsDeny -and
        $HasExtendedRight -and
        $IsApplyGroupPolicy -and
        $IsDirectRule
    )
}


# ============================================================
# 15. FUNCION: COMPROBAR SI UN EQUIPO ESTA EXCLUIDO
# ============================================================

function Test-ComputerExcluded {

    param(
        [Parameter(Mandatory=$true)]
        $Computer
    )


    try {

        $ACL = Get-CurrentGPOAcl
    }
    catch {

        throw
    }


    foreach ($ACE in $ACL.Access) {

        $ExclusionParameters = @{
            ACE = $ACE
        }

        if (-not (Test-IsApplyGroupPolicyDeny @ExclusionParameters)) {

            continue
        }


        $SIDParameters = @{
            ACE = $ACE
        }

        $ACESID = Get-ACESID @SIDParameters


        if (-not $ACESID) {

            continue
        }


        if ($ACESID.Value -eq $Computer.SID.Value) {

            return $true
        }
    }


    return $false
}


# ============================================================
# 16. FUNCION: OBTENER EQUIPO
# ============================================================

function Get-ComputerFromAD {

    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )


    $ComputerParameters = @{
        Identity    = $ComputerName
        Properties  = @(
            "DNSHostName",
            "Enabled",
            "SID",
            "DistinguishedName"
        )
        ErrorAction = "Stop"
    }


    return Get-ADComputer @ComputerParameters
}


# ============================================================
# 17. FUNCION: LISTAR EQUIPOS EXCLUIDOS
# ============================================================

function Show-ExcludedComputers {

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host " EQUIPOS EXCLUIDOS" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""


    try {

        $ACL = Get-CurrentGPOAcl
    }
    catch {

        Write-Host "[ERROR] No fue posible leer la ACL." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        return
    }


    $ExcludedComputers = @()


    foreach ($ACE in $ACL.Access) {

        $ExclusionParameters = @{
            ACE = $ACE
        }

        if (-not (Test-IsApplyGroupPolicyDeny @ExclusionParameters)) {

            continue
        }


        $SIDParameters = @{
            ACE = $ACE
        }

        $ACESID = Get-ACESID @SIDParameters


        if (-not $ACESID) {

            continue
        }


        try {

            $ComputerParameters = @{
                Identity    = $ACESID.Value
                Properties  = @(
                    "DNSHostName",
                    "Enabled",
                    "SID",
                    "DistinguishedName"
                )
                ErrorAction = "Stop"
            }

            $Computer = Get-ADComputer @ComputerParameters


            $ExcludedComputers += $Computer
        }
        catch {

            # La ACE puede corresponder a un usuario, grupo
            # u otro principal.
            #
            # Este script solo muestra cuentas de equipo.
        }
    }


    if ($ExcludedComputers.Count -eq 0) {

        Write-Host "No existen equipos excluidos." -ForegroundColor Yellow
        Write-Host ""

        return
    }


    $ExcludedComputers = @(
        $ExcludedComputers |
            Sort-Object Name -Unique
    )


    $ExcludedComputers |
        Select-Object Name, DNSHostName, Enabled, DistinguishedName |
        Format-Table -AutoSize


    Write-Host ""
    Write-Host "Total: $($ExcludedComputers.Count)" -ForegroundColor Cyan
    Write-Host ""
}


# ============================================================
# 18. FUNCION: AGREGAR EXCLUSION
# ============================================================

function Add-ExcludedComputer {

    Write-Host ""
    Write-Host "----- Agregar equipo a exclusiones -----" -ForegroundColor Cyan
    Write-Host ""


    $ComputerName = Read-Host "Ingrese el nombre del equipo"


    if ([string]::IsNullOrWhiteSpace($ComputerName)) {

        Write-Host ""
        Write-Host "[ERROR] Debe ingresar un nombre de equipo." -ForegroundColor Red

        return
    }


    $ComputerName = $ComputerName.Trim()


    try {

        $ComputerParameters = @{
            ComputerName = $ComputerName
        }

        $Computer = Get-ComputerFromAD @ComputerParameters
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No existe el equipo en Active Directory:" -ForegroundColor Red
        Write-Host "        $ComputerName"
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Red

        return
    }


    try {

        $TestParameters = @{
            Computer = $Computer
        }

        if (Test-ComputerExcluded @TestParameters) {

            Write-Host ""
            Write-Host "[EXISTE] El equipo ya esta excluido." -ForegroundColor Yellow
            Write-Host "         $($Computer.Name)"
            Write-Host ""

            return
        }
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible verificar las exclusiones actuales." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        return
    }


    Write-Host ""
    Write-Host "Equipo encontrado:" -ForegroundColor Cyan
    Write-Host "  Nombre : $($Computer.Name)"
    Write-Host "  DNS    : $($Computer.DNSHostName)"
    Write-Host "  Activo : $($Computer.Enabled)"
    Write-Host "  SID    : $($Computer.SID)"
    Write-Host "  OU/DN  : $($Computer.DistinguishedName)"
    Write-Host ""

    Write-Host "Se configurara:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Deny -> Apply Group Policy"
    Write-Host ""
    Write-Host "sobre:"
    Write-Host ""
    Write-Host "  $GPOName"
    Write-Host ""


    $Confirmation = Read-Host "Confirma agregar esta exclusion? (S/N)"


    if ($Confirmation -notmatch '^[Ss]$') {

        Write-Host ""
        Write-Host "[CANCELADO] No se realizaron cambios." -ForegroundColor Yellow
        Write-Host ""

        return
    }


    try {

        $ACL = Get-CurrentGPOAcl


        $ADRights = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight

        $AccessType = [System.Security.AccessControl.AccessControlType]::Deny

        $Inheritance = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::None


        $RuleArguments = @(
            $Computer.SID,
            $ADRights,
            $AccessType,
            $ApplyGroupPolicyGuid,
            $Inheritance
        )


        $RuleParameters = @{
            TypeName     = "System.DirectoryServices.ActiveDirectoryAccessRule"
            ArgumentList = $RuleArguments
        }

        $DenyRule = New-Object @RuleParameters


        $ACL.AddAccessRule($DenyRule)


        $SetACLParameters = @{
            Path        = $GPOADPath
            AclObject   = $ACL
            ErrorAction = "Stop"
        }

        Set-Acl @SetACLParameters


        # ----------------------------------------------------
        # Verificar que la exclusion se haya aplicado
        # ----------------------------------------------------

        $VerificationParameters = @{
            Computer = $Computer
        }

        $ExcludedAfterChange = Test-ComputerExcluded @VerificationParameters


        if (-not $ExcludedAfterChange) {

            throw "La ACL fue modificada pero no se encontro la exclusion esperada al verificar nuevamente."
        }


        Write-Host ""
        Write-Host "[AGREGADO] Equipo excluido correctamente." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Equipo : $($Computer.Name)"
        Write-Host "  GPO    : $GPOName"
        Write-Host ""
        Write-Host "Configurado:"
        Write-Host "  Deny -> Apply Group Policy"
        Write-Host ""
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible configurar la exclusion." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
    }
}


# ============================================================
# 19. FUNCION: QUITAR EXCLUSION
# ============================================================

function Remove-ExcludedComputer {

    Write-Host ""

    Show-ExcludedComputers


    $ComputerName = Read-Host "Ingrese el nombre del equipo a quitar"


    if ([string]::IsNullOrWhiteSpace($ComputerName)) {

        Write-Host ""
        Write-Host "[ERROR] Debe ingresar un nombre de equipo." -ForegroundColor Red

        return
    }


    $ComputerName = $ComputerName.Trim()


    try {

        $ComputerParameters = @{
            ComputerName = $ComputerName
        }

        $Computer = Get-ComputerFromAD @ComputerParameters
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] Equipo no encontrado." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        return
    }


    try {

        $TestParameters = @{
            Computer = $Computer
        }

        if (-not (Test-ComputerExcluded @TestParameters)) {

            Write-Host ""
            Write-Host "[INFO] El equipo no se encuentra excluido." -ForegroundColor Yellow
            Write-Host ""

            return
        }
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible consultar las exclusiones." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        return
    }


    Write-Host ""
    Write-Host "Equipo:" -ForegroundColor Cyan
    Write-Host "  Nombre : $($Computer.Name)"
    Write-Host "  DNS    : $($Computer.DNSHostName)"
    Write-Host "  SID    : $($Computer.SID)"
    Write-Host ""

    Write-Host "Se eliminara:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Deny -> Apply Group Policy"
    Write-Host ""
    Write-Host "de:"
    Write-Host ""
    Write-Host "  $GPOName"
    Write-Host ""


    $Confirmation = Read-Host "Quitar la exclusion? (S/N)"


    if ($Confirmation -notmatch '^[Ss]$') {

        Write-Host ""
        Write-Host "[CANCELADO] No se realizaron cambios." -ForegroundColor Yellow
        Write-Host ""

        return
    }


    try {

        $ACL = Get-CurrentGPOAcl

        $RulesToRemove = @()


        foreach ($ACE in $ACL.Access) {

            $ExclusionParameters = @{
                ACE = $ACE
            }

            if (-not (Test-IsApplyGroupPolicyDeny @ExclusionParameters)) {

                continue
            }


            $SIDParameters = @{
                ACE = $ACE
            }

            $ACESID = Get-ACESID @SIDParameters


            if (-not $ACESID) {

                continue
            }


            if ($ACESID.Value -eq $Computer.SID.Value) {

                $RulesToRemove += $ACE
            }
        }


        if ($RulesToRemove.Count -eq 0) {

            Write-Host ""
            Write-Host "[INFO] No se encontraron reglas directas para eliminar." -ForegroundColor Yellow
            Write-Host ""

            return
        }


        foreach ($Rule in $RulesToRemove) {

            [void]$ACL.RemoveAccessRuleSpecific($Rule)
        }


        $SetACLParameters = @{
            Path        = $GPOADPath
            AclObject   = $ACL
            ErrorAction = "Stop"
        }

        Set-Acl @SetACLParameters


        # ----------------------------------------------------
        # Verificar que la exclusion haya desaparecido
        # ----------------------------------------------------

        $VerificationParameters = @{
            Computer = $Computer
        }

        $ExcludedAfterChange = Test-ComputerExcluded @VerificationParameters


        if ($ExcludedAfterChange) {

            throw "La exclusion continua presente despues de modificar la ACL."
        }


        Write-Host ""
        Write-Host "[ELIMINADO] Exclusion removida correctamente." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Equipo : $($Computer.Name)"
        Write-Host "  GPO    : $GPOName"
        Write-Host ""
        Write-Host "El equipo vuelve a poder aplicar la GPO si cumple" -ForegroundColor Green
        Write-Host "con el resto de las condiciones de aplicacion."
        Write-Host ""
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] No fue posible quitar la exclusion." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
    }
}


# ============================================================
# 20. FUNCION: VERIFICAR EQUIPO
# ============================================================

function Show-ComputerStatus {

    Write-Host ""
    Write-Host "----- Verificar equipo -----" -ForegroundColor Cyan
    Write-Host ""


    $ComputerName = Read-Host "Ingrese el nombre del equipo"


    if ([string]::IsNullOrWhiteSpace($ComputerName)) {

        Write-Host ""
        Write-Host "[ERROR] Debe ingresar un nombre de equipo." -ForegroundColor Red
        Write-Host ""

        return
    }


    $ComputerName = $ComputerName.Trim()


    try {

        $ComputerParameters = @{
            ComputerName = $ComputerName
        }

        $Computer = Get-ComputerFromAD @ComputerParameters
    }
    catch {

        Write-Host ""
        Write-Host "[ERROR] Equipo no encontrado." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        return
    }


    Write-Host ""
    Write-Host "Equipo:" -ForegroundColor Cyan
    Write-Host "  Nombre : $($Computer.Name)"
    Write-Host "  DNS    : $($Computer.DNSHostName)"
    Write-Host "  Activo : $($Computer.Enabled)"
    Write-Host "  SID    : $($Computer.SID)"
    Write-Host "  DN     : $($Computer.DistinguishedName)"
    Write-Host ""


    try {

        $TestParameters = @{
            Computer = $Computer
        }

        $IsExcluded = Test-ComputerExcluded @TestParameters
    }
    catch {

        Write-Host "[ERROR] No fue posible consultar la ACL de la GPO." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        return
    }


    Write-Host "Estado:" -ForegroundColor Cyan


    if ($IsExcluded) {

        Write-Host "  EXCLUIDO" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Tiene una regla directa:"
        Write-Host ""
        Write-Host "  Deny -> Apply Group Policy"
        Write-Host ""
        Write-Host "La GPO no se aplicara a este equipo debido a esta exclusion."
    }
    else {

        Write-Host "  NO EXCLUIDO" -ForegroundColor Green
        Write-Host ""
        Write-Host "No existe una regla directa Deny -> Apply Group Policy"
        Write-Host "para este equipo en la GPO."
    }


    Write-Host ""
}


# ============================================================
# 21. MENU PRINCIPAL
# ============================================================

do {

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host " Excepciones - GPO Equipos Inactividad" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "GPO:"
    Write-Host "  $GPOName"
    Write-Host ""

    Write-Host "1. Listar equipos excluidos"
    Write-Host "2. Agregar equipo a exclusiones"
    Write-Host "3. Quitar equipo de exclusiones"
    Write-Host "4. Verificar un equipo"
    Write-Host "5. Salir"
    Write-Host ""


    $Option = Read-Host "Seleccione una opcion"


    switch ($Option) {

        "1" {

            Show-ExcludedComputers
        }


        "2" {

            Add-ExcludedComputer
        }


        "3" {

            Remove-ExcludedComputer
        }


        "4" {

            Show-ComputerStatus
        }


        "5" {

            Write-Host ""
            Write-Host "Saliendo del gestor de excepciones." -ForegroundColor Green
        }


        default {

            Write-Host ""
            Write-Host "[ERROR] Opcion invalida." -ForegroundColor Red
        }
    }

}
while ($Option -ne "5")


# ============================================================
# 22. FIN
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " GESTION DE EXCEPCIONES FINALIZADA" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
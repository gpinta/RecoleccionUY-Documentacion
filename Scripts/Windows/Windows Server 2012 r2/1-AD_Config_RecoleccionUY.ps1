<#
.SYNOPSIS
    Configuracion de Active Directory para Recoleccion UY.

.DOMINIO
    neltek.uy

.DESCRIPCION
    Configura los objetos de Active Directory utilizados
    por el ecosistema Recoleccion UY.

    Configura:
      - Estructura de OUs.
      - OU Disabled Users en la raiz del dominio.
      - Grupos de aplicacion e infraestructura.
      - Usuarios de testing.
      - Cuenta privilegiada infra01.
      - Cuenta tecnica svc_recoleccion_ldap.
      - Membresias administrativas Windows/Linux.
      - GG_REC_Server_Admins_Windows en:
          Domain Admins
          BUILTIN\Administrators
          BUILTIN\Remote Desktop Users.

.NOTAS
    Diseñado para Windows Server 2012 R2.
    Debe ejecutarse cuando Active Directory ya se encuentre
    instalado y operativo.
#>


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

$DomainDN   = "DC=neltek,DC=uy"
$DomainName = "neltek.uy"


# ============================================================
# 2. INTERRUPTORES
# ============================================================

$CrearOUs                      = $true
$CrearGrupos                   = $true
$CrearUsuariosTesting          = $true
$CrearCuentaInfra01            = $true
$CrearCuentaLDAP               = $true

$AgregarInfra01AWindows        = $true
$AgregarInfra01ALinux          = $true

$AgregarWindowsADomainAdmins   = $true
$AgregarWindowsAAdministrators = $true

$MoverUsuariosExistentes       = $false


# ============================================================
# 3. RUTAS ACTIVE DIRECTORY
# ============================================================

# OU principal del proyecto
$OURecoleccion = "OU=RecoleccionUY,$DomainDN"

# OU ubicada fuera de RecoleccionUY
$OUDisabledUsers = "OU=Disabled Users,$DomainDN"

# OUs internas de RecoleccionUY
$OUUsuarios             = "OU=Usuarios,$OURecoleccion"
$OUCuentasPrivilegiadas = "OU=CuentasPrivilegiadas,$OURecoleccion"

$OUGrupos          = "OU=Grupos,$OURecoleccion"
$OUAplicaciones    = "OU=Aplicaciones,$OUGrupos"
$OUInfraestructura = "OU=Infraestructura,$OUGrupos"

$OUEquipos    = "OU=Equipos,$OURecoleccion"
$OUServidores = "OU=Servidores,$OUEquipos"
$OUClientes   = "OU=Clientes,$OUEquipos"

$OUCuentasServicio = "OU=CuentasServicio,$OURecoleccion"


# ============================================================
# 4. INICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Recoleccion UY - Active Directory" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""


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

    if ($CurrentDomain.DNSRoot -ne $DomainName) {

        Write-Host "[ERROR] Dominio incorrecto." -ForegroundColor Red
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
# 7. FUNCION: CREAR OU SI NO EXISTE
# ============================================================

function New-OUIfNotExists {

    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Description
    )

    $DistinguishedName = "OU=$Name,$Path"

    try {

        # Se utiliza Filter en lugar de Identity.
        # Si la OU no existe, simplemente devuelve resultado vacio.
        $OU = Get-ADOrganizationalUnit `
            -Filter "Name -eq '$Name'" `
            -SearchBase $Path `
            -SearchScope OneLevel `
            -ErrorAction Stop

        if ($OU) {

            Write-Host "[EXISTE] OU: $DistinguishedName" -ForegroundColor Yellow
        }
        else {

            $OUParameters = @{
                Name                            = $Name
                Path                            = $Path
                Description                     = $Description
                ProtectedFromAccidentalDeletion = $true
                ErrorAction                     = "Stop"
            }

            New-ADOrganizationalUnit @OUParameters

            Write-Host "[CREADA] OU: $DistinguishedName" -ForegroundColor Green
        }
    }
    catch {

        Write-Host "[ERROR] No se pudo procesar la OU:" -ForegroundColor Red
        Write-Host "        $DistinguishedName" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ============================================================
# 8. CREAR OUs
# ============================================================

if ($CrearOUs) {

    Write-Host ""
    Write-Host "----- Creacion de OUs -----" -ForegroundColor Cyan


    # --------------------------------------------------------
    # OU PRINCIPAL RECOLECCION UY
    # --------------------------------------------------------

    New-OUIfNotExists `
        -Name "RecoleccionUY" `
        -Path $DomainDN `
        -Description "Estructura principal de Recoleccion UY"


    # --------------------------------------------------------
    # OU DISABLED USERS
    # FUERA DE RECOLECCION UY
    # --------------------------------------------------------

    New-OUIfNotExists `
        -Name "Disabled Users" `
        -Path $DomainDN `
        -Description "Usuarios deshabilitados del dominio"


    # --------------------------------------------------------
    # OUs INTERNAS DE RECOLECCION UY
    # --------------------------------------------------------

    New-OUIfNotExists `
        -Name "Usuarios" `
        -Path $OURecoleccion `
        -Description "Usuarios humanos cotidianos de Recoleccion UY"

    New-OUIfNotExists `
        -Name "CuentasPrivilegiadas" `
        -Path $OURecoleccion `
        -Description "Cuentas administrativas privilegiadas"

    New-OUIfNotExists `
        -Name "Grupos" `
        -Path $OURecoleccion `
        -Description "Grupos de Active Directory"

    New-OUIfNotExists `
        -Name "Aplicaciones" `
        -Path $OUGrupos `
        -Description "Grupos correspondientes a aplicaciones"

    New-OUIfNotExists `
        -Name "Infraestructura" `
        -Path $OUGrupos `
        -Description "Grupos administrativos de infraestructura"

    New-OUIfNotExists `
        -Name "Equipos" `
        -Path $OURecoleccion `
        -Description "Equipos asociados a Recoleccion UY"

    New-OUIfNotExists `
        -Name "Servidores" `
        -Path $OUEquipos `
        -Description "Servidores asociados a Recoleccion UY"

    New-OUIfNotExists `
        -Name "Clientes" `
        -Path $OUEquipos `
        -Description "Equipos cliente asociados a Recoleccion UY"

    New-OUIfNotExists `
        -Name "CuentasServicio" `
        -Path $OURecoleccion `
        -Description "Cuentas tecnicas utilizadas por servicios"
}


# ============================================================
# 9. FUNCION: CREAR GRUPO SI NO EXISTE
# ============================================================

function New-ADGroupIfNotExists {

    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Description
    )

    try {

        $Group = Get-ADGroup `
            -Filter "SamAccountName -eq '$Name'" `
            -ErrorAction Stop

        if ($Group) {

            Write-Host "[EXISTE] Grupo: $Name" -ForegroundColor Yellow
        }
        else {

            $GroupParameters = @{
                Name           = $Name
                SamAccountName = $Name
                GroupCategory  = "Security"
                GroupScope     = "Global"
                Path           = $Path
                Description    = $Description
                ErrorAction    = "Stop"
            }

            New-ADGroup @GroupParameters

            Write-Host "[CREADO] Grupo: $Name" -ForegroundColor Green
        }
    }
    catch {

        Write-Host "[ERROR] Grupo: $Name" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ============================================================
# 10. CREAR GRUPOS
# ============================================================

if ($CrearGrupos) {

    Write-Host ""
    Write-Host "----- Grupos de Aplicaciones -----" -ForegroundColor Cyan

    New-ADGroupIfNotExists `
        -Name "GG_REC_Backend_Operators" `
        -Path $OUAplicaciones `
        -Description "Operadores del Backend Administrativo de Recoleccion UY"

    New-ADGroupIfNotExists `
        -Name "GG_REC_Backend_Admins" `
        -Path $OUAplicaciones `
        -Description "Administradores funcionales del Backend Administrativo de Recoleccion UY"

    New-ADGroupIfNotExists `
        -Name "GG_REC_Backend_Readers" `
        -Path $OUAplicaciones `
        -Description "Usuarios de solo lectura del Backend Administrativo de Recoleccion UY"


    Write-Host ""
    Write-Host "----- Grupos de Infraestructura -----" -ForegroundColor Cyan

    New-ADGroupIfNotExists `
        -Name "GG_REC_Server_Admins_Windows" `
        -Path $OUInfraestructura `
        -Description "Administradores de infraestructura Windows"

    New-ADGroupIfNotExists `
        -Name "GG_REC_Server_Admins_Linux" `
        -Path $OUInfraestructura `
        -Description "Administradores de infraestructura Linux"
}


# ============================================================
# 11. FUNCION: CREAR USUARIO DE TESTING
# ============================================================

function New-BackendTestUserIfNotExists {

    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$SamAccountName,

        [Parameter(Mandatory=$true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory=$true)]
        [string]$Description
    )

    try {

        $User = Get-ADUser `
            -Filter "SamAccountName -eq '$SamAccountName'" `
            -Properties UserPrincipalName, DistinguishedName `
            -ErrorAction Stop

        if (-not $User) {

            $User = Get-ADUser `
                -Filter "UserPrincipalName -eq '$UserPrincipalName'" `
                -Properties UserPrincipalName, DistinguishedName `
                -ErrorAction Stop
        }

        if ($User) {

            Write-Host "[EXISTE] Usuario testing: $UserPrincipalName" -ForegroundColor Yellow
            Write-Host "         sAMAccountName: $($User.SamAccountName)" -ForegroundColor DarkGray
            Write-Host "         $($User.DistinguishedName)" -ForegroundColor DarkGray

            return
        }

        $Password = Read-Host "Ingrese password inicial para $UserPrincipalName" -AsSecureString

        $UserParameters = @{
            Name                  = $Name
            DisplayName           = $Name
            SamAccountName        = $SamAccountName
            UserPrincipalName     = $UserPrincipalName
            Path                  = $OUUsuarios
            Description           = $Description
            AccountPassword       = $Password
            Enabled               = $true
            ChangePasswordAtLogon = $false
            ErrorAction           = "Stop"
        }

        New-ADUser @UserParameters

        Write-Host "[CREADO] Usuario testing: $UserPrincipalName" -ForegroundColor Green
        Write-Host "         sAMAccountName: $SamAccountName" -ForegroundColor DarkGray
    }
    catch {

        Write-Host "[ERROR] No se pudo crear el usuario testing $UserPrincipalName." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ============================================================
# 12. CREAR USUARIOS DE TESTING
# ============================================================

if ($CrearUsuariosTesting) {

    Write-Host ""
    Write-Host "----- Usuarios de testing del Backend -----" -ForegroundColor Cyan

    New-BackendTestUserIfNotExists `
        -Name "admin recoleccion" `
        -SamAccountName "admin.recoleccion" `
        -UserPrincipalName "admin.recoleccion@$DomainName" `
        -Description "Usuario de testing - Administrador Backend Recoleccion UY"

    New-BackendTestUserIfNotExists `
        -Name "operadores recoleccion" `
        -SamAccountName "operadores.recolecc" `
        -UserPrincipalName "operadores.recoleccion@$DomainName" `
        -Description "Usuario de testing - Operador Backend Recoleccion UY"

    New-BackendTestUserIfNotExists `
        -Name "consulta recoleccion" `
        -SamAccountName "consulta.recoleccion" `
        -UserPrincipalName "consulta.recoleccion@$DomainName" `
        -Description "Usuario de testing - Reader Backend Recoleccion UY"
}


# ============================================================
# 13. CREAR CUENTA PRIVILEGIADA infra01
# ============================================================

if ($CrearCuentaInfra01) {

    Write-Host ""
    Write-Host "----- Cuenta privilegiada infra01 -----" -ForegroundColor Cyan

    $InfraUserName = "infra01"

    try {

        $InfraUser = Get-ADUser `
            -Filter "SamAccountName -eq '$InfraUserName'" `
            -Properties DistinguishedName `
            -ErrorAction Stop

        if ($InfraUser) {

            Write-Host "[EXISTE] infra01@$DomainName" -ForegroundColor Yellow
            Write-Host "         $($InfraUser.DistinguishedName)" -ForegroundColor DarkGray
        }
        else {

            $InfraPassword = Read-Host "Ingrese password inicial para infra01" -AsSecureString

            $InfraParameters = @{
                Name                  = "infra01"
                SamAccountName        = "infra01"
                UserPrincipalName     = "infra01@$DomainName"
                Path                  = $OUCuentasPrivilegiadas
                Description           = "Cuenta privilegiada de administracion de infraestructura Recoleccion UY"
                AccountPassword       = $InfraPassword
                Enabled               = $true
                ChangePasswordAtLogon = $true
                ErrorAction           = "Stop"
            }

            New-ADUser @InfraParameters

            Write-Host "[CREADO] infra01@$DomainName" -ForegroundColor Green
        }
    }
    catch {

        Write-Host "[ERROR] No se pudo procesar infra01." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ============================================================
# 14. FUNCION: AGREGAR USUARIO A GRUPO
# ============================================================

function Add-UserToGroupIfNeeded {

    param(
        [Parameter(Mandatory=$true)]
        [string]$UserName,

        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )

    try {

        $User = Get-ADUser -Identity $UserName -ErrorAction Stop
        $Group = Get-ADGroup -Identity $GroupName -ErrorAction Stop

        $Membership = Get-ADGroupMember `
            -Identity $Group `
            -Recursive:$false `
            -ErrorAction Stop |
            Where-Object {
                $_.DistinguishedName -eq $User.DistinguishedName
            }

        if ($Membership) {

            Write-Host "[EXISTE] $UserName -> $GroupName" -ForegroundColor Yellow
        }
        else {

            Add-ADGroupMember `
                -Identity $Group `
                -Members $User `
                -ErrorAction Stop

            Write-Host "[AGREGADO] $UserName -> $GroupName" -ForegroundColor Green
        }
    }
    catch {

        Write-Host "[ERROR] No se pudo agregar $UserName a $GroupName." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ============================================================
# 15. MEMBRESIAS DE USUARIOS DE TESTING
# ============================================================

if ($CrearUsuariosTesting -and $CrearGrupos) {

    Write-Host ""
    Write-Host "----- Membresias de usuarios testing -----" -ForegroundColor Cyan

    Add-UserToGroupIfNeeded `
        -UserName "admin.recoleccion" `
        -GroupName "GG_REC_Backend_Admins"

    Add-UserToGroupIfNeeded `
        -UserName "operadores.recolecc" `
        -GroupName "GG_REC_Backend_Operators"

    Add-UserToGroupIfNeeded `
        -UserName "consulta.recoleccion" `
        -GroupName "GG_REC_Backend_Readers"
}


# ============================================================
# 16. MEMBRESIAS infra01
# ============================================================

if ($CrearCuentaInfra01 -and $CrearGrupos -and $AgregarInfra01AWindows) {

    Add-UserToGroupIfNeeded `
        -UserName "infra01" `
        -GroupName "GG_REC_Server_Admins_Windows"
}

if ($CrearCuentaInfra01 -and $CrearGrupos -and $AgregarInfra01ALinux) {

    Add-UserToGroupIfNeeded `
        -UserName "infra01" `
        -GroupName "GG_REC_Server_Admins_Linux"
}


# ============================================================
# 17. FUNCION: ANIDAR GRUPOS
# ============================================================

function Add-GroupToGroupIfNeeded {

    param(
        [Parameter(Mandatory=$true)]
        [string]$ChildGroup,

        [Parameter(Mandatory=$true)]
        [string]$ParentGroup
    )

    try {

        $Child = Get-ADGroup -Identity $ChildGroup -ErrorAction Stop
        $Parent = Get-ADGroup -Identity $ParentGroup -ErrorAction Stop

        $Membership = Get-ADGroupMember `
            -Identity $Parent `
            -Recursive:$false `
            -ErrorAction Stop |
            Where-Object {
                $_.DistinguishedName -eq $Child.DistinguishedName
            }

        if ($Membership) {

            Write-Host "[EXISTE] $ChildGroup -> $($Parent.Name)" -ForegroundColor Yellow
        }
        else {

            Add-ADGroupMember `
                -Identity $Parent `
                -Members $Child `
                -ErrorAction Stop

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
# 18. PRIVILEGIOS WINDOWS
# ============================================================

if ($CrearGrupos -and $AgregarWindowsADomainAdmins) {

    $DomainSID = $CurrentDomain.DomainSID.Value
    $DomainAdminsSID = "$DomainSID-512"

    Add-GroupToGroupIfNeeded `
        -ChildGroup "GG_REC_Server_Admins_Windows" `
        -ParentGroup $DomainAdminsSID
}


if ($CrearGrupos -and $AgregarWindowsAAdministrators) {

    Add-GroupToGroupIfNeeded `
        -ChildGroup "GG_REC_Server_Admins_Windows" `
        -ParentGroup "S-1-5-32-544"
}


# ============================================================
# 19. REMOTE DESKTOP USERS
# ============================================================

if ($CrearGrupos) {

    Add-GroupToGroupIfNeeded `
        -ChildGroup "GG_REC_Server_Admins_Windows" `
        -ParentGroup "S-1-5-32-555"
}


# ============================================================
# 20. CREAR CUENTA DE SERVICIO LDAP
# ============================================================

if ($CrearCuentaLDAP) {

    Write-Host ""
    Write-Host "----- Cuenta de servicio LDAP -----" -ForegroundColor Cyan

    $ServiceUserName = "svc_recoleccion_ldap"

    try {

        $ServiceUser = Get-ADUser `
            -Filter "SamAccountName -eq '$ServiceUserName'" `
            -ErrorAction Stop

        if ($ServiceUser) {

            Write-Host "[EXISTE] $ServiceUserName" -ForegroundColor Yellow
        }
        else {

            $ServicePassword = Read-Host "Ingrese password para $ServiceUserName" -AsSecureString

            $ServiceParameters = @{
                Name                 = $ServiceUserName
                SamAccountName       = $ServiceUserName
                UserPrincipalName    = "$ServiceUserName@$DomainName"
                Path                 = $OUCuentasServicio
                Description          = "Cuenta tecnica LDAP utilizada por Recoleccion UY"
                AccountPassword      = $ServicePassword
                Enabled              = $true
                PasswordNeverExpires = $true
                CannotChangePassword = $true
                ErrorAction          = "Stop"
            }

            New-ADUser @ServiceParameters

            Write-Host "[CREADO] $ServiceUserName" -ForegroundColor Green
        }
    }
    catch {

        Write-Host "[ERROR] No se pudo procesar $ServiceUserName." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}


# ============================================================
# 21. MOVER USUARIOS nombre.apellido
# ============================================================

if ($MoverUsuariosExistentes) {

    Write-Host ""
    Write-Host "----- Organizacion de usuarios cotidianos -----" -ForegroundColor Cyan

    try {

        $Usuarios = Get-ADUser `
            -Filter * `
            -SearchBase "CN=Users,$DomainDN" `
            -SearchScope OneLevel `
            -Properties SamAccountName `
            -ErrorAction Stop

        foreach ($Usuario in $Usuarios) {

            $Sam = $Usuario.SamAccountName

            if ($Sam -match '^[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+$') {

                try {

                    Move-ADObject `
                        -Identity $Usuario.DistinguishedName `
                        -TargetPath $OUUsuarios `
                        -ErrorAction Stop

                    Write-Host "[MOVIDO] $Sam -> OU=Usuarios" -ForegroundColor Green
                }
                catch {

                    Write-Host "[ERROR] No se pudo mover $Sam." -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Red

                    throw
                }
            }
        }
    }
    catch {

        Write-Host "[ERROR] No se pudo consultar CN=Users." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        throw
    }
}
else {

    Write-Host "[OMITIDO] Movimiento de usuarios existentes." -ForegroundColor DarkYellow
}


# ============================================================
# 22. FIN
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " CONFIGURACION ACTIVE DIRECTORY FINALIZADA" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
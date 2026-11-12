<#
.SYNOPSIS
    Habilita temporalmente compatibilidad CredSSP
    en un equipo HOST que utilizará RDP.

.DESCRIPCION
    Este script modifica temporalmente la configuración
    CredSSP del equipo cliente/host.

    Configura:

        AllowEncryptionOracle = 2

    Esto permite que un cliente RDP moderno pueda conectarse
    a un servidor antiguo que todavía utiliza una implementación
    CredSSP no compatible con las políticas actuales.

    IMPORTANTE:

    Esta configuración reduce la protección de CredSSP.

    Debe utilizarse únicamente de forma temporal
    para realizar la conexión RDP necesaria.

    Al finalizar la administración remota ejecutar:

        HOST_CredSSP_Restaurar.ps1

.NOTAS
    Este script debe ejecutarse en el HOST físico o
    equipo cliente desde el cual se realizará RDP.

    NO debe ejecutarse en WS-DC-01.

    Requiere PowerShell ejecutado como Administrador.
#>


# ============================================================
# 1. CONFIGURACIÓN GENERAL
# ============================================================
#
# Ruta del Registro utilizada por Windows para almacenar
# la política de compatibilidad CredSSP.
#
# Si la ruta no existe, el script la crea automáticamente.
# ============================================================

$CredSSPPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters"


# ============================================================
# 2. VALOR TEMPORAL
# ============================================================
#
# AllowEncryptionOracle:
#
#   0 = Force Updated Clients
#       Máxima protección.
#
#   1 = Mitigated
#       Compatibilidad limitada.
#
#   2 = Vulnerable
#       Permite conexión con servidores CredSSP antiguos.
#
# En este laboratorio necesitamos temporalmente:
#
#   AllowEncryptionOracle = 2
#
# IMPORTANTE:
# No debe dejarse configurado permanentemente.
# ============================================================

$AllowEncryptionOracleValue = 2


# ============================================================
# 3. INICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" `
    -ForegroundColor Yellow

Write-Host " CredSSP - HABILITACIÓN TEMPORAL" `
    -ForegroundColor Yellow

Write-Host " Equipo HOST / Cliente RDP" `
    -ForegroundColor Yellow

Write-Host "========================================================" `
    -ForegroundColor Yellow

Write-Host ""


# ============================================================
# 4. VERIFICAR / CREAR RUTA DEL REGISTRO
# ============================================================
#
# Algunas instalaciones de Windows no tienen creada
# previamente la ruta CredSSP\Parameters.
#
# Si no existe:
#
#   - se crea.
#
# Si ya existe:
#
#   - no se modifica ninguna otra configuración.
# ============================================================

try {

    if (-not (Test-Path $CredSSPPath)) {

        New-Item `
            -Path $CredSSPPath `
            -Force `
            -ErrorAction Stop |
            Out-Null

        Write-Host "[CREADA] Ruta CredSSP\Parameters." `
            -ForegroundColor Green

    }
    else {

        Write-Host "[EXISTE] Ruta CredSSP\Parameters." `
            -ForegroundColor Yellow
    }

}
catch {

    Write-Host "[ERROR] No fue posible crear/verificar la ruta CredSSP." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 1
}


# ============================================================
# 5. CONFIGURAR AllowEncryptionOracle
# ============================================================
#
# Se crea o reemplaza:
#
#   AllowEncryptionOracle
#
# Tipo:
#
#   REG_DWORD
#
# Valor:
#
#   2
#
# El parámetro -Force permite:
#
#   - crear el valor si no existe.
#   - actualizarlo si ya existe.
# ============================================================

try {

    New-ItemProperty `
        -Path $CredSSPPath `
        -Name "AllowEncryptionOracle" `
        -PropertyType DWord `
        -Value $AllowEncryptionOracleValue `
        -Force `
        -ErrorAction Stop |
        Out-Null


    Write-Host "[OK] AllowEncryptionOracle configurado." `
        -ForegroundColor Green

}
catch {

    Write-Host "[ERROR] No fue posible configurar AllowEncryptionOracle." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 1
}


# ============================================================
# 6. VERIFICACIÓN
# ============================================================
#
# Se vuelve a consultar el Registro para comprobar
# que el valor realmente quedó en:
#
#   AllowEncryptionOracle = 2
# ============================================================

try {

    $ConfiguredValue = (
        Get-ItemProperty `
            -Path $CredSSPPath `
            -Name "AllowEncryptionOracle" `
            -ErrorAction Stop
    ).AllowEncryptionOracle


    if ($ConfiguredValue -eq $AllowEncryptionOracleValue) {

        Write-Host ""
        Write-Host "[OK] Verificación correcta." `
            -ForegroundColor Green

        Write-Host ""
        Write-Host "AllowEncryptionOracle : $ConfiguredValue"

    }
    else {

        Write-Host "[ERROR] El valor configurado no es el esperado." `
            -ForegroundColor Red

        Write-Host "Esperado : $AllowEncryptionOracleValue"
        Write-Host "Detectado: $ConfiguredValue"

        exit 1
    }

}
catch {

    Write-Host "[ERROR] No fue posible verificar CredSSP." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 1
}


# ============================================================
# 7. RESULTADO
# ============================================================

Write-Host ""
Write-Host "========================================================" `
    -ForegroundColor Green

Write-Host " CREDSSP TEMPORALMENTE HABILITADO" `
    -ForegroundColor Green

Write-Host "========================================================" `
    -ForegroundColor Green

Write-Host ""

Write-Host "Ya puede realizar la conexión RDP." `
    -ForegroundColor White

Write-Host ""

Write-Host "IMPORTANTE:" `
    -ForegroundColor Red

Write-Host "Al finalizar la administración remota ejecute:" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host "  HOST_CredSSP_Restaurar.ps1" `
    -ForegroundColor White

Write-Host ""

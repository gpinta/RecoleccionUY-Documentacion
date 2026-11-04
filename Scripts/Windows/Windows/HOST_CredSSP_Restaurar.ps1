<#
.SYNOPSIS
    Restaura la configuración predeterminada de CredSSP
    en un equipo HOST.

.DESCRIPCION
    Este script elimina la configuración temporal utilizada
    para permitir compatibilidad con servidores CredSSP antiguos.

    Elimina:

        AllowEncryptionOracle

    Después de eliminar ese valor, Windows vuelve a utilizar
    su comportamiento normal/predeterminado para CredSSP.

.NOTAS
    Este script debe ejecutarse en el HOST físico o
    equipo cliente desde el cual se realizó RDP.

    NO debe ejecutarse en WS-DC-01.

    Requiere PowerShell ejecutado como Administrador.
#>


# ============================================================
# 1. CONFIGURACIÓN GENERAL
# ============================================================
#
# Ruta utilizada por CredSSP para la política temporal.
# ============================================================

$CredSSPPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters"


# ============================================================
# 2. INICIO
# ============================================================

Write-Host ""
Write-Host "========================================================" `
    -ForegroundColor Cyan

Write-Host " CredSSP - RESTAURAR CONFIGURACIÓN" `
    -ForegroundColor Cyan

Write-Host " Equipo HOST / Cliente RDP" `
    -ForegroundColor Cyan

Write-Host "========================================================" `
    -ForegroundColor Cyan

Write-Host ""


# ============================================================
# 3. VERIFICAR SI EXISTE LA RUTA
# ============================================================
#
# Si la ruta no existe:
#
#   - significa que no hay configuración CredSSP temporal
#     almacenada en esta ubicación.
#
# En ese caso no es necesario realizar cambios.
# ============================================================

if (-not (Test-Path $CredSSPPath)) {

    Write-Host "[OK] La ruta CredSSP\Parameters no existe." `
        -ForegroundColor Green

    Write-Host "No hay configuración temporal que restaurar."

    exit 0
}


# ============================================================
# 4. VERIFICAR AllowEncryptionOracle
# ============================================================
#
# Se comprueba si el valor temporal:
#
#   AllowEncryptionOracle
#
# está presente.
# ============================================================

try {

    $Property = Get-ItemProperty `
        -Path $CredSSPPath `
        -Name "AllowEncryptionOracle" `
        -ErrorAction SilentlyContinue

}
catch {

    Write-Host "[ERROR] No fue posible consultar CredSSP." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 1
}


# ============================================================
# 5. ELIMINAR CONFIGURACIÓN TEMPORAL
# ============================================================
#
# Si AllowEncryptionOracle existe:
#
#   - se elimina únicamente ese valor.
#
# NO se elimina toda la clave CredSSP.
#
# Esto evita modificar otras configuraciones que eventualmente
# pudieran existir en el equipo.
# ============================================================

try {

    if ($null -ne $Property) {

        Remove-ItemProperty `
            -Path $CredSSPPath `
            -Name "AllowEncryptionOracle" `
            -ErrorAction Stop


        Write-Host "[ELIMINADO] AllowEncryptionOracle." `
            -ForegroundColor Green

    }
    else {

        Write-Host "[OK] AllowEncryptionOracle no estaba configurado." `
            -ForegroundColor Green
    }

}
catch {

    Write-Host "[ERROR] No fue posible eliminar AllowEncryptionOracle." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 1
}


# ============================================================
# 6. VERIFICACIÓN FINAL
# ============================================================
#
# Se vuelve a consultar el Registro.
#
# El resultado correcto es que:
#
#   AllowEncryptionOracle
#
# ya no exista.
# ============================================================

try {

    $Verification = Get-ItemProperty `
        -Path $CredSSPPath `
        -Name "AllowEncryptionOracle" `
        -ErrorAction SilentlyContinue


    if ($null -eq $Verification) {

        Write-Host ""
        Write-Host "[OK] AllowEncryptionOracle ya no existe." `
            -ForegroundColor Green

    }
    else {

        Write-Host "[ERROR] AllowEncryptionOracle continúa presente." `
            -ForegroundColor Red

        exit 1
    }

}
catch {

    Write-Host "[ERROR] No fue posible verificar la restauración." `
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

Write-Host " CREDSSP RESTAURADO" `
    -ForegroundColor Green

Write-Host "========================================================" `
    -ForegroundColor Green

Write-Host ""

Write-Host "El equipo vuelve a utilizar la configuración" `
    -ForegroundColor White

Write-Host "predeterminada de CredSSP." `
    -ForegroundColor White

Write-Host ""

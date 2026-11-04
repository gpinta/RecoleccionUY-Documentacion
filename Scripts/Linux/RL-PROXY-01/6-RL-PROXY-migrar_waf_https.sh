#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C

# Recoleccion UY - RL-PROXY-01
# Activacion HTTPS exclusiva en publicacion del WAF existente.
# No modifica RL-APP, DNS, nginx interno ni firewall.
DIR=/opt/recoleccion-proxy
COMPOSE="$DIR/docker-compose.yml"
TEMPLATE="$DIR/waf/default.conf.template"
CERT="$DIR/tls/certs/recoleccion.crt"
KEY="$DIR/tls/certs/recoleccion.key"
CA="$DIR/tls/ca/recoleccion-ca.crt"
# Copias destinadas al contenedor, sin alterar materiales de la CA ni claves originales.
WAF_TLS="$DIR/waf/tls-runtime"
WAF_CERT="$WAF_TLS/recoleccion.crt"
WAF_KEY="$WAF_TLS/recoleccion.key"
IP=192.168.50.20
HOSTS=(recoleccion.neltek.uy admin-recoleccion.neltek.uy camiones-recoleccion.neltek.uy)
TEMP=""
BACKUP=""
CHANGED=0
SUCCESS=0

ok(){ printf '[OK] %s\n' "$*"; }
info(){ printf '[INFO] %s\n' "$*"; }
warn(){ printf '[ADVERTENCIA] %s\n' "$*" >&2; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
dc(){ (cd "$DIR" && docker compose -f "$COMPOSE" "$@"); }

wait_healthy(){
    local i state
    for ((i=1;i<=45;i++)); do
        state="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' recoleccion_waf 2>/dev/null || true)"
        case "$state" in
            healthy) ok "WAF healthy"; return 0;;
            unhealthy|exited|dead) warn "WAF: $state"; return 1;;
            running) # Para imagen sin healthcheck
                if [[ "$(docker inspect -f '{{if .Config.Healthcheck}}yes{{else}}no{{end}}' recoleccion_waf)" == no ]]; then
                    docker exec recoleccion_waf nginx -t >/dev/null 2>&1 && return 0
                fi;;
        esac
        sleep 2
    done
    warn "Timeout esperando WAF healthy (90 s)."
    return 1
}

# Devuelve el estado y causa reales; acepta 1xx-4xx, rechaza 5xx/000.
probe(){
    local scheme="$1" host="$2" attempt="${3:-1}" url code err rc
    local -a opts
    err="$TEMP/curl-error.txt"
    : > "$err"
    if [[ "$scheme" == https ]]; then
        url="https://$host/"
        opts=(--cacert "$CA" --resolve "$host:443:$IP")
    else
        url="http://$IP/"
        opts=(-H "Host: $host")
    fi
    rc=0
    code="$(curl --noproxy '*' -sS --connect-timeout 3 --max-time 12 \
        "${opts[@]}" -o /dev/null -w '%{http_code}' "$url" 2>"$err")" || rc=$?
    if (( rc==0 )) && [[ "$code" =~ ^[1-4][0-9][0-9]$ ]]; then
        ok "$scheme $host -> $code"
        return 0
    fi
    warn "$scheme $host intento $attempt: curl_rc=$rc HTTP=${code:-sin_codigo} $(tr '\n' ' ' < "$err")"
    return 1
}
verify_all(){
    local scheme="$1" host i good
    for host in "${HOSTS[@]}"; do
        good=0
        for ((i=1;i<=12;i++)); do
            if probe "$scheme" "$host" "$i"; then good=1; break; fi
            sleep 2
        done
        ((good==1)) || return 1
    done
}

restore(){
    [[ -n "$BACKUP" && -s "$BACKUP/docker-compose.yml" ]] || return 1
    warn "Restaurando Compose previo desde $BACKUP"
    cp -a "$BACKUP/docker-compose.yml" "$COMPOSE" || return 1
    cp -a "$BACKUP/default.conf.template" "$TEMPLATE" || return 1
    dc config --quiet || return 1
    dc up -d --no-deps --force-recreate waf || return 1
    wait_healthy || return 1
    docker exec recoleccion_waf nginx -t || return 1
    verify_all http || return 1
    return 0
}
cleanup(){
    local status=$?
    trap - EXIT
    if (( status != 0 && CHANGED == 1 && SUCCESS == 0 )); then
        if restore; then
            ok "Configuracion HTTP anterior restaurada y comprobada."
        else
            warn "No se pudo confirmar la restauracion automatica."
            warn "Respaldo conservado: $BACKUP"
            warn "Inspeccionar docker compose ps, docker logs recoleccion_waf y docker port recoleccion_waf."
        fi
    fi
    if [[ -n "$TEMP" && -d "$TEMP" && ! -L "$TEMP" ]]; then
        case "$TEMP" in "$DIR"/.tls-https.*) rm -rf -- "$TEMP" || true;; esac
    fi
    exit "$status"
}
trap cleanup EXIT

(( EUID==0 )) || die "Ejecutar como root."
(( $#==0 )) || die "No acepta parametros."
[[ "$(hostname -s | tr '[:upper:]' '[:lower:]')" == rl-proxy-01 ]] || die "Servidor incorrecto."
for tool in docker python3 openssl curl mktemp sha256sum install cmp; do
    command -v "$tool" >/dev/null 2>&1 || die "Falta: $tool"
done
[[ -d "$DIR" && ! -L "$DIR" ]] || die "Ruta del proyecto invalida."
for path in "$COMPOSE" "$TEMPLATE" "$CERT" "$KEY" "$CA"; do
    [[ -s "$path" && ! -L "$path" ]] || die "Archivo inexistente/vacio/simbolico: $path"
done
docker info >/dev/null 2>&1 || die "Docker no disponible."
dc config --quiet || die "Compose actual invalido."
for c in recoleccion_waf recoleccion_proxy recoleccion_dns; do
    [[ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null || true)" == true ]] || die "Contenedor inactivo: $c"
done
openssl verify -purpose sslserver -CAfile "$CA" "$CERT" >/dev/null || die "Certificado TLS invalido."
openssl x509 -in "$CERT" -checkend 604800 -noout >/dev/null || die "TLS vence dentro de 7 dias."
for host in "${HOSTS[@]}"; do
    openssl verify -purpose sslserver -verify_hostname "$host" -CAfile "$CA" "$CERT" >/dev/null || die "SAN invalido: $host"
done
[[ "$(openssl pkey -in "$KEY" -pubout -outform DER | openssl dgst -sha256)" == \
   "$(openssl x509 -in "$CERT" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)" ]] || die "Certificado y clave no coinciden."
ok "Material TLS verificado."

TEMP="$(mktemp -d "$DIR/.tls-https.XXXXXXXX")"
chmod 700 "$TEMP"
dc config --format json > "$TEMP/original.json"

# Validar instalacion efectiva antes de alterar archivos.
python3 - "$TEMP/original.json" "$IP" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
s=d["services"]
if set(s)!={"nginx","dnsmasq","waf"}:
    raise SystemExit("Servicios Compose inesperados")
for name,container in (("nginx","recoleccion_proxy"),("dnsmasq","recoleccion_dns"),("waf","recoleccion_waf")):
    if s[name].get("container_name")!=container:
        raise SystemExit("Contenedor no coincide: "+name)
if s["nginx"].get("ports"):
    raise SystemExit("Nginx interno tiene puertos publicados")
p=s["waf"].get("ports",[])
if len(p)!=1 or str(p[0].get("host_ip",""))!=sys.argv[2] or int(p[0]["published"])!=80 or int(p[0]["target"])!=8080:
    raise SystemExit("WAF no esta en configuracion HTTP original 80->8080; no modificar")
if not str(s["waf"].get("image","")).startswith("owasp/modsecurity-crs:"):
    raise SystemExit("Imagen WAF inesperada")
print("[OK] Topologia original comprobada.")
PY

# La plantilla existente queda intacta; publica exclusivamente HTTPS en host.
for mark in 'listen ${SSL_PORT} ssl' '${SSL_CERT_FILE}' '${SSL_CERT_KEY_FILE}'; do
    grep -Fq "$mark" "$TEMPLATE" || die "La plantilla no contiene: $mark"
done
info "Plantilla WAF conservada."
verify_all http || die "HTTP previo no responde correctamente."

python3 - "$TEMP/original.json" "$TEMP/docker-compose.yml" "$DIR" "$IP" <<'PY'
import json,sys
from pathlib import Path
original,out,base,ip=sys.argv[1:]
d=json.load(open(original))
w=d["services"]["waf"]
w["ports"]=[{"mode":"ingress","host_ip":ip,"target":8443,"published":"443","protocol":"tcp"}]
env=w.get("environment",{})
if isinstance(env,list): env=dict(x.split("=",1) for x in env)
env.update({"PORT":"8080","SSL_PORT":"8443","SSL_CERT_FILE":"/etc/nginx/ssl/recoleccion.crt",
            "SSL_CERT_KEY_FILE":"/etc/nginx/ssl/recoleccion.key","SSL_PROTOCOLS":"TLSv1.2 TLSv1.3"})
w["environment"]=env
mounts=w.setdefault("volumes",[])
for name in ("recoleccion.crt","recoleccion.key"):
    target="/etc/nginx/ssl/"+name
    if any(v.get("target")==target for v in mounts):
        raise SystemExit("Montaje TLS previo inesperado: "+target)
    mounts.append({"type":"bind","source":str(Path(base)/"waf"/"tls-runtime"/name),
                   "target":target,"read_only":True,"bind":{"selinux":"z"}})
Path(out).write_text(json.dumps(d,indent=2)+"\n")
PY

(cd "$DIR" && docker compose -f "$TEMP/docker-compose.yml" --project-directory "$DIR" config --format json) > "$TEMP/candidate.json" || die "Compose candidato invalido."
python3 - "$TEMP/original.json" "$TEMP/candidate.json" "$IP" <<'PY'
import json,sys,copy
a=json.load(open(sys.argv[1]))
b=json.load(open(sys.argv[2]))
if a.get("name")!=b.get("name"): raise SystemExit("Cambio de proyecto Docker Compose")
if set(a["services"])!=set(b["services"]): raise SystemExit("Cambio de servicios")
for n in ("nginx","dnsmasq"):
    if a["services"][n]!=b["services"][n]: raise SystemExit("Servicio alterado: "+n)
wa=copy.deepcopy(a["services"]["waf"])
wb=copy.deepcopy(b["services"]["waf"])
for field in ("ports","volumes","environment"):
    wa.pop(field,None)
    wb.pop(field,None)
if wa!=wb: raise SystemExit("Propiedades WAF ajenas a HTTPS modificadas")
p=b["services"]["waf"].get("ports",[])
if not(len(p)==1 and int(p[0]["published"])==443 and int(p[0]["target"])==8443 and str(p[0].get("host_ip"))==sys.argv[3]):
    raise SystemExit("Puerto HTTPS incorrecto")
for name in ("recoleccion.crt","recoleccion.key"):
    target="/etc/nginx/ssl/"+name
    if not any(m.get("target")==target and m.get("read_only") for m in b["services"]["waf"]["volumes"]):
        raise SystemExit("Montaje TLS invalido: "+name)
print("[OK] Solo cambia la configuracion TLS del WAF.")
PY

# Preparar materiales de lectura exclusiva para el proceso nginx (GID 101).
# Importante: con SELinux Enforcing, un archivo cert_t no necesariamente
# puede ser leido en un bind mount. Etiquetar SOLO las copias del WAF.
prepare_waf_tls(){
    local gid
    gid="$(docker exec recoleccion_waf id -g nginx)" || die "No se pudo obtener GID nginx."
    [[ "$gid" =~ ^[0-9]+$ ]] || die "GID nginx invalido."
    [[ ! -L "$WAF_TLS" && ! -L "$WAF_CERT" && ! -L "$WAF_KEY" ]] || die "Ruta TLS WAF con enlace simbolico."
    if [[ -e "$WAF_TLS" && ! -d "$WAF_TLS" ]]; then
        die "Ruta TLS WAF no es directorio."
    fi
    install -d -o 0 -g "$gid" -m 0750 "$WAF_TLS"
    # No reemplazar materiales de una ejecucion anterior si el path no es regular.
    for f in "$WAF_CERT" "$WAF_KEY"; do
        [[ ! -e "$f" || -f "$f" ]] || die "Archivo TLS WAF invalido: $f"
    done
    install -o 0 -g "$gid" -m 0644 "$CERT" "$WAF_CERT"
    install -o 0 -g "$gid" -m 0640 "$KEY" "$WAF_KEY"

    if [[ "$(getenforce 2>/dev/null || true)" == "Enforcing" ||
          "$(getenforce 2>/dev/null || true)" == "Permissive" ]]; then
        command -v chcon >/dev/null 2>&1 || die "SELinux activo sin herramienta chcon."
        chcon -t container_file_t "$WAF_TLS" "$WAF_CERT" "$WAF_KEY" ||
            die "No se pudo etiquetar material TLS para el contenedor."
    fi

    # Verificar que el material copiado corresponde al certificado esperado.
    cmp -s "$CERT" "$WAF_CERT" || die "Copia de certificado TLS incorrecta."
    cmp -s "$KEY" "$WAF_KEY" || die "Copia de clave TLS incorrecta."
    ok "Material TLS WAF preparado (root:$gid, permisos restringidos, SELinux)."
}

prepare_waf_tls

info "Prevalidando WAF HTTPS en contenedor temporal (sin publicar puertos)..."
if ! (cd "$DIR" && docker compose -f "$TEMP/docker-compose.yml" --project-directory "$DIR" run --rm --no-deps waf nginx -t) > "$TEMP/preflight.log" 2>&1; then
    cat "$TEMP/preflight.log" >&2
    die "Fallo en prevalidacion HTTPS; no se modifico el servicio."
fi
ok "Prevalidacion HTTPS correcta."

BACKUP="$DIR/backups-waf/tls-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -m 0700 -p "$BACKUP"
cp -a "$COMPOSE" "$BACKUP/docker-compose.yml"
cp -a "$TEMPLATE" "$BACKUP/default.conf.template"
(cd "$BACKUP" && sha256sum docker-compose.yml default.conf.template > MANIFEST.sha256)
ok "Respaldo: $BACKUP"

CHANGED=1
cp "$TEMP/docker-compose.yml" "$COMPOSE"
dc config --quiet || die "Compose final invalido."
dc up -d --no-deps --force-recreate waf || die "Error recreando WAF HTTPS."
wait_healthy || die "WAF no alcanzo estado healthy."
docker exec recoleccion_waf nginx -t || die "Nginx WAF invalido."
docker exec recoleccion_proxy nginx -t || die "Nginx interno invalido."
verify_all https || {
    docker logs --tail 65 recoleccion_waf >&2 || true
    die "HTTPS no responde correctamente; revisar errores anteriores."
}
ports="$(docker port recoleccion_waf)"
[[ "$ports" == *"${IP}:443"* ]] || die "No se publica HTTPS 443."
[[ "$ports" != *"${IP}:80"* ]] || die "HTTP 80 publicado por WAF."
[[ -z "$(docker port recoleccion_proxy)" ]] || die "Nginx interno publica puertos."
if curl --noproxy '*' -sS --connect-timeout 2 --max-time 3 "http://$IP/" -o /dev/null 2>/dev/null; then
    die "Otro servicio continua respondiendo en HTTP/80."
fi
SUCCESS=1
CHANGED=0
printf '\n'
ok "HTTPS funcionando para los tres dominios; WAF en ${IP}:443 y HTTP publico cerrado."
info "Se conservan el Nginx interno, DNS, reglas WAF y backup: $BACKUP"
info "En RL-FW-01 habilitar TCP/443 y cerrar TCP/80 solo tras verificar desde un cliente."
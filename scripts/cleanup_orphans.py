import json
import os
import subprocess
from datetime import datetime, timezone

NOMBRE_DEL_BUCKET = "previewpanda-tfstate-nico2026"
CARPETA_DE_PREVIEWS = "previews/"
DIAS_LIMITE = int(os.environ.get("DIAS_LIMITE", "3"))
REPOSITORIO_GITHUB = "NicooGon/previewpanda"
NOMBRE_DEL_REPOSITORIO_ECR = "previewpanda"


def obtener_lista_de_entornos():
    """Busca en AWS que archivos de state hay guardados."""

    comando = [
        "aws", "s3api", "list-objects-v2",
        "--bucket", NOMBRE_DEL_BUCKET,
        "--prefix", CARPETA_DE_PREVIEWS,
        "--output", "json",
    ]

    resultado = subprocess.run(comando, capture_output=True, text=True, check=True)
    respuesta_completa = json.loads(resultado.stdout)
    lista_de_archivos = respuesta_completa.get("Contents", [])

    entornos = []

    for archivo in lista_de_archivos:
        ruta_del_archivo = archivo["Key"]

        if not ruta_del_archivo.endswith("terraform.tfstate"):
            continue

        partes = ruta_del_archivo.split("/")
        nombre_de_la_carpeta = partes[1]

        if not nombre_de_la_carpeta.startswith("pr-"):
            continue

        numero_de_pr = nombre_de_la_carpeta[3:]

        fecha_de_modificacion = datetime.fromisoformat(archivo["LastModified"])
        ahora = datetime.now(timezone.utc)
        dias_sin_cambios = (ahora - fecha_de_modificacion).days

        entorno = {
            "numero_de_pr": numero_de_pr,
            "ruta_del_archivo": ruta_del_archivo,
            "dias_sin_cambios": dias_sin_cambios,
        }
        entornos.append(entorno)

    return entornos


def consultar_estado_del_pr(numero_de_pr):
    """
    Pregunta a GitHub por ese PR.
    Devuelve "OPEN", "CERRADO" o "DESCONOCIDO" (si gh fallo por otra razon
    que no sea "el PR no existe").
    """

    comando = [
        "gh", "pr", "view", numero_de_pr,
        "--repo", REPOSITORIO_GITHUB,
        "--json", "state",
        "-q", ".state",
    ]

    resultado = subprocess.run(comando, capture_output=True, text=True)

    if resultado.returncode == 0:
        estado = resultado.stdout.strip()
        return "OPEN" if estado == "OPEN" else "CERRADO"

    error = resultado.stderr.lower()
    if "could not resolve" in error or "no pull requests found" in error:
        return "CERRADO"

    return "DESCONOCIDO"


def destruir_entorno(numero_de_pr):
    """Llama al mismo script bash que usan destroy-preview.yml y destroy.yml."""

    nombre_del_entorno = "pr-" + numero_de_pr
    print("Destruyendo entorno huerfano:", nombre_del_entorno)

    variables_de_entorno = {
        **os.environ,
        "TF_STATE_BUCKET": NOMBRE_DEL_BUCKET,
        "ECR_REPOSITORY": NOMBRE_DEL_REPOSITORIO_ECR,
    }

    subprocess.run(
        ["bash", "scripts/destruir_entorno.sh", nombre_del_entorno],
        env=variables_de_entorno,
        check=True,
    )


def main():
    """Revisa todos los entornos y destruye los huerfanos."""

    entornos = obtener_lista_de_entornos()
    print("Se encontraron", len(entornos), "entornos de preview.")

    for entorno in entornos:
        numero_de_pr = entorno["numero_de_pr"]
        dias_sin_cambios = entorno["dias_sin_cambios"]
        nombre_del_entorno = "pr-" + numero_de_pr

        estado_del_pr = consultar_estado_del_pr(numero_de_pr)

        if estado_del_pr == "OPEN":
            print(nombre_del_entorno, "-> el PR sigue abierto, no se toca.")
            continue

        if estado_del_pr == "DESCONOCIDO":
            print(nombre_del_entorno, "-> no se pudo confirmar el estado del PR, no se toca.")
            continue

        if dias_sin_cambios <= DIAS_LIMITE:
            print(nombre_del_entorno, "-> cerrado, pero todavia no pasaron", DIAS_LIMITE, "dias.")
            continue

        destruir_entorno(numero_de_pr)

    print("Listo, revision terminada.")


if __name__ == "__main__":
    main()

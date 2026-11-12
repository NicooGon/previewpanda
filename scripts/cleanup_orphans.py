import json
import subprocess
from datetime import datetime, timezone

NOMBRE_DEL_BUCKET = "previewpanda-tfstate-nico2026"
CARPETA_DE_PREVIEWS = "previews/"
DIAS_LIMITE = 3
CARPETA_DEL_MODULO_TERRAFORM = "infra/preview"
REPOSITORIO_GITHUB = "NicooGon/previewpanda"


def obtener_lista_de_entornos():
    """Busca en AWS que archivos de state hay guardados."""

    # Comando de AWS para listar los archivos del bucket.
    comando = [
        "aws", "s3api", "list-objects-v2",
        "--bucket", NOMBRE_DEL_BUCKET,
        "--prefix", CARPETA_DE_PREVIEWS,
        "--output", "json",
    ]

    resultado = subprocess.run(comando, capture_output=True, text=True, check=True)

    # AWS devuelve JSON como texto; esto lo convierte en datos de Python.
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

        # AWS da la fecha en texto; la convertimos para poder restarla.
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


def el_pull_request_esta_abierto(numero_de_pr):
    """Pregunta a GitHub si ese PR sigue abierto."""

    comando = [
        "gh", "pr", "view", numero_de_pr,
        "--repo", REPOSITORIO_GITHUB,
        "--json", "state",
        "-q", ".state",
    ]

    resultado = subprocess.run(comando, capture_output=True, text=True)

    if resultado.returncode != 0:
        return False

    estado = resultado.stdout.strip()
    return estado == "OPEN"


def destruir_entorno(numero_de_pr, ruta_del_archivo):
    """Corre terraform destroy sobre el state de un PR puntual."""

    nombre_del_entorno = "pr-" + numero_de_pr
    print("Destruyendo entorno huerfano:", nombre_del_entorno)

    subprocess.run(
        [
            "terraform", "init",
            "-reconfigure",
            "-backend-config=key=" + ruta_del_archivo,
        ],
        cwd=CARPETA_DEL_MODULO_TERRAFORM,
        check=True,
    )

    subprocess.run(
        [
            "terraform", "destroy",
            "-auto-approve",
            "-var=env_name=" + nombre_del_entorno,
        ],
        cwd=CARPETA_DEL_MODULO_TERRAFORM,
        check=True,
    )


def main():
    """Revisa todos los entornos y destruye los huerfanos."""

    entornos = obtener_lista_de_entornos()
    print("Se encontraron", len(entornos), "entornos de preview.")

    for entorno in entornos:
        numero_de_pr = entorno["numero_de_pr"]
        ruta_del_archivo = entorno["ruta_del_archivo"]
        dias_sin_cambios = entorno["dias_sin_cambios"]
        nombre_del_entorno = "pr-" + numero_de_pr

        if el_pull_request_esta_abierto(numero_de_pr):
            print(nombre_del_entorno, "-> el PR sigue abierto, no se toca.")
            continue

        if dias_sin_cambios <= DIAS_LIMITE:
            print(nombre_del_entorno, "-> cerrado, pero todavia no pasaron", DIAS_LIMITE, "dias.")
            continue

        destruir_entorno(numero_de_pr, ruta_del_archivo)

    print("Listo, revision terminada.")


if __name__ == "__main__":
    main()

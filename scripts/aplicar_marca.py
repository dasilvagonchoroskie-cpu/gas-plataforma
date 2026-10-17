#!/usr/bin/env python3
"""Aplica a marca da revenda nos três aplicativos.

Lê a pasta marca/ e gera tudo o que depende dela:

  marca/marca.json        nome do app, frase, nomes dos painéis e cores
  marca/icone.png         ícone quadrado, de preferência 1024 x 1024
  marca/icone_frente.png  (opcional) só o símbolo, com fundo transparente,
                          para o ícone "adaptável" do Android
  marca/logo.png          logo das telas de entrada (fundo transparente)

Gera: ícones Android (cliente, Super Central e Central), ícones do iPhone
(cliente), ícones do painel web, cores dos avisos e a cópia do logo usada
pelos apps. A esteira roda este script antes de gerar os APKs; rodar à mão
também funciona: python3 scripts/aplicar_marca.py
"""
import json
import re
import shutil
import sys
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
MARCA = RAIZ / "marca"
APPS_ANDROID = ["cliente", "painel"]

# Tamanhos do Android em pixels: ícone comum (48 dp) e frente do adaptável (108 dp).
DENSIDADES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

CHAVES_OBRIGATORIAS = ["NOME_APP", "NOME_SUPER_CENTRAL", "NOME_CENTRAL", "COR_PRINCIPAL"]


def falhar(mensagem: str) -> None:
    print(f"ERRO na marca: {mensagem}", file=sys.stderr)
    sys.exit(1)


def ler_cor(texto: str, campo: str) -> tuple[int, int, int]:
    if not re.fullmatch(r"#?[0-9A-Fa-f]{6}", texto or ""):
        falhar(f'{campo} precisa ser uma cor como "#0B5C7A" (veio "{texto}").')
    texto = texto.lstrip("#")
    return tuple(int(texto[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def abrir_quadrada(caminho: Path, minimo: int) -> Image.Image:
    if not caminho.exists():
        falhar(f"falta o arquivo {caminho.relative_to(RAIZ)}.")
    img = Image.open(caminho).convert("RGBA")
    if img.width != img.height:
        falhar(f"{caminho.name} precisa ser quadrado (veio {img.width} x {img.height}).")
    if img.width < minimo:
        falhar(f"{caminho.name} precisa ter pelo menos {minimo} x {minimo} pixels.")
    return img


def sem_transparencia(img: Image.Image, fundo: tuple[int, int, int]) -> Image.Image:
    base = Image.new("RGBA", img.size, fundo + (255,))
    base.alpha_composite(img)
    return base.convert("RGB")


def no_centro(img: Image.Image, proporcao: float, lado: int,
              fundo: tuple[int, int, int, int] = (0, 0, 0, 0)) -> Image.Image:
    """Coloca a imagem reduzida no centro de um quadro (margem de segurança)."""
    quadro = Image.new("RGBA", (lado, lado), fundo)
    menor = round(lado * proporcao)
    quadro.alpha_composite(img.resize((menor, menor), Image.LANCZOS),
                           ((lado - menor) // 2, (lado - menor) // 2))
    return quadro


def salvar(img: Image.Image, destino: Path, lado: int) -> None:
    destino.parent.mkdir(parents=True, exist_ok=True)
    img.resize((lado, lado), Image.LANCZOS).save(destino, optimize=True)


def cor_hex(cor: tuple[int, int, int]) -> str:
    return "#FF{:02X}{:02X}{:02X}".format(*cor)


def android(app: str, icone: Image.Image, frente: Image.Image,
            fundo: tuple[int, int, int], principal: tuple[int, int, int]) -> None:
    res = RAIZ / "apps" / app / "android" / "app" / "src" / "main" / "res"
    for nome, fator in DENSIDADES.items():
        salvar(icone, res / f"mipmap-{nome}" / "ic_launcher.png", round(48 * fator))
        salvar(frente, res / f"mipmap-{nome}" / "ic_launcher_foreground.png", round(108 * fator))
    adaptavel = res / "mipmap-anydpi-v26" / "ic_launcher.xml"
    adaptavel.parent.mkdir(parents=True, exist_ok=True)
    adaptavel.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Gerado por scripts/aplicar_marca.py (não editar à mão). -->\n"
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    (res / "values" / "cores_marca.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Gerado por scripts/aplicar_marca.py a partir de marca/marca.json. -->\n"
        "<resources>\n"
        f'    <color name="ic_launcher_background">{cor_hex(fundo)}</color>\n'
        f'    <color name="cor_notificacao">{cor_hex(principal)}</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )


def iphone(icone_cheio: Image.Image) -> None:
    pasta = RAIZ / "apps" / "cliente" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = pasta / "Contents.json"
    if not contents.exists():
        return
    for item in json.loads(contents.read_text(encoding="utf-8"))["images"]:
        arquivo = item.get("filename")
        if not arquivo:
            continue
        lado = round(float(item["size"].split("x")[0]) * int(item["scale"].rstrip("x")))
        salvar(icone_cheio, pasta / arquivo, lado)


def painel_web(icone_cheio: Image.Image, frente: Image.Image,
               fundo: tuple[int, int, int], principal: tuple[int, int, int]) -> None:
    web = RAIZ / "apps" / "painel" / "web"
    salvar(icone_cheio, web / "favicon.png", 64)
    salvar(icone_cheio, web / "icons" / "Icon-192.png", 192)
    salvar(icone_cheio, web / "icons" / "Icon-512.png", 512)
    mascaravel = sem_transparencia(no_centro(frente, 0.8, 1024), fundo).convert("RGBA")
    salvar(mascaravel, web / "icons" / "Icon-maskable-192.png", 192)
    salvar(mascaravel, web / "icons" / "Icon-maskable-512.png", 512)
    manifesto = web / "manifest.json"
    dados = json.loads(manifesto.read_text(encoding="utf-8"))
    dados["theme_color"] = "#{:02X}{:02X}{:02X}".format(*principal)
    manifesto.write_text(json.dumps(dados, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def principal() -> None:
    config = json.loads((MARCA / "marca.json").read_text(encoding="utf-8"))
    for chave in CHAVES_OBRIGATORIAS:
        if not str(config.get(chave, "")).strip():
            falhar(f"marca.json precisa ter {chave}.")
    principal_ = ler_cor(config["COR_PRINCIPAL"], "COR_PRINCIPAL")
    fundo = ler_cor(config.get("COR_FUNDO_ICONE") or config["COR_PRINCIPAL"], "COR_FUNDO_ICONE")

    icone = abrir_quadrada(MARCA / "icone.png", 512)
    icone_cheio = sem_transparencia(icone, fundo).convert("RGBA")
    caminho_frente = MARCA / "icone_frente.png"
    if caminho_frente.exists():
        # Símbolo um pouco menor, para caber no recorte redondo do Android.
        frente = no_centro(abrir_quadrada(caminho_frente, 512), 0.86, 1024)
    else:
        frente = no_centro(icone_cheio, 0.66, 1024)

    for app in APPS_ANDROID:
        android(app, icone_cheio, frente, fundo, principal_)
    iphone(icone_cheio)
    painel_web(icone_cheio, frente, fundo, principal_)

    logo = abrir_quadrada(MARCA / "logo.png", 256)
    destino_logo = RAIZ / "packages" / "design_system" / "assets" / "marca" / "logo.png"
    destino_logo.parent.mkdir(parents=True, exist_ok=True)
    if logo.width > 512:
        salvar(logo, destino_logo, 512)
    else:
        shutil.copyfile(MARCA / "logo.png", destino_logo)

    print(f'Marca aplicada: "{config["NOME_APP"]}", cor {config["COR_PRINCIPAL"]}.')


if __name__ == "__main__":
    principal()

#!/usr/bin/env python3
"""Desenha a marca PROVISÓRIA (gota com chama) até a revenda mandar a dela.

Gera em marca/: icone.png (ícone cheio), icone_frente.png (só o símbolo, fundo
transparente, para o ícone adaptável do Android) e logo.png (símbolo na cor
da marca, para as telas de entrada). Uso: python3 scripts/desenhar_marca_provisoria.py
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
MARCA = RAIZ / "marca"
ESCALA = 4  # desenha maior e reduz, para as bordas ficarem lisas


def cor(texto):
    texto = texto.lstrip("#")
    return tuple(int(texto[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def gota(cx, cy, altura, largura=0.78, passos=400):
    """Pontos de uma gota com a ponta para cima, centrada em (cx, cy)."""
    pontos = []
    for i in range(passos):
        t = 2 * math.pi * i / passos
        x = math.sin(t) * math.sin(t / 2) * largura
        y = -math.cos(t)
        pontos.append((cx + x * altura / 2, cy + y * altura / 2))
    return pontos


def simbolo(tamanho, cor_gota, cor_chama):
    """Gota (água) com uma chama (gás) dentro."""
    lado = tamanho * ESCALA
    img = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon(gota(lado * 0.5, lado * 0.53, lado * 0.92), fill=cor_gota)
    # Chama: duas línguas de fogo sobrepostas, na parte de baixo da gota.
    d.polygon(gota(lado * 0.5, lado * 0.66, lado * 0.46, largura=0.70), fill=cor_chama)
    d.polygon(gota(lado * 0.555, lado * 0.72, lado * 0.26, largura=0.62), fill=cor_gota)
    return img.resize((tamanho, tamanho), Image.LANCZOS)


def principal():
    config = json.loads((MARCA / "marca.json").read_text(encoding="utf-8"))
    principal_ = cor(config["COR_PRINCIPAL"])
    fundo = cor(config.get("COR_FUNDO_ICONE", config["COR_PRINCIPAL"]))
    branco = (255, 255, 255, 255)

    # Ícone cheio: fundo da marca e símbolo branco ocupando ~62% do quadro.
    icone = Image.new("RGBA", (1024, 1024), fundo)
    s = simbolo(640, branco, fundo)
    icone.alpha_composite(s, ((1024 - 640) // 2, (1024 - 640) // 2))
    icone.convert("RGB").save(MARCA / "icone.png", optimize=True)

    # Frente do ícone adaptável: só o símbolo, transparente.
    frente = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    frente.alpha_composite(s, ((1024 - 640) // 2, (1024 - 640) // 2))
    frente.save(MARCA / "icone_frente.png", optimize=True)

    # Logo das telas de entrada: símbolo na cor da marca, chama branca.
    simbolo(512, principal_, branco).save(MARCA / "logo.png", optimize=True)
    print("Marca provisória desenhada em", MARCA)


if __name__ == "__main__":
    principal()

class_name MemoramaData
## ================================================================
## EDITAR AQUÍ — Configuración de niveles del memorama
## ================================================================
##
## Para cambiar el tamaño de cada nivel edita LEVEL_SIZES.
## Para cambiar el contenido de las cartas edita LEVEL_CONTENT.
##
## Reglas:
##   • columns × rows debe ser un número PAR (para formar pares).
##   • LEVEL_CONTENT[n] debe tener exactamente (columns × rows / 2)
##     entradas; si hay menos se rellenan con "?" automáticamente.
##
## Cada entrada es un PAR MIXTO: [carta_texto, carta_imagen]
## La primera carta muestra el texto; la segunda muestra la imagen.
## El jugador debe encontrar cuál texto corresponde a cuál imagen.
##
##   Par ejemplo:
##   [
##     {"type": "text",  "value": "Garrapata"},
##     {"type": "image", "value": "res://assets/monte/garrapata.png"},
##   ],
##
## También puedes usar texto en ambas cartas si no tienes imagen aún:
##   [
##     {"type": "text", "value": "Concepto"},
##     {"type": "text", "value": "Definición"},
##   ],
## ================================================================


# ── Títulos de cada nivel ────────────────────────────────────────
const LEVEL_TITLES: Array = [
	"Tipos de Garrapatas",
	"Cómo quitar una garrapata",
]

# ── Tamaños de cuadrícula por nivel [columnas, filas] ───────────
const LEVEL_SIZES: Array = [
	[2, 2],   # Nivel 1 →  4 cartas =  2 pares  · Tipos de Garrapatas
	[2, 4],   # Nivel 2 →  8 cartas =  4 pares  · Cómo quitar una garrapata
]


# ── Contenido de las cartas ─────────────────────────────────────
# Cada entrada = [carta_A, carta_B]  →  forman una pareja
const LEVEL_CONTENT: Array = [

	# ── Nivel 1 · Tipos de Garrapatas · 2 pares ────────────────
	[
		[{"type": "text", "value": "Garrapata blanda"}, {"type": "image", "value": "res://assets/monte/memorama_img/blanda.png"}],
		[{"type": "text", "value": "Garrapata dura"}, {"type": "image", "value": "res://assets/monte/memorama_img/dura.png"}],
	],

	# ── Nivel 2 · Cómo quitar una garrapata · 4 pares ──────────
	[
		[{"type": "text", "value": "Paso 1"}, {"type": "image", "value": "res://assets/monte/memorama_img/paso1.png"}],
		[{"type": "text", "value": "Paso 2"}, {"type": "image", "value": "res://assets/monte/memorama_img/paso2.png"}],
		[{"type": "text", "value": "Paso 3"}, {"type": "image", "value": "res://assets/monte/memorama_img/paso3.png"}],
		[{"type": "text", "value": "Paso 4"}, {"type": "image", "value": "res://assets/monte/memorama_img/paso4.png"}],
	],
]

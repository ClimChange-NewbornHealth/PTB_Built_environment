# =============================================================
# PRODUCTO 3 - MAPAS DESCRIPTIVOS
# FONDECYT 11240322
# =============================================================

library(ggplot2)
library(sf)
library(dplyr)
library(ggspatial)
library(patchwork)
library(gridExtra)
library(grid)

# =============================================================
# 0. CARGAR DATOS BASE
# =============================================================

comunas_33 <- st_read("01_Input/Shapefiles/Comunas_santiago_33/comunas_santiago_33_WGS84.shp")
producto1 <- read.csv("01_Input/Producto1/producto1_entorno_urbano.csv")

dir.create("01_Input/Producto3", showWarnings = FALSE)
dir.create("03_Output/Maps", showWarnings = FALSE)

# =============================================================
# 1. MAPA DE REFERENCIA (nombres de comunas -- se muestra una vez)
# =============================================================

comunas_33 <- comunas_33 %>%
  arrange(COMUNA) %>%
  mutate(numero_mapa = row_number())

tabla_referencia <- comunas_33 %>%
  st_drop_geometry() %>%
  select(numero_mapa, COMUNA) %>%
  arrange(numero_mapa)

# Tabla en 2 columnas (16 y 17 comunas) para que se vea compacta
mitad <- ceiling(nrow(tabla_referencia) / 2)
tabla_col1 <- tabla_referencia[1:mitad, ]
tabla_col2 <- tabla_referencia[(mitad + 1):nrow(tabla_referencia), ]

if (nrow(tabla_col2) < nrow(tabla_col1)) {
  tabla_col2 <- rbind(tabla_col2, data.frame(numero_mapa = NA, COMUNA = NA))
}

tabla_dos_columnas <- data.frame(
  N1 = tabla_col1$numero_mapa, Comuna1 = tabla_col1$COMUNA,
  N2 = tabla_col2$numero_mapa, Comuna2 = tabla_col2$COMUNA
)
tabla_dos_columnas[is.na(tabla_dos_columnas)] <- ""

# Mapa base con números y colores pastel por comuna
mapa_referencia <- ggplot(comunas_33) +
  geom_sf(aes(fill = COMUNA), color = "white", size = 0.4, show.legend = FALSE) +
  geom_sf_text(aes(label = numero_mapa), size = 3, color = "black", fontface = "bold") +
  scale_fill_manual(values = colorRampPalette(
    c("#A8DADC", "#F4A896", "#B8E0D2", "#F6E27F", "#D6C6E1", "#FFCAD4", "#A9DEF9")
  )(33)) +
  annotation_north_arrow(location = "tr", which_north = "true",
                         style = north_arrow_fancy_orienteering(),
                         height = unit(1, "cm"), width = unit(1, "cm")) +
  annotation_scale(location = "bl", width_hint = 0.3) +
  labs(title = "Mapa de referencia - Comunas de estudio",
       subtitle = "Región Metropolitana de Santiago") +
  theme_void() +
  theme(
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(color = "grey40")
  )

# Tabla de referencia como objeto gráfico
tabla_grafica <- tableGrob(
  tabla_dos_columnas,
  rows = NULL,
  cols = c("N°", "Comuna", "N°", "Comuna"),
  theme = ttheme_minimal(
    core = list(fg_params = list(fontsize = 9, hjust = 0, x = 0.05),
                padding = unit(c(2.5, 2), "mm")),
    colhead = list(fg_params = list(fontsize = 9.5, fontface = "bold"))
  )
)

# Mapa + tabla (tabla empujada hacia abajo con espacio vacío arriba)
columna_derecha <- plot_spacer() / wrap_elements(tabla_grafica) +
  plot_layout(heights = c(0.4, 0.6))

mapa_con_leyenda <- mapa_referencia + columna_derecha +
  plot_layout(widths = c(2.5, 1))

mapa_con_leyenda

ggsave("03_Output/Maps/mapa_referencia_comunas.png",
       plot = mapa_con_leyenda, width = 10, height = 7, dpi = 300, bg = "white")

# =============================================================
# 2. FUNCIONES GENÉRICAS (se definen una sola vez)
# =============================================================

# 2a. Mapa de una variable (un solo año)
# Norte: arriba-derecha | Escala: abajo-izquierda | CRS: abajo
crear_mapa_variable <- function(datos_sf, variable, titulo, subtitulo, unidad_leyenda,
                                paleta = "viridis", direccion = -1, limites = NULL) {
  ggplot(datos_sf) +
    geom_sf(aes(fill = .data[[variable]]), color = "white", size = 0.3) +
    scale_fill_viridis_c(name = unidad_leyenda, option = paleta, direction = direccion,
                         limits = limites,
                         guide = guide_colorbar(title.position = "top", title.hjust = 0.5)) +
    annotation_north_arrow(location = "tr", which_north = "true",
                           style = north_arrow_fancy_orienteering(),
                           height = unit(1.5, "cm"), width = unit(1.5, "cm")) +
    annotation_scale(location = "bl", width_hint = 0.25, text_cex = 0.8) +
    labs(title = titulo, subtitle = subtitulo,
         caption = "CRS: WGS84 (EPSG:4326)") +
    theme_void() +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "grey40"),
      plot.caption = element_text(color = "grey60", size = 7, hjust = 0),
      legend.title = element_text(size = 11),
      legend.text = element_text(size = 9),
      legend.key.width = unit(0.5, "cm"),
      legend.key.height = unit(0.8, "cm"),
      plot.margin = margin(5, 5, 5, 5)
    )
}

# 2b. Comparación de dos años en paneles, con escala compartida
# Requiere una columna "anio" en los datos
crear_mapa_comparacion <- function(datos_sf, variable, titulo, subtitulo, unidad_leyenda,
                                   limites = NULL, paleta = "viridis", direccion = -1,
                                   nota_fuente = NULL) {
  ggplot(datos_sf) +
    geom_sf(aes(fill = .data[[variable]]), color = "white", size = 0.3) +
    scale_fill_viridis_c(name = unidad_leyenda, option = paleta, direction = direccion,
                         limits = limites,
                         guide = guide_colorbar(title.position = "top", title.hjust = 0.5)) +
    facet_wrap(~ anio) +
    annotation_scale(location = "bl", width_hint = 0.25, text_cex = 0.7) +
    labs(title = titulo, subtitle = subtitulo,
         caption = paste0("CRS: WGS84 (EPSG:4326)", nota_fuente)) +
    theme_void() +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "grey40"),
      plot.caption = element_text(color = "grey60", size = 7, hjust = 0),
      legend.title = element_text(size = 11),
      legend.text = element_text(size = 9),
      legend.key.width = unit(0.5, "cm"),
      legend.key.height = unit(0.8, "cm"),
      strip.text = element_text(face = "bold", size = 11)
    )
}

# 2c. Mapa de una variable con gradiente de un solo color (gris claro -> color oscuro)
# Para variables concentradas en pocas comunas, donde viridis se ve como mancha
crear_mapa_gradiente <- function(datos_sf, variable, titulo, subtitulo, unidad_leyenda,
                                 color_alto, etiquetas = waiver()) {
  ggplot(datos_sf) +
    geom_sf(aes(fill = .data[[variable]]), color = "white", size = 0.3) +
    scale_fill_gradient(low = "grey90", high = color_alto, name = unidad_leyenda,
                        labels = etiquetas,
                        guide = guide_colorbar(title.position = "top", title.hjust = 0.5)) +
    annotation_north_arrow(location = "tr", which_north = "true",
                           style = north_arrow_fancy_orienteering(),
                           height = unit(1.5, "cm"), width = unit(1.5, "cm")) +
    annotation_scale(location = "bl", width_hint = 0.25, text_cex = 0.8) +
    labs(title = titulo, subtitle = subtitulo,
         caption = "CRS: WGS84 (EPSG:4326)") +
    theme_void() +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "grey40"),
      plot.caption = element_text(color = "grey60", size = 7, hjust = 0),
      legend.title = element_text(size = 11),
      legend.text = element_text(size = 9)
    )
}


# =============================================================
# 3. MAPA: DISTANCIA A SALUD (2019)
# =============================================================

mapa_salud_2019 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2019) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, dist_salud_km),
    by = c("CUT_COM" = "cod_com")
  )

mapa_dist_salud <- crear_mapa_variable(
  datos_sf = mapa_salud_2019,
  variable = "dist_salud_km",
  titulo = "Distancia mínima a establecimiento de salud",
  subtitulo = "Desde centro cívico/municipal, 2019 · Fuente: DEIS/MINSAL",
  unidad_leyenda = "Distancia\n(km)"
)

mapa_dist_salud

ggsave("03_Output/Maps/mapa_dist_salud_2019.png",
       plot = mapa_dist_salud, width = 8, height = 6, dpi = 300, bg = "white")

# =============================================================
# 4. MAPA: DENSIDAD POBLACIONAL (2020)
# Fuente WorldPop. Ojo: población de Puente Alto parece sobreestimada
# vs. INE (pendiente de revisar con Estela).
# =============================================================

mapa_densidad_2020 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2020) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, densidad_hab_km2),
    by = c("CUT_COM" = "cod_com")
  )

mapa_densidad <- crear_mapa_variable(
  datos_sf = mapa_densidad_2020,
  variable = "densidad_hab_km2",
  titulo = "Densidad poblacional",
  subtitulo = "Año 2020 · Fuente: WorldPop",
  unidad_leyenda = "Densidad\n(hab/km²)"
)

mapa_densidad

ggsave("03_Output/Maps/mapa_densidad_2020.png",
       plot = mapa_densidad, width = 8, height = 6, dpi = 300, bg = "white")

# =============================================================
# 5. MAPAS: PARQUES URBANOS (2009 vs 2019)
# Escala compartida entre años para poder comparar.
# Limitación: Lo Barnechea subestimado en 2009; Huechuraba cae sin explicación.
# =============================================================

mapa_parques_2009 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2009) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, pct_parques),
    by = c("CUT_COM" = "cod_com")
  )

mapa_parques_2019 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2019) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, pct_parques),
    by = c("CUT_COM" = "cod_com")
  )

# Verificación rápida de los joins (sin NA esperado)
mapa_parques_2009 %>% st_drop_geometry() %>% select(CUT_COM, COMUNA, pct_parques) %>% head(5)
mapa_parques_2019 %>% st_drop_geometry() %>% select(CUT_COM, COMUNA, pct_parques) %>% head(5)

# Rango combinado de ambos años para escala compartida
rango_parques <- range(c(mapa_parques_2009$pct_parques, mapa_parques_2019$pct_parques), na.rm = TRUE)
rango_parques

# Mapas individuales
mapa_pct_parques_2009 <- crear_mapa_variable(
  datos_sf = mapa_parques_2009,
  variable = "pct_parques",
  titulo = "Porcentaje de parques urbanos",
  subtitulo = "Año 2009",
  unidad_leyenda = "% parques",
  limites = rango_parques
)

mapa_pct_parques_2019 <- crear_mapa_variable(
  datos_sf = mapa_parques_2019,
  variable = "pct_parques",
  titulo = "Porcentaje de parques urbanos",
  subtitulo = "Año 2019",
  unidad_leyenda = "% parques",
  limites = rango_parques
)

mapa_pct_parques_2009
mapa_pct_parques_2019

ggsave("03_Output/Maps/mapa_pct_parques_2009.png",
       plot = mapa_pct_parques_2009, width = 8, height = 6, dpi = 300, bg = "white")

ggsave("03_Output/Maps/mapa_pct_parques_2019.png",
       plot = mapa_pct_parques_2019, width = 8, height = 6, dpi = 300, bg = "white")

# Comparación lado a lado (una sola leyenda)
datos_parques <- bind_rows(
  mapa_parques_2009 %>% mutate(anio = "2009"),
  mapa_parques_2019 %>% mutate(anio = "2019")
)

mapa_parques_comparacion <- crear_mapa_comparacion(
  datos_sf = datos_parques,
  variable = "pct_parques",
  titulo = "Porcentaje de parques urbanos",
  subtitulo = "Comparación 2009 vs. 2019",
  unidad_leyenda = "% parques",
  limites = rango_parques
)

mapa_parques_comparacion

ggsave("03_Output/Maps/mapa_pct_parques_comparacion_2009_2019.png",
       plot = mapa_parques_comparacion, width = 14, height = 6, dpi = 300, bg = "white")

# =============================================================
# 6. MAPA: NDVI VERANO (2009 vs 2020)
# =============================================================

mapa_ndvi_2009 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2009) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, ndvi_verano),
    by = c("CUT_COM" = "cod_com")
  )

mapa_ndvi_2020 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2020) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, ndvi_verano),
    by = c("CUT_COM" = "cod_com")
  )

rango_ndvi <- range(c(mapa_ndvi_2009$ndvi_verano, mapa_ndvi_2020$ndvi_verano), na.rm = TRUE)
rango_ndvi

datos_ndvi_combinados <- bind_rows(
  mapa_ndvi_2009 %>% mutate(anio = "2009"),
  mapa_ndvi_2020 %>% mutate(anio = "2020")
)

mapa_ndvi_comparacion <- crear_mapa_comparacion(
  datos_sf = datos_ndvi_combinados,
  variable = "ndvi_verano",
  titulo = "Índice de vegetación (NDVI), verano",
  subtitulo = "Comparación 2009 vs. 2020",
  unidad_leyenda = "NDVI",
  limites = rango_ndvi
)

mapa_ndvi_comparacion

ggsave("03_Output/Maps/mapa_ndvi_comparacion_2009_2020.png",
       plot = mapa_ndvi_comparacion, width = 12, height = 6, dpi = 300, bg = "white")

# =============================================================
# 7. MAPA: TEMPERATURA SUPERFICIAL LST VERANO (2009 vs 2020)
# =============================================================

mapa_lst_2009 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2009) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, lst_verano),
    by = c("CUT_COM" = "cod_com")
  )

mapa_lst_2020 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2020) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, lst_verano),
    by = c("CUT_COM" = "cod_com")
  )

rango_lst <- range(c(mapa_lst_2009$lst_verano, mapa_lst_2020$lst_verano), na.rm = TRUE)
rango_lst

datos_lst_combinados <- bind_rows(
  mapa_lst_2009 %>% mutate(anio = "2009"),
  mapa_lst_2020 %>% mutate(anio = "2020")
)

mapa_lst_comparacion <- crear_mapa_comparacion(
  datos_sf = datos_lst_combinados,
  variable = "lst_verano",
  titulo = "Temperatura superficial terrestre (LST), verano",
  subtitulo = "Comparación 2009 vs. 2020",
  unidad_leyenda = "LST (°C)",
  limites = rango_lst,
  paleta = "inferno"
)

mapa_lst_comparacion

# Promedio por año (para citar el aumento)
comparacion_lst <- datos_lst_combinados %>%
  st_drop_geometry() %>%
  group_by(anio) %>%
  summarise(lst_promedio = round(mean(lst_verano, na.rm = TRUE), 2))

comparacion_lst

ggsave("03_Output/Maps/mapa_lst_comparacion_2009_2020.png",
       plot = mapa_lst_comparacion, width = 12, height = 6, dpi = 300, bg = "white")

# =============================================================
# 8. MAPA: SUPERFICIE IMPERMEABLE (2009 vs 2020)
# GHSL solo publica 2010/2015/2020: "2009" usa el dato de 2010.
# =============================================================

mapa_impervious_2009 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2009) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, sup_impermeable),
    by = c("CUT_COM" = "cod_com")
  )

mapa_impervious_2020 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2020) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, sup_impermeable),
    by = c("CUT_COM" = "cod_com")
  )

rango_impervious <- range(c(mapa_impervious_2009$sup_impermeable, mapa_impervious_2020$sup_impermeable), na.rm = TRUE)
rango_impervious

datos_impervious_combinados <- bind_rows(
  mapa_impervious_2009 %>% mutate(anio = "2009 (dato 2010)"),
  mapa_impervious_2020 %>% mutate(anio = "2020")
)

mapa_impervious_comparacion <- crear_mapa_comparacion(
  datos_sf = datos_impervious_combinados,
  variable = "sup_impermeable",
  titulo = "Superficie impermeable (construida)",
  subtitulo = "Comparación 2009 vs. 2020",
  unidad_leyenda = "Sup. impermeable\n(m²/km²)",
  limites = rango_impervious,
  paleta = "magma",
  nota_fuente = " · GHSL, resolución cada 5 años"
)

mapa_impervious_comparacion

# Resumen por año (para citar el cambio: +6.8% en el promedio)
comparacion_impervious <- datos_impervious_combinados %>%
  st_drop_geometry() %>%
  group_by(anio) %>%
  summarise(
    promedio = round(mean(sup_impermeable, na.rm = TRUE), 2),
    mediana = round(median(sup_impermeable, na.rm = TRUE), 2),
    minimo = round(min(sup_impermeable, na.rm = TRUE), 2),
    maximo = round(max(sup_impermeable, na.rm = TRUE), 2)
  )

comparacion_impervious

ggsave("03_Output/Maps/mapa_impervious_comparacion_2009_2020.png",
       plot = mapa_impervious_comparacion, width = 12, height = 6, dpi = 300, bg = "white")

# =============================================================
# 9. MAPA: COBERTURA ARBÓREA (2009 vs 2020)
# =============================================================

mapa_cobertura_2009 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2009) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, cobertura_arborea),
    by = c("CUT_COM" = "cod_com")
  )

mapa_cobertura_2020 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2020) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, cobertura_arborea),
    by = c("CUT_COM" = "cod_com")
  )

rango_cobertura <- range(c(mapa_cobertura_2009$cobertura_arborea, mapa_cobertura_2020$cobertura_arborea), na.rm = TRUE)
rango_cobertura

datos_cobertura_combinados <- bind_rows(
  mapa_cobertura_2009 %>% mutate(anio = "2009"),
  mapa_cobertura_2020 %>% mutate(anio = "2020")
)

mapa_cobertura_comparacion <- crear_mapa_comparacion(
  datos_sf = datos_cobertura_combinados,
  variable = "cobertura_arborea",
  titulo = "Cobertura arbórea",
  subtitulo = "Comparación 2009 vs. 2020",
  unidad_leyenda = "Cobertura\narbórea (%)",
  limites = rango_cobertura,
  nota_fuente = " · Fuente: Hansen Global Forest Change"
)

mapa_cobertura_comparacion

ggsave("03_Output/Maps/mapa_cobertura_arborea_comparacion_2009_2020.png",
       plot = mapa_cobertura_comparacion, width = 12, height = 6, dpi = 300, bg = "white")

# =============================================================
# 10. MAPA: MIGRACIÓN (2017)
# Independencia, Santiago y Estación Central destacan muy por sobre el resto.
# =============================================================

mapa_migracion_2017 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2017) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, pct_inmigrantes),
    by = c("CUT_COM" = "cod_com")
  )

mapa_migracion <- crear_mapa_variable(
  datos_sf = mapa_migracion_2017,
  variable = "pct_inmigrantes",
  titulo = "Porcentaje de población inmigrante internacional",
  subtitulo = "Año 2017 · Fuente: Censo 2017 (INE)",
  unidad_leyenda = "% inmigrantes",
  paleta = "plasma"
)

mapa_migracion

ggsave("03_Output/Maps/mapa_migracion_2017.png",
       plot = mapa_migracion, width = 8, height = 6, dpi = 300, bg = "white")

# =============================================================
# 11. MAPA: BHT GENERAL (2017)
# direccion = 1: valores altos = mayor bienestar (colores claros = mejor).
# Patrón nororiente (más bienestar) vs. resto de la ciudad.
# =============================================================

mapa_bht_2017 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2017) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, bht, dim_socioeconomica, dim_accesibilidad, dim_ambiental, dim_seguridad),
    by = c("CUT_COM" = "cod_com")
  )

mapa_bht <- crear_mapa_variable(
  datos_sf = mapa_bht_2017,
  variable = "bht",
  titulo = "Índice de Bienestar Territorial (BHT)",
  subtitulo = "Año 2017 · Fuente: CIT-UAI",
  unidad_leyenda = "BHT",
  paleta = "viridis",
  direccion = 1
)

mapa_bht

ggsave("03_Output/Maps/mapa_bht_2017.png",
       plot = mapa_bht, width = 8, height = 6, dpi = 300, bg = "white")

# =============================================================
# 12. MAPA: DIMENSIONES DEL BHT (2017)
# 4 paneles con escala compartida. Las dimensiones no son intercambiables.
# =============================================================

datos_dimensiones <- mapa_bht_2017 %>%
  select(COMUNA, CUT_COM, dim_socioeconomica, dim_accesibilidad, dim_ambiental, dim_seguridad, geometry) %>%
  tidyr::pivot_longer(
    cols = c(dim_socioeconomica, dim_accesibilidad, dim_ambiental, dim_seguridad),
    names_to = "dimension",
    values_to = "valor"
  ) %>%
  mutate(dimension = recode(dimension,
                            "dim_socioeconomica" = "Socioeconómica",
                            "dim_accesibilidad" = "Accesibilidad",
                            "dim_ambiental" = "Ambiental",
                            "dim_seguridad" = "Seguridad"
  ))

rango_dimensiones <- range(datos_dimensiones$valor, na.rm = TRUE)
rango_dimensiones

mapa_dimensiones <- ggplot(datos_dimensiones) +
  geom_sf(aes(fill = valor), color = "white", size = 0.2) +
  scale_fill_viridis_c(name = "Índice", option = "viridis", direction = 1,
                       limits = rango_dimensiones,
                       guide = guide_colorbar(title.position = "top", title.hjust = 0.5)) +
  facet_wrap(~ dimension) +
  annotation_scale(location = "bl", width_hint = 0.25, text_cex = 0.6) +
  labs(title = "Dimensiones del Bienestar Territorial (BHT)",
       subtitle = "Año 2017 · Fuente: CIT-UAI",
       caption = "CRS: WGS84 (EPSG:4326)") +
  theme_void() +
  theme(
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(color = "grey40"),
    plot.caption = element_text(color = "grey60", size = 7, hjust = 0),
    legend.title = element_text(size = 10),
    legend.text = element_text(size = 8),
    legend.key.width = unit(0.4, "cm"),
    legend.key.height = unit(0.6, "cm"),
    strip.text = element_text(face = "bold", size = 10)
  )

mapa_dimensiones

ggsave("03_Output/Maps/mapa_bht_dimensiones_2017.png",
       plot = mapa_dimensiones, width = 10, height = 8, dpi = 300, bg = "white")

# =============================================================
# 13. MAPAS: SOVI (2017) -- continuo y categórico
# =============================================================

mapa_sovi_2017 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2017) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, indice_vulnerabilidad, categoria_vulnerabilidad),
    by = c("CUT_COM" = "cod_com")
  )

# 13a. Continuo
mapa_sovi <- crear_mapa_variable(
  datos_sf = mapa_sovi_2017,
  variable = "indice_vulnerabilidad",
  titulo = "Índice de Vulnerabilidad Social (SOVI)",
  subtitulo = "Año 2017 · Valores negativos = menos vulnerable",
  unidad_leyenda = "SOVI",
  paleta = "magma",
  direccion = -1
)

mapa_sovi

ggsave("03_Output/Maps/mapa_sovi_2017.png",
       plot = mapa_sovi, width = 8, height = 6, dpi = 300, bg = "white")

# 13b. Categórico (4 colores discretos)
mapa_categoria_sovi <- ggplot(mapa_sovi_2017) +
  geom_sf(aes(fill = categoria_vulnerabilidad), color = "white", size = 0.3) +
  scale_fill_manual(
    name = "Vulnerabilidad",
    values = c("Baja" = "#2c7bb6", "Medio-baja" = "#abd9e9",
               "Medio-alta" = "#fdae61", "Alta" = "#d7191c"),
    na.value = "grey80"
  ) +
  annotation_north_arrow(location = "tr", which_north = "true",
                         style = north_arrow_fancy_orienteering(),
                         height = unit(1.5, "cm"), width = unit(1.5, "cm")) +
  annotation_scale(location = "bl", width_hint = 0.25, text_cex = 0.8) +
  labs(title = "Categoría de Vulnerabilidad Social (SOVI)",
       subtitle = "Año 2017",
       caption = "CRS: WGS84 (EPSG:4326)") +
  theme_void() +
  theme(
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(color = "grey40"),
    plot.caption = element_text(color = "grey60", size = 7, hjust = 0)
  )

mapa_categoria_sovi

ggsave("03_Output/Maps/mapa_categoria_sovi_2017.png",
       plot = mapa_categoria_sovi, width = 8, height = 6, dpi = 300, bg = "white")

# =============================================================
# 14. MAPA: ÁREA INDUSTRIAL (estática)
# Fuente: PRC (IDE MINVU). Se filtra 2020 solo para obtener una fila por comuna.
# Correcciones manuales: Estación Central (solo IPA), Lo Barnechea (0), Puente Alto (sin INF).
# =============================================================

mapa_industria_2020 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2020) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, area_industrial_ha),
    by = c("CUT_COM" = "cod_com")
  )

mapa_industria <- crear_mapa_gradiente(
  datos_sf = mapa_industria_2020,
  variable = "area_industrial_ha",
  titulo = "Superficie de zonas industriales",
  subtitulo = "Variable estática · Fuente: PRC, IDE MINVU",
  unidad_leyenda = "Hectáreas",
  color_alto = "#7a0000"
)

mapa_industria

ggsave("03_Output/Maps/mapa_area_industrial.png",
       plot = mapa_industria, width = 8, height = 6, dpi = 300, bg = "white")

# =============================================================
# 15. MAPA: DENSIDAD DE VÍAS PRINCIPALES (estática)
# Fuente: OpenStreetMap (Geofabrik).
# =============================================================

mapa_vias_2020 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2020) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, vias_km_por_km2),
    by = c("CUT_COM" = "cod_com")
  )

mapa_vias <- crear_mapa_gradiente(
  datos_sf = mapa_vias_2020,
  variable = "vias_km_por_km2",
  titulo = "Densidad de vías principales",
  subtitulo = "Variable estática · Fuente: OpenStreetMap (Geofabrik)",
  unidad_leyenda = "Km/km²",
  color_alto = "#08306b"
)

mapa_vias

ggsave("03_Output/Maps/mapa_vias_densidad.png",
       plot = mapa_vias, width = 8, height = 6, dpi = 300, bg = "white")

# =============================================================
# 16. MAPA: N° DE ESTABLECIMIENTOS DE SALUD (2019)
# Solo red pública (nivel 1° y 2°). 
# =============================================================

mapa_n_salud_2019 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2019) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, n_establecimientos_salud),
    by = c("CUT_COM" = "cod_com")
  )

mapa_n_salud <- crear_mapa_gradiente(
  datos_sf = mapa_n_salud_2019,
  variable = "n_establecimientos_salud",
  titulo = "Número de establecimientos de salud",
  subtitulo = "Nivel 1° y 2° · Año 2019 · Fuente: DEIS/MINSAL",
  unidad_leyenda = "N° establec.",
  color_alto = "#00441b"
)

mapa_n_salud

ggsave("03_Output/Maps/mapa_n_establecimientos_salud_2019.png",
       plot = mapa_n_salud, width = 8, height = 6, dpi = 300, bg = "white")

# =============================================================
# 17. MAPA: POBLACIÓN TOTAL (2020)
# Fuente WorldPop.
# =============================================================

mapa_poblacion_2020 <- comunas_33 %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(
    producto1 %>%
      filter(year == 2020) %>%
      mutate(cod_com = as.character(cod_com)) %>%
      select(cod_com, poblacion_total),
    by = c("CUT_COM" = "cod_com")
  )

mapa_poblacion <- crear_mapa_gradiente(
  datos_sf = mapa_poblacion_2020,
  variable = "poblacion_total",
  titulo = "Población total",
  subtitulo = "Año 2020 · Fuente: WorldPop",
  unidad_leyenda = "Habitantes",
  color_alto = "#4a0072",
  etiquetas = scales::comma
)

mapa_poblacion

ggsave("03_Output/Maps/mapa_poblacion_2020.png",
       plot = mapa_poblacion, width = 8, height = 6, dpi = 300, bg = "white")

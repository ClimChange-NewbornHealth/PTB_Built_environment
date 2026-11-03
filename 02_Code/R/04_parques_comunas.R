# =============================================================
# PARQUES POR COMUNA - VARIABLE TEMPORAL (2009, 2013, 2019)
# FONDECYT 11240322
# Fotos independientes por año -- no comparables entre sí,
# cada fuente usa criterio distinto de qué es "parque".
# =============================================================
library(sf)
library(dplyr)
library(stringr)
library(readr)
source("Scripts/0.1 Functions.R")

# -------------------------------------------------------------
# 0. SHAPEFILE BASE DE COMUNAS
# -------------------------------------------------------------
comunas_33 <- st_read("01_Input/Shapefiles/Comunas_santiago_33/comunas_santiago_33_WGS84.shp")
comunas_33_utm <- st_transform(comunas_33, crs = 32719)

comunas_superficie <- comunas_33 %>%
  st_drop_geometry() %>%
  select(CUT_COM, SUPERFICIE) %>%
  mutate(CUT_COM = as.character(CUT_COM))

# ===============================================================
# 1. PARQUES 2009
# Fuente: Gobierno Regional Metropolitano (Política Regional de 
# Áreas Verdes). Mide sobre el límite comunal completo (incluye
# zona rural/cordillerana).
# Filtro: AV_REAL=="si" + ESTADO=="Consolidada" + TIPO_97=="Implementada"
# (exige área efectivamente habilitada, no solo planificada).
# Exclusión manual: 5 polígonos etiquetados "Parque" que en 
# realidad son cerros/riberas mal clasificados.
# Limitación conocida: en Lo Barnechea no se marcó como 
# implementada una extensión real del Parque Metropolitano.
# ===============================================================
parques_2009 <- st_read("01_Input/Shapefiles/Parques_2009/AV_Política_Regional_RMS.shp")

excluir_nombres <- c("Co. Chena", "Co. Blanco", "Co. Navia", 
                     "Co. Jardin Alto", "Cca. Rio Mapocho")

parques_2009_filtrado <- parques_2009 %>%
  filter(
    AV_REAL == "si",
    ESTADO == "Consolidada",
    TIPO_97 == "Implementada",
    !NOMBRE_AV %in% excluir_nombres
  )

parques_2009_filtrado_utm <- st_transform(parques_2009_filtrado, crs = 32719)

parques_2009_interseccion <- st_intersection(parques_2009_filtrado_utm, comunas_33_utm) %>%
  mutate(area_ha = as.numeric(st_area(.)) / 10000)

resumen_parques_2009 <- parques_2009_interseccion %>%
  st_drop_geometry() %>%
  group_by(CUT_COM) %>%
  summarise(
    area_parques_ha_2009 = sum(area_ha, na.rm = TRUE),
    n_parques_2009 = n(),
    .groups = "drop"
  ) %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(comunas_superficie, by = "CUT_COM") %>%
  mutate(pct_parques_2009 = round((area_parques_ha_2009 / (SUPERFICIE * 100)) * 100, 2)) %>%
  select(CUT_COM, area_parques_ha_2009, n_parques_2009, pct_parques_2009)

nrow(resumen_parques_2009)  

comunas_cut <- comunas_33 %>%
  st_drop_geometry() %>%
  select(CUT_COM, COMUNA) %>%
  mutate(CUT_COM = as.character(CUT_COM), comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))) %>%
  select(CUT_COM, comuna_std)

parques_2009 <- read.csv("01_Input/Producto1/parques_2009.csv") %>%
  left_join(comunas_cut, by = "comuna_std") %>%
  select(-comuna_std)
write_excel_csv(parques_2009, "01_Input/Producto1/parques_2009.csv")

# ===============================================================
# 2. PARQUES 2013
# Fuente: Plan Regulador Metropolitano de Santiago (PRMS), 
# Sistema Metropolitano de Áreas Verdes y Recreación.
# A diferencia de 2009, distingue explícitamente sector rural 
# vs. urbano en el atributo "sector" -- se documenta ambos 
# totales (con y sin zona rural) para transparencia.
# Capa de cobertura nacional -- se filtra a las 33 comunas de estudio.
# ===============================================================
parques_2013 <- st_read("01_Input/Parques_2013/e4c0f00a-5057-4dc0-b277-0c6acc6f1dc0202047-1-2sbc5w.45r23.shp")
parques_2013_utm <- st_transform(parques_2013, crs = 32719)

comunas_std_33 <- quitar_tildes(str_trim(str_to_upper(comunas_33$COMUNA)))

resumen_parques_2013 <- parques_2013_utm %>%
  st_drop_geometry() %>%
  mutate(
    comuna_std = quitar_tildes(str_trim(str_to_upper(comuna))),
    es_rural = str_detect(sector, "Rural")
  ) %>%
  filter(comuna_std %in% comunas_std_33) %>%
  group_by(comuna_std) %>%
  summarise(
    area_parques_ha_2013_total = sum(sup_ha, na.rm = TRUE),
    area_parques_ha_2013_sin_rural = sum(sup_ha[!es_rural], na.rm = TRUE),
    n_parques_2013 = n(),
    .groups = "drop"
  )

# Pedro Aguirre Cerda no tiene polígonos registrados en esta capa -- se agrega con 0
resumen_parques_2013 <- resumen_parques_2013 %>%
  bind_rows(tibble(
    comuna_std = "PEDRO AGUIRRE CERDA",
    area_parques_ha_2013_total = 0,
    area_parques_ha_2013_sin_rural = 0,
    n_parques_2013 = 0
  ))

resumen_parques_2013 <- resumen_parques_2013 %>%
  left_join(
    comunas_33 %>% st_drop_geometry() %>% select(CUT_COM, SUPERFICIE) %>%
      mutate(CUT_COM = as.character(CUT_COM)),
    by = "CUT_COM"
  ) %>%
  mutate(pct_parques_2013 = round(100 * area_parques_ha_2013_total / (SUPERFICIE * 100), 2)) %>%
  select(-SUPERFICIE)

write_excel_csv(resumen_parques_2013, "01_Input/Producto1/parques_2013.csv")


# ===============================================================
# 3. PARQUES 2019
# Fuente: INE, catastro de plazas y parques urbanos (CALIDAD_LUC_PzPq).
# Mide solo sobre el área urbana consolidada de cada comuna 
# (a diferencia de 2009 y 2013, que incluyen zona rural/cordillerana).
# Distingue plazas (PZ) de parques (PQ) por separado.
# Capa de cobertura nacional -- se filtra a las 33 comunas de estudio.
# Algunas comunas tienen más de una zona urbana registrada -- se
# unen geométricamente antes de calcular el área total.
# ===============================================================
parques_2019 <- st_read("01_Input/Shapefiles/Parques_2019/CALIDAD_LUC_PzPq.shp")
parques_2019_utm <- st_transform(parques_2019, crs = 32719)

resumen_parques_2019 <- parques_2019_utm %>%
  mutate(comuna_std = quitar_tildes(str_trim(str_to_upper(NOMBRE_COM)))) %>%
  filter(comuna_std %in% comunas_std_33) %>%
  st_drop_geometry() %>%
  group_by(comuna_std) %>%
  summarise(
    area_parques_ha_2019 = sum(M2_PZPQ_TO, na.rm = TRUE) / 10000,
    n_plazas_2019 = sum(PZ_NR_TOTA, na.rm = TRUE),
    n_parques_2019 = sum(PQ_NR_TOTA, na.rm = TRUE),
    .groups = "drop"
  )

nrow(resumen_parques_2019)  # verificación: debe dar 33
parques_2019 <- read.csv("01_Input/Producto1/parques_2019.csv") %>%
  mutate(CUT_COM = as.character(CUT_COM)) %>%
  left_join(comunas_33 %>% st_drop_geometry() %>% select(CUT_COM, SUPERFICIE) %>% mutate(CUT_COM = as.character(CUT_COM)), by = "CUT_COM") %>%
  mutate(pct_parques_2019 = round(100 * area_parques_ha_2019 / (SUPERFICIE * 100), 2)) %>%
  select(-SUPERFICIE)
write_excel_csv(parques_2019, "01_Input/Producto1/parques_2019.csv")
names(parques_2019)

# ===============================================================
# 4. TABLA CONSOLIDADA -- las tres fuentes lado a lado
# IMPORTANTE: no son comparables entre sí (distintos criterios
# de "parque" y distinta cobertura geográfica). Se presentan
# como fotografías independientes, no como serie temporal.
# ===============================================================

nombres_correctos <- tibble(
  comuna_std = c("CERRILLOS", "CERRO NAVIA", "CONCHALI", "EL BOSQUE", "ESTACION CENTRAL",
                 "HUECHURABA", "INDEPENDENCIA", "LA CISTERNA", "LA FLORIDA", "LA GRANJA",
                 "LA PINTANA", "LA REINA", "LAS CONDES", "LO BARNECHEA", "LO ESPEJO",
                 "LO PRADO", "MACUL", "MAIPU", "NUNOA", "PEDRO AGUIRRE CERDA",
                 "PENALOLEN", "PROVIDENCIA", "PUDAHUEL", "PUENTE ALTO", "QUILICURA",
                 "QUINTA NORMAL", "RECOLETA", "RENCA", "SAN JOAQUIN", "SAN MIGUEL",
                 "SAN RAMON", "SANTIAGO", "VITACURA"),
  nombre_correcto = c("Cerrillos", "Cerro Navia", "Conchalí", "El Bosque", "Estación Central",
                      "Huechuraba", "Independencia", "La Cisterna", "La Florida", "La Granja",
                      "La Pintana", "La Reina", "Las Condes", "Lo Barnechea", "Lo Espejo",
                      "Lo Prado", "Macul", "Maipú", "Ñuñoa", "Pedro Aguirre Cerda",
                      "Peñalolén", "Providencia", "Pudahuel", "Puente Alto", "Quilicura",
                      "Quinta Normal", "Recoleta", "Renca", "San Joaquín", "San Miguel",
                      "San Ramón", "Santiago", "Vitacura")
)

resumen_parques_2009_std <- resumen_parques_2009 %>%
  left_join(
    comunas_33 %>% st_drop_geometry() %>% select(CUT_COM, COMUNA) %>% mutate(CUT_COM = as.character(CUT_COM)),
    by = "CUT_COM"
  ) %>%
  mutate(comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))) %>%
  select(comuna_std, area_parques_ha_2009, n_parques_2009, pct_parques_2009)

parques_consolidado <- resumen_parques_2009_std %>%
  left_join(resumen_parques_2013, by = "comuna_std") %>%
  left_join(resumen_parques_2019, by = "comuna_std") %>%
  left_join(nombres_correctos, by = "comuna_std")

nrow(parques_consolidado)  # verificación: debe dar 33

glimpse(parques_consolidado)

library(gt)

# --- Tabla 2009 (2 columnas) ---
datos_2009 <- parques_consolidado %>%
  arrange(desc(pct_parques_2009)) %>%
  select(nombre_correcto, area_parques_ha_2009, n_parques_2009, pct_parques_2009)

n_mitad <- ceiling(nrow(datos_2009) / 2)
mitad_1 <- datos_2009[1:n_mitad, ] %>%
  rename(COMUNA_1 = nombre_correcto, area_1 = area_parques_ha_2009, n_1 = n_parques_2009, pct_1 = pct_parques_2009)
mitad_2 <- datos_2009[(n_mitad + 1):nrow(datos_2009), ] %>%
  rename(COMUNA_2 = nombre_correcto, area_2 = area_parques_ha_2009, n_2 = n_parques_2009, pct_2 = pct_parques_2009)
if (nrow(mitad_2) < nrow(mitad_1)) mitad_2 <- mitad_2 %>% add_row(COMUNA_2 = NA, area_2 = NA, n_2 = NA, pct_2 = NA)

rango_pct_2009 <- range(datos_2009$pct_parques_2009, na.rm = TRUE)

tabla_parques_2009 <- bind_cols(mitad_1, mitad_2) %>%
  gt() %>%
  tab_header(
    title = "Parques y Áreas Verdes, 2009",
    subtitle = "Fuente: Gobierno Regional Metropolitano — Política Regional de Áreas Verdes"
  ) %>%
  tab_source_note("Mide sobre el límite comunal completo, incluyendo zona rural/cordillerana. No comparable con 2013 ni 2019 (criterios distintos).") %>%
  cols_label(
    COMUNA_1 = "Comuna", area_1 = "Área (ha)", n_1 = "N° polígonos", pct_1 = "% comuna",
    COMUNA_2 = "Comuna", area_2 = "Área (ha)", n_2 = "N° polígonos", pct_2 = "% comuna"
  ) %>%
  fmt_number(columns = c(area_1, area_2, pct_1, pct_2), decimals = 2) %>%
  sub_missing(columns = everything(), missing_text = "") %>%
  data_color(columns = pct_1, colors = scales::col_numeric(
    palette = c("#f4a582", "#fee08b", "#a1d76a"), domain = rango_pct_2009)) %>%
  data_color(columns = pct_2, colors = scales::col_numeric(
    palette = c("#f4a582", "#fee08b", "#a1d76a"), domain = rango_pct_2009))

gtsave(tabla_parques_2009, "03_Output/Maps/tabla_parques_2009.png", vwidth = 2000, vheight = 1400)

# --- Tabla 2013 (2 columnas) ---
datos_2013 <- parques_consolidado %>%
  arrange(desc(area_parques_ha_2013_sin_rural)) %>%
  select(nombre_correcto, area_parques_ha_2013_total, area_parques_ha_2013_sin_rural, n_parques_2013)

n_mitad <- ceiling(nrow(datos_2013) / 2)
mitad_1 <- datos_2013[1:n_mitad, ] %>%
  rename(COMUNA_1 = nombre_correcto, tot_1 = area_parques_ha_2013_total, sr_1 = area_parques_ha_2013_sin_rural, n_1 = n_parques_2013)
mitad_2 <- datos_2013[(n_mitad + 1):nrow(datos_2013), ] %>%
  rename(COMUNA_2 = nombre_correcto, tot_2 = area_parques_ha_2013_total, sr_2 = area_parques_ha_2013_sin_rural, n_2 = n_parques_2013)
if (nrow(mitad_2) < nrow(mitad_1)) mitad_2 <- mitad_2 %>% add_row(COMUNA_2 = NA, tot_2 = NA, sr_2 = NA, n_2 = NA)

rango_sr_2013 <- range(datos_2013$area_parques_ha_2013_sin_rural, na.rm = TRUE)

tabla_parques_2013 <- bind_cols(mitad_1, mitad_2) %>%
  gt() %>%
  tab_header(
    title = "Parques y Áreas Verdes, 2013",
    subtitle = "Fuente: Plan Regulador Metropolitano de Santiago (PRMS)"
  ) %>%
  tab_source_note("Distingue sector rural/urbano explícitamente. No comparable con 2009 ni 2019 (criterios distintos).") %>%
  cols_label(
    COMUNA_1 = "Comuna", tot_1 = "Total (ha)", sr_1 = "Sin rural (ha)", n_1 = "N° polígonos",
    COMUNA_2 = "Comuna", tot_2 = "Total (ha)", sr_2 = "Sin rural (ha)", n_2 = "N° polígonos"
  ) %>%
  fmt_number(columns = c(tot_1, tot_2, sr_1, sr_2), decimals = 2) %>%
  sub_missing(columns = everything(), missing_text = "") %>%
  data_color(columns = sr_1, colors = scales::col_numeric(
    palette = c("#f4a582", "#fee08b", "#a1d76a"), domain = rango_sr_2013)) %>%
  data_color(columns = sr_2, colors = scales::col_numeric(
    palette = c("#f4a582", "#fee08b", "#a1d76a"), domain = rango_sr_2013))

gtsave(tabla_parques_2013, "03_Output/Maps/tabla_parques_2013.png", vwidth = 2000, vheight = 1400)


# --- Tabla 2019 (2 columnas) ---
datos_2019 <- parques_consolidado %>%
  arrange(desc(area_parques_ha_2019)) %>%
  select(nombre_correcto, area_parques_ha_2019, n_plazas_2019, n_parques_2019)

n_mitad <- ceiling(nrow(datos_2019) / 2)
mitad_1 <- datos_2019[1:n_mitad, ] %>%
  rename(COMUNA_1 = nombre_correcto, area_1 = area_parques_ha_2019, pz_1 = n_plazas_2019, pq_1 = n_parques_2019)
mitad_2 <- datos_2019[(n_mitad + 1):nrow(datos_2019), ] %>%
  rename(COMUNA_2 = nombre_correcto, area_2 = area_parques_ha_2019, pz_2 = n_plazas_2019, pq_2 = n_parques_2019)
if (nrow(mitad_2) < nrow(mitad_1)) mitad_2 <- mitad_2 %>% add_row(COMUNA_2 = NA, area_2 = NA, pz_2 = NA, pq_2 = NA)

rango_area_2019 <- range(datos_2019$area_parques_ha_2019, na.rm = TRUE)

tabla_parques_2019 <- bind_cols(mitad_1, mitad_2) %>%
  gt() %>%
  tab_header(
    title = "Parques y Plazas Urbanas, 2019",
    subtitle = "Fuente: INE — Catastro de plazas y parques urbanos"
  ) %>%
  tab_source_note("Mide solo sobre el área urbana consolidada, con infraestructura catastrada. No comparable con 2009 ni 2013 (criterios distintos).") %>%
  cols_label(
    COMUNA_1 = "Comuna", area_1 = "Área (ha)", pz_1 = "N° plazas", pq_1 = "N° parques",
    COMUNA_2 = "Comuna", area_2 = "Área (ha)", pz_2 = "N° plazas", pq_2 = "N° parques"
  ) %>%
  fmt_number(columns = c(area_1, area_2), decimals = 2) %>%
  sub_missing(columns = everything(), missing_text = "") %>%
  data_color(columns = area_1, colors = scales::col_numeric(
    palette = c("#f4a582", "#fee08b", "#a1d76a"), domain = rango_area_2019)) %>%
  data_color(columns = area_2, colors = scales::col_numeric(
    palette = c("#f4a582", "#fee08b", "#a1d76a"), domain = rango_area_2019))

gtsave(tabla_parques_2019, "03_Output/Maps/tabla_parques_2019.png", vwidth = 2000, vheight = 1400)

library(ggplot2)
library(ggspatial)

crear_mapa_variable <- function(datos_sf, variable, titulo, subtitulo, unidad_leyenda, 
                                paleta = "viridis", direccion = -1) {
  ggplot(datos_sf) +
    geom_sf(aes(fill = .data[[variable]]), color = "grey30", size = 0.3) +
    scale_fill_viridis_c(name = unidad_leyenda, option = paleta, direction = direccion) +
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
      legend.title = element_text(size = 10),
      legend.text = element_text(size = 8),
      legend.key.width = unit(0.4, "cm"),
      legend.key.height = unit(0.6, "cm"),
      legend.box.spacing = unit(0, "pt"),
      legend.margin = margin(l = 0, r = 5),
      plot.margin = margin(5, 5, 5, 5)
    )
}

# preparar geometría con los datos de las tres fuentes
mapa_parques_datos <- comunas_33_utm %>%
  st_transform(4326) %>%  # volver a WGS84 para consistencia con los demás mapas
  left_join(parques_consolidado, by = c("COMUNA" = "nombre_correcto"))

# --- Mapa 2009 ---
mapa_parques_2009 <- crear_mapa_variable(
  mapa_parques_datos, "pct_parques_2009",
  "Parques y Áreas Verdes, 2009",
  "Fuente: Gobierno Regional Metropolitano — mide comuna completa",
  "% de la comuna",
  paleta = "viridis", direccion = -1
)

mapa_parques_2009
ggsave("03_Output/Maps/mapa_parques_2009.png",
       mapa_parques_2009, width = 8, height = 8, dpi = 300, bg = "white")

# --- Mapa 2013 ---
mapa_parques_2013 <- crear_mapa_variable(
  mapa_parques_datos, "area_parques_ha_2013_sin_rural",
  "Parques y Áreas Verdes, 2013",
  "Fuente: PRMS — excluye sector rural",
  "Área (ha)",
  paleta = "viridis", direccion = -1
)

mapa_parques_2013
ggsave("03_Output/Maps/mapa_parques_2013.png",
       mapa_parques_2013, width = 8, height = 8, dpi = 300, bg = "white")

# --- Mapa 2019 ---
mapa_parques_2019 <- crear_mapa_variable(
  mapa_parques_datos, "area_parques_ha_2019",
  "Parques y Plazas Urbanas, 2019",
  "Fuente: INE — solo área urbana consolidada",
  "Área (ha)",
  paleta = "viridis", direccion = -1
)

mapa_parques_2019
ggsave("03_Output/Maps/mapa_parques_2019.png",
       mapa_parques_2019, width = 8, height = 8, dpi = 300, bg = "white")































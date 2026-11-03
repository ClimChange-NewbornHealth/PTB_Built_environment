# =========================================================
# VARIABLE SALUD - AÑO 2019 
# Fuente: Establecimientos de Salud Nivel 1° y 2° - SNSS
# Cuenca del Maipo (RM, Valparaíso, O'Higgins) - DEIS/MINSAL
# Corte: 2019 (dentro del periodo de estudio 2009-2020)
# =========================================================

library(sf)
library(dplyr)
library(readxl)

# ---------------------------------------------------------
# 1. DESCARGAR Y GUARDAR CAPA DE SALUD 2019 (Feature Service ArcGIS)
# ---------------------------------------------------------

url_salud_2019 <- "https://services7.arcgis.com/UeyripQFTg6pfUe5/arcgis/rest/services/SaludPrimariaSNSSCuencaMaipo/FeatureServer/0/query?where=1=1&outFields=*&f=geojson"

salud_2019 <- st_read(url_salud_2019)

# Guardar copia local para reproducibilidad (no depender del servicio externo)
dir.create("01_Input/Salud_2019", showWarnings = FALSE)
st_write(salud_2019, "01_Input/Salud_2019/establecimientos_salud_2019.shp", delete_layer = TRUE)

# ---------------------------------------------------------
# 2. FILTRAR A LAS 33 COMUNAS DE ESTUDIO (por código CUT_, no por nombre)
# ---------------------------------------------------------

salud_2019 <- st_read("01_Input/Salud_2019/establecimientos_salud_2019.shp")

codigos_33_comunas <- c(sprintf("131%02d", 1:32), "13201")

salud_2019_filtrado <- salud_2019 %>%
  filter(CUT_ %in% codigos_33_comunas)

# Verificación: deben ser 33 comunas, sin faltantes
n_distinct(salud_2019_filtrado$CUT_)
setdiff(codigos_33_comunas, unique(salud_2019_filtrado$CUT_))

# ---------------------------------------------------------
# 3. CORREGIR ERROR DE FUENTE: 1 registro con CUT_ mal asignado
#    (CECOSF Villa Olímpica: traía CUT_ 13123/Providencia,
#     pero geometría + nombre confirman que es Ñuñoa 13120)
# ---------------------------------------------------------

salud_2019_corregido <- salud_2019_filtrado %>%
  mutate(CUT_ = if_else(CUT_ == "13123" & COMUNA_ == "Ñuñoa", "13120", CUT_))

# Verificación: 33 códigos únicos, sin duplicados
n_distinct(salud_2019_corregido$CUT_)

# Guardar versión corregida
st_write(salud_2019_corregido, 
         "01_Input/Salud_2019/establecimientos_salud_2019_corregido.shp", 
         delete_layer = TRUE)

# Conteo de establecimientos por comuna
conteo_2019_final <- salud_2019_corregido %>%
  st_drop_geometry() %>%
  count(CUT_, name = "n_establecimientos_2019")

# ---------------------------------------------------------
# 4. CARGAR CAPA DE MUNICIPALIDADES (coordenadas de Ismael)
#    Reemplaza el centroide geográfico por el centro cívico/municipal
# ---------------------------------------------------------

municipalidades <- read_excel("01_Input/Salud_2019/municipalidades.xlsx")

# Separar columna combinada "lat, lon" en dos columnas numéricas
municipalidades_sep <- municipalidades %>%
  mutate(
    lat = as.numeric(sub(",.*", "", municipalidad)),
    lon = as.numeric(sub(".*,\\s*", "", municipalidad))
  )

# Convertir a objeto espacial y reproyectar a UTM 32719
municipalidades_sf <- st_as_sf(municipalidades_sep, 
                               coords = c("lon", "lat"), 
                               crs = 4326)

municipalidades_utm <- st_transform(municipalidades_sf, crs = 32719)

# Verificación: deben ser 33 comunas
nrow(municipalidades_utm)

# ---------------------------------------------------------
# 5. CALCULAR DISTANCIA MÍNIMA: MUNICIPALIDAD -> ESTABLECIMIENTO MÁS CERCANO
#    (sin restringir a la propia comuna )
# ---------------------------------------------------------

salud_2019_utm <- st_transform(salud_2019_corregido, crs = 32719)

matriz_distancias <- st_distance(municipalidades_utm, salud_2019_utm)
municipalidades_utm$dist_salud_km_2019 <- apply(matriz_distancias, 1, min) / 1000

tabla_distancias <- municipalidades_utm %>%
  st_drop_geometry() %>%
  select(comuna, dist_salud_km_2019)

# ---------------------------------------------------------
# 6. UNIR DISTANCIA + CONTEO EN UNA SOLA TABLA (usando CUT_ como llave)
#    Se usa el shapefile de comunas como puente nombre <-> CUT_
# ---------------------------------------------------------

quitar_tildes <- function(x) {
  chartr("áéíóúÁÉÍÓÚñÑ", "aeiouAEIOUnN", x)
}

comunas_33 <- st_read("01_Input/Shapefiles/Comunas_santiago_33/comunas_santiago_33_WGS84.shp")

puente_comunas <- comunas_33 %>%
  st_drop_geometry() %>%
  select(CUT_COM, COMUNA) %>%
  distinct() %>%
  mutate(comuna_limpia = quitar_tildes(COMUNA))

tabla_distancias <- tabla_distancias %>%
  mutate(comuna_limpia = quitar_tildes(comuna))

tabla_distancias_cut <- tabla_distancias %>%
  left_join(puente_comunas %>% select(CUT_COM, comuna_limpia), by = "comuna_limpia")

# Verificación: 0 NA esperado
sum(is.na(tabla_distancias_cut$CUT_COM))

salud_2019_final <- tabla_distancias_cut %>%
  rename(CUT_ = CUT_COM) %>%
  mutate(CUT_ = as.character(CUT_)) %>%
  left_join(conteo_2019_final, by = "CUT_") %>%
  select(CUT_, comuna, dist_salud_km_2019, n_establecimientos_2019) %>%
  arrange(CUT_)

# ---------------------------------------------------------
# 7. GUARDAR RESULTADO FINAL
# ---------------------------------------------------------

write.csv(salud_2019_final, "01_Input/Producto1/salud_2019_final.csv", row.names = FALSE)

library(sf)
library(dplyr)
library(readxl)

# ---------------------------------------------------------
# 1. DESCARGAR Y GUARDAR CAPA DE SALUD 2019 (Feature Service ArcGIS)
# ---------------------------------------------------------

url_salud_2019 <- "https://services7.arcgis.com/UeyripQFTg6pfUe5/arcgis/rest/services/SaludPrimariaSNSSCuencaMaipo/FeatureServer/0/query?where=1=1&outFields=*&f=geojson"

salud_2019 <- st_read(url_salud_2019)

# Guardar copia local para reproducibilidad (no depender del servicio externo)
dir.create("01_Input/Salud_2019", showWarnings = FALSE)
st_write(salud_2019, "01_Input/Salud_2019/establecimientos_salud_2019.shp", delete_layer = TRUE)

# ---------------------------------------------------------
# 2. FILTRAR A LAS 33 COMUNAS DE ESTUDIO (por código CUT_, no por nombre)
# ---------------------------------------------------------

salud_2019 <- st_read("01_Input/Salud_2019/establecimientos_salud_2019.shp")

codigos_33_comunas <- c(sprintf("131%02d", 1:32), "13201")

salud_2019_filtrado <- salud_2019 %>%
  filter(CUT_ %in% codigos_33_comunas)

# Verificación: deben ser 33 comunas, sin faltantes
n_distinct(salud_2019_filtrado$CUT_)
setdiff(codigos_33_comunas, unique(salud_2019_filtrado$CUT_))

# ---------------------------------------------------------
# 3. CORREGIR ERROR DE FUENTE: 1 registro con CUT_ mal asignado
#    (CECOSF Villa Olímpica: traía CUT_ 13123/Providencia,
#     pero geometría + nombre confirman que es Ñuñoa 13120)
# ---------------------------------------------------------

salud_2019_corregido <- salud_2019_filtrado %>%
  mutate(CUT_ = if_else(CUT_ == "13123" & COMUNA_ == "Ñuñoa", "13120", CUT_))

# Verificación: 33 códigos únicos, sin duplicados
n_distinct(salud_2019_corregido$CUT_)

# Guardar versión corregida
st_write(salud_2019_corregido, 
         "01_Input/Salud_2019/establecimientos_salud_2019_corregido.shp", 
         delete_layer = TRUE)

# Conteo de establecimientos por comuna
conteo_2019_final <- salud_2019_corregido %>%
  st_drop_geometry() %>%
  count(CUT_, name = "n_establecimientos_2019")

# ---------------------------------------------------------
# 4. CARGAR CAPA DE MUNICIPALIDADES (coordenadas de Ismael)
#    Reemplaza el centroide geográfico por el centro cívico/municipal
# ---------------------------------------------------------

municipalidades <- read_excel("01_Input/Salud_2019/municipalidades.xlsx")

# Separar columna combinada "lat, lon" en dos columnas numéricas
municipalidades_sep <- municipalidades %>%
  mutate(
    lat = as.numeric(sub(",.*", "", municipalidad)),
    lon = as.numeric(sub(".*,\\s*", "", municipalidad))
  )

# Convertir a objeto espacial y reproyectar a UTM 32719
municipalidades_sf <- st_as_sf(municipalidades_sep, 
                               coords = c("lon", "lat"), 
                               crs = 4326)

municipalidades_utm <- st_transform(municipalidades_sf, crs = 32719)

# Verificación: deben ser 33 comunas
nrow(municipalidades_utm)

# ---------------------------------------------------------
# 5. CALCULAR DISTANCIA MÍNIMA: MUNICIPALIDAD -> ESTABLECIMIENTO MÁS CERCANO
#    (sin restringir a la propia comuna, igual criterio que usa el equipo de Estela)
# ---------------------------------------------------------

salud_2019_utm <- st_transform(salud_2019_corregido, crs = 32719)

matriz_distancias <- st_distance(municipalidades_utm, salud_2019_utm)
municipalidades_utm$dist_salud_km_2019 <- apply(matriz_distancias, 1, min) / 1000

tabla_distancias <- municipalidades_utm %>%
  st_drop_geometry() %>%
  select(comuna, dist_salud_km_2019)

# ---------------------------------------------------------
# 6. UNIR DISTANCIA + CONTEO EN UNA SOLA TABLA (usando CUT_ como llave)
#    Se usa el shapefile de comunas como puente nombre <-> CUT_
# ---------------------------------------------------------

quitar_tildes <- function(x) {
  chartr("áéíóúÁÉÍÓÚñÑ", "aeiouAEIOUnN", x)
}

comunas_33 <- st_read("01_Input/Shapefiles/Comunas_santiago_33/comunas_santiago_33_WGS84.shp")

puente_comunas <- comunas_33 %>%
  st_drop_geometry() %>%
  select(CUT_COM, COMUNA) %>%
  distinct() %>%
  mutate(comuna_limpia = quitar_tildes(COMUNA))

tabla_distancias <- tabla_distancias %>%
  mutate(comuna_limpia = quitar_tildes(comuna))

tabla_distancias_cut <- tabla_distancias %>%
  left_join(puente_comunas %>% select(CUT_COM, comuna_limpia), by = "comuna_limpia")

# Verificación: 0 NA esperado
sum(is.na(tabla_distancias_cut$CUT_COM))

salud_2019_final <- tabla_distancias_cut %>%
  rename(CUT_ = CUT_COM) %>%
  mutate(CUT_ = as.character(CUT_)) %>%
  left_join(conteo_2019_final, by = "CUT_") %>%
  select(CUT_, comuna, dist_salud_km_2019, n_establecimientos_2019) %>%
  arrange(CUT_)

# ---------------------------------------------------------
# 7. GUARDAR RESULTADO FINAL
# ---------------------------------------------------------

write.csv(salud_2019_final, "01_Input/Producto1/salud_2019_final.csv", row.names = FALSE)


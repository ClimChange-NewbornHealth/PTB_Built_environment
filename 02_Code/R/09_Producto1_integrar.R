# =============================================
# Producto 1 - Base de datos entorno urbano
# FONDECYT 11240322
# =============================================

library(dplyr)
library(sf)
library(readr)

# Función para quitar tildes
quitar_tildes <- function(x) {
  chartr("áéíóúüñÁÉÍÓÚÜÑ", "aeiouunAEIOUUN", x)
}

# =============================================
# Shapefile de comunas (para área comunal, ya no viene de WorldPop)
# =============================================
comunas_33 <- st_read("01_Input/Shapefiles/Comunas_santiago_33/comunas_santiago_33_WGS84.shp")

area_comunas <- comunas_33 %>%
  st_drop_geometry() %>%
  transmute(COMUNA, area_km2 = SUPERFICIE)

# =============================================
# Cargar variables con serie temporal
# =============================================
ndvi_verano <- read.csv("01_Input/NDVI/NDVI_verano_comunas_santiago_2009_2020.csv")
ndvi_anual  <- read.csv("01_Input/NDVI/NDVI_anual_comunas_santiago_2009_2020.csv")
lst_verano  <- read.csv("01_Input/LST/LST_verano_comunas_santiago_2009_2020.csv")
lst_anual   <- read.csv("01_Input/LST/LST_anual_comunas_santiago_2009_2020.csv")
treecover   <- read.csv("01_Input/Cobertura_Arborea/TreeCover_comunas_santiago_2009_2020.csv")
impervious  <- read.csv("01_Input/Impervious/Impervious_comunas_santiago_2009_2020.csv")
poblacion_ine <- read.csv("01_Input/Producto1/ine_totales_rm.csv")

# =============================================
# Cargar variables estáticas y estandarizar nombres
# =============================================
sovi <- read.csv("01_Input/Producto1/sovi_santiago_33.csv")

bht <- read.csv("01_Input/Producto1/bht_santiago_33.csv")

bht_dim <- read.csv("01_Input/Producto1/bht_dimensiones_santiago_33.csv")

vias <- read.csv("01_Input/Producto1/vias_principales_santiago_33.csv") %>%
  mutate(COMUNA = quitar_tildes(COMUNA))

industrias <- read.csv("01_Input/Producto1/industrias_santiago_33.csv") %>%
  mutate(COM = quitar_tildes(COM))

# Variable de salud actualizada (2019, centro municipal)
salud_2019 <- read.csv("01_Input/Producto1/salud_2019_final.csv") %>%
  mutate(CUT_ = as.character(CUT_))

# Variable de migración (Censo 2017)
migracion_2017 <- read.csv("01_Input/Producto1/migracion_2017_santiago_33.csv") %>%
  mutate(CUT = as.character(CUT))

# Variable de parques (2009, 2013 y 2019)
parques_2009 <- read.csv("01_Input/Producto1/parques_2009.csv") %>%
  mutate(CUT_COM = as.character(CUT_COM))
parques_2013 <- read.csv("01_Input/Producto1/parques_2013.csv") %>%
  mutate(CUT_COM = as.character(CUT_COM))
parques_2019 <- read.csv("01_Input/Producto1/parques_2019.csv") %>%
  mutate(CUT_COM = as.character(CUT_COM))

# =============================================
# Unir variables con serie temporal (satelitales + INE)
# =============================================
base_temporal <- ndvi_verano %>%
  rename(ndvi_verano = NDVI) %>%
  left_join(ndvi_anual %>% rename(ndvi_anual = NDVI_anual),
            by = c("COMUNA", "year")) %>%
  left_join(lst_verano %>% rename(lst_verano = LST),
            by = c("COMUNA", "year")) %>%
  left_join(lst_anual %>% rename(lst_anual = LST_anual),
            by = c("COMUNA", "year")) %>%
  left_join(treecover %>% rename(cobertura_arborea = treecover),
            by = c("COMUNA", "year")) %>%
  left_join(impervious %>% 
              select(COMUNA, year, impervious) %>%
              rename(sup_impermeable = impervious),
            by = c("COMUNA", "year")) %>%
  left_join(poblacion_ine %>% 
              select(COMUNA, year, poblacion_ine) %>%
              rename(poblacion_total = poblacion_ine),
            by = c("COMUNA", "year")) %>%
  left_join(area_comunas, by = "COMUNA") %>%
  mutate(densidad_hab_km2 = round(poblacion_total / area_km2, 2))

# =============================================
# Unir variables estáticas
# =============================================
producto1 <- base_temporal %>%
  mutate(comuna_std = quitar_tildes(str_to_upper(COMUNA))) %>%
  left_join(sovi %>% 
              mutate(comuna_std = quitar_tildes(str_to_upper(name_comuna))) %>%
              select(comuna_std, cod_com, sovi, vulnerablidad) %>%
              rename(indice_vulnerabilidad = sovi,
                     categoria_vulnerabilidad = vulnerablidad),
            by = "comuna_std") %>%
  left_join(bht %>% select(cod_com, bht_promedio) %>%
              rename(bht = bht_promedio),
            by = "cod_com") %>%
  left_join(bht_dim %>% select(cod_com, dim_socioeconomica, dim_accesibilidad,
                               dim_ambiental, dim_seguridad),
            by = "cod_com") %>%
  left_join(vias %>% 
              mutate(comuna_std = quitar_tildes(str_to_upper(COMUNA))) %>%
              select(comuna_std, densidad_km_km2) %>%
              rename(vias_km_por_km2 = densidad_km_km2),
            by = "comuna_std") %>%
  left_join(industrias %>% 
              mutate(comuna_std = quitar_tildes(str_to_upper(COM))) %>%
              select(comuna_std, area_industrial_ha),
            by = "comuna_std") %>%
  select(-comuna_std)

# =============================================
# Integrar variable de salud actualizada
# Corte único 2019 (centro municipal) -- NA en el resto de años
# =============================================
producto1 <- producto1 %>%
  mutate(cod_com = as.character(cod_com)) %>%
  left_join(
    salud_2019 %>% select(CUT_, dist_salud_km_2019, n_establecimientos_2019),
    by = c("cod_com" = "CUT_")
  ) %>%
  mutate(
    dist_salud_km = if_else(year == 2019, dist_salud_km_2019, NA_real_),
    n_establecimientos_salud = if_else(year == 2019, as.numeric(n_establecimientos_2019), NA_real_)
  ) %>%
  select(-dist_salud_km_2019, -n_establecimientos_2019)

# =============================================
# Integrar variable de migración (Censo 2017)
# Corte único 2017, mismo tratamiento que SOVI/BHT
# =============================================
producto1 <- producto1 %>%
  left_join(
    migracion_2017 %>% select(CUT, PROP_INMIG),
    by = c("cod_com" = "CUT")
  ) %>%
  rename(pct_inmigrantes = PROP_INMIG) %>%
  mutate(
    pct_inmigrantes = if_else(year == 2017, pct_inmigrantes, NA_real_)
  )

# =============================================
# Integrar variable de parques (2009, 2013 y 2019)
# Tres años reales -- NA en el resto del periodo.
# No comparables entre sí (distintos criterios de
# "parque" y distinta cobertura geográfica por año).
# =============================================
producto1 <- producto1 %>%
  left_join(parques_2009 %>% select(CUT_COM, area_parques_ha_2009, pct_parques_2009),
            by = c("cod_com" = "CUT_COM")) %>%
  left_join(parques_2013 %>% select(CUT_COM, area_parques_ha_2013_total, pct_parques_2013),
            by = c("cod_com" = "CUT_COM")) %>%
  left_join(parques_2019 %>% select(CUT_COM, area_parques_ha_2019, pct_parques_2019),
            by = c("cod_com" = "CUT_COM")) %>%
  mutate(
    area_parques_ha = case_when(
      year == 2009 ~ area_parques_ha_2009,
      year == 2013 ~ area_parques_ha_2013_total,
      year == 2019 ~ area_parques_ha_2019,
      TRUE ~ NA_real_
    ),
    pct_parques = case_when(
      year == 2009 ~ pct_parques_2009,
      year == 2013 ~ pct_parques_2013,
      year == 2019 ~ pct_parques_2019,
      TRUE ~ NA_real_
    )
  ) %>%
  select(-area_parques_ha_2009, -pct_parques_2009,
         -area_parques_ha_2013_total, -pct_parques_2013,
         -area_parques_ha_2019, -pct_parques_2019)

# =============================================
# Aplicar NA a variables censales (Censo 2017) fuera de su año real
# NOTA: densidad_hab_km2 ahora usa INE (serie completa 2009-2020),
# reemplaza la versión anterior basada en WorldPop
# =============================================
variables_censales_2017 <- c(
  "indice_vulnerabilidad",
  "categoria_vulnerabilidad",
  "bht",
  "dim_socioeconomica",
  "dim_accesibilidad",
  "dim_ambiental",
  "dim_seguridad",
  "pct_inmigrantes"
)

producto1 <- producto1 %>%
  mutate(across(
    all_of(variables_censales_2017),
    ~ if_else(year == 2017, ., NA)
  ))

# =============================================
# Reordenar columnas según lógica temática
# =============================================
producto1 <- producto1 %>%
  select(
    # Identificadores
    COMUNA, cod_com, year,
    # Características demográficas base (INE, serie completa)
    poblacion_total, area_km2, densidad_hab_km2,
    pct_inmigrantes,
    # Vegetación y verde urbano
    ndvi_verano, ndvi_anual,
    cobertura_arborea,
    pct_parques, area_parques_ha,
    # Calor urbano y superficie
    lst_verano, lst_anual,
    sup_impermeable,
    # Contaminación y actividad industrial
    area_industrial_ha,
    vias_km_por_km2,
    # Socioeconómico y vulnerabilidad
    indice_vulnerabilidad, categoria_vulnerabilidad,
    bht, dim_socioeconomica, dim_accesibilidad,
    dim_ambiental, dim_seguridad,
    # Acceso a servicios de salud
    dist_salud_km, n_establecimientos_salud
  )

producto1 <- producto1 %>%
  mutate(across(where(is.numeric), ~ round(., 2)))

# =============================================
# Verificaciones
# =============================================
print(paste("Filas:", nrow(producto1)))
print(paste("Columnas:", ncol(producto1)))
print(paste("NA en cod_com:", sum(is.na(producto1$cod_com))))
print(names(producto1))

print(paste("Valores reales dist_salud_km (esperado 33):", sum(!is.na(producto1$dist_salud_km))))
print(paste("Valores reales area_parques_ha (esperado 99, 33x3 años):", sum(!is.na(producto1$area_parques_ha))))
print(paste("NA en densidad_hab_km2 (esperado 0):", sum(is.na(producto1$densidad_hab_km2))))

producto1 %>%
  select(all_of(variables_censales_2017)) %>%
  summarise(across(everything(), ~ sum(!is.na(.)))) %>%
  print()

# =============================================
# Guardar
# =============================================
write_excel_csv(producto1, "01_Input/Producto1/producto1_entorno_urbano.csv")

print("Producto 1 guardado correctamente")

View(producto1)

# =============================================================
# PRODUCTO 2 - Control de calidad
# FONDECYT 11240322
#
# Validaciones sobre la base analítica consolidada 
# (01_Input/Producto2/base_analitica_producto2.csv)
# =============================================================

library(dplyr)

births_producto2 <- read.csv("01_Input/Producto2/base_analitica_producto2.csv")

# -------------------------------------------------------------
# 1. VALIDACIÓN CRUZADA: SOVI propio vs. SOVI de José Daniel
# Resultado: coinciden exactamente en las 33 comunas (misma 
# fuente/metodología). categoria_vulnerabilidad (ES) equivale 
# a vulnerability (EN), mismo dato en distinto idioma.
# -------------------------------------------------------------

comparacion_sovi <- births_producto2 %>%
  distinct(com, indice_vulnerabilidad, sovi, categoria_vulnerabilidad, vulnerability)

comparacion_sovi

# -------------------------------------------------------------
# 2. COBERTURA DE NA POR VARIABLE
# Resultado esperado: satelitales/WorldPop/vías/industria = 
# 713918 (100%); censales = 70929 (año 2017); salud/parques = 
# 29691 (año 2019, parques también suma 2009)
# -------------------------------------------------------------

births_producto2 %>%
  summarise(across(
    c(ndvi_verano, ndvi_anual, cobertura_arborea, sup_impermeable,
      poblacion_total, densidad_hab_km2,
      pct_parques, area_parques_ha,
      bht, indice_vulnerabilidad, pct_inmigrantes,
      dist_salud_km, n_establecimientos_salud,
      vias_km_por_km2, area_industrial_ha),
    ~ sum(!is.na(.))
  )) %>%
  t()

# -------------------------------------------------------------
# 3. RANGOS ESPERADOS (detectar valores fuera de lo razonable)
# -------------------------------------------------------------

births_producto2 %>%
  summarise(
    ndvi_min = min(ndvi_verano, na.rm = TRUE),
    ndvi_max = max(ndvi_verano, na.rm = TRUE),
    lst_min = min(lst_verano, na.rm = TRUE),
    lst_max = max(lst_verano, na.rm = TRUE),
    pct_parques_min = min(pct_parques, na.rm = TRUE),
    pct_parques_max = max(pct_parques, na.rm = TRUE),
    weeks_min = min(weeks, na.rm = TRUE),
    weeks_max = max(weeks, na.rm = TRUE)
  )

# -------------------------------------------------------------
# 4. CASOS DE POST-TÉRMINO (weeks > 42)
# Resultado: 54 casos (0.008%), todos correctamente marcados 
# como birth_preterm = 0. No son errores de clasificación.
# -------------------------------------------------------------

births_producto2 %>%
  filter(weeks > 42) %>%
  count(weeks, birth_preterm) %>%
  arrange(desc(weeks))

# -------------------------------------------------------------
# 5. COBERTURA DE COMUNAS
# Resultado: 33 comunas representadas, sin pérdidas en el cruce
# -------------------------------------------------------------

n_distinct(births_producto2$com)

list.files("01_Input/", recursive = FALSE)



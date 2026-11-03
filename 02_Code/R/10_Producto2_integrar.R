# =============================================================
# PRODUCTO 2 - Base analítica consolidada
# FONDECYT 11240322
#
# Integra el Producto 1 (entorno urbano) con la base de 
# nacimientos (births_2010_2020_last_week_hw_o3.RData).
#
# Criterio de unión (año): year_week1 -- año de la semana 1 de 
# gestación (inicio del embarazo/concepción). Se usa en vez de year_nac porque el 71% de los 
# nacimientos (508,338 de 713,918) tiene year_nac distinto a 
# year_week1 -- no es un caso borde, es la mayoría de los casos, 
# dado que el embarazo dura ~9 meses.
# =============================================================
library(dplyr)
library(readr)

# -------------------------------------------------------------
# 1. CARGAR PRODUCTO 1
# -------------------------------------------------------------
producto1 <- read.csv("01_Input/Producto1/producto1_entorno_urbano.csv") %>%
  mutate(cod_com = as.character(cod_com))

# -------------------------------------------------------------
# 2. CARGAR BASE DE NACIMIENTOS
# -------------------------------------------------------------
e <- new.env()
load("01_Input/Data_ANID/births_2010_2020_last_week_hw_o3.RData", envir = e)
births <- e[[ls(e)[1]]]

# -------------------------------------------------------------
# 3. CRUCE: births + Producto 1
# Join por comuna (com/cod_com) + year_week1
# -------------------------------------------------------------
births_producto2 <- births %>%
  mutate(cod_com = as.character(com)) %>%
  left_join(producto1, by = c("cod_com" = "cod_com", "year_week1" = "year"))

# -------------------------------------------------------------
# 4. VERIFICACIONES
# -------------------------------------------------------------
print(paste("Filas (esperado 713918):", nrow(births_producto2)))
print(paste("Sin duplicados:", nrow(births) == nrow(births_producto2)))
print(paste("Valores reales NDVI (esperado 713918, cobertura total):", 
            sum(!is.na(births_producto2$ndvi_verano))))
print(paste("Valores reales densidad_hab_km2 (esperado 713918, INE):", 
            sum(!is.na(births_producto2$densidad_hab_km2))))
print(paste("Valores reales BHT (solo year_week1 == 2017):", 
            sum(!is.na(births_producto2$bht))))
print(paste("Valores reales dist_salud_km (solo year_week1 == 2019):", 
            sum(!is.na(births_producto2$dist_salud_km))))
print(paste("Valores reales area_parques_ha (year_week1 == 2009, 2013 o 2019):", 
            sum(!is.na(births_producto2$area_parques_ha))))

# -------------------------------------------------------------
# 5. GUARDAR
# -------------------------------------------------------------
dir.create("01_Input/Producto2", showWarnings = FALSE)
write_excel_csv(births_producto2, "01_Input/Producto2/base_analitica_producto2.csv")

producto2 <- read.csv("01_Input/Producto2/base_analitica_producto2.csv")
View(producto2)


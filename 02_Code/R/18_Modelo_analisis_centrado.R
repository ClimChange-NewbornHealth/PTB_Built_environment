# =============================================================
# MODELOS DE COX - EXPOSICIÓN DE TODO EL EMBARAZO (periodo total)
# VERSIÓN CENTRADA
# FONDECYT 11240322
#
# Exposición continua (temperatura máxima, PM2.5, NO2, ozono) x entorno
# urbano en terciles. Cada exposición va CENTRADA en su promedio (dentro de
# cada muestra). Sin errores robustos por comuna.
#
# Exposición: promedio diario entre el inicio del embarazo (date_week1)
# y el parto (date_end_week), en la comuna de residencia.
# Cada modelo se ajusta en dos muestras:
#   - Solo la estación relevante (según mes de nacimiento):
#       temperatura máxima y ozono: verano (nov-mar)
#       PM2.5 y NO2: invierno (may-ago)
#   - Todos los nacimientos
# Unidades: temperatura por 1°C; PM2.5 y NO2 por 10 unidades; ozono por 1 unidad.
# =============================================================
library(dplyr)
library(readr)
library(survival)
library(gt)
library(openxlsx)

# -------------------------------------------------------------
# 1. DATOS
# -------------------------------------------------------------
base_analitica <- read_csv("01_Input/Producto2/base_analitica_producto2.csv")

e2 <- new.env()
load("01_Input/Data_ANID/pollution_2010_2020.RData", envir = e2)
pollution <- e2[[ls(e2)[1]]]

# -------------------------------------------------------------
# 2. EXPOSICIÓN DE TODO EL EMBARAZO
# Suma acumulada diaria por comuna; el promedio del embarazo es la
# diferencia entre la suma al parto y la suma al inicio, dividida por
# los días con dato.
# -------------------------------------------------------------
pollution_cum <- pollution %>%
  mutate(date = as.Date(date)) %>%
  arrange(com, date) %>%
  group_by(com) %>%
  mutate(
    tmax_cum = cumsum(coalesce(tmax, 0)),            tmax_n = cumsum(!is.na(tmax)),
    pm25_cum = cumsum(coalesce(pm25_idw_pred, 0)),   pm25_n = cumsum(!is.na(pm25_idw_pred)),
    no2_cum  = cumsum(coalesce(no2_idw_pred, 0)),    no2_n  = cumsum(!is.na(no2_idw_pred)),
    o3_cum   = cumsum(coalesce(o3_idw_pred, 0)),     o3_n   = cumsum(!is.na(o3_idw_pred))
  ) %>%
  ungroup() %>%
  dplyr::select(com, date, tmax_cum, tmax_n, pm25_cum, pm25_n, no2_cum, no2_n, o3_cum, o3_n)

base_analitica <- base_analitica %>%
  mutate(date_week1 = as.Date(date_week1), date_end_week = as.Date(date_end_week)) %>%
  left_join(pollution_cum %>% dplyr::rename_with(~ paste0(.x, "_ini"), .cols = -c(com, date)),
            by = c("com", "date_week1" = "date")) %>%
  left_join(pollution_cum %>% dplyr::rename_with(~ paste0(.x, "_fin"), .cols = -c(com, date)),
            by = c("com", "date_end_week" = "date")) %>%
  mutate(
    tmax_total    = round((tmax_cum_fin - tmax_cum_ini) / (tmax_n_fin - tmax_n_ini), 2),
    pm25_total_10 = round((pm25_cum_fin - pm25_cum_ini) / (pm25_n_fin - pm25_n_ini), 2) / 10,
    no2_total_10  = round((no2_cum_fin - no2_cum_ini) / (no2_n_fin - no2_n_ini), 2) / 10,
    o3_total      = round((o3_cum_fin - o3_cum_ini) / (o3_n_fin - o3_n_ini), 2)   # ozono sin dividir: por 1 unidad
  )

# -------------------------------------------------------------
# 3. TERCILES DE ENTORNO URBANO (a nivel de comuna)
# Promedio de cada variable por comuna en todos los años (2009-2020);
# las 33 comunas se dividen en Bajo / Medio / Alto (Bajo = referencia).
# -------------------------------------------------------------
terciles_comuna <- base_analitica %>%
  group_by(COMUNA) %>%
  summarise(
    ndvi_prom = mean(ndvi_verano, na.rm = TRUE),
    cobertura_prom = mean(cobertura_arborea, na.rm = TRUE),
    impermeable_prom = mean(sup_impermeable, na.rm = TRUE),
    densidad_prom = mean(densidad_hab_km2, na.rm = TRUE),
    vias_prom = mean(vias_km_por_km2, na.rm = TRUE),
    industrial_prom = mean(area_industrial_ha, na.rm = TRUE),
    lst_verano_prom = mean(lst_verano, na.rm = TRUE),
    lst_anual_prom = mean(lst_anual, na.rm = TRUE)
  ) %>%
  mutate(
    ndvi_tercil = ntile(ndvi_prom, 3),
    cobertura_tercil = ntile(cobertura_prom, 3),
    impermeable_tercil = ntile(impermeable_prom, 3),
    densidad_tercil = ntile(densidad_prom, 3),
    vias_tercil = ntile(vias_prom, 3),
    industrial_tercil = ntile(industrial_prom, 3),
    lst_verano_tercil = ntile(lst_verano_prom, 3),
    lst_anual_tercil = ntile(lst_anual_prom, 3),
    across(ends_with("_tercil"), ~factor(., levels = 1:3, labels = c("Bajo", "Medio", "Alto")))
  ) %>%
  dplyr::select(COMUNA, ends_with("_tercil"))

base_analitica <- base_analitica %>% left_join(terciles_comuna, by = "COMUNA")

# -------------------------------------------------------------
# 4. MUESTRAS Y CENTRADO DE LA EXPOSICIÓN
#   base_analitica : todos los nacimientos
#   base_verano    : nacidos en nov-mar
#   base_invierno  : nacidos en may-ago
# Cada muestra se centra con SU PROPIO promedio. Las variables centradas
# se llaman igual en las tres: tmax_c, pm25_c, no2_c, o3_c.
# -------------------------------------------------------------
base_verano   <- base_analitica %>% filter(month_nac %in% c(11, 12, 1, 2, 3))
base_invierno <- base_analitica %>% filter(month_nac %in% c(5, 6, 7, 8))

centrar <- function(d) {
  d %>% mutate(
    tmax_c = tmax_total    - mean(tmax_total,    na.rm = TRUE),
    pm25_c = pm25_total_10 - mean(pm25_total_10, na.rm = TRUE),
    no2_c  = no2_total_10  - mean(no2_total_10,  na.rm = TRUE),
    o3_c   = o3_total      - mean(o3_total,      na.rm = TRUE)
  )
}
base_verano   <- centrar(base_verano)
base_invierno <- centrar(base_invierno)
base_analitica <- centrar(base_analitica)

covariables <- "sex + age_group_mom + job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + sovi + year_nac"

# -------------------------------------------------------------
# 5. MODELOS DE COX
# Cada modelo:
#   Surv(weeks, birth_preterm) ~ exposición_centrada * entorno (tercil) + covariables
# Nombre: modelo_<exposición>_<entorno>_<muestra>
# -------------------------------------------------------------

# --- Temperatura máxima (por 1°C): verano y todos los nacimientos ---
modelo_tmax_vias_verano         <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * vias_tercil +", covariables)), data = base_verano)
modelo_tmax_ndvi_verano         <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * ndvi_tercil +", covariables)), data = base_verano)
modelo_tmax_cobertura_verano    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * cobertura_tercil +", covariables)), data = base_verano)
modelo_tmax_impermeable_verano  <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * impermeable_tercil +", covariables)), data = base_verano)
modelo_tmax_densidad_verano     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * densidad_tercil +", covariables)), data = base_verano)
modelo_tmax_industrial_verano   <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * industrial_tercil +", covariables)), data = base_verano)
modelo_tmax_lstverano_verano    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * lst_verano_tercil +", covariables)), data = base_verano)
modelo_tmax_lstanual_verano     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * lst_anual_tercil +", covariables)), data = base_verano)

modelo_tmax_vias_todos          <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * vias_tercil +", covariables)), data = base_analitica)
modelo_tmax_ndvi_todos          <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * ndvi_tercil +", covariables)), data = base_analitica)
modelo_tmax_cobertura_todos     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * cobertura_tercil +", covariables)), data = base_analitica)
modelo_tmax_impermeable_todos   <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * impermeable_tercil +", covariables)), data = base_analitica)
modelo_tmax_densidad_todos      <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * densidad_tercil +", covariables)), data = base_analitica)
modelo_tmax_industrial_todos    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * industrial_tercil +", covariables)), data = base_analitica)
modelo_tmax_lstverano_todos     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * lst_verano_tercil +", covariables)), data = base_analitica)
modelo_tmax_lstanual_todos      <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_c * lst_anual_tercil +", covariables)), data = base_analitica)

# --- PM2.5 (por 10 unidades): invierno y todos los nacimientos ---
modelo_pm25_vias_invierno         <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * vias_tercil +", covariables)), data = base_invierno)
modelo_pm25_ndvi_invierno         <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * ndvi_tercil +", covariables)), data = base_invierno)
modelo_pm25_cobertura_invierno    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * cobertura_tercil +", covariables)), data = base_invierno)
modelo_pm25_impermeable_invierno  <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * impermeable_tercil +", covariables)), data = base_invierno)
modelo_pm25_densidad_invierno     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * densidad_tercil +", covariables)), data = base_invierno)
modelo_pm25_industrial_invierno   <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * industrial_tercil +", covariables)), data = base_invierno)
modelo_pm25_lstverano_invierno    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * lst_verano_tercil +", covariables)), data = base_invierno)
modelo_pm25_lstanual_invierno     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * lst_anual_tercil +", covariables)), data = base_invierno)

modelo_pm25_vias_todos          <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * vias_tercil +", covariables)), data = base_analitica)
modelo_pm25_ndvi_todos          <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * ndvi_tercil +", covariables)), data = base_analitica)
modelo_pm25_cobertura_todos     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * cobertura_tercil +", covariables)), data = base_analitica)
modelo_pm25_impermeable_todos   <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * impermeable_tercil +", covariables)), data = base_analitica)
modelo_pm25_densidad_todos      <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * densidad_tercil +", covariables)), data = base_analitica)
modelo_pm25_industrial_todos    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * industrial_tercil +", covariables)), data = base_analitica)
modelo_pm25_lstverano_todos     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * lst_verano_tercil +", covariables)), data = base_analitica)
modelo_pm25_lstanual_todos      <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_c * lst_anual_tercil +", covariables)), data = base_analitica)

# --- NO2 (por 10 unidades): invierno y todos los nacimientos ---
modelo_no2_vias_invierno         <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * vias_tercil +", covariables)), data = base_invierno)
modelo_no2_ndvi_invierno         <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * ndvi_tercil +", covariables)), data = base_invierno)
modelo_no2_cobertura_invierno    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * cobertura_tercil +", covariables)), data = base_invierno)
modelo_no2_impermeable_invierno  <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * impermeable_tercil +", covariables)), data = base_invierno)
modelo_no2_densidad_invierno     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * densidad_tercil +", covariables)), data = base_invierno)
modelo_no2_industrial_invierno   <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * industrial_tercil +", covariables)), data = base_invierno)
modelo_no2_lstverano_invierno    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * lst_verano_tercil +", covariables)), data = base_invierno)
modelo_no2_lstanual_invierno     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * lst_anual_tercil +", covariables)), data = base_invierno)

modelo_no2_vias_todos          <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * vias_tercil +", covariables)), data = base_analitica)
modelo_no2_ndvi_todos          <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * ndvi_tercil +", covariables)), data = base_analitica)
modelo_no2_cobertura_todos     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * cobertura_tercil +", covariables)), data = base_analitica)
modelo_no2_impermeable_todos   <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * impermeable_tercil +", covariables)), data = base_analitica)
modelo_no2_densidad_todos      <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * densidad_tercil +", covariables)), data = base_analitica)
modelo_no2_industrial_todos    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * industrial_tercil +", covariables)), data = base_analitica)
modelo_no2_lstverano_todos     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * lst_verano_tercil +", covariables)), data = base_analitica)
modelo_no2_lstanual_todos      <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ no2_c * lst_anual_tercil +", covariables)), data = base_analitica)

# --- Ozono (por 1 unidad): verano y todos los nacimientos ---
modelo_o3_vias_verano         <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * vias_tercil +", covariables)), data = base_verano)
modelo_o3_ndvi_verano         <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * ndvi_tercil +", covariables)), data = base_verano)
modelo_o3_cobertura_verano    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * cobertura_tercil +", covariables)), data = base_verano)
modelo_o3_impermeable_verano  <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * impermeable_tercil +", covariables)), data = base_verano)
modelo_o3_densidad_verano     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * densidad_tercil +", covariables)), data = base_verano)
modelo_o3_industrial_verano   <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * industrial_tercil +", covariables)), data = base_verano)
modelo_o3_lstverano_verano    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * lst_verano_tercil +", covariables)), data = base_verano)
modelo_o3_lstanual_verano     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * lst_anual_tercil +", covariables)), data = base_verano)

modelo_o3_vias_todos          <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * vias_tercil +", covariables)), data = base_analitica)
modelo_o3_ndvi_todos          <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * ndvi_tercil +", covariables)), data = base_analitica)
modelo_o3_cobertura_todos     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * cobertura_tercil +", covariables)), data = base_analitica)
modelo_o3_impermeable_todos   <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * impermeable_tercil +", covariables)), data = base_analitica)
modelo_o3_densidad_todos      <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * densidad_tercil +", covariables)), data = base_analitica)
modelo_o3_industrial_todos    <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * industrial_tercil +", covariables)), data = base_analitica)
modelo_o3_lstverano_todos     <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * lst_verano_tercil +", covariables)), data = base_analitica)
modelo_o3_lstanual_todos      <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ o3_c * lst_anual_tercil +", covariables)), data = base_analitica)

# -------------------------------------------------------------
# 6. TABLAS
# Por modelo se apilan 5 filas: exposición (en el grupo Bajo del entorno),
# entorno Medio y Alto vs. Bajo, e interacciones Medio y Alto.
# Cada tabla muestra dos columnas: la estación y todos los nacimientos.
# -------------------------------------------------------------
vars_entorno <- c("vias_tercil", "ndvi_tercil", "cobertura_tercil", "impermeable_tercil",
                  "densidad_tercil", "industrial_tercil", "lst_verano_tercil", "lst_anual_tercil")
nombres_entorno <- c("Vías", "NDVI", "Cobertura arbórea", "Sup. impermeable",
                     "Densidad", "Industrial", "LST verano", "LST anual")
codigos_entorno <- c("vias", "ndvi", "cobertura", "impermeable",
                     "densidad", "industrial", "lstverano", "lstanual")

nota_tabla <- paste(
  "La exposición entra como variable continua, centrada en su promedio. Bajo, Medio y Alto son los terciles de cada variable del entorno urbano",
  "(Bajo = grupo de referencia); las filas del entorno comparan terciles con la exposición promedio.",
  "Ajustado por sexo del RN, edad/educación/situación laboral de madre y padre, SOVI y año de nacimiento."
)

# Extrae las 5 filas de un modelo
extraer_formato_largo <- function(modelo, var_calor, var_entorno, nombre_entorno, nombre_calor, unidad) {
  coefs <- summary(modelo)$coefficients
  ci <- exp(confint(modelo))
  f_hr <- function(nm) round(exp(coefs[nm, "coef"]), 3)
  f_ci <- function(nm) paste0("[", round(ci[nm, 1], 3), "-", round(ci[nm, 2], 3), "]")
  f_fila <- function(nm) paste0(f_hr(nm), " ", f_ci(nm))
  
  nm_medio <- paste0(var_entorno, "Medio")
  nm_alto <- paste0(var_entorno, "Alto")
  
  tibble(
    Fila = c(
      paste0(nombre_calor, " ", unidad, " (en comunas con ", nombre_entorno, " Bajo)"),
      paste0(nombre_entorno, " Medio vs. Bajo"),
      paste0(nombre_entorno, " Alto vs. Bajo"),
      paste0(nombre_calor, " × ", nombre_entorno, " Medio (vs. Bajo)"),
      paste0(nombre_calor, " × ", nombre_entorno, " Alto (vs. Bajo)")
    ),
    `HR (IC 95%)` = c(
      f_fila(var_calor), f_fila(nm_medio), f_fila(nm_alto),
      f_fila(paste0(var_calor, ":", nm_medio)), f_fila(paste0(var_calor, ":", nm_alto))
    )
  )
}

# Arma la tabla de una exposición leyendo los modelos ya ajustados (sección 5)
tabla_exposicion <- function(codigo_exp, var_calor, nombre_calor, unidad, estacion, nombre_estacion) {
  filas <- list()
  for (i in seq_along(vars_entorno)) {
    m_est <- get(paste0("modelo_", codigo_exp, "_", codigos_entorno[i], "_", estacion))
    m_todos <- get(paste0("modelo_", codigo_exp, "_", codigos_entorno[i], "_todos"))
    d1 <- extraer_formato_largo(m_est, var_calor, vars_entorno[i], nombres_entorno[i], nombre_calor, unidad)
    d2 <- extraer_formato_largo(m_todos, var_calor, vars_entorno[i], nombres_entorno[i], nombre_calor, unidad)
    filas[[i]] <- tibble(Modelo = nombres_entorno[i], Fila = d1$Fila,
                         col_estacion = d1$`HR (IC 95%)`, col_todos = d2$`HR (IC 95%)`)
  }
  d <- bind_rows(filas)
  names(d)[3:4] <- c(nombre_estacion, "Todos los nacimientos")
  d
}

# Imagen de la tabla
guardar_tabla_png <- function(datos_tabla, titulo, subtitulo, archivo) {
  tabla <- datos_tabla %>%
    dplyr::select(-Modelo) %>%
    gt() %>%
    tab_header(title = titulo, subtitle = subtitulo) %>%
    cols_label(Fila = "") %>%
    tab_footnote(nota_tabla)
  gtsave(tabla, archivo, vwidth = 1400, vheight = 2000)
  tabla
}

# Excel: una hoja por exposición; cada modelo con color alterno y línea gruesa arriba
exportar_excel <- function(lista, titulos, archivo) {
  wb <- createWorkbook()
  fondos <- c("#DCE6F1", "#FFFFFF")
  est_titulo <- createStyle(textDecoration = "bold", fontSize = 13)
  est_enc <- createStyle(textDecoration = "bold", fontColour = "#FFFFFF", fgFill = "#1F3864", halign = "center", wrapText = TRUE)
  
  for (hoja in names(lista)) {
    d <- lista[[hoja]]
    nc <- ncol(d)
    addWorksheet(wb, hoja)
    writeData(wb, hoja, titulos[[hoja]], startRow = 1)
    addStyle(wb, hoja, est_titulo, rows = 1, cols = 1)
    
    # el nombre del modelo se escribe solo en su primera fila
    d_xl <- d %>%
      group_by(Modelo) %>%
      mutate(Modelo = ifelse(row_number() == 1, Modelo, "")) %>%
      ungroup()
    writeData(wb, hoja, d_xl, startRow = 3)
    addStyle(wb, hoja, est_enc, rows = 3, cols = 1:nc, gridExpand = TRUE)
    
    modelos <- unique(d$Modelo)
    for (k in seq_along(modelos)) {
      filas <- 3 + which(d$Modelo == modelos[k])
      fondo <- fondos[(k - 1) %% 2 + 1]
      addStyle(wb, hoja, createStyle(fgFill = fondo), rows = filas, cols = 1:nc, gridExpand = TRUE, stack = TRUE)
      addStyle(wb, hoja, createStyle(border = "top", borderStyle = "medium"), rows = filas[1], cols = 1:nc, gridExpand = TRUE, stack = TRUE)
      addStyle(wb, hoja, createStyle(textDecoration = "bold"), rows = filas[1], cols = 1, stack = TRUE)
    }
    addStyle(wb, hoja, createStyle(halign = "center"), rows = 4:(3 + nrow(d)), cols = 3:nc, gridExpand = TRUE, stack = TRUE)
    
    writeData(wb, hoja, nota_tabla, startRow = 3 + nrow(d) + 2)
    setColWidths(wb, hoja, cols = 1:nc, widths = c(20, 58, 26, 26))
  }
  saveWorkbook(wb, archivo, overwrite = TRUE)
}

carpeta <- "03_Output/Tables"
dir.create("03_Output/Tables", showWarnings = FALSE)

n_verano <- format(nrow(base_verano), big.mark = ".")
n_invierno <- format(nrow(base_invierno), big.mark = ".")
n_todos <- format(nrow(base_analitica), big.mark = ".")

# Temperatura máxima (por 1°C)
d_tmax <- tabla_exposicion("tmax", "tmax_c", "Temperatura", "por 1°C", "verano", "Solo verano (nov-mar)")
sub_tmax <- paste0("HR por cada 1°C e IC 95%. Verano: n = ", n_verano, "; todos los nacimientos: n = ", n_todos)
tabla_tmax <- guardar_tabla_png(d_tmax, "Temperatura Máxima (todo el embarazo) × Entorno Urbano", sub_tmax,
                                file.path(carpeta, "tabla_tmax_formato_estela_centrado.png"))

# PM2.5 (por 10 unidades)
d_pm25 <- tabla_exposicion("pm25", "pm25_c", "PM2.5", "por 10 unidades", "invierno", "Solo invierno (may-ago)")
sub_pm25 <- paste0("HR por cada 10 unidades e IC 95%. Invierno: n = ", n_invierno, "; todos los nacimientos: n = ", n_todos)
tabla_pm25 <- guardar_tabla_png(d_pm25, "PM2.5 (todo el embarazo) × Entorno Urbano", sub_pm25,
                                file.path(carpeta, "tabla_pm25_formato_estela_centrado.png"))

# NO2 (por 10 unidades)
d_no2 <- tabla_exposicion("no2", "no2_c", "NO2", "por 10 unidades", "invierno", "Solo invierno (may-ago)")
sub_no2 <- paste0("HR por cada 10 unidades e IC 95%. Invierno: n = ", n_invierno, "; todos los nacimientos: n = ", n_todos)
tabla_no2 <- guardar_tabla_png(d_no2, "NO2 (todo el embarazo) × Entorno Urbano", sub_no2,
                               file.path(carpeta, "tabla_no2_formato_estela_centrado.png"))

# Ozono (por 1 unidad)
d_o3 <- tabla_exposicion("o3", "o3_c", "Ozono", "por 1 unidad", "verano", "Solo verano (nov-mar)")
sub_o3 <- paste0("HR por cada 1 unidad e IC 95%. Verano: n = ", n_verano, "; todos los nacimientos: n = ", n_todos)
tabla_o3 <- guardar_tabla_png(d_o3, "Ozono (todo el embarazo) × Entorno Urbano", sub_o3,
                              file.path(carpeta, "tabla_o3_formato_estela_centrado.png"))

# Excel con las cuatro tablas (una hoja cada una)
exportar_excel(
  lista = list("Temp max" = d_tmax, "PM2.5" = d_pm25, "NO2" = d_no2, "Ozono" = d_o3),
  titulos = list("Temp max" = paste0("Temperatura Máxima (todo el embarazo) × Entorno Urbano. ", sub_tmax),
                 "PM2.5" = paste0("PM2.5 (todo el embarazo) × Entorno Urbano. ", sub_pm25),
                 "NO2" = paste0("NO2 (todo el embarazo) × Entorno Urbano. ", sub_no2),
                 "Ozono" = paste0("Ozono (todo el embarazo) × Entorno Urbano. ", sub_o3)),
  archivo = "03_Output/Tables/tablas_periodo_total_centrado_con_todos.xlsx"
)

# =============================================================
# MODELOS DE COX - ÚLTIMA SEMANA GESTACIONAL
# Ola de calor (EHF, TAD) y temperatura continua x entorno urbano
# FONDECYT 11240322
# =============================================================
library(survival)
library(dplyr)
library(readr)
library(slider)
library(gt)

base_analitica <- read_csv("01_Input/Producto2/base_analitica_producto2.csv")

# -------------------------------------------------------------
# 1. MODELO BASE (EHF 3 días)
# -------------------------------------------------------------
modelo_cox_base <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin + sex + age_group_mom + job_group_mom + 
    educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + sovi + year_nac,
  data = base_analitica
)
summary(modelo_cox_base)

# -------------------------------------------------------------
# 2. EHF 3 DÍAS x ENTORNO URBANO (variables continuas)
# -------------------------------------------------------------
modelo_ndvi <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin * ndvi_verano + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_cobertura <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin * cobertura_arborea + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_impermeable <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin * sup_impermeable + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_densidad <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin * densidad_hab_km2 + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_vias <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin * vias_km_por_km2 + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_industrial <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin * area_industrial_ha + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)

# -------------------------------------------------------------
# 3. TEMPERATURA MÁXIMA DE LA ÚLTIMA SEMANA (pollution_2010_2020.RData)
# Promedio móvil de 7 días por comuna (tmax_7d). Variable continua.
# -------------------------------------------------------------
e2 <- new.env()
load("01_Input/Data_ANID/pollution_2010_2020.RData", envir = e2)
pollution <- e2[[ls(e2)[1]]]

pollution <- pollution %>%
  mutate(date = as.Date(date)) %>%
  arrange(com, date) %>%
  group_by(com) %>%
  mutate(tmax_7d = slide_dbl(tmax, mean, .before = 6, na.rm = TRUE)) %>%
  ungroup()

base_analitica <- base_analitica %>%
  mutate(date_nac = as.Date(date_nac)) %>%
  left_join(pollution %>% select(com, date, tmax_7d), by = c("com", "date_nac" = "date"))

# -------------------------------------------------------------
# 4. TEMPERATURA CONTINUA (tmax_7d) x ENTORNO URBANO
# -------------------------------------------------------------
modelo_tmax_ndvi <- coxph(
  Surv(weeks, birth_preterm) ~ tmax_7d * ndvi_verano + sex + age_group_mom + job_group_mom + 
    educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + sovi + year_nac,
  data = base_analitica
)
modelo_tmax_cobertura <- coxph(
  Surv(weeks, birth_preterm) ~ tmax_7d * cobertura_arborea + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_tmax_impermeable <- coxph(
  Surv(weeks, birth_preterm) ~ tmax_7d * sup_impermeable + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_tmax_densidad <- coxph(
  Surv(weeks, birth_preterm) ~ tmax_7d * densidad_hab_km2 + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_tmax_vias <- coxph(
  Surv(weeks, birth_preterm) ~ tmax_7d * vias_km_por_km2 + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_tmax_industrial <- coxph(
  Surv(weeks, birth_preterm) ~ tmax_7d * area_industrial_ha + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)

# -------------------------------------------------------------
# 5. FUNCIÓN Y TABLA: TEMPERATURA MÁXIMA (7 días) x ENTORNO URBANO
# -------------------------------------------------------------
extraer_resultados <- function(modelo, var_calor, var_entorno) {
  coefs <- summary(modelo)$coefficients
  ci <- exp(confint(modelo))
  data.frame(
    hr_calor = round(exp(coefs[var_calor, "coef"]), 3),
    ci_calor = paste0("[", round(ci[var_calor, 1], 3), "-", round(ci[var_calor, 2], 3), "]"),
    hr_entorno = round(exp(coefs[var_entorno, "coef"]), 3),
    ci_entorno = paste0("[", round(ci[var_entorno, 1], 3), "-", round(ci[var_entorno, 2], 3), "]"),
    hr_interaccion = round(exp(coefs[paste0(var_calor, ":", var_entorno), "coef"]), 3),
    ci_interaccion = paste0("[", round(ci[paste0(var_calor, ":", var_entorno), 1], 3), "-", 
                            round(ci[paste0(var_calor, ":", var_entorno), 2], 3), "]")
  )
}

tabla_2_datos <- bind_rows(
  "NDVI" = extraer_resultados(modelo_tmax_ndvi, "tmax_7d", "ndvi_verano"),
  "Cobertura arbórea" = extraer_resultados(modelo_tmax_cobertura, "tmax_7d", "cobertura_arborea"),
  "Sup. impermeable" = extraer_resultados(modelo_tmax_impermeable, "tmax_7d", "sup_impermeable"),
  "Densidad" = extraer_resultados(modelo_tmax_densidad, "tmax_7d", "densidad_hab_km2"),
  "Vías" = extraer_resultados(modelo_tmax_vias, "tmax_7d", "vias_km_por_km2"),
  "Industrial" = extraer_resultados(modelo_tmax_industrial, "tmax_7d", "area_industrial_ha"),
  .id = "Variable"
)

tabla_2 <- tabla_2_datos %>%
  gt() %>%
  tab_header(
    title = "Temperatura Máxima (7 días) × Entorno Urbano",
    subtitle = "HR e intervalo de confianza 95% para cada componente del modelo"
  ) %>%
  tab_spanner(label = "Calor (por 1°C)", columns = c(hr_calor, ci_calor)) %>%
  tab_spanner(label = "Entorno urbano", columns = c(hr_entorno, ci_entorno)) %>%
  tab_spanner(label = "Interacción", columns = c(hr_interaccion, ci_interaccion)) %>%
  cols_label(
    Variable = "Variable",
    hr_calor = "HR", ci_calor = "IC 95%",
    hr_entorno = "HR", ci_entorno = "IC 95%",
    hr_interaccion = "HR", ci_interaccion = "IC 95%"
  )
gtsave(tabla_2, "03_Output/Tables/tabla_modelo_2_tmax_formato_estela.png", vwidth = 1800, vheight = 800)

# -------------------------------------------------------------
# 6. ROBUSTEZ (NDVI como variable de prueba)
# -------------------------------------------------------------
# EHF 2 y 4 días x NDVI (también alimentan la tabla de duraciones)
modelo_ehf2d_ndvi <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_2d_bin * ndvi_verano + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)
modelo_ehf4d_ndvi <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_4d_bin * ndvi_verano + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)

# NDVI en terciles
# OJO: terciles sobre filas de nacimientos con ntile(); parte comunas entre
# categorías. Los terciles por comuna están en el script de periodo total.
base_analitica <- base_analitica %>%
  mutate(ndvi_tercil = factor(ntile(ndvi_verano, 3), levels = 1:3, labels = c("Bajo", "Medio", "Alto")))

modelo_tercil_ndvi <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin * ndvi_tercil + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)

# Sin comunas atípicas (Lo Barnechea, Las Condes)
base_sin_atipicas <- base_analitica %>% filter(!COMUNA %in% c("Lo Barnechea", "Las Condes"))
modelo_sin_atipicas <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_4d_bin * ndvi_verano + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_sin_atipicas
)

# -------------------------------------------------------------
# 7. TABLAS EHF (2, 3 y 4 días) x ENTORNO URBANO, 3 bloques
# -------------------------------------------------------------
armar_tabla_ehf <- function(datos, dias) {
  datos %>%
    gt() %>%
    tab_header(
      title = paste0("Ola de Calor (EHF, ", dias, " días) × Entorno Urbano"),
      subtitle = "HR e intervalo de confianza 95% para cada componente del modelo"
    ) %>%
    tab_spanner(label = "Ola de calor (sí/no)", columns = c(hr_calor, ci_calor)) %>%
    tab_spanner(label = "Entorno urbano", columns = c(hr_entorno, ci_entorno)) %>%
    tab_spanner(label = "Interacción", columns = c(hr_interaccion, ci_interaccion)) %>%
    cols_label(
      Variable = "Variable",
      hr_calor = "HR", ci_calor = "IC 95%",
      hr_entorno = "HR", ci_entorno = "IC 95%",
      hr_interaccion = "HR", ci_interaccion = "IC 95%"
    )
}

archivos_ehf <- c("2" = "tabla_modelo_ehf2d.png", "3" = "tabla_modelo_1_ehf3d.png", "4" = "tabla_modelo_ehf4d.png")

vars_entorno_cont <- c("ndvi_verano", "cobertura_arborea", "sup_impermeable", 
                       "densidad_hab_km2", "vias_km_por_km2", "area_industrial_ha")
nombres_entorno_cont <- c("NDVI", "Cobertura arbórea", "Sup. impermeable", 
                          "Densidad", "Vías", "Industrial")

# 2 y 4 días: se ajustan los modelos dentro del bucle
for (dias in c(2, 4)) {
  var_ehf <- paste0("HW_EHF_TAD_", dias, "d_bin")
  filas <- list()
  for (i in seq_along(vars_entorno_cont)) {
    f <- as.formula(paste("Surv(weeks, birth_preterm) ~", var_ehf, "*", vars_entorno_cont[i],
                          "+ sex + age_group_mom + job_group_mom + educ_group_mom +",
                          "age_group_dad + educ_group_dad + job_group_dad + sovi + year_nac"))
    filas[[nombres_entorno_cont[i]]] <- extraer_resultados(coxph(f, data = base_analitica), var_ehf, vars_entorno_cont[i])
  }
  tabla <- armar_tabla_ehf(bind_rows(filas, .id = "Variable"), dias)
  gtsave(tabla, file.path("03_Output/Tables", archivos_ehf[as.character(dias)]), vwidth = 1800, vheight = 800)
}

# 3 días: usa los modelos de la sección 2
tabla_1_datos <- bind_rows(
  "NDVI" = extraer_resultados(modelo_ndvi, "HW_EHF_TAD_3d_bin", "ndvi_verano"),
  "Cobertura arbórea" = extraer_resultados(modelo_cobertura, "HW_EHF_TAD_3d_bin", "cobertura_arborea"),
  "Sup. impermeable" = extraer_resultados(modelo_impermeable, "HW_EHF_TAD_3d_bin", "sup_impermeable"),
  "Densidad" = extraer_resultados(modelo_densidad, "HW_EHF_TAD_3d_bin", "densidad_hab_km2"),
  "Vías" = extraer_resultados(modelo_vias, "HW_EHF_TAD_3d_bin", "vias_km_por_km2"),
  "Industrial" = extraer_resultados(modelo_industrial, "HW_EHF_TAD_3d_bin", "area_industrial_ha"),
  .id = "Variable"
)
gtsave(armar_tabla_ehf(tabla_1_datos, 3), file.path("03_Output/Tables", archivos_ehf["3"]), vwidth = 1800, vheight = 800)

# -------------------------------------------------------------
# 8. TABLA: EHF (2, 3 y 4 días) x NDVI, comparación por duración
# -------------------------------------------------------------
extraer_duracion <- function(modelo, var_ehf, duracion) {
  coefs <- summary(modelo)$coefficients
  data.frame(
    Duracion = duracion,
    HR_calor = round(exp(coefs[var_ehf, "coef"]), 3),
    p_calor = round(coefs[var_ehf, "Pr(>|z|)"], 3),
    HR_interaccion = round(exp(coefs[paste0(var_ehf, ":ndvi_verano"), "coef"]), 3),
    p_interaccion = round(coefs[paste0(var_ehf, ":ndvi_verano"), "Pr(>|z|)"], 3)
  )
}

tabla_3 <- bind_rows(
  extraer_duracion(modelo_ehf2d_ndvi, "HW_EHF_TAD_2d_bin", "2 días"),
  extraer_duracion(modelo_ndvi, "HW_EHF_TAD_3d_bin", "3 días"),
  extraer_duracion(modelo_ehf4d_ndvi, "HW_EHF_TAD_4d_bin", "4 días")
) %>%
  gt() %>%
  tab_header(
    title = "Ola de Calor (EHF) × NDVI, por Duración del Evento",
    subtitle = "Ninguna interacción alcanza significancia; 4 días es la más cercana"
  ) %>%
  cols_label(
    Duracion = "Duración",
    HR_calor = "HR calor", p_calor = "p (calor)",
    HR_interaccion = "HR interacción", p_interaccion = "p (interacción)"
  )
gtsave(tabla_3, "03_Output/Tables/tabla_modelo_3_duraciones_ndvi.png", vwidth = 1400, vheight = 700)

# -------------------------------------------------------------
# 9. TABLA: PRUEBAS DE ROBUSTEZ ADICIONALES
# El p de splines (0.510) viene de un pspline(tmax_7d) corrido aparte.
# -------------------------------------------------------------
c_terc <- summary(modelo_tercil_ndvi)$coefficients
c_atip <- summary(modelo_sin_atipicas)$coefficients

tabla_4 <- data.frame(
  Prueba = c("NDVI en terciles (Medio vs Bajo)", "NDVI en terciles (Alto vs Bajo)",
             "Sin comunas atípicas (Lo Barnechea, Las Condes)", 
             "Forma de la curva calor-riesgo (splines, TMAX)"),
  Resultado = c(
    paste0("HR=", round(exp(c_terc["HW_EHF_TAD_3d_bin:ndvi_tercilMedio", "coef"]), 3)),
    paste0("HR=", round(exp(c_terc["HW_EHF_TAD_3d_bin:ndvi_tercilAlto", "coef"]), 3)),
    paste0("HR=", round(exp(c_atip["HW_EHF_TAD_4d_bin:ndvi_verano", "coef"]), 3), " (interacción EHF-4d)"),
    "Curva ≈ lineal (sin quiebres)"
  ),
  Valor_p = c(
    round(c_terc["HW_EHF_TAD_3d_bin:ndvi_tercilMedio", "Pr(>|z|)"], 3),
    round(c_terc["HW_EHF_TAD_3d_bin:ndvi_tercilAlto", "Pr(>|z|)"], 3),
    round(c_atip["HW_EHF_TAD_4d_bin:ndvi_verano", "Pr(>|z|)"], 3),
    0.510
  )
) %>%
  gt() %>%
  tab_header(
    title = "Pruebas de Robustez Adicionales",
    subtitle = "Ningún ajuste metodológico cambia la conclusión principal"
  ) %>%
  tab_footnote(
    footnote = "El test de splines evalúa si la relación calor-riesgo es una curva o una línea recta; no compara dos grupos, por eso no tiene HR asociado.",
    locations = cells_body(columns = Resultado, rows = 4)
  ) %>%
  cols_label(Prueba = "Prueba", Resultado = "Resultado", Valor_p = "Valor p")
gtsave(tabla_4, "03_Output/Tables/tabla_modelo_4_robustez.png", vwidth = 1600, vheight = 800)

# -------------------------------------------------------------
# 10. TABLA: ¿POR QUÉ CAMBIA EL HR DEL CALOR ENTRE MODELOS?
# -------------------------------------------------------------
modelo_sin_interaccion <- coxph(
  Surv(weeks, birth_preterm) ~ HW_EHF_TAD_3d_bin + ndvi_verano + sex + age_group_mom + 
    job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + 
    sovi + year_nac,
  data = base_analitica
)

hr_ic <- function(modelo, variable) {
  list(hr = round(exp(coef(modelo)[variable]), 3),
       ic = paste0("[", paste(round(exp(confint(modelo)[variable, ]), 3), collapse = "-"), "]"))
}
res_sin <- hr_ic(modelo_sin_interaccion, "HW_EHF_TAD_3d_bin")
res_con <- hr_ic(modelo_ndvi, "HW_EHF_TAD_3d_bin")
rango_ndvi <- round(range(base_analitica$ndvi_verano, na.rm = TRUE), 2)

tabla_explicacion <- data.frame(
  Modelo = c("Sin interacción (calor + NDVI por separado)", "Con interacción (calor × NDVI)"),
  HR_calor = c(res_sin$hr, res_con$hr),
  IC_95 = c(res_sin$ic, res_con$ic),
  Interpretacion = c(
    "Efecto promedio del calor en toda la muestra",
    paste0("Efecto del calor cuando NDVI=0 (valor que no existe en los datos: rango real ", 
           rango_ndvi[1], "-", rango_ndvi[2], ")")
  )
) %>%
  gt() %>%
  tab_header(
    title = "¿Por qué cambia el HR del calor entre modelos?",
    subtitle = paste0("El NDVI nunca vale 0 en la muestra (rango real: ", rango_ndvi[1], " a ", rango_ndvi[2], ")")
  ) %>%
  cols_label(Modelo = "Modelo", HR_calor = "HR calor", IC_95 = "IC 95%", Interpretacion = "Qué representa este número") %>%
  tab_footnote(
    footnote = "Una posible solución sería centrar la variable NDVI (restar su media) antes de correr el modelo, para que el HR represente el efecto en el NDVI promedio, no en NDVI=0.",
    locations = cells_column_labels(columns = HR_calor)
  )
gtsave(tabla_explicacion, "03_Output/Tables/tabla_explicacion_hr_calor.png", vwidth = 1400, vheight = 700)


# =============================================================
# MODELOS DE COX - TERCILES DE ENTORNO URBANO
# Temperatura máxima (7 días, continua) x entorno urbano en terciles
# FONDECYT 11240322
# =============================================================

base_prueba <- base_analitica %>% select(-any_of("ndvi_tercil"))

# Temperatura y contaminación: promedio móvil de 7 días por comuna
e2 <- new.env()
load("01_Input/Data_ANID/pollution_2010_2020.RData", envir = e2)
pollution <- e2[[ls(e2)[1]]]

pollution <- pollution %>%
  mutate(date = as.Date(date)) %>%
  arrange(com, date) %>%
  group_by(com) %>%
  mutate(
    tmax_7d = slide_dbl(tmax, mean, .before = 6, na.rm = TRUE),
    pm25_7d = slide_dbl(pm25_idw_pred, mean, .before = 6, na.rm = TRUE),
    no2_7d  = slide_dbl(no2_idw_pred, mean, .before = 6, na.rm = TRUE)
  ) %>%
  ungroup()

base_prueba <- base_prueba %>%
  select(-any_of(c("tmax_7d", "tad_7d"))) %>%
  mutate(date_nac = as.Date(date_nac)) %>%
  left_join(
    pollution %>% select(com, date, tmax_7d, pm25_7d, no2_7d),
    by = c("com", "date_nac" = "date")
  )

# -------------------------------------------------------------
# Terciles a nivel de comuna (promedio de todos los años), no de nacimiento.
# Cada comuna queda en un solo grupo. Ocho variables, un solo join.
# -------------------------------------------------------------
terciles_comuna <- base_prueba %>%
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
  select(COMUNA, ends_with("_tercil"))

base_prueba <- base_prueba %>% left_join(terciles_comuna, by = "COMUNA")

# -------------------------------------------------------------
# Modelos: temperatura máxima (7 días) x entorno en terciles
# -------------------------------------------------------------
covariables <- "sex + age_group_mom + job_group_mom + educ_group_mom + age_group_dad + educ_group_dad + job_group_dad + sovi + year_nac"

modelo_tmax_ndvi_tercil <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * ndvi_tercil +", covariables)), data = base_prueba)
modelo_tmax_cobertura_tercil <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * cobertura_tercil +", covariables)), data = base_prueba)
modelo_tmax_impermeable_tercil <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * impermeable_tercil +", covariables)), data = base_prueba)
modelo_tmax_densidad_tercil <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * densidad_tercil +", covariables)), data = base_prueba)
modelo_tmax_vias_tercil <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * vias_tercil +", covariables)), data = base_prueba)
modelo_tmax_industrial_tercil <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * industrial_tercil +", covariables)), data = base_prueba)
modelo_tmax_lstverano_tercil <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * lst_verano_tercil +", covariables)), data = base_prueba)
modelo_tmax_lstanual_tercil <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * lst_anual_tercil +", covariables)), data = base_prueba)

# -------------------------------------------------------------
# Tablas en 3 bloques (calor / entorno / interacción)
#-------------------------------------------------------------
extraer_tercil_3b <- function(modelo, var_calor, var_entorno) {
  coefs <- summary(modelo)$coefficients
  ci <- exp(confint(modelo))
  f_hr <- function(nm) round(exp(coefs[nm, "coef"]), 3)
  f_ci <- function(nm) paste0("[", round(ci[nm, 1], 3), "-", round(ci[nm, 2], 3), "]")
  
  nm_ent <- paste0(var_entorno, c("Medio", "Alto"))
  nm_int <- paste0(var_calor, ":", var_entorno, c("Medio", "Alto"))
  
  data.frame(
    Comparacion = c("Medio vs. Bajo", "Alto vs. Bajo"),
    hr_calor = c(f_hr(var_calor), NA),
    ci_calor = c(f_ci(var_calor), NA),
    hr_entorno = sapply(nm_ent, f_hr),
    ci_entorno = sapply(nm_ent, f_ci),
    hr_inter = sapply(nm_int, f_hr),
    ci_inter = sapply(nm_int, f_ci),
    row.names = NULL
  )
}

armar_tabla_3b <- function(datos, titulo) {
  datos %>%
    gt(groupname_col = "Variable") %>%
    tab_header(
      title = titulo,
      subtitle = "HR e intervalo de confianza 95%; el entorno y la interacción se comparan contra el tercil Bajo"
    ) %>%
    tab_spanner(label = "Calor (por 1°C, tercil Bajo)", columns = c(hr_calor, ci_calor)) %>%
    tab_spanner(label = "Entorno urbano", columns = c(hr_entorno, ci_entorno)) %>%
    tab_spanner(label = "Interacción", columns = c(hr_inter, ci_inter)) %>%
    cols_label(
      Comparacion = "Comparación",
      hr_calor = "HR", ci_calor = "IC 95%",
      hr_entorno = "HR", ci_entorno = "IC 95%",
      hr_inter = "HR", ci_inter = "IC 95%"
    ) %>%
    sub_missing(columns = everything(), missing_text = "")
}

tabla_terciles_3b <- bind_rows(
  "NDVI" = extraer_tercil_3b(modelo_tmax_ndvi_tercil, "tmax_7d", "ndvi_tercil"),
  "Cobertura arbórea" = extraer_tercil_3b(modelo_tmax_cobertura_tercil, "tmax_7d", "cobertura_tercil"),
  "Sup. impermeable" = extraer_tercil_3b(modelo_tmax_impermeable_tercil, "tmax_7d", "impermeable_tercil"),
  "Densidad" = extraer_tercil_3b(modelo_tmax_densidad_tercil, "tmax_7d", "densidad_tercil"),
  "Vías" = extraer_tercil_3b(modelo_tmax_vias_tercil, "tmax_7d", "vias_tercil"),
  "Industrial" = extraer_tercil_3b(modelo_tmax_industrial_tercil, "tmax_7d", "industrial_tercil"),
  .id = "Variable"
)
gtsave(armar_tabla_3b(tabla_terciles_3b, "Temperatura Máxima (7 días) × Entorno Urbano en Terciles"),
       "03_Output/Tables/tabla_terciles_3bloques.png", vwidth = 1800, vheight = 1300)

tabla_lst_datos <- bind_rows(
  "LST verano" = extraer_tercil_3b(modelo_tmax_lstverano_tercil, "tmax_7d", "lst_verano_tercil"),
  "LST anual" = extraer_tercil_3b(modelo_tmax_lstanual_tercil, "tmax_7d", "lst_anual_tercil"),
  .id = "Variable"
)
gtsave(armar_tabla_3b(tabla_lst_datos, "Temperatura Máxima (7 días) × Temperatura Superficial (LST) en Terciles"),
       "03_Output/Tables/tabla_terciles_lst.png", vwidth = 1800, vheight = 800)

# -------------------------------------------------------------
# Tabla de terciles con HR, IC y valor p de la interacción
# -------------------------------------------------------------
extraer_tercil <- function(modelo, var_calor, var_entorno) {
  coefs <- summary(modelo)$coefficients
  ci <- exp(confint(modelo))
  
  nivel_medio <- paste0(var_calor, ":", var_entorno, "Medio")
  nivel_alto <- paste0(var_calor, ":", var_entorno, "Alto")
  
  data.frame(
    Nivel = c("Medio vs. Bajo", "Alto vs. Bajo"),
    HR = round(exp(coefs[c(nivel_medio, nivel_alto), "coef"]), 3),
    IC_95 = c(
      paste0("[", round(ci[nivel_medio, 1], 3), "-", round(ci[nivel_medio, 2], 3), "]"),
      paste0("[", round(ci[nivel_alto, 1], 3), "-", round(ci[nivel_alto, 2], 3), "]")
    ),
    Valor_p = round(coefs[c(nivel_medio, nivel_alto), "Pr(>|z|)"], 3)
  )
}

tabla_terciles <- bind_rows(
  "NDVI" = extraer_tercil(modelo_tmax_ndvi_tercil, "tmax_7d", "ndvi_tercil"),
  "Cobertura arbórea" = extraer_tercil(modelo_tmax_cobertura_tercil, "tmax_7d", "cobertura_tercil"),
  "Sup. impermeable" = extraer_tercil(modelo_tmax_impermeable_tercil, "tmax_7d", "impermeable_tercil"),
  "Densidad" = extraer_tercil(modelo_tmax_densidad_tercil, "tmax_7d", "densidad_tercil"),
  "Vías" = extraer_tercil(modelo_tmax_vias_tercil, "tmax_7d", "vias_tercil"),
  "Industrial" = extraer_tercil(modelo_tmax_industrial_tercil, "tmax_7d", "industrial_tercil"),
  .id = "Variable"
) %>%
  gt(groupname_col = "Variable") %>%
  tab_header(
    title = "Interacción Temperatura × Entorno Urbano (Terciles)",
    subtitle = "HR e intervalo de confianza 95%, comparado contra tercil Bajo"
  ) %>%
  cols_label(Nivel = "Comparación", HR = "HR", IC_95 = "IC 95%", Valor_p = "Valor p")
gtsave(tabla_terciles, "03_Output/Tables/tabla_terciles_completa.png", vwidth = 1400, vheight = 1200)

# =============================================================
# VARIABLES DE CORTE ÚNICO (BHT, dimensiones, migración, salud)
# Solo tienen dato en un año (2017 o 2019). Dos versiones:
#   A: solo nacimientos del año con dato real (submuestra).
#   B: el valor de cada comuna se repite en todos los años (muestra completa).
# =============================================================
variables_corte_unico <- c("bht", "dim_socioeconomica", "dim_accesibilidad",
                           "dim_ambiental", "dim_seguridad", "pct_inmigrantes",
                           "dist_salud_km", "n_establecimientos_salud")

# Versión B: valor único por comuna, repetido en todos los años
base_repetida <- base_prueba %>%
  group_by(COMUNA) %>%
  mutate(across(all_of(variables_corte_unico), ~ first(na.omit(.)))) %>%
  ungroup()

# Terciles de las 33 comunas (un valor por comuna)
terciles_unico <- base_repetida %>%
  distinct(COMUNA, across(all_of(variables_corte_unico))) %>%
  mutate(
    bht_tercil = ntile(bht, 3),
    socioec_tercil = ntile(dim_socioeconomica, 3),
    accesib_tercil = ntile(dim_accesibilidad, 3),
    ambiental_tercil = ntile(dim_ambiental, 3),
    seguridad_tercil = ntile(dim_seguridad, 3),
    inmigr_tercil = ntile(pct_inmigrantes, 3),
    distsalud_tercil = ntile(dist_salud_km, 3),
    nestab_tercil = ntile(n_establecimientos_salud, 3),
    across(ends_with("_tercil"), ~factor(., levels = 1:3, labels = c("Bajo", "Medio", "Alto")))
  ) %>%
  select(COMUNA, ends_with("_tercil"))

base_repetida <- base_repetida %>% left_join(terciles_unico, by = "COMUNA")
base_prueba <- base_prueba %>% left_join(terciles_unico, by = "COMUNA")

# Modelos de BHT (índice general): versión B (repetido) y versión A (cohorte 2017)
modelo_B_bht <- coxph(
  as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * bht_tercil +", covariables)),
  data = base_repetida
)
modelo_A_bht <- coxph(
  as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * bht_tercil +", covariables)),
  data = base_prueba %>% filter(year_week1 == 2017)
)

# Listas donde se van guardando los resultados de cada variable
resultados_B <- list()
resultados_A <- list()
resultados_B[["BHT (índice general)"]] <- extraer_tercil_3b(modelo_B_bht, "tmax_7d", "bht_tercil")
resultados_A[["BHT (índice general)"]] <- extraer_tercil_3b(modelo_A_bht, "tmax_7d", "bht_tercil")


# -------------------------------------------------------------
# Modelos de las otras variables de corte único
# Año de corte: 2017 (BHT y sus dimensiones, migración), 2019 (salud)
# -------------------------------------------------------------
corte_unico <- data.frame(
  etiqueta = c("BHT: dim. socioeconómica", "BHT: dim. accesibilidad", "BHT: dim. ambiental",
               "BHT: dim. seguridad", "Migración (% inmigrantes)", 
               "Salud: distancia (km)", "Salud: N° establecimientos"),
  tercil = c("socioec_tercil", "accesib_tercil", "ambiental_tercil",
             "seguridad_tercil", "inmigr_tercil", "distsalud_tercil", "nestab_tercil"),
  anio = c(2017, 2017, 2017, 2017, 2017, 2019, 2019)
)

for (i in seq_len(nrow(corte_unico))) {
  f <- as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d *", corte_unico$tercil[i], "+", covariables))
  
  modelo_B <- coxph(f, data = base_repetida)
  modelo_A <- coxph(f, data = base_prueba %>% filter(year_week1 == corte_unico$anio[i]))
  
  resultados_B[[corte_unico$etiqueta[i]]] <- extraer_tercil_3b(modelo_B, "tmax_7d", corte_unico$tercil[i])
  resultados_A[[corte_unico$etiqueta[i]]] <- extraer_tercil_3b(modelo_A, "tmax_7d", corte_unico$tercil[i])
}

# -------------------------------------------------------------
# Tablas de corte único: versión B (repetido) y versión A (submuestra)
# -------------------------------------------------------------
armar_tabla_corte_unico <- function(resultados, subtitulo, nota) {
  bind_rows(resultados, .id = "Variable") %>%
    gt(groupname_col = "Variable") %>%
    tab_header(
      title = "Temperatura Máxima (7 días) × Variables de Corte Único (Terciles)",
      subtitle = subtitulo
    ) %>%
    tab_spanner(label = "Calor (por 1°C, tercil Bajo)", columns = c(hr_calor, ci_calor)) %>%
    tab_spanner(label = "Entorno", columns = c(hr_entorno, ci_entorno)) %>%
    tab_spanner(label = "Interacción", columns = c(hr_inter, ci_inter)) %>%
    cols_label(
      Comparacion = "Comparación",
      hr_calor = "HR", ci_calor = "IC 95%",
      hr_entorno = "HR", ci_entorno = "IC 95%",
      hr_inter = "HR", ci_inter = "IC 95%"
    ) %>%
    sub_missing(columns = everything(), missing_text = "") %>%
    tab_footnote(nota)
}

tabla_B <- armar_tabla_corte_unico(
  resultados_B,
  "Versión B: valor del año de corte repetido en todos los años (n = 713.918)",
  "Los valores de BHT, sus dimensiones y migración corresponden a 2017; los de salud, a 2019. Se asume que la posición relativa de cada comuna no cambió entre 2010 y 2020."
)
gtsave(tabla_B, "03_Output/Tables/tabla_corte_unico_B_repetido.png", vwidth = 1800, vheight = 2400)

tabla_A <- armar_tabla_corte_unico(
  resultados_A,
  "Versión A: solo nacimientos con dato real (BHT y migración: cohorte 2017, n ≈ 71 mil; salud: cohorte 2019, n ≈ 30 mil)",
  "Muestra reducida: los IC son más anchos y el efecto de la temperatura depende de cómo fue el verano de esa cohorte en particular."
)
gtsave(tabla_A, "03_Output/Tables/tabla_corte_unico_A_submuestra.png", vwidth = 1800, vheight = 2400)

# -------------------------------------------------------------
# PARQUES (2009, 2013 y 2019): cada fuente por separado
# Las tres fuentes usan criterios distintos de "parque" y no son comparables
# entre sí, así que cada una entra como una variable propia, con su tercil,
# y se repite en todos los años (versión B).
# -------------------------------------------------------------
producto1 <- read.csv("01_Input/Producto1/producto1_entorno_urbano.csv")

parques_fotos <- producto1 %>%
  filter(year %in% c(2009, 2013, 2019)) %>%
  select(COMUNA, year, pct_parques) %>%
  tidyr::pivot_wider(names_from = year, values_from = pct_parques, names_prefix = "parques_") %>%
  mutate(
    parques09_tercil = factor(ntile(parques_2009, 3), levels = 1:3, labels = c("Bajo", "Medio", "Alto")),
    parques13_tercil = factor(ntile(parques_2013, 3), levels = 1:3, labels = c("Bajo", "Medio", "Alto")),
    parques19_tercil = factor(ntile(parques_2019, 3), levels = 1:3, labels = c("Bajo", "Medio", "Alto"))
  ) %>%
  select(COMUNA, ends_with("_tercil"))

base_repetida <- base_repetida %>% left_join(parques_fotos, by = "COMUNA")

modelo_B_parques09 <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * parques09_tercil +", covariables)), data = base_repetida)
modelo_B_parques13 <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * parques13_tercil +", covariables)), data = base_repetida)
modelo_B_parques19 <- coxph(as.formula(paste("Surv(weeks, birth_preterm) ~ tmax_7d * parques19_tercil +", covariables)), data = base_repetida)

resultados_parques <- list(
  "Parques 2009 (GORE, comuna completa)" = extraer_tercil_3b(modelo_B_parques09, "tmax_7d", "parques09_tercil"),
  "Parques 2013 (PRMS)" = extraer_tercil_3b(modelo_B_parques13, "tmax_7d", "parques13_tercil"),
  "Parques 2019 (INE, zona urbana)" = extraer_tercil_3b(modelo_B_parques19, "tmax_7d", "parques19_tercil")
)

tabla_parques_cox <- bind_rows(resultados_parques, .id = "Variable") %>%
  gt(groupname_col = "Variable") %>%
  tab_header(
    title = "Temperatura Máxima (7 días) × Parques (Terciles, cada fuente por separado)",
    subtitle = "Versión B: valor de cada fuente repetido en todos los años (n = 713.918)"
  ) %>%
  tab_spanner(label = "Calor (por 1°C, tercil Bajo)", columns = c(hr_calor, ci_calor)) %>%
  tab_spanner(label = "Entorno", columns = c(hr_entorno, ci_entorno)) %>%
  tab_spanner(label = "Interacción", columns = c(hr_inter, ci_inter)) %>%
  cols_label(
    Comparacion = "Comparación",
    hr_calor = "HR", ci_calor = "IC 95%",
    hr_entorno = "HR", ci_entorno = "IC 95%",
    hr_inter = "HR", ci_inter = "IC 95%"
  ) %>%
  sub_missing(columns = everything(), missing_text = "") %>%
  tab_footnote("Las tres fuentes usan criterios distintos de 'parque' y no son comparables entre sí; por eso se analizan como variables separadas y no como serie temporal.")


tabla_parques_cox
gtsave(tabla_parques_cox, "03_Output/Tables/tabla_terciles_parques.png", vwidth = 1800, vheight = 900)

# =============================================================
# CONTAMINACIÓN (promedio de 7 días) x ENTORNO URBANO EN TERCILES
# La contaminación entra continua (por 10 unidades) y el entorno en terciles.
# =============================================================

base_prueba <- base_prueba %>%
  mutate(
    pm25_10 = pm25_7d / 10,
    o3_10 = o3_krg_7d / 10,
    no2_10 = no2_7d / 10
  )


vars_entorno <- c("ndvi_tercil", "cobertura_tercil", "impermeable_tercil", "densidad_tercil",
                  "vias_tercil", "industrial_tercil", "lst_verano_tercil", "lst_anual_tercil")

nombres_entorno <- c("NDVI", "Cobertura arbórea", "Sup. impermeable", "Densidad",
                     "Vías", "Industrial", "LST verano", "LST anual")

# PM2.5 (7 días)
resultados_pm25 <- list()

for (i in seq_along(vars_entorno)) {
  formula_i <- as.formula(paste("Surv(weeks, birth_preterm) ~ pm25_10 *", vars_entorno[i], "+", covariables))
  modelo_i <- coxph(formula_i, data = base_prueba)
  resultados_pm25[[nombres_entorno[i]]] <- extraer_tercil_3b(modelo_i, "pm25_10", vars_entorno[i])
}

tabla_pm25 <- bind_rows(resultados_pm25, .id = "Variable") %>%
  gt(groupname_col = "Variable") %>%
  tab_header(
    title = "PM2.5 (promedio 7 días) × Entorno Urbano en Terciles",
    subtitle = "HR por cada 10 µg/m³; entorno e interacción comparados contra el tercil Bajo (n = 713.918)"
  ) %>%
  tab_spanner(label = "PM2.5 (por 10 µg/m³, tercil Bajo)", columns = c(hr_calor, ci_calor)) %>%
  tab_spanner(label = "Entorno urbano", columns = c(hr_entorno, ci_entorno)) %>%
  tab_spanner(label = "Interacción", columns = c(hr_inter, ci_inter)) %>%
  cols_label(
    Comparacion = "Comparación",
    hr_calor = "HR", ci_calor = "IC 95%",
    hr_entorno = "HR", ci_entorno = "IC 95%",
    hr_inter = "HR", ci_inter = "IC 95%"
  ) %>%
  sub_missing(columns = everything(), missing_text = "")


tabla_pm25
gtsave(tabla_pm25, "03_Output/Tables/tabla_pm25_terciles.png", vwidth = 1800, vheight = 2400)

# -------------------------------------------------------------
# OZONO Y NO2 (promedio 7 días) x ENTORNO URBANO EN TERCILES
# Misma estructura que PM2.5, con una función para cada contaminante.
# vars_entorno y nombres_entorno están definidos en el bloque de PM2.5.
# -------------------------------------------------------------
correr_contaminante <- function(var_exp, nombre, archivo) {
  resultados <- list()
  for (i in seq_along(vars_entorno)) {
    f <- as.formula(paste("Surv(weeks, birth_preterm) ~", var_exp, "*", vars_entorno[i], "+", covariables))
    m <- coxph(f, data = base_prueba)
    resultados[[nombres_entorno[i]]] <- extraer_tercil_3b(m, var_exp, vars_entorno[i])
  }
  tabla <- bind_rows(resultados, .id = "Variable") %>%
    gt(groupname_col = "Variable") %>%
    tab_header(
      title = paste0(nombre, " (promedio 7 días) × Entorno Urbano en Terciles"),
      subtitle = "HR por cada 10 unidades; entorno e interacción comparados contra el tercil Bajo (n = 713.918)"
    ) %>%
    tab_spanner(label = paste0(nombre, " (por 10 unidades, tercil Bajo)"), columns = c(hr_calor, ci_calor)) %>%
    tab_spanner(label = "Entorno urbano", columns = c(hr_entorno, ci_entorno)) %>%
    tab_spanner(label = "Interacción", columns = c(hr_inter, ci_inter)) %>%
    cols_label(Comparacion = "Comparación", hr_calor = "HR", ci_calor = "IC 95%",
               hr_entorno = "HR", ci_entorno = "IC 95%", hr_inter = "HR", ci_inter = "IC 95%") %>%
    sub_missing(columns = everything(), missing_text = "")
  gtsave(tabla, archivo, vwidth = 1800, vheight = 2400)
}

correr_contaminante("o3_10",  "Ozono", "03_Output/Tables/tabla_o3_terciles.png")
correr_contaminante("no2_10", "NO2",   "03_Output/Tables/tabla_no2_terciles.png")


















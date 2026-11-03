# =============================================================
# PRODUCTO 3 - GRÁFICOS DE CAMBIO (2009 vs 2020)
# =============================================================

library(ggplot2)
library(sf)
library(dplyr)
library(tidyr)
library(stringr)
library(ggspatial)
library(gt)
library(patchwork)

# =============================================================
# 0. DATOS BASE Y FUNCIONES AUXILIARES
# =============================================================

comunas_33 <- st_read("01_Input/Shapefiles/Comunas_santiago_33/comunas_santiago_33_WGS84.shp")
producto1 <- read.csv("01_Input/Producto1/producto1_entorno_urbano.csv")

# Estandariza nombres de comuna (el shapefile trae tildes, Producto 1 no)
quitar_tildes <- function(x) {
  chartr("áéíóúüñÁÉÍÓÚÜÑ", "aeiouunAEIOUUN", x)
}
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

producto1 <- producto1 %>%
  mutate(comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))) %>%
  left_join(nombres_correctos, by = "comuna_std") %>%
  mutate(COMUNA = nombre_correcto) %>%
  select(-comuna_std, -nombre_correcto)

sum(is.na(producto1$COMUNA))  # debe dar 0

dir.create("03_Output/Maps", showWarnings = FALSE)

# =============================================================
# 1. FUNCIONES GENÉRICAS
# =============================================================
# 1a. Mapa de diferencia. Por defecto divergente (azul-gris-rojo);
# con paleta = "magma" (u otra viridis) usa escala continua.
crear_mapa_diferencia <- function(datos_diff, columna, titulo, subtitulo,
                                  unidad_leyenda = "Δ °C", paleta = "divergente",
                                  limites = NULL,
                                  colores = c("#2166ac", "#f7f7f7", "#d73027"),
                                  color_borde = "grey30") {
  datos_sf <- comunas_33 %>%
    mutate(comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))) %>%
    left_join(datos_diff %>% select(comuna_std, all_of(columna)), by = "comuna_std")
  
  escala <- if (paleta == "divergente") {
    scale_fill_gradient2(name = unidad_leyenda, low = colores[1], mid = colores[2],
                         high = colores[3], midpoint = 0, limits = limites)
  } else {
    scale_fill_viridis_c(name = unidad_leyenda, option = paleta, direction = -1,
                         limits = limites)
  }
  
  ggplot(datos_sf) +
    geom_sf(aes(fill = .data[[columna]]), color = color_borde, size = 0.3) +
    escala +
    annotation_north_arrow(location = "tr", which_north = "true",
                           style = north_arrow_fancy_orienteering(),
                           height = unit(1.5, "cm"), width = unit(1.5, "cm")) +
    annotation_scale(location = "bl", width_hint = 0.25, text_cex = 0.8) +
    labs(title = titulo, subtitle = str_wrap(subtitulo, 85),
         caption = "CRS: WGS84 (EPSG:4326)") +
    theme_void() +
    theme(plot.title = element_text(face = "bold"),
          plot.subtitle = element_text(color = "grey40"))
}

# 1b. Barras por comuna. Por defecto rojo/azul según signo;
# con color_unico usa un solo color (para variables donde todo sube o no cambia).
crear_barras_diferencia <- function(datos_diff, columna, titulo,
                                    etiqueta_y = "Diferencia (°C)",
                                    color_unico = NULL, limites_y = NULL,
                                    subtitulo = NULL,
                                    colores_signo = c("TRUE" = "#d73027", "FALSE" = "#4575b4")) {
  if (!is.null(subtitulo)) subtitulo <- str_wrap(subtitulo, 80)
  
  p <- ggplot(datos_diff, aes(x = reorder(COMUNA, .data[[columna]]),
                              y = .data[[columna]]))
  if (is.null(color_unico)) {
    p <- p + geom_col(aes(fill = .data[[columna]] > 0)) +
      scale_fill_manual(values = colores_signo, guide = "none")
  } else {
    p <- p + geom_col(fill = color_unico)
  }
  p + coord_flip() +
    scale_y_continuous(limits = limites_y) +
    labs(title = titulo, subtitle = subtitulo, x = NULL, y = etiqueta_y) +
    theme_minimal(base_size = 10)
}

# 1c. Divide una tabla en dos mitades lado a lado (para que quepa en una imagen)
# Agrega "_1" y "_2" a los nombres de las columnas.
dividir_en_mitades <- function(datos) {
  n_mitad <- ceiling(nrow(datos) / 2)
  mitad_1 <- datos[1:n_mitad, ]
  mitad_2 <- datos[(n_mitad + 1):nrow(datos), ]
  if (nrow(mitad_2) < nrow(mitad_1)) mitad_2 <- add_row(mitad_2)
  names(mitad_1) <- paste0(names(mitad_1), "_1")
  names(mitad_2) <- paste0(names(mitad_2), "_2")
  bind_cols(mitad_1, mitad_2)
}

# 1d. Tabla de dos columnas de comunas con un valor numérico coloreado
crear_tabla_2col <- function(datos, col_valor, titulo, subtitulo, etiqueta_valor,
                             decimales, paleta, dominio, nota = NULL) {
  cols_valor <- paste0(col_valor, c("_1", "_2"))
  etiquetas <- setNames(list("Comuna", etiqueta_valor, "Comuna", etiqueta_valor),
                        c("COMUNA_1", cols_valor[1], "COMUNA_2", cols_valor[2]))
  
  tabla <- dividir_en_mitades(datos) %>%
    gt() %>%
    tab_header(title = titulo, subtitle = subtitulo) %>%
    cols_label(.list = etiquetas) %>%
    fmt_number(columns = all_of(cols_valor), decimals = decimales) %>%
    sub_missing(columns = everything(), missing_text = "") %>%
    data_color(columns = all_of(cols_valor),
               colors = scales::col_numeric(palette = paleta, domain = dominio))
  
  if (!is.null(nota)) tabla <- tab_source_note(tabla, nota)
  tabla
}

# 1e. Mapa de una variable (viridis), con límites de escala opcionales
crear_mapa_variable <- function(datos_sf, variable, titulo, subtitulo, unidad_leyenda,
                                paleta = "viridis", direccion = -1, limites = NULL,
                                color_borde = "grey30") {
  ggplot(datos_sf) +
    geom_sf(aes(fill = .data[[variable]]), color = color_borde, size = 0.3) +
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

# 1f. Une nombres en una frase: "A", "A y B", "A, B y C" (usa "e" antes de i-)
listar_nombres <- function(x) {
  n <- length(x)
  if (n == 1) return(x)
  conector <- if (grepl("^[IiYy]", x[n])) " e " else " y "
  paste0(paste(x[-n], collapse = ", "), conector, x[n])
}

# 1g. Guarda una tabla gt con tamaño ampliado (evita que se corte el PNG)
guardar_tabla <- function(tabla, ruta, ancho = 2000, alto = 1200) {
  gtsave(tabla, ruta, vwidth = ancho, vheight = alto)
}

# 1h. Tabla de cambio entre dos años, 33 comunas en dos columnas.
# datos debe traer: COMUNA, valor_ini, valor_fin, diff, pct (pct = NA si no se puede calcular)
crear_tabla_cambio_2col <- function(datos, titulo, subtitulo, nota,
                                    etiqueta_ini, etiqueta_fin, decimales,
                                    paleta, dominio, mostrar_pct = TRUE) {
  datos <- datos %>%
    select(COMUNA, valor_ini, valor_fin, diff, pct) %>%
    mutate(pct = ifelse(is.na(pct), "N/A", formatC(pct, format = "f", digits = 1)))
  if (!mostrar_pct) datos <- select(datos, -pct)
  
  etiquetas <- c("Comuna", etiqueta_ini, etiqueta_fin, "Dif.", if (mostrar_pct) "Cambio (%)")
  etiquetas_lista <- c(setNames(as.list(etiquetas), paste0(names(datos), "_1")),
                       setNames(as.list(etiquetas), paste0(names(datos), "_2")))
  
  cols_num <- paste0(rep(c("valor_ini", "valor_fin", "diff"), 2), rep(c("_1", "_2"), each = 3))
  
  dividir_en_mitades(datos) %>%
    gt() %>%
    tab_header(title = titulo, subtitle = subtitulo) %>%
    tab_source_note(nota) %>%
    cols_label(.list = etiquetas_lista) %>%
    fmt_number(columns = all_of(cols_num), decimals = decimales) %>%
    sub_missing(columns = everything(), missing_text = "") %>%
    data_color(columns = all_of(c("diff_1", "diff_2")),
               colors = scales::col_numeric(palette = paleta, domain = dominio))
}


# =============================================================
# 2. LST ANUAL: CAMBIO 2020 - 2009 (resultado secundario, patrón mixto)
# =============================================================

lst_diff <- producto1 %>%
  filter(year %in% c(2009, 2020)) %>%
  select(COMUNA, year, lst_anual) %>%
  pivot_wider(names_from = year, values_from = lst_anual, names_prefix = "lst_") %>%
  mutate(
    diff_lst = lst_2020 - lst_2009,
    comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))
  )

mean(lst_diff$diff_lst)
summary(lst_diff$diff_lst)

# Extremos calculados con los datos (leerlos antes de guardar el mapa)
comunas_bajan <- lst_diff %>% slice_min(diff_lst, n = 2) %>% pull(COMUNA)
comunas_suben <- lst_diff %>% slice_max(diff_lst, n = 2) %>% pull(COMUNA)
hay_comunas_que_bajan <- any(lst_diff$diff_lst < 0)

nota_lst <- if (hay_comunas_que_bajan) {
  paste0("Diferencia 2020 − 2009. A diferencia del verano, el patrón anual es mixto: ",
         "baja sobre todo en ", listar_nombres(comunas_bajan),
         " y sube sobre todo en ", listar_nombres(comunas_suben), ".")
} else {
  paste0("Diferencia 2020 − 2009. Todas las comunas suben; el mayor aumento ocurre en ",
         listar_nombres(comunas_suben), ".")
}
nota_lst

mapa_diff_lst <- crear_mapa_diferencia(
  datos_diff = lst_diff,
  columna = "diff_lst",
  titulo = "Cambio en Temperatura Superficial Anual (LST)",
  subtitulo = nota_lst
)

grafico_barras_lst <- crear_barras_diferencia(
  datos_diff = lst_diff,
  columna = "diff_lst",
  titulo = "Cambio en LST anual por comuna (2020 − 2009)"
)

mapa_diff_lst
grafico_barras_lst

ggsave("03_Output/Maps/mapa_diff_lst_anual_2009_2020.png",
       mapa_diff_lst, width = 8, height = 8, dpi = 300, bg = "white")
ggsave("03_Output/Maps/barras_diff_lst_anual_2009_2020.png",
       grafico_barras_lst, width = 8, height = 8, dpi = 300, bg = "white")

# =============================================================
# 3. LST VERANO: CAMBIO 2020 - 2009 (hallazgo principal)
# Todas las comunas suben; el promedio debería ser ~+2.9 °C.
# =============================================================

lst_verano_diff <- producto1 %>%
  filter(year %in% c(2009, 2020)) %>%
  select(COMUNA, year, lst_verano) %>%
  pivot_wider(names_from = year, values_from = lst_verano, names_prefix = "lst_verano_") %>%
  mutate(
    diff_lst_verano = lst_verano_2020 - lst_verano_2009,
    comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))
  )

mean(lst_verano_diff$diff_lst_verano)
summary(lst_verano_diff$diff_lst_verano)

# Notas calculadas con los datos (leerlas antes de guardar)
top3_verano <- lst_verano_diff %>% slice_max(diff_lst_verano, n = 3) %>% pull(COMUNA)
todas_suben <- all(lst_verano_diff$diff_lst_verano > 0)

nota_verano_mapa <- paste0(
  "Diferencia 2020 − 2009. ",
  if (todas_suben) "Aumento generalizado en las 33 comunas, liderado por "
  else "Mayor aumento en ",
  listar_nombres(top3_verano), "."
)
nota_verano_mapa

mapa_diff_lst_verano <- crear_mapa_diferencia(
  datos_diff = lst_verano_diff,
  columna = "diff_lst_verano",
  titulo = "Cambio en Temperatura Superficial de Verano (LST)",
  subtitulo = nota_verano_mapa
)

grafico_barras_lst_verano <- crear_barras_diferencia(
  datos_diff = lst_verano_diff,
  columna = "diff_lst_verano",
  titulo = "Cambio en LST de verano por comuna (2020 − 2009)",
  subtitulo = paste0(listar_nombres(top3_verano), " registran el mayor aumento",
                     if (todas_suben) "; todas las comunas muestran incremento." else "."),
  color_unico = "#d73027"
)

mapa_diff_lst_verano
grafico_barras_lst_verano

ggsave("03_Output/Maps/mapa_diff_lst_verano_2009_2020.png",
       mapa_diff_lst_verano, width = 8, height = 8, dpi = 300, bg = "white")
ggsave("03_Output/Maps/barras_diff_lst_verano_2009_2020.png",
       grafico_barras_lst_verano, width = 8, height = 8, dpi = 300, bg = "white")

# =============================================================
# 4. SUPERFICIE IMPERMEABLE: CAMBIO 2020 - 2009 (solo datos, aún sin gráfico)
# GHSL: el "2009" usa el dato de 2010. Unidad: m²/km², no °C.
# =============================================================

impermeable_diff <- producto1 %>%
  filter(year %in% c(2009, 2020)) %>%
  select(COMUNA, year, sup_impermeable) %>%
  pivot_wider(names_from = year, values_from = sup_impermeable, names_prefix = "imperv_") %>%
  mutate(
    diff_impermeable = imperv_2020 - imperv_2009,
    comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))
  )

# =============================================================
# 5. SUPERFICIE IMPERMEABLE: MAPA Y BARRAS DE CAMBIO 2020 - 2009
# (impermeable_diff ya se calculó en la sección 4)
# GHSL: el "2009" usa el dato de 2010. Unidad: m²/km².
# =============================================================

summary(impermeable_diff$diff_impermeable)

# Nota del gráfico, calculada con los datos (3 comunas con mayor aumento y la de menor cambio)
top_imp <- impermeable_diff %>% slice_max(diff_impermeable, n = 3) %>% pull(COMUNA)
min_imp <- impermeable_diff %>% slice_min(diff_impermeable, n = 1) %>% pull(COMUNA)

nota_imp <- paste0(
  listar_nombres(top_imp), " lideran el aumento. ",
  min_imp, " muestra el menor cambio",
  if (min_imp == "Lo Barnechea") ", por su extensa superficie no urbanizable" else "",
  "."
)
nota_imp  # leerla antes de guardar el gráfico
mapa_diff_impermeable <- crear_mapa_diferencia(
  datos_diff = impermeable_diff,
  columna = "diff_impermeable",
  titulo = "Cambio en Superficie Impermeable",
  subtitulo = paste0("Diferencia 2020 − 2009. ", nota_imp),
  unidad_leyenda = "Δ m²/km²",
  paleta = "magma"
)

grafico_barras_impermeable <- crear_barras_diferencia(
  datos_diff = impermeable_diff,
  columna = "diff_impermeable",
  titulo = "Cambio en superficie impermeable por comuna (2020 − 2009)",
  subtitulo = nota_imp,
  etiqueta_y = "Diferencia (m²/km²)",
  color_unico = "#7b3294"
)

mapa_diff_impermeable
grafico_barras_impermeable

ggsave("03_Output/Maps/mapa_diff_impermeable_2009_2020.png",
       mapa_diff_impermeable, width = 8, height = 8, dpi = 300, bg = "white")
ggsave("03_Output/Maps/barras_diff_impermeable_2009_2020.png",
       grafico_barras_impermeable, width = 8, height = 8, dpi = 300, bg = "white")

# =============================================================
# 6. NDVI: CAMBIO 2020 - 2009 (confirma estabilidad)
# Escala fija y angosta (±0.05) para no exagerar visualmente un cambio que es ruido.
# =============================================================

ndvi_diff <- producto1 %>%
  filter(year %in% c(2009, 2020)) %>%
  select(COMUNA, year, ndvi_anual, ndvi_verano) %>%
  pivot_wider(names_from = year, values_from = c(ndvi_anual, ndvi_verano)) %>%
  mutate(
    diff_ndvi_anual = ndvi_anual_2020 - ndvi_anual_2009,
    diff_ndvi_verano = ndvi_verano_2020 - ndvi_verano_2009,
    comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))
  )

summary(ndvi_diff$diff_ndvi_anual)
summary(ndvi_diff$diff_ndvi_verano)

mapa_diff_ndvi <- crear_mapa_diferencia(
  datos_diff = ndvi_diff,
  columna = "diff_ndvi_anual",
  titulo = "Cambio en NDVI",
  subtitulo = "Diferencia 2020 − 2009 (rango prácticamente nulo)",
  unidad_leyenda = "Δ NDVI",
  limites = c(-0.05, 0.05)
)

grafico_barras_ndvi <- crear_barras_diferencia(
  datos_diff = ndvi_diff,
  columna = "diff_ndvi_anual",
  titulo = "Cambio en NDVI por comuna (2020 − 2009)",
  subtitulo = "Confirma estabilidad: sin cambios relevantes en el período",
  etiqueta_y = "Diferencia NDVI",
  color_unico = "grey50",
  limites_y = c(-0.05, 0.05)
)

mapa_diff_ndvi
grafico_barras_ndvi

ggsave("03_Output/Maps/mapa_diff_ndvi_2009_2020.png",
       mapa_diff_ndvi, width = 8, height = 8, dpi = 300, bg = "white")
ggsave("03_Output/Maps/barras_diff_ndvi_2009_2020.png",
       grafico_barras_ndvi, width = 8, height = 8, dpi = 300, bg = "white")

# Tabla resumen NDVI
cambio_max_ndvi <- max(abs(ndvi_diff$diff_ndvi_anual), na.rm = TRUE)

tabla_ndvi <- tibble(
  Estadístico = c("Mínimo", "Máximo", "Media", "Desviación estándar"),
  Valor = c(min(ndvi_diff$diff_ndvi_anual, na.rm = TRUE),
            max(ndvi_diff$diff_ndvi_anual, na.rm = TRUE),
            mean(ndvi_diff$diff_ndvi_anual, na.rm = TRUE),
            sd(ndvi_diff$diff_ndvi_anual, na.rm = TRUE))
) %>%
  gt() %>%
  tab_header(
    title = "Cambio en NDVI (2009-2020)",
    subtitle = "Resumen estadístico de las 33 comunas"
  ) %>%
  tab_source_note(paste0("El índice de vegetación se mantuvo estable en el período: el mayor cambio en una comuna fue de ",
                         round(cambio_max_ndvi, 3), " puntos de NDVI.")) %>%
  fmt_number(columns = Valor, decimals = 4)

tabla_ndvi

guardar_tabla(tabla_ndvi, "03_Output/Maps/tabla_ndvi_resumen.png")

# =============================================================
# 7. COBERTURA ARBÓREA: CAMBIO 2020 - 2009 (tabla con las 33 comunas)
# =============================================================

cobertura_diff <- producto1 %>%
  filter(year %in% c(2009, 2020)) %>%
  select(COMUNA, year, cobertura_arborea) %>%
  pivot_wider(names_from = year, values_from = cobertura_arborea, names_prefix = "cobertura_") %>%
  mutate(
    diff_cobertura = cobertura_2020 - cobertura_2009,
    diff_pct = if_else(cobertura_2009 > 0, 100 * diff_cobertura / cobertura_2009, NA_real_),
    diff_pct_texto = if_else(is.na(diff_pct), "N/A", formatC(diff_pct, format = "f", digits = 1)),
    comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))
  )

# Nota calculada con los datos
n_sin_cambio <- sum(cobertura_diff$diff_cobertura == 0)
comuna_mayor_perdida <- cobertura_diff$COMUNA[which.min(cobertura_diff$diff_cobertura)]

nota_cobertura <- paste0(
  if (min(cobertura_diff$diff_cobertura) < 0) {
    paste0(comuna_mayor_perdida, " presenta la mayor pérdida de cobertura arbórea del período; ")
  } else {
    "Ninguna comuna pierde cobertura; "
  },
  n_sin_cambio, " de 33 comunas no registran cambio."
)
nota_cobertura  # leerla antes de guardar

datos_cobertura <- cobertura_diff %>%
  arrange(desc(diff_cobertura)) %>%
  select(COMUNA, cobertura_2009, cobertura_2020, diff_cobertura, diff_pct_texto)

dominio_cobertura <- c(min(cobertura_diff$diff_cobertura, -0.01), 0)

tabla_cobertura_2col <- dividir_en_mitades(datos_cobertura) %>%
  gt() %>%
  tab_header(
    title = "Cambio en Cobertura Arbórea (2009-2020)",
    subtitle = "Las 33 comunas de estudio"
  ) %>%
  tab_source_note(nota_cobertura) %>%
  cols_label(
    COMUNA_1 = "Comuna", cobertura_2009_1 = "2009 (%)", cobertura_2020_1 = "2020 (%)",
    diff_cobertura_1 = "Dif. (pp)", diff_pct_texto_1 = "Cambio (%)",
    COMUNA_2 = "Comuna", cobertura_2009_2 = "2009 (%)", cobertura_2020_2 = "2020 (%)",
    diff_cobertura_2 = "Dif. (pp)", diff_pct_texto_2 = "Cambio (%)"
  ) %>%
  fmt_number(columns = c(cobertura_2009_1, cobertura_2020_1, diff_cobertura_1,
                         cobertura_2009_2, cobertura_2020_2, diff_cobertura_2),
             decimals = 2) %>%
  sub_missing(columns = everything(), missing_text = "") %>%
  data_color(columns = c(diff_cobertura_1, diff_cobertura_2),
             colors = scales::col_numeric(palette = c("#f4a582", "#f7f7f7"),
                                          domain = dominio_cobertura))

tabla_cobertura_2col

guardar_tabla(tabla_cobertura_2col, "03_Output/Maps/tabla_cobertura_arborea.png")


# =============================================================
# 8. PARQUES: CAMBIO 2019 - 2009 (% de superficie comunal)
# =============================================================

parques_diff <- producto1 %>%
  filter(year %in% c(2009, 2019)) %>%
  select(COMUNA, year, pct_parques) %>%
  pivot_wider(names_from = year, values_from = pct_parques, names_prefix = "parques_") %>%
  mutate(
    diff_parques = parques_2019 - parques_2009,
    comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))
  )

summary(parques_diff$diff_parques)

# Comuna con la mayor caída (calculada, no escrita a mano)
comuna_mayor_caida <- parques_diff$COMUNA[which.min(parques_diff$diff_parques)]
comuna_mayor_caida

mapa_diff_parques <- crear_mapa_diferencia(
  datos_diff = parques_diff,
  columna = "diff_parques",
  titulo = "Cambio en Porcentaje de Parques",
  subtitulo = "Diferencia 2019 − 2009",
  unidad_leyenda = "Δ % parques",
  colores = c("#2166ac", "#f7f7f7", "#1a9850"),
  color_borde = "grey30"
)

grafico_barras_parques <- crear_barras_diferencia(
  datos_diff = parques_diff,
  columna = "diff_parques",
  titulo = "Cambio en % de parques por comuna (2019 − 2009)",
  subtitulo = paste0(comuna_mayor_caida, " presenta la mayor caída"),
  etiqueta_y = "Diferencia (%)",
  colores_signo = c("TRUE" = "darkgreen", "FALSE" = "blue")
)

mapa_diff_parques
grafico_barras_parques

ggsave("03_Output/Maps/mapa_diff_parques_2009_2019.png",
       mapa_diff_parques, width = 8, height = 8, dpi = 300, bg = "white")
ggsave("03_Output/Maps/barras_diff_parques_2009_2019.png",
       grafico_barras_parques, width = 8, height = 8, dpi = 300, bg = "white")

# =============================================================
# 9. POBLACIÓN Y DENSIDAD (2020): WorldPop vs INE.
# =============================================================

comparacion_poblacion <- readr::read_csv("01_Input/INE_población/comparacion_poblacion_ine_worldpop.csv")

datos_2020 <- comparacion_poblacion %>%
  filter(year == 2020) %>%
  mutate(comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))) %>%
  left_join(nombres_correctos, by = "comuna_std")

mapa_datos <- comunas_33 %>%
  mutate(comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))) %>%
  left_join(datos_2020 %>% select(comuna_std, poblacion_worldpop, poblacion_ine,
                                  densidad_worldpop, densidad_ine),
            by = "comuna_std")

# 9a. Comparación 2x2 con escala compartida entre fuentes
lim_poblacion <- range(c(mapa_datos$poblacion_worldpop, mapa_datos$poblacion_ine), na.rm = TRUE)
lim_densidad <- range(c(mapa_datos$densidad_worldpop, mapa_datos$densidad_ine), na.rm = TRUE)

mapa_pob_wp <- crear_mapa_variable(mapa_datos, "poblacion_worldpop",
                                   "Población total (2020)", "WorldPop", "Habitantes",
                                   limites = lim_poblacion)
mapa_pob_ine <- crear_mapa_variable(mapa_datos, "poblacion_ine",
                                    "Población total (2020)", "INE", "Habitantes",
                                    limites = lim_poblacion)
mapa_dens_wp <- crear_mapa_variable(mapa_datos, "densidad_worldpop",
                                    "Densidad poblacional (2020)", "WorldPop", "Hab/km²",
                                    limites = lim_densidad)
mapa_dens_ine <- crear_mapa_variable(mapa_datos, "densidad_ine",
                                     "Densidad poblacional (2020)", "INE", "Hab/km²",
                                     limites = lim_densidad)

mapa_comparativo <- (mapa_pob_wp | mapa_pob_ine) / (mapa_dens_wp | mapa_dens_ine)

mapa_comparativo

ggsave("03_Output/Maps/mapa_comparacion_poblacion_densidad_ine_worldpop_2020.png",
       mapa_comparativo, width = 12, height = 12, dpi = 300, bg = "white")

# 9b. Solo INE, cada mapa con su propia escala, y nota calculada con los datos
unir_nombres <- function(a, b) paste(a, if (grepl("^[Ii]", b)) "e" else "y", b)

top_pob <- datos_2020 %>% slice_max(poblacion_ine, n = 2)
top_dens <- datos_2020 %>% slice_max(densidad_ine, n = 2)
min_dens <- datos_2020 %>% slice_min(densidad_ine, n = 1)

nota_ine <- paste0(
  unir_nombres(
    paste0(top_pob$nombre_correcto[1], " (", round(top_pob$poblacion_ine[1] / 1000), " mil hab.)"),
    paste0(top_pob$nombre_correcto[2], " (", round(top_pob$poblacion_ine[2] / 1000), " mil hab.)")
  ),
  " concentran la mayor población total. ",
  unir_nombres(top_dens$nombre_correcto[1], top_dens$nombre_correcto[2]),
  " presentan la mayor densidad poblacional, mientras que ",
  min_dens$nombre_correcto, " muestra la menor",
  if (min_dens$nombre_correcto == "Lo Barnechea") ", asociado a su extensa superficie de baja ocupación urbana" else "",
  "."
)

nota_ine

mapa_pob_ine_solo <- crear_mapa_variable(
  mapa_datos, "poblacion_ine", "Población Total, 2020",
  "Fuente: INE, Estimaciones y Proyecciones de Población", "Habitantes")

mapa_dens_ine_solo <- crear_mapa_variable(
  mapa_datos, "densidad_ine", "Densidad Poblacional, 2020",
  "Fuente: INE, Estimaciones y Proyecciones de Población", "Hab/km²")

mapa_poblacion_densidad <- (mapa_pob_ine_solo | mapa_dens_ine_solo) +
  plot_annotation(
    caption = str_wrap(nota_ine, 150),
    theme = theme(plot.caption = element_text(hjust = 0, size = 9, color = "grey30"))
  )

mapa_poblacion_densidad

ggsave("03_Output/Maps/mapa_poblacion_densidad_ine_2020.png",
       mapa_poblacion_densidad, width = 12, height = 7, dpi = 300, bg = "white")

# =============================================================
# 10. TABLAS (2017): BHT, DIMENSIONES BHT, SOVI Y MIGRACIÓN
# Paleta pastel (rojo claro - amarillo - verde claro) y nota al pie en cada tabla.
# =============================================================

paleta_pastel <- c("#f4a582", "#fee08b", "#a1d76a")

# 10a. BHT
datos_bht <- producto1 %>%
  filter(year == 2017) %>%
  select(COMUNA, bht) %>%
  arrange(desc(bht))

tabla_bht_2col <- crear_tabla_2col(
  datos = datos_bht,
  col_valor = "bht",
  titulo = "Bienestar Humano Territorial (BHT), 2017",
  subtitulo = "Fuente: Centro de Inteligencia Territorial, Universidad Adolfo Ibáñez (CIT-UAI)",
  etiqueta_valor = "Índice BHT",
  decimales = 3,
  paleta = paleta_pastel,
  dominio = range(datos_bht$bht, na.rm = TRUE),
  nota = "Se observan los valores más altos en comunas del sector nororiente, y los más bajos en comunas periféricas como Cerro Navia, La Pintana y San Ramón."
)

tabla_bht_2col

guardar_tabla(tabla_bht_2col, "03_Output/Maps/tabla_bht_2017.png")

# 10b. Dimensiones del BHT (cada dimensión con su propio rango de color)
datos_dim_bht <- producto1 %>%
  filter(year == 2017) %>%
  select(COMUNA, dim_accesibilidad, dim_ambiental, dim_seguridad, dim_socioeconomica) %>%
  arrange(COMUNA)

tabla_dimensiones_bht <- datos_dim_bht %>%
  gt() %>%
  tab_header(
    title = "Dimensiones del Bienestar Humano Territorial, 2017",
    subtitle = "Fuente: Centro de Inteligencia Territorial, Universidad Adolfo Ibáñez (CIT-UAI)"
  ) %>%
  tab_source_note("Cada dimensión presenta un patrón distinto: Santiago muestra alta accesibilidad pero baja seguridad, mientras que Quilicura, Renca y La Pintana concentran los valores más bajos en accesibilidad, ambiental y socioeconómica respectivamente.") %>%
  cols_label(
    COMUNA = "Comuna",
    dim_accesibilidad = "Accesibilidad",
    dim_ambiental = "Ambiental",
    dim_seguridad = "Seguridad",
    dim_socioeconomica = "Socioeconómica"
  ) %>%
  fmt_number(columns = starts_with("dim_"), decimals = 3)

for (col in c("dim_accesibilidad", "dim_ambiental", "dim_seguridad", "dim_socioeconomica")) {
  tabla_dimensiones_bht <- tabla_dimensiones_bht %>%
    data_color(columns = all_of(col),
               colors = scales::col_numeric(palette = paleta_pastel,
                                            domain = range(datos_dim_bht[[col]], na.rm = TRUE)))
}

tabla_dimensiones_bht

guardar_tabla(tabla_dimensiones_bht, "03_Output/Maps/tabla_dimensiones_bht_2017.png")

# 10c. SOVI (índice + categoría). Colores pastel fijados por nombre de categoría.
colores_sovi <- c("Baja" = "#a1d76a", "Medio-baja" = "#c2e699",
                  "Medio-alta" = "#fee08b", "Alta" = "#f4a582")

datos_sovi <- producto1 %>%
  filter(year == 2017) %>%
  select(COMUNA, indice_vulnerabilidad, categoria_vulnerabilidad) %>%
  arrange(indice_vulnerabilidad)

tabla_sovi_2col <- dividir_en_mitades(datos_sovi) %>%
  gt() %>%
  tab_header(
    title = "Índice de Vulnerabilidad Social (SOVI), 2017",
    subtitle = "Fuente: José Daniel Conejeros — validado contra base de nacimientos"
  ) %>%
  tab_source_note("San Miguel y Santiago quedan clasificados en categoría 'Baja' vulnerabilidad, junto a comunas como Las Condes y Providencia, pese a presentar índices menos favorables dentro de esa misma categoría.") %>%
  cols_label(
    COMUNA_1 = "Comuna", indice_vulnerabilidad_1 = "Índice", categoria_vulnerabilidad_1 = "Categoría",
    COMUNA_2 = "Comuna", indice_vulnerabilidad_2 = "Índice", categoria_vulnerabilidad_2 = "Categoría"
  ) %>%
  fmt_number(columns = c(indice_vulnerabilidad_1, indice_vulnerabilidad_2), decimals = 3) %>%
  sub_missing(columns = everything(), missing_text = "")

# Color por nombre de categoría (no depende del orden alfabético)
for (categoria in names(colores_sovi)) {
  tabla_sovi_2col <- tabla_sovi_2col %>%
    tab_style(
      style = cell_fill(color = colores_sovi[[categoria]]),
      locations = cells_body(columns = categoria_vulnerabilidad_1,
                             rows = categoria_vulnerabilidad_1 %in% categoria)
    ) %>%
    tab_style(
      style = cell_fill(color = colores_sovi[[categoria]]),
      locations = cells_body(columns = categoria_vulnerabilidad_2,
                             rows = categoria_vulnerabilidad_2 %in% categoria)
    )
}

tabla_sovi_2col

guardar_tabla(tabla_sovi_2col, "03_Output/Maps/tabla_sovi_2017.png")

# 10d. Migración
datos_migracion <- producto1 %>%
  filter(year == 2017) %>%
  select(COMUNA, pct_inmigrantes) %>%
  arrange(desc(pct_inmigrantes))

tabla_migracion_2col <- crear_tabla_2col(
  datos = datos_migracion,
  col_valor = "pct_inmigrantes",
  titulo = "Población Inmigrante Internacional, 2017",
  subtitulo = "Fuente: INE Censo 2017, vía Esri Living Atlas",
  etiqueta_valor = "% Inmigrantes",
  decimales = 1,
  paleta = c("#f7f7f7", "#6baed6"),
  dominio = range(datos_migracion$pct_inmigrantes, na.rm = TRUE),
  nota = "Independencia y Santiago concentran los porcentajes más altos de población inmigrante internacional."
)

tabla_migracion_2col

guardar_tabla(tabla_migracion_2col, "03_Output/Maps/tabla_migracion_2017.png")

# =============================================================
# 11. TABLA: ACCESO A SALUD PÚBLICA (2019), en dos columnas de comunas
# Distancia: verde = cerca, rojo = lejos. N° de establecimientos: verde = más.
# =============================================================

datos_salud <- producto1 %>%
  filter(year == 2019) %>%
  select(COMUNA, dist_salud_km, n_establecimientos_salud) %>%
  arrange(desc(n_establecimientos_salud))

dominio_dist <- range(datos_salud$dist_salud_km, na.rm = TRUE)
dominio_n <- range(datos_salud$n_establecimientos_salud, na.rm = TRUE)

tabla_salud_2col <- dividir_en_mitades(datos_salud) %>%
  gt() %>%
  tab_header(
    title = "Acceso a Salud Pública, 2019",
    subtitle = "Fuente: DEIS/MINSAL — establecimientos nivel 1° y 2°"
  ) %>%
  tab_source_note("Las comunas periféricas concentran más establecimientos de salud pública, mientras que comunas de mayores ingresos como Vitacura y Las Condes presentan menos, asociado al uso de salud privada.") %>%
  cols_label(
    COMUNA_1 = "Comuna", dist_salud_km_1 = "Distancia (km)", n_establecimientos_salud_1 = "N° Establec.",
    COMUNA_2 = "Comuna", dist_salud_km_2 = "Distancia (km)", n_establecimientos_salud_2 = "N° Establec."
  ) %>%
  fmt_number(columns = c(dist_salud_km_1, dist_salud_km_2), decimals = 2) %>%
  sub_missing(columns = everything(), missing_text = "") %>%
  data_color(columns = c(dist_salud_km_1, dist_salud_km_2),
             colors = scales::col_numeric(palette = rev(paleta_pastel), domain = dominio_dist)) %>%
  data_color(columns = c(n_establecimientos_salud_1, n_establecimientos_salud_2),
             colors = scales::col_numeric(palette = paleta_pastel, domain = dominio_n))

tabla_salud_2col

guardar_tabla(tabla_salud_2col, "03_Output/Maps/tabla_salud_2019.png")


# =============================================================
# 12. TABLAS (variables estáticas): VÍAS E INDUSTRIA, en dos columnas de comunas
# =============================================================

# 12a. Densidad de vías principales
datos_vias <- producto1 %>%
  filter(year == 2020) %>%
  select(COMUNA, vias_km_por_km2) %>%
  arrange(desc(vias_km_por_km2))

top_vias <- head(datos_vias$COMUNA, 2)

tabla_vias_2col <- crear_tabla_2col(
  datos = datos_vias,
  col_valor = "vias_km_por_km2",
  titulo = "Densidad de Vías Principales",
  subtitulo = "Fuente: OSM/Geofabrik — motorway, trunk, primary, secondary",
  etiqueta_valor = "Km vía / km²",
  decimales = 2,
  paleta = rev(paleta_pastel),
  dominio = range(datos_vias$vias_km_por_km2, na.rm = TRUE),
  nota = paste0(listar_nombres(top_vias),
                " presentan la mayor densidad de vías principales de las 33 comunas.")
)

tabla_vias_2col

guardar_tabla(tabla_vias_2col, "03_Output/Maps/tabla_vias.png")

# 12b. Superficie industrial
datos_industrial <- producto1 %>%
  filter(year == 2020) %>%
  select(COMUNA, area_industrial_ha) %>%
  arrange(desc(area_industrial_ha))

top_industrial <- head(datos_industrial$COMUNA, 3)

tabla_industrial_2col <- crear_tabla_2col(
  datos = datos_industrial,
  col_valor = "area_industrial_ha",
  titulo = "Superficie Industrial",
  subtitulo = "Fuente: Planes Reguladores Comunales (PRC), IDE MINVU",
  etiqueta_valor = "Área (ha)",
  decimales = 1,
  paleta = rev(paleta_pastel),
  dominio = range(datos_industrial$area_industrial_ha, na.rm = TRUE),
  nota = paste0(listar_nombres(top_industrial),
                " concentran la mayor superficie industrial de las 33 comunas.")
)

tabla_industrial_2col

guardar_tabla(tabla_industrial_2col, "03_Output/Maps/tabla_industrial.png")

# =============================================================
# 13. TABLAS DE CAMBIO 2009-2020 (33 comunas): SUPERFICIE IMPERMEABLE, NDVI Y LST VERANO
# =============================================================

paleta_cambio <- c("#a1d76a", "#f7f7f7", "#f4a582")

# 13a. Superficie impermeable (nota_imp viene de la sección 5)
datos_imp_tabla <- impermeable_diff %>%
  transmute(COMUNA, valor_ini = imperv_2009, valor_fin = imperv_2020,
            diff = diff_impermeable,
            pct = if_else(imperv_2009 > 0, 100 * diff_impermeable / imperv_2009, NA_real_)) %>%
  arrange(desc(diff))

tabla_impermeable_2col <- crear_tabla_cambio_2col(
  datos = datos_imp_tabla,
  titulo = "Cambio en Superficie Impermeable (2009-2020)",
  subtitulo = "Las 33 comunas de estudio · GHSL: el dato de 2009 corresponde a 2010",
  nota = nota_imp,
  etiqueta_ini = "2009 (m²/km²)", etiqueta_fin = "2020 (m²/km²)",
  decimales = 1,
  paleta = paleta_cambio,
  dominio = range(datos_imp_tabla$diff, na.rm = TRUE)
)

tabla_impermeable_2col

guardar_tabla(tabla_impermeable_2col, "03_Output/Maps/tabla_impermeable.png")

# 13b. NDVI anual
cambio_max_ndvi <- max(abs(ndvi_diff$diff_ndvi_anual), na.rm = TRUE)

datos_ndvi_tabla <- ndvi_diff %>%
  transmute(COMUNA, valor_ini = ndvi_anual_2009, valor_fin = ndvi_anual_2020,
            diff = diff_ndvi_anual,
            pct = if_else(ndvi_anual_2009 > 0, 100 * diff_ndvi_anual / ndvi_anual_2009, NA_real_)) %>%
  arrange(diff)

tabla_ndvi_2col <- crear_tabla_cambio_2col(
  datos = datos_ndvi_tabla,
  titulo = "Cambio en NDVI (2009-2020)",
  subtitulo = "Las 33 comunas de estudio",
  nota = paste0("El índice se mantuvo estable en el período: el mayor cambio en una comuna fue de ",
                round(cambio_max_ndvi, 3), " puntos de NDVI."),
  etiqueta_ini = "2009", etiqueta_fin = "2020",
  decimales = 3,
  paleta = paleta_cambio,
  dominio = range(datos_ndvi_tabla$diff, na.rm = TRUE)
)

tabla_ndvi_2col

guardar_tabla(tabla_ndvi_2col, "03_Output/Maps/tabla_ndvi_completa.png")

# 13c. LST de verano (sin columna de % : el cero de °C es arbitrario)
top3_verano <- lst_verano_diff %>% slice_max(diff_lst_verano, n = 3) %>% pull(COMUNA)
todas_suben <- all(lst_verano_diff$diff_lst_verano > 0)

datos_lst_tabla <- lst_verano_diff %>%
  transmute(COMUNA, valor_ini = lst_verano_2009, valor_fin = lst_verano_2020,
            diff = diff_lst_verano, pct = NA_real_) %>%
  arrange(desc(diff))

tabla_lst_verano_2col <- crear_tabla_cambio_2col(
  datos = datos_lst_tabla,
  titulo = "Cambio en LST de Verano (2009-2020)",
  subtitulo = "Las 33 comunas de estudio",
  nota = paste0(if (todas_suben) "Todas las comunas muestran aumento. " else "",
                listar_nombres(top3_verano), " lideran el cambio."),
  etiqueta_ini = "2009 (°C)", etiqueta_fin = "2020 (°C)",
  decimales = 2,
  paleta = c("#fee08b", "#f4a582"),
  dominio = range(datos_lst_tabla$diff, na.rm = TRUE),
  mostrar_pct = FALSE
)

tabla_lst_verano_2col

guardar_tabla(tabla_lst_verano_2col, "03_Output/Maps/tabla_lst_verano.png")





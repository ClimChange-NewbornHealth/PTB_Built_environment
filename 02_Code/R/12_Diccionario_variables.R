# =============================================================
# DICCIONARIO DE VARIABLES - Producto 1 y Producto 2
# FONDECYT 11240322
# =============================================================

library(tibble)

diccionario <- tribble(
  ~variable, ~descripcion, ~fuente, ~cobertura_temporal, ~unidad, ~notas,
  # Identificadores
  "COMUNA", "Nombre de la comuna (sin tildes)", "Elaboración propia", "N/A", "Texto", "",
  "cod_com", "Código oficial de comuna (CUT)", "INE", "N/A", "Código", "",
  "year", "Año calendario", "N/A", "2009-2020", "Año", ""
)

diccionario <- diccionario %>%
  add_row(
    variable = "indice_vulnerabilidad",
    descripcion = "Índice de Vulnerabilidad Social (SOVI), valor continuo por comuna",
    fuente = "Elaborado por equipo de investigación (José Daniel Conejeros), archivo sovi_datasets.RData",
    cobertura_temporal = "2017 (único año, dato censal)",
    unidad = "Índice continuo (valores negativos = menos vulnerable, según convención del equipo)",
    notas = "Validado en Producto 2: coincide exactamente con la variable 'sovi' que trae la base de nacimientos (misma fuente). Metodología de construcción del índice no documentada en este proyecto -- consultar con José Daniel Conejeros si se requiere detalle."
  ) %>%
  add_row(
    variable = "categoria_vulnerabilidad",
    descripcion = "Categoría de vulnerabilidad social (versión categórica del SOVI)",
    fuente = "Elaborado por equipo de investigación (José Daniel Conejeros), archivo sovi_datasets.RData",
    cobertura_temporal = "2017 (único año, dato censal)",
    unidad = "Categórica: Baja / Medio-baja / Medio-alta / Alta",
    notas = "Equivale a la variable 'vulnerability' (en inglés: Low/Medium-low/Medium-high) que trae la base de nacimientos -- mismo dato, distinto idioma. Validado en control de calidad de Producto 2."
  ) %>%
  add_row(
    variable = "bht",
    descripcion = "Índice de Bienestar Territorial (IBT), promedio ponderado por población desde nivel manzana a nivel comunal",
    fuente = "Matriz de Bienestar Humano Territorial (MBHT), Centro de Inteligencia Territorial, Universidad Adolfo Ibáñez (CIT-UAI); provisto por equipo de investigación (José Daniel Conejeros)",
    cobertura_temporal = "2017 (único año, dato censal)",
    unidad = "Índice (0-1; valores altos = menos vulnerable)",
    notas = "Promedio ponderado por número de personas por manzana censal, no promedio simple"
  ) %>%
  add_row(
    variable = "dim_socioeconomica",
    descripcion = "Dimensión socioeconómica del Índice de Bienestar Territorial",
    fuente = "Matriz de Bienestar Humano Territorial (MBHT), Centro de Inteligencia Territorial, Universidad Adolfo Ibáñez (CIT-UAI); provisto por equipo de investigación (José Daniel Conejeros)",
    cobertura_temporal = "2017 (único año, dato censal)",
    unidad = "Índice (0-1)",
    notas = "Promedio ponderado por población desde nivel manzana censal. Metodología de construcción del índice no documentada en este proyecto -- consultar con José Daniel Conejeros o CIT-UAI si se requiere detalle."
  ) %>%
  add_row(
    variable = "dim_accesibilidad",
    descripcion = "Dimensión de accesibilidad del Índice de Bienestar Territorial",
    fuente = "Matriz de Bienestar Humano Territorial (MBHT), Centro de Inteligencia Territorial, Universidad Adolfo Ibáñez (CIT-UAI); provisto por equipo de investigación (José Daniel Conejeros)",
    cobertura_temporal = "2017 (único año, dato censal)",
    unidad = "Índice (0-1)",
    notas = "Promedio ponderado por población desde nivel manzana censal. Metodología de construcción del índice no documentada en este proyecto -- consultar con José Daniel Conejeros o CIT-UAI si se requiere detalle."
  ) %>%
  add_row(
    variable = "dim_ambiental",
    descripcion = "Dimensión ambiental del Índice de Bienestar Territorial",
    fuente = "Matriz de Bienestar Humano Territorial (MBHT), Centro de Inteligencia Territorial, Universidad Adolfo Ibáñez (CIT-UAI); provisto por equipo de investigación (José Daniel Conejeros)",
    cobertura_temporal = "2017 (único año, dato censal)",
    unidad = "Índice (0-1)",
    notas = "Promedio ponderado por población desde nivel manzana censal. Metodología de construcción del índice no documentada en este proyecto -- consultar con José Daniel Conejeros o CIT-UAI si se requiere detalle."
  ) %>%
  add_row(
    variable = "dim_seguridad",
    descripcion = "Dimensión de seguridad del Índice de Bienestar Territorial",
    fuente = "Matriz de Bienestar Humano Territorial (MBHT), Centro de Inteligencia Territorial, Universidad Adolfo Ibáñez (CIT-UAI); provisto por equipo de investigación (José Daniel Conejeros)",
    cobertura_temporal = "2017 (único año, dato censal)",
    unidad = "Índice (0-1)",
    notas = "Promedio ponderado por población desde nivel manzana censal. Metodología de construcción del índice no documentada en este proyecto -- consultar con José Daniel Conejeros o CIT-UAI si se requiere detalle."
  )

diccionario

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "area_parques_ha",
    descripcion = "Superficie total de parques urbanos/áreas verdes por comuna",
    fuente = "2009: Gobierno Regional Metropolitano (Política Regional de Áreas Verdes). 2013: Plan Regulador Metropolitano de Santiago (PRMS). 2019: INE (catastro de plazas y parques urbanos)",
    cobertura_temporal = "2009, 2013 y 2019 (únicos años reales; NA en el resto del periodo)",
    unidad = "Hectáreas",
    notas = "Las tres fuentes usan criterios distintos de qué es 'parque' y qué área de la comuna miden (2009 y 2013: comuna completa, incluye zona rural/cordillerana; 2019: solo área urbana consolidada, exige infraestructura catastrada). NO son comparables entre sí como serie temporal -- se presentan como fotografías independientes de cada año, sin calcular aumento/reducción (decisión confirmada por Estela). 2009 filtrado con AV_REAL=si + ESTADO=Consolidada + TIPO_97=Implementada, más exclusión manual de 5 polígonos mal etiquetados (cerros/riberas). Limitación conocida en Lo Barnechea: catastro 2009 subestima área real. Caso Huechuraba investigado a fondo (ver bitácora): la caída aparente 2009-2019 se explica en gran parte por el Bosque Santiago, clasificado como zona rural en 2013 y por tanto excluido del área urbana de 2019."
  ) %>%
  add_row(
    variable = "pct_parques",
    descripcion = "Porcentaje de superficie comunal ocupado por parques urbanos/áreas verdes",
    fuente = "2009: Gobierno Regional Metropolitano. 2013: PRMS. 2019: INE",
    cobertura_temporal = "2009, 2013 y 2019 (únicos años reales; NA en el resto del periodo)",
    unidad = "Porcentaje (%)",
    notas = "Calculado como area_parques_ha / superficie comunal total (área_km2) para los tres años. Mismas limitaciones que area_parques_ha -- fuentes no comparables entre sí (ver esa variable)."
  )

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "vias_km_por_km2",
    descripcion = "Densidad de vías principales (autopistas, troncales, primarias y secundarias) por área comunal",
    fuente = "OpenStreetMap vía Geofabrik (chile-latest-free.shp)",
    cobertura_temporal = "Estática, repetida en los 12 años (2009-2020)",
    unidad = "Km de vía / km² de superficie comunal",
    notas = "Tratada como variable estática por no presentar cambios significativos año a año en la red vial principal dentro del periodo de estudio. Vías reproyectadas a UTM 32719 antes de calcular longitud."
  )

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "dist_salud_km",
    descripcion = "Distancia mínima desde el centro cívico/municipal de la comuna al establecimiento de salud (nivel 1° y 2°) más cercano, sin restringir a la propia comuna",
    fuente = "DEIS/MINSAL, capa de Establecimientos de Salud SNSS (cuenca del Maipo), corte 2019",
    cobertura_temporal = "2019 (único año real; NA en el resto del periodo)",
    unidad = "Kilómetros",
    notas = "Calculada desde coordenadas de municipalidad (provistas por Ismael), no desde centroide geográfico -- mismo criterio usado por el equipo para contaminación atmosférica. Se corrigió 1 registro con código de comuna mal asignado en la fuente original (CECOSF Villa Olímpica)."
  ) %>%
  add_row(
    variable = "n_establecimientos_salud",
    descripcion = "Número de establecimientos de salud (nivel 1° y 2°) dentro de la comuna",
    fuente = "DEIS/MINSAL, capa de Establecimientos de Salud SNSS (cuenca del Maipo), corte 2019",
    cobertura_temporal = "2019 (único año real; NA en el resto del periodo)",
    unidad = "Conteo",
    notas = "Reemplaza la variable original que usaba una capa de 2026, fuera del periodo de estudio."
  )
diccionario <- diccionario %>%
  add_row(
    variable = "area_industrial_ha",
    descripcion = "Superficie de zonas industriales por comuna, según uso de suelo del Plan Regulador Comunal",
    fuente = "Planes Reguladores Comunales (PRC), IDE MINVU",
    cobertura_temporal = "Estática, repetida en los 12 años (2009-2020)",
    unidad = "Hectáreas",
    notas = "Zonas industriales identificadas por patrón de nomenclatura (varía entre comunas, ya que cada PRC define su propia codificación). Correcciones manuales aplicadas: Estación Central (solo zona IPA, exclusivamente industrial); Lo Barnechea (corregido a 0, ZIE-2 es infraestructura, no industria); Puente Alto (excluidas zonas INF, infraestructura sanitaria/energética, no industrial). Tratada como estática por no reflejar cambios significativos año a año en el periodo -- limitación: no se revisó cada versión histórica de PRC por comuna."
  )

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "pct_inmigrantes",
    descripcion = "Porcentaje de población inmigrante internacional sobre población residente total, por comuna",
    fuente = "Censo 2017 (INE), vía Esri Living Atlas (capa 'Migración Internacional')",
    cobertura_temporal = "2017 (único año, dato censal)",
    unidad = "Porcentaje (%)",
    notas = "Calculado por el INE como INMIGRANTE / POB_RESIDE * 100. Valores coherentes con lo conocido: Independencia, Santiago y Estación Central con las proporciones más altas."
  )

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "ndvi_verano",
    descripcion = "Índice de vegetación de diferencia normalizada (NDVI), promedio comunal en periodo de verano (diciembre-marzo)",
    fuente = "Google Earth Engine: Landsat 5/7 Collection 2 T1_L2 (2009-2012), Landsat 8 Collection 2 T1_L2 (2013-2020)",
    cobertura_temporal = "2009-2020 (anual, dato real cada año)",
    unidad = "Índice (-1 a 1)",
    notas = "Filtro de nubosidad <20%. Ventana de verano definida como diciembre del año t a marzo del año t+1 (época cálida, noviembre-marzo según definición del equipo para variables de calor)."
  ) %>%
  add_row(
    variable = "ndvi_anual",
    descripcion = "Índice de vegetación de diferencia normalizada (NDVI), promedio comunal anual (enero-diciembre)",
    fuente = "Google Earth Engine: Landsat 5/7 Collection 2 T1_L2 (2009-2012), Landsat 8 Collection 2 T1_L2 (2013-2020)",
    cobertura_temporal = "2009-2020 (anual, dato real cada año)",
    unidad = "Índice (-1 a 1)",
    notas = "Filtro de nubosidad <20%. Rango observado en Producto 2 fue bajo (0.06-0.18) -- consistente con zona urbana densa con poca vegetación; NDVI incluye praderas y suelo desnudo, no distingue parques reales (ver cobertura_arborea y area_parques_ha como variables complementarias)."
  )

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "lst_verano",
    descripcion = "Temperatura superficial terrestre (LST), promedio comunal en periodo de verano (diciembre-marzo)",
    fuente = "Google Earth Engine: Landsat 5/7 Collection 2 T1_L2, banda ST_B6 (2009-2012); Landsat 8 Collection 2 T1_L2, banda ST_B10 (2013-2020)",
    cobertura_temporal = "2009-2020 (anual, dato real cada año)",
    unidad = "Grados Celsius (°C)",
    notas = "Filtro de nubosidad <20%. Es temperatura de la superficie (suelo/asfalto), no del aire ambiente -- variable complementaria a los datos de temperatura del aire (CR2) que maneja el equipo de Estela para calor extremo."
  ) %>%
  add_row(
    variable = "lst_anual",
    descripcion = "Temperatura superficial terrestre (LST), promedio comunal anual (enero-diciembre)",
    fuente = "Google Earth Engine: Landsat 5/7 Collection 2 T1_L2, banda ST_B6 (2009-2012); Landsat 8 Collection 2 T1_L2, banda ST_B10 (2013-2020)",
    cobertura_temporal = "2009-2020 (anual, dato real cada año)",
    unidad = "Grados Celsius (°C)",
    notas = "Filtro de nubosidad <20%. Misma fuente y método que lst_verano, ventana anual completa."
  )

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "cobertura_arborea",
    descripcion = "Porcentaje de cobertura arbórea (copa de árboles) por comuna",
    fuente = "Google Earth Engine: Hansen Global Forest Change (global_forest_change_2025_v1_13), UMD",
    cobertura_temporal = "2009-2020 (anual, dato real cada año)",
    unidad = "Porcentaje (0-100%)",
    notas = "No es medición satelital directa año a año: parte de cobertura base del año 2000 y se ajusta aplicando pérdidas (lossyear) y ganancias (gain 2000-2012) acumuladas hasta cada año. Se usa como complemento a NDVI porque distingue mejor vegetación arbórea real de otro tipo de verde (praderas, cultivos)."
  )

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "sup_impermeable",
    descripcion = "Superficie impermeable (construida) por celda, promedio comunal",
    fuente = "Google Earth Engine: GHSL JRC/GHSL/P2023A/GHS_BUILT_S",
    cobertura_temporal = "2009-2020, pero con resolución temporal real de solo 3 puntos (dataset disponible cada 5 años)",
    unidad = "m² construido / km² de celda",
    notas = "GHSL solo tiene datos para 2010, 2015 y 2020. Se asignó el año más cercano: 2009-2012 -> 2010; 2013-2017 -> 2015; 2018-2020 -> 2020. No es una serie anual real, sino una aproximación por bloques de años."
  )

diccionario

diccionario <- diccionario %>%
  add_row(
    variable = "poblacion_total",
    descripcion = "Población total estimada por comuna",
    fuente = "INE, Estimaciones y Proyecciones de Población por Comuna 2002-2035 (base Censo 2017)",
    cobertura_temporal = "2009-2020 (anual, dato real cada año)",
    unidad = "Habitantes",
    notas = "Reemplaza el uso exclusivo del Censo 2017 para densidad/población"
  ) %>%
  add_row(
    variable = "area_km2",
    descripcion = "Superficie de la comuna, calculada desde la geometría del polígono comunal",
    fuente = "Elaboración propia (Google Earth Engine, a partir del asset de comunas)",
    cobertura_temporal = "2009-2020 (repetida; el límite comunal no varía en el periodo)",
    unidad = "Kilómetros cuadrados (km²)",
    notas = "Se incluye como variable de apoyo -- permite recalcular densidad u otros indicadores de área si es necesario."
  ) %>%
  add_row(
    variable = "densidad_hab_km2",
    descripcion = "Densidad poblacional por comuna",
    fuente = "INE, Estimaciones y Proyecciones de Población por Comuna 2002-2035 (base Censo 2017)",
    cobertura_temporal = "2009-2020 (anual, dato real cada año)",
    unidad = "Habitantes / km²",
    notas = "Reemplaza la variable de densidad basada en Censo 2017 (que solo tenía un año real). Calculada como poblacion_total / area_km2."
  )

diccionario

diccionario <- diccionario %>%
  mutate(
    fuente = if_else(
      variable %in% c("bht", "dim_socioeconomica", "dim_accesibilidad", "dim_ambiental", "dim_seguridad"),
      "Matriz de Bienestar Humano Territorial (MBHT), Centro de Inteligencia Territorial, Universidad Adolfo Ibáñez (CIT-UAI); provisto por equipo de investigación (José Daniel Conejeros)",
      fuente
    )
  )
diccionario %>% filter(variable == "bht") %>% pull(fuente)

View(diccionario)

diccionario_actualizado <- diccionario %>%
  mutate(
    fuente = case_when(
      variable == "poblacion_total" ~ "INE, Estimaciones y Proyecciones de Población por Comuna 2002-2035 (base Censo 2017)",
      variable == "densidad_hab_km2" ~ "INE, Estimaciones y Proyecciones de Población por Comuna 2002-2035 (base Censo 2017)",
      TRUE ~ fuente
    ),
    notas = case_when(
      variable == "poblacion_total" ~ "INE es proyección demográfica, no censo directo salvo en 2017.",
      variable == "densidad_hab_km2" ~ "Recalculada como poblacion_total (INE) / area_km2",
      TRUE ~ notas
    )
  )

write_excel_csv(diccionario_actualizado, "01_Input/Producto1/diccionario_variables.csv")




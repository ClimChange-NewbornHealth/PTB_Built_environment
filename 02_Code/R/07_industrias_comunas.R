# =============================================
# Superficie Industrial por Comuna — Santiago
# FONDECYT 11240322
# =============================================
# Nota metodológica: La variable de superficie industrial se calculó
# a partir de los Planes Reguladores Comunales (PRC) del IDE MINVU.
# Dado que cada PRC usa nomenclatura propia, se identificaron zonas
# industriales mediante patrones: ^I, ZI, industrial, productiv, 4AI, EI.
# Correcciones específicas:
# - Estación Central: solo zona IPA (industrial exclusiva)
# - Lo Barnechea: corregido a 0 (zonas ZIE-2 son infraestructura, no industria)
# - Puente Alto: excluidas zonas INF (infraestructura sanitaria y energética)
# Variable estática, no varía por año.
# =============================================

# Cargar librerías
library(sf)
library(dplyr)
library(purrr)

# Listar PRC de las 33 comunas
prc_files <- list.files(
  "01_Input/Shapefiles/IPT_metropolitana/Uso_suelo_RM/PRC",
  pattern = "^IPT_13_PRC_.*\\.shp$",
  full.names = TRUE
)

prc_comunas_33 <- c(
  "IPT_13_PRC_Cerrillos.shp", "IPT_13_PRC_Cerro_Navia.shp",
  "IPT_13_PRC_Conchali.shp", "IPT_13_PRC_El_Bosque.shp",
  "IPT_13_PRC_Estacion_Central.shp", "IPT_13_PRC_Huechuraba.shp",
  "IPT_13_PRC_Independencia.shp", "IPT_13_PRC_La_Cisterna.shp",
  "IPT_13_PRC_La_Florida.shp", "IPT_13_PRC_La_Granja.shp",
  "IPT_13_PRC_La_Pintana.shp", "IPT_13_PRC_La_Reina.shp",
  "IPT_13_PRC_Las_Condes.shp", "IPT_13_PRC_Lo_Barnechea.shp",
  "IPT_13_PRC_Lo_Espejo.shp", "IPT_13_PRC_Lo_Prado.shp",
  "IPT_13_PRC_Macul.shp", "IPT_13_PRC_Maipu.shp",
  "IPT_13_PRC_Nunoa.shp", "IPT_13_PRC_Pedro_Aguirre_Cerda.shp",
  "IPT_13_PRC_Penalolen.shp", "IPT_13_PRC_Providencia.shp",
  "IPT_13_PRC_Pudahuel.shp", "IPT_13_PRC_Puente_Alto.shp",
  "IPT_13_PRC_Quilicura.shp", "IPT_13_PRC_Quinta_Normal.shp",
  "IPT_13_PRC_Recoleta.shp", "IPT_13_PRC_Renca.shp",
  "IPT_13_PRC_San_Joaquin.shp", "IPT_13_PRC_San_Miguel.shp",
  "IPT_13_PRC_San_Ramon.shp", "IPT_13_PRC_Santiago.shp",
  "IPT_13_PRC_Vitacura.shp"
)

prc_paths <- prc_files[basename(prc_files) %in% prc_comunas_33]

# Cargar y filtrar zonas industriales
industrias <- map_dfr(prc_paths, function(path) {
  tryCatch({
    capa <- st_read(path, quiet = TRUE) %>%
      st_transform(32719) %>%
      filter(grepl("^I|ZI|industrial|industria|productiv|4AI|\\bEI\\b|-EI",
                   ZONA, ignore.case = TRUE)) %>%
      select(COM, ZONA, geometry) %>%
      mutate(COM = as.character(COM),
             ZONA = as.character(ZONA))
  }, error = function(e) NULL)
})

# Calcular área industrial por comuna
industrias_area <- industrias %>%
  mutate(area_m2 = as.numeric(st_area(.))) %>%
  st_drop_geometry() %>%
  group_by(COM) %>%
  summarise(
    area_industrial_ha = round(sum(area_m2) / 10000, 2),
    n_zonas_industriales = n()
  )

# Completar con comunas sin industria
todas_comunas <- data.frame(COM = c("Cerrillos", "Cerro Navia", "Conchalí",
                                    "El Bosque", "Estación Central", "Huechuraba", "Independencia",
                                    "La Cisterna", "La Florida", "La Granja", "La Pintana", "La Reina",
                                    "Las Condes", "Lo Barnechea", "Lo Espejo", "Lo Prado", "Macul",
                                    "Maipú", "Ñuñoa", "Pedro Aguirre Cerda", "Peñalolen", "Providencia",
                                    "Pudahuel", "Puente Alto", "Quilicura", "Quinta Normal", "Recoleta",
                                    "Renca", "San Joaquín", "San Miguel", "San Ramón", "Santiago", "Vitacura"))

industrias_final <- todas_comunas %>%
  left_join(industrias_area, by = "COM") %>%
  mutate(
    area_industrial_ha = ifelse(is.na(area_industrial_ha), 0, area_industrial_ha),
    n_zonas_industriales = ifelse(is.na(n_zonas_industriales), 0, n_zonas_industriales)
  )

# Corrección Estación Central: solo zona IPA
ec_corregido <- st_read(prc_paths[grep("Estacion_Central.shp$", prc_paths)], quiet = TRUE) %>%
  st_transform(32719) %>%
  filter(ZONA == "IPA") %>%
  mutate(area_m2 = as.numeric(st_area(.)), COM = "Estación Central") %>%
  st_drop_geometry() %>%
  summarise(COM = first(COM),
            area_industrial_ha = round(sum(area_m2) / 10000, 2),
            n_zonas_industriales = n())

industrias_final <- industrias_final %>%
  filter(COM != "Estación Central") %>%
  bind_rows(ec_corregido)

# Corrección Lo Barnechea: a 0
industrias_final <- industrias_final %>%
  mutate(
    area_industrial_ha = ifelse(COM == "Lo Barnechea", 0, area_industrial_ha),
    n_zonas_industriales = ifelse(COM == "Lo Barnechea", 0, n_zonas_industriales)
  )

# Corrección Puente Alto: excluir zonas INF
puente_alto_corregido <- st_read(prc_paths[grep("Puente_Alto.shp$", prc_paths)], quiet = TRUE) %>%
  st_transform(32719) %>%
  filter(grepl("^I|ZI|industrial|industria|productiv|4AI|\\bEI\\b|-EI",
               ZONA, ignore.case = TRUE)) %>%
  filter(!grepl("^INF", ZONA)) %>%
  mutate(area_m2 = as.numeric(st_area(.))) %>%
  st_drop_geometry() %>%
  summarise(COM = "Puente Alto",
            area_industrial_ha = round(sum(area_m2) / 10000, 2),
            n_zonas_industriales = n())

industrias_final <- industrias_final %>%
  filter(COM != "Puente Alto") %>%
  bind_rows(puente_alto_corregido) %>%
  arrange(COM)

# Guardar
write.csv(industrias_final,
          "01_Input/Producto1/industrias_santiago_33.csv",
          row.names = FALSE)

print("Archivo guardado correctamente")





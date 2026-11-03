library(sf)

# Capa 0
url_capa0 <- "https://services.arcgis.com/r7t1P5pnkoOLRdhr/arcgis/rest/services/Migraci%C3%B3n_Internacional/FeatureServer/0/query?where=1=1&outFields=*&f=geojson"

capa0 <- st_read(url_capa0)

# Capa 1
url_capa1 <- "https://services.arcgis.com/r7t1P5pnkoOLRdhr/arcgis/rest/services/Migraci%C3%B3n_Internacional/FeatureServer/1/query?where=1=1&outFields=*&f=geojson"

capa1 <- st_read(url_capa1)

# Revisar cuál es cuál
cat("Capa 0 - filas:", nrow(capa0), "\n")
cat("Capa 0 - nombres:", paste(names(capa0), collapse = ", "), "\n\n")

cat("Capa 1 - filas:", nrow(capa1), "\n")
cat("Capa 1 - nombres:", paste(names(capa1), collapse = ", "), "\n")

cat("Capa 1 - filas:", nrow(capa1), "\n\n")

capa1 %>%
  st_drop_geometry() %>%
  select(CUT, NOM_REGION, NOM_COMUNA, INMIGRANTE, INMIGRAN_1, POB_RESIDE, PROP_INMIG) %>%
  head(10)

codigos_33_comunas <- c(sprintf("131%02d", 1:32), "13201")

migracion_33 <- capa1 %>%
  st_drop_geometry() %>%
  filter(CUT %in% codigos_33_comunas) %>%
  select(CUT, NOM_COMUNA, INMIGRANTE, POB_RESIDE, PROP_INMIG)

nrow(migracion_33)
migracion_33

dir.create("01_Input/Migracion", showWarnings = FALSE)
write.csv(migracion_33, "01_Input/Producto1/migracion_2017_santiago_33.csv", row.names = FALSE)







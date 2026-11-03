# =============================================
# Vías Principales por Comuna — Santiago
# FONDECYT 11240322
# =============================================
# Nota metodológica: Se calculó la densidad de vías principales
# (autopistas, troncales, primarias y secundarias) por km² de área comunal.
# Fuente: OpenStreetMap vía Geofabrik (chile-latest-free.shp)
# Las vías se reproyectaron a UTM Zona 19S (EPSG:32719) para calcular
# longitudes en metros correctamente.
# Variable estática, no varía por año.
# =============================================

# Cargar librerías
library(sf)
library(dplyr)

# Cargar vías de Chile y filtrar vías principales
vias_principales <- st_read("01_Input/Shapefiles/OSM/gis_osm_roads_free_1.shp", quiet = TRUE) %>%
  filter(fclass %in% c("motorway", "motorway_link", "trunk", "trunk_link",
                       "primary", "primary_link", "secondary"))

# Cargar comunas de Santiago
comunas <- st_read("01_Input/Shapefiles/Comunas_santiago_33/comunas_santiago_33_WGS84.shp", 
                   quiet = TRUE)

# Calcular área comunal en km²
comunas_area <- comunas %>%
  st_transform(32719) %>%
  mutate(
    area_comuna_m2 = as.numeric(st_area(.)),
    area_comuna_ha = round(area_comuna_m2 / 10000, 2)
  ) %>%
  st_drop_geometry() %>%
  select(COMUNA, area_comuna_m2, area_comuna_ha)

# Recortar vías al área de Santiago y reproyectar a UTM para medir en metros
vias_santiago <- st_intersection(vias_principales, comunas) %>%
  st_transform(32719)

# Calcular densidad de vías por comuna
vias_densidad <- vias_santiago %>%
  mutate(longitud_m = as.numeric(st_length(.))) %>%
  st_drop_geometry() %>%
  group_by(COMUNA) %>%
  summarise(
    n_vias = n(),
    longitud_total_km = round(sum(longitud_m, na.rm = TRUE) / 1000, 2)
  ) %>%
  left_join(comunas_area, by = "COMUNA") %>%
  mutate(
    densidad_km_km2 = round(longitud_total_km / area_comuna_ha * 100, 2)
  ) %>%
  select(COMUNA, n_vias, longitud_total_km, densidad_km_km2)

# Verificar
print(paste("Comunas procesadas:", nrow(vias_densidad)))

# Guardar
write.csv(vias_densidad,
          "01_Input/Producto1/vias_principales_santiago_33.csv",
          row.names = FALSE)

print("Archivo guardado correctamente")



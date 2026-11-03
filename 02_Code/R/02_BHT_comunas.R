# =============================================

# Cargar librerías
library(readxl)
library(dplyr)

# Cargar datos BHT (nivel manzana)
bht_data <- read_excel("01_Input/Data_ANID/BHT/BHT.xlsx")

# Códigos CUT de las 33 comunas del área de estudio
codigos_santiago <- c(13101, 13102, 13103, 13104, 13105, 13106, 13107, 
                      13108, 13109, 13110, 13111, 13112, 13113, 13114, 
                      13115, 13116, 13117, 13118, 13119, 13120, 13121, 
                      13122, 13123, 13124, 13125, 13126, 13127, 13128, 
                      13129, 13130, 13131, 13132, 13201)

# Filtrar las 33 comunas
bht_santiago <- bht_data[bht_data$cod_com %in% codigos_santiago, ]

# Calcular promedio ponderado de BHT por comuna
bht_comunas <- bht_santiago %>%
  group_by(cod_com) %>%
  summarise(
    bht_promedio = weighted.mean(bht, personas, na.rm = TRUE),
    bht_simple = mean(bht, na.rm = TRUE),
    n_manzanas = n(),
    poblacion_total = sum(personas, na.rm = TRUE)
  ) %>%
  arrange(cod_com) %>%
  left_join(sovi_santiago[, c("cod_com", "name_comuna")], by = "cod_com")

# Guardar
write.csv(bht_comunas,
          "01_Input/Producto1/bht_santiago_33.csv",
          row.names = FALSE)

print("Archivo guardado correctamente")

BHT <- read.csv("01_Input/Producto1/bht_santiago_33.csv")
 View(BHT)






# =============================================
# BHT Dimensiones por Comuna
# FONDECYT 11240322
# =============================================

# Cargar librerías
library(readxl)
library(dplyr)

# Códigos CUT de las 33 comunas del área de estudio
codigos_santiago <- c(13101, 13102, 13103, 13104, 13105, 13106, 13107, 
                      13108, 13109, 13110, 13111, 13112, 13113, 13114, 
                      13115, 13116, 13117, 13118, 13119, 13120, 13121, 
                      13122, 13123, 13124, 13125, 13126, 13127, 13128, 
                      13129, 13130, 13131, 13132, 13201)

# Cargar las 4 dimensiones
dim_socioeconomica <- read_excel("01_Input/Data_ANID/BHT/Dim_Socioeconomica.xlsx")
dim_accesibilidad  <- read_excel("01_Input/Data_ANID/BHT/Dim_Accesibilidad.xlsx")
dim_ambiental      <- read_excel("01_Input/Data_ANID/BHT/Dim_Ambiental.xlsx")
dim_seguridad      <- read_excel("01_Input/Data_ANID/BHT/Dim_Seguridad.xlsx")

# Agregar cada dimensión por comuna (promedio ponderado por personas)
dim_soc_comunas <- dim_socioeconomica %>%
  filter(cod_com %in% codigos_santiago) %>%
  group_by(cod_com) %>%
  summarise(dim_socioeconomica = weighted.mean(dim_soc, personas, na.rm = TRUE))

dim_acc_comunas <- dim_accesibilidad %>%
  filter(cod_com %in% codigos_santiago) %>%
  group_by(cod_com) %>%
  summarise(dim_accesibilidad = weighted.mean(dim_acc, personas, na.rm = TRUE))

dim_amb_comunas <- dim_ambiental %>%
  filter(cod_com %in% codigos_santiago) %>%
  group_by(cod_com) %>%
  summarise(dim_ambiental = weighted.mean(dim_amb, personas, na.rm = TRUE))

dim_seg_comunas <- dim_seguridad %>%
  filter(cod_com %in% codigos_santiago) %>%
  group_by(cod_com) %>%
  summarise(dim_seguridad = weighted.mean(dim_seg, personas, na.rm = TRUE))

# Unir todas las dimensiones
bht_dimensiones <- bht_comunas %>%
  select(cod_com, name_comuna) %>%
  left_join(dim_soc_comunas, by = "cod_com") %>%
  left_join(dim_acc_comunas, by = "cod_com") %>%
  left_join(dim_amb_comunas, by = "cod_com") %>%
  left_join(dim_seg_comunas, by = "cod_com")

# Guardar
write.csv(bht_dimensiones,
          "01_Input/Producto1/bht_dimensiones_santiago_33.csv",
          row.names = FALSE)

print("Archivo guardado correctamente")




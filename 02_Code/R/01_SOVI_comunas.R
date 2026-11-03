# =============================================
# SOVI - Vulnerabilidad Social por Comuna
# FONDECYT 11240322
# =============================================

# Cargar datos
e <- new.env()
load("01_Input/Data_ANID/sovi_datasets.RData", envir = e)
sovi_fulldataset <- e$sovi_fulldataset

# Lista de 33 comunas del área de estudio (sin tildes)
comunas_santiago <- c("Pudahuel", "Cerro Navia", "Huechuraba", "Conchali", 
                      "La Pintana", "El Bosque", "Estacion Central", "Pedro Aguirre Cerda", 
                      "Recoleta", "Independencia", "Lo Espejo", "La Cisterna", "La Florida", 
                      "Penalolen", "Las Condes", "La Reina", "Lo Barnechea", "Vitacura", 
                      "Quinta Normal", "Lo Prado", "Cerrillos", "Maipu", "Macul", "Nunoa", 
                      "Puente Alto", "Quilicura", "Renca", "San Joaquin", "San Miguel", 
                      "San Ramon", "La Granja", "Providencia", "Santiago")

# Filtrar las 33 comunas
sovi_santiago <- sovi_fulldataset[sovi_fulldataset$name_comuna %in% comunas_santiago, ]

# Verificar
print(paste("Número de comunas:", nrow(sovi_santiago)))
table(sovi_santiago$vulnerablidad)

# Guardar
write.csv(sovi_santiago, 
          "01_Input/Producto1/sovi_santiago_33.csv", 
          row.names = FALSE)

print("Archivo guardado correctamente")


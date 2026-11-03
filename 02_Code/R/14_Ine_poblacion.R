# =============================================
# Población INE 2002-2035 
# Serie completa 2009-2020, sin NA
# =============================================
ine_totales_rm <- read_csv(
  "01_Input/INE_población/ine_estimaciones_2002_2035.csv",
  locale = locale(encoding = "Latin1")
) %>%
  mutate(across(starts_with("Poblacion"), as.numeric)) %>%
  group_by(`Nombre Comuna`) %>%
  summarise(across(starts_with("Poblacion"), sum), .groups = "drop") %>%
  pivot_longer(
    cols = starts_with("Poblacion"),
    names_to = "year",
    values_to = "poblacion_ine",
    names_prefix = "Poblacion "
  ) %>%
  mutate(
    year = as.integer(year),
    comuna_std = quitar_tildes(str_trim(str_to_upper(`Nombre Comuna`)))
  ) %>%
  filter(comuna_std %in% quitar_tildes(str_trim(str_to_upper(comunas_33$COMUNA))),
         year %in% 2009:2020) %>%
  left_join(
    comunas_33 %>% st_drop_geometry() %>%
      transmute(COMUNA, comuna_std = quitar_tildes(str_trim(str_to_upper(COMUNA)))),
    by = "comuna_std"
  ) %>%
  select(COMUNA, year, poblacion_ine)

nrow(ine_totales_rm)  # verificación: debe dar 396 (33 comunas x 12 años)
write_excel_csv(ine_totales_rm, "01_Input/Producto1/ine_totales_rm.csv")







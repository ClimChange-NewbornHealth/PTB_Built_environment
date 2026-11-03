// =============================================
// Superficie Impermeable por comuna — Santiago 2009-2020
// FONDECYT 11240322
// =============================================
// Nota metodológica: El dataset GHSL tiene resolución temporal de 5 años
// (2010, 2015, 2020). Se asigna el año más cercano a cada año del período:
// 2009-2012 → 2010, 2013-2017 → 2015, 2018-2020 → 2020

// Cargar las 33 comunas de Santiago
var comunas = ee.FeatureCollection(
  'projects/fondecyt-entorno-urbano/assets/comunas_santiago_33_WGS84'
);

// Cargar dataset GHSL
var ghsl = ee.ImageCollection('JRC/GHSL/P2023A/GHS_BUILT_S')
  .filterBounds(comunas);

// Función para obtener superficie impermeable por año GHSL
function getGHSL(ghslYear) {
  return ghsl
    .filter(ee.Filter.eq('system:index', String(ghslYear)))
    .first()
    .select('built_surface')
    .rename('impervious');
}

// Asignar año GHSL más cercano a cada año del estudio
var years = [2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020];

var resultados = years.map(function(year) {
  var ghslYear;
  if (year <= 2012) {
    ghslYear = 2010;
  } else if (year <= 2017) {
    ghslYear = 2015;
  } else {
    ghslYear = 2020;
  }
  
  var img = getGHSL(ghslYear);
  
  var imp_comunas = img.reduceRegions({
    collection: comunas,
    reducer: ee.Reducer.mean(),
    scale: 100
  });
  
  return imp_comunas.map(function(feature) {
    return ee.Feature(null, {
      'COMUNA': feature.get('COMUNA'),
      'year': year,
      'ghsl_year': ghslYear,
      'impervious': ee.Number(feature.get('mean')).multiply(100).round().divide(100)
    });
  });
});

var tabla_final = ee.FeatureCollection(resultados).flatten();
print('Total registros:', tabla_final.size());

// Visualizar
Map.centerObject(comunas, 10);
Map.addLayer(comunas, {color: 'blue'}, 'Comunas Santiago');

// Exportar
Export.table.toDrive({
  collection: tabla_final,
  description: 'Impervious_comunas_santiago_2009_2020',
  fileFormat: 'CSV',
  selectors: ['COMUNA', 'year', 'ghsl_year', 'impervious']
});
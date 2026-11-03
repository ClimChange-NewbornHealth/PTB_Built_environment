// =============================================
// Cobertura Arbórea por comuna — Santiago 2009-2020
// FONDECYT 11240322
// =============================================

// Cargar las 33 comunas de Santiago
var comunas = ee.FeatureCollection(
  'projects/fondecyt-entorno-urbano/assets/comunas_santiago_33_WGS84'
);

// Cargar dataset Hansen Global Forest Change
var hansen = ee.Image("UMD/hansen/global_forest_change_2025_v1_13");

// treecover2000: cobertura arbórea base en el año 2000 (0-100%)
// lossyear: año en que se perdió cobertura (1=2001, 9=2009, etc.)
// gain: ganancia de cobertura 2000-2012

var treecover2000 = hansen.select('treecover2000');
var lossyear = hansen.select('lossyear');
var gain = hansen.select('gain');

// Función para calcular cobertura arbórea por año
// Parte de la cobertura base 2000 y aplica pérdidas y ganancias
function getTreeCover(year) {
  // Pérdidas ocurridas hasta ese año (lossyear va de 1=2001 a 23=2023)
  var yearsSince2000 = year - 2000;
  var lossToYear = lossyear.lte(yearsSince2000).and(lossyear.gt(0));
  
  // Cobertura ajustada: base 2000 menos pérdidas más ganancias
  var cover = treecover2000
    .where(lossToYear, 0)
    .where(gain.eq(1).and(lossToYear.not()), treecover2000.add(10).min(100));
  
  return cover.rename('treecover');
}

// Verificar
print('Comunas cargadas:', comunas.size());
Map.centerObject(comunas, 10);
Map.addLayer(comunas, {color: 'blue'}, 'Comunas Santiago');
Map.addLayer(treecover2000.clip(comunas),
  {min: 0, max: 100, palette: ['white', 'green']},
  'Cobertura arbórea 2000');

// =============================================
// Loop para todos los años 2009-2020
// =============================================
var years = [2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020];

var resultados = years.map(function(year) {
  var cover = getTreeCover(year);
  
  var cover_comunas = cover.reduceRegions({
    collection: comunas,
    reducer: ee.Reducer.mean(),
    scale: 30
  });
  
  return cover_comunas.map(function(feature) {
    return ee.Feature(null, {
      'COMUNA': feature.get('COMUNA'),
      'year': year,
      'treecover': ee.Number(feature.get('mean')).multiply(100).round().divide(100)
    });
  });
});

var tabla_final = ee.FeatureCollection(resultados).flatten();
print('Total registros:', tabla_final.size());

// Exportar
Export.table.toDrive({
  collection: tabla_final,
  description: 'TreeCover_comunas_santiago_2009_2020',
  fileFormat: 'CSV',
  selectors: ['COMUNA', 'year', 'treecover']
});
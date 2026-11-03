// =============================================
// NDVI por comuna — Santiago 2009-2020
// FONDECYT 11240322
// =============================================

// Cargar las 33 comunas de Santiago
var comunas = ee.FeatureCollection(
  'projects/fondecyt-entorno-urbano/assets/comunas_santiago_33_WGS84'
);

// Función NDVI Landsat 8 (2013-2020)
function getNDVI_L8(year) {
  var startDate = ee.Date.fromYMD(year, 12, 1);
  var endDate = ee.Date.fromYMD(year + 1, 3, 1);
  
  return ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
    .filterBounds(comunas)
    .filterDate(startDate, endDate)
    .filter(ee.Filter.lt('CLOUD_COVER', 20))
    .map(function(img) {
      return img.normalizedDifference(['SR_B5', 'SR_B4']).rename('NDVI');
    }).median();
}

// Función NDVI Landsat 5/7 (2009-2012)
function getNDVI_L57(year) {
  var startDate = ee.Date.fromYMD(year, 12, 1);
  var endDate = ee.Date.fromYMD(year + 1, 3, 1);
  
  var l5 = ee.ImageCollection('LANDSAT/LT05/C02/T1_L2')
    .filterBounds(comunas)
    .filterDate(startDate, endDate)
    .filter(ee.Filter.lt('CLOUD_COVER', 20))
    .map(function(img) {
      return img.normalizedDifference(['SR_B4', 'SR_B3']).rename('NDVI');
    });

  var l7 = ee.ImageCollection('LANDSAT/LE07/C02/T1_L2')
    .filterBounds(comunas)
    .filterDate(startDate, endDate)
    .filter(ee.Filter.lt('CLOUD_COVER', 20))
    .map(function(img) {
      return img.normalizedDifference(['SR_B4', 'SR_B3']).rename('NDVI');
    });

  return l5.merge(l7).median();
}

// Verificar
print('Comunas cargadas:', comunas.size());
Map.centerObject(comunas, 10);
Map.addLayer(comunas, {color: 'blue'}, 'Comunas Santiago');

// =============================================
// Loop para todos los años 2009-2020
// =============================================
var years = [2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020];

var resultados = years.map(function(year) {
  var ndvi;
  if (year < 2013) {
    ndvi = getNDVI_L57(year);
  } else {
    ndvi = getNDVI_L8(year);
  }
  
  var ndvi_comunas = ndvi.reduceRegions({
    collection: comunas,
    reducer: ee.Reducer.mean(),
    scale: 30
  });
  
  return ndvi_comunas.map(function(feature) {
    return feature.set('year', year);
  });
});

var tabla_final = ee.FeatureCollection(resultados).flatten();
print('Total de registros:', tabla_final.size());
// =============================================
// NDVI anual completo (enero-diciembre)
// =============================================
var resultados_anual = years.map(function(year) {
  var startDate = ee.Date.fromYMD(year, 1, 1);
  var endDate = ee.Date.fromYMD(year, 12, 31);
  
  var ndvi;
  if (year < 2013) {
    var l5 = ee.ImageCollection('LANDSAT/LT05/C02/T1_L2')
      .filterBounds(comunas)
      .filterDate(startDate, endDate)
      .filter(ee.Filter.lt('CLOUD_COVER', 20))
      .map(function(img) {
        return img.normalizedDifference(['SR_B4', 'SR_B3']).rename('NDVI');
      });
    var l7 = ee.ImageCollection('LANDSAT/LE07/C02/T1_L2')
      .filterBounds(comunas)
      .filterDate(startDate, endDate)
      .filter(ee.Filter.lt('CLOUD_COVER', 20))
      .map(function(img) {
        return img.normalizedDifference(['SR_B4', 'SR_B3']).rename('NDVI');
      });
    ndvi = l5.merge(l7).median();
  } else {
    ndvi = ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
      .filterBounds(comunas)
      .filterDate(startDate, endDate)
      .filter(ee.Filter.lt('CLOUD_COVER', 20))
      .map(function(img) {
        return img.normalizedDifference(['SR_B5', 'SR_B4']).rename('NDVI');
      }).median();
  }
  
  var ndvi_comunas = ndvi.reduceRegions({
    collection: comunas,
    reducer: ee.Reducer.mean(),
    scale: 30
  });
  
  return ndvi_comunas.map(function(feature) {
    return feature.set('year', year);
  });
});

var tabla_anual = ee.FeatureCollection(resultados_anual).flatten();

var tabla_anual_limpia = tabla_anual.map(function(feature) {
  return ee.Feature(null, {
    'COMUNA': feature.get('COMUNA'),
    'year': feature.get('year'),
    'NDVI_anual': ee.Number(feature.get('mean')).multiply(10000).round().divide(10000)
  });
});

Export.table.toDrive({
  collection: tabla_anual_limpia,
  description: 'NDVI_anual_comunas_santiago_2009_2020',
  fileFormat: 'CSV',
  selectors: ['COMUNA', 'year', 'NDVI_anual']
});
// =============================================
// Limpiar y exportar tabla final
// =============================================
var tabla_limpia = tabla_final.map(function(feature) {
  return ee.Feature(null, {
    'COMUNA': feature.get('COMUNA'),
    'year': feature.get('year'),
    'NDVI': ee.Number(feature.get('mean')).multiply(10000).round().divide(10000)
  });
});

Export.table.toDrive({
  collection: tabla_limpia,
  description: 'NDVI_comunas_santiago_2009_2020_limpio',
  fileFormat: 'CSV',
  selectors: ['COMUNA', 'year', 'NDVI'] 
});
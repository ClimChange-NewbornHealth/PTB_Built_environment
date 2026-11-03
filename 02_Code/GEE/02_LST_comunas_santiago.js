// =============================================
// LST - Temperatura Superficial Terrestre
// por comuna — Santiago 2009-2020
// FONDECYT 11240322
// =============================================

// Cargar las 33 comunas de Santiago
var comunas = ee.FeatureCollection(
  'projects/fondecyt-entorno-urbano/assets/comunas_santiago_33_WGS84'
);

// Función LST Landsat 8 (2013-2020)
function getLST_L8(year) {
  var startDate = ee.Date.fromYMD(year, 12, 1);
  var endDate = ee.Date.fromYMD(year + 1, 3, 1);
  
  return ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
    .filterBounds(comunas)
    .filterDate(startDate, endDate)
    .filter(ee.Filter.lt('CLOUD_COVER', 20))
    .map(function(img) {
      return img.select('ST_B10')
                .multiply(0.00341802)
                .add(149.0)
                .subtract(273.15)
                .rename('LST');
    }).median();
}

// Función LST Landsat 5/7 (2009-2012)
function getLST_L57(year) {
  var startDate = ee.Date.fromYMD(year, 12, 1);
  var endDate = ee.Date.fromYMD(year + 1, 3, 1);
  
  var l5 = ee.ImageCollection('LANDSAT/LT05/C02/T1_L2')
    .filterBounds(comunas)
    .filterDate(startDate, endDate)
    .filter(ee.Filter.lt('CLOUD_COVER', 20))
    .map(function(img) {
      return img.select('ST_B6')
                .multiply(0.00341802)
                .add(149.0)
                .subtract(273.15)
                .rename('LST');
    });

  var l7 = ee.ImageCollection('LANDSAT/LE07/C02/T1_L2')
    .filterBounds(comunas)
    .filterDate(startDate, endDate)
    .filter(ee.Filter.lt('CLOUD_COVER', 20))
    .map(function(img) {
      return img.select('ST_B6')
                .multiply(0.00341802)
                .add(149.0)
                .subtract(273.15)
                .rename('LST');
    });

  return l5.merge(l7).median();
}

// Verificar
print('Comunas cargadas:', comunas.size());
Map.centerObject(comunas, 10);
Map.addLayer(comunas, {color: 'blue'}, 'Comunas Santiago')

// =============================================
// Loop para todos los años 2009-2020
// =============================================
var years = [2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020];

var resultados = years.map(function(year) {
  var lst;
  if (year < 2013) {
    lst = getLST_L57(year);
  } else {
    lst = getLST_L8(year);
  }
  
  var lst_comunas = lst.reduceRegions({
    collection: comunas,
    reducer: ee.Reducer.mean(),
    scale: 30
  });
  
  return lst_comunas.map(function(feature) {
    return ee.Feature(null, {
      'COMUNA': feature.get('COMUNA'),
      'year': year,
      'LST': ee.Number(feature.get('mean')).multiply(100).round().divide(100)
    });
  });
});

var tabla_final = ee.FeatureCollection(resultados).flatten();
print('Total registros:', tabla_final.size());

// =============================================
// LST anual completo (enero-diciembre)
// =============================================
var resultados_anual = years.map(function(year) {
  var startDate = ee.Date.fromYMD(year, 1, 1);
  var endDate = ee.Date.fromYMD(year, 12, 31);
  
  var lst;
  if (year < 2013) {
    var l5 = ee.ImageCollection('LANDSAT/LT05/C02/T1_L2')
      .filterBounds(comunas)
      .filterDate(startDate, endDate)
      .filter(ee.Filter.lt('CLOUD_COVER', 20))
      .map(function(img) {
        return img.select('ST_B6')
                  .multiply(0.00341802)
                  .add(149.0)
                  .subtract(273.15)
                  .rename('LST');
      });
    var l7 = ee.ImageCollection('LANDSAT/LE07/C02/T1_L2')
      .filterBounds(comunas)
      .filterDate(startDate, endDate)
      .filter(ee.Filter.lt('CLOUD_COVER', 20))
      .map(function(img) {
        return img.select('ST_B6')
                  .multiply(0.00341802)
                  .add(149.0)
                  .subtract(273.15)
                  .rename('LST');
      });
    lst = l5.merge(l7).median();
  } else {
    lst = ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
      .filterBounds(comunas)
      .filterDate(startDate, endDate)
      .filter(ee.Filter.lt('CLOUD_COVER', 20))
      .map(function(img) {
        return img.select('ST_B10')
                  .multiply(0.00341802)
                  .add(149.0)
                  .subtract(273.15)
                  .rename('LST');
      }).median();
  }
  
  var lst_comunas = lst.reduceRegions({
    collection: comunas,
    reducer: ee.Reducer.mean(),
    scale: 30
  });
  
  return lst_comunas.map(function(feature) {
    return ee.Feature(null, {
      'COMUNA': feature.get('COMUNA'),
      'year': year,
      'LST_anual': ee.Number(feature.get('mean')).multiply(100).round().divide(100)
    });
  });
});

var tabla_anual = ee.FeatureCollection(resultados_anual).flatten();

// =============================================
// Exportar tablas
// =============================================
Export.table.toDrive({
  collection: tabla_final,
  description: 'LST_verano_comunas_santiago_2009_2020',
  fileFormat: 'CSV',
  selectors: ['COMUNA', 'year', 'LST']
});

Export.table.toDrive({
  collection: tabla_anual,
  description: 'LST_anual_comunas_santiago_2009_2020',
  fileFormat: 'CSV',
  selectors: ['COMUNA', 'year', 'LST_anual']
});
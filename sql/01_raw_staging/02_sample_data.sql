-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Sample Data
-- Inserts representative rows so the demo runs with visible output
-- Run as: DEMO_ENGINEER
-------------------------------------------------------------------------------

USE ROLE DEMO_ENGINEER;
USE DATABASE RETAIL_TRANSFORM_DEMO;
USE WAREHOUSE DEMO_ETL_WH;

-------------------------------------------------------------------------------
-- Reference Data
-------------------------------------------------------------------------------
USE SCHEMA REF;

INSERT INTO REF.DIM_PRODUCT (MATERIAL_NUMBER, UPC, PRODUCT_NAME, BRAND, CATEGORY, SUB_CATEGORY, UNIT_WEIGHT_KG, PACK_SIZE, AVG_PRICE_PER_KG, EFFECTIVE_FROM)
VALUES
    ('MAT-001', '028000000012', 'Sunrise Classic Coffee 200g',    'Sunrise',  'Beverages',    'Coffee',           0.200, 1, 32.50, '2024-01-01'),
    ('MAT-002', '028000000029', 'ChocoCrunch Bar 41.5g',  'ChocoCrunch',   'Confectionery','Chocolate Bars',   0.0415, 1, 18.00, '2024-01-01'),
    ('MAT-003', '028000000036', 'PetPrime Chicken 3.5lb','PetPrime',   'Pet Care',     'Dry Dog Food',     1.588, 1, 6.80, '2024-01-01'),
    ('MAT-004', '028000000043', 'QuickBite Instant Noodles 5pk', 'QuickBite',    'Food',         'Instant Noodles',  0.350, 5, 4.20, '2024-01-01'),
    ('MAT-005', '028000000050', 'CrystalSpring Sparkling 750ml', 'CrystalSpring',  'Beverages',    'Water',            0.750, 1, 2.40, '2024-01-01'),
    ('MAT-006', '028000000067', 'Sunrise Gold Roast 100g',       'Sunrise',  'Beverages',    'Coffee',           0.100, 1, 55.00, '2024-01-01'),
    ('MAT-007', '028000000074', 'ChocoCrunch Chunky 50g',       'ChocoCrunch',   'Confectionery','Chocolate Bars',   0.050, 1, 16.00, '2024-01-01'),
    ('MAT-008', '028000000081', 'PetPrime Gourmet 85g',  'PetPrime',   'Pet Care',     'Wet Cat Food',     0.085, 1, 12.50, '2024-01-01');

INSERT INTO REF.DIM_STORE (RETAILER_CODE, RETAILER_NAME, STORE_ID, STORE_NAME, CITY, STATE, REGION)
VALUES
    ('WMT', 'Walmart',  'WMT-4201', 'Walmart Supercenter #4201', 'Bentonville', 'AR', 'South'),
    ('WMT', 'Walmart',  'WMT-4502', 'Walmart Supercenter #4502', 'Dallas',      'TX', 'South'),
    ('WMT', 'Walmart',  'WMT-3108', 'Walmart Supercenter #3108', 'Chicago',     'IL', 'Midwest'),
    ('KRO', 'Kroger',   'KRO-0531', 'Kroger #531',              'Cincinnati',  'OH', 'Midwest'),
    ('KRO', 'Kroger',   'KRO-0842', 'Kroger #842',              'Atlanta',     'GA', 'South'),
    ('TGT', 'Target',   'TGT-1892', 'Target #1892',             'Minneapolis', 'MN', 'Midwest'),
    ('TGT', 'Target',   'TGT-2104', 'Target #2104',             'Los Angeles', 'CA', 'West');

INSERT INTO REF.DIM_FX_RATES (RATE_DATE, CURRENCY_CODE, RATE_TO_USD)
VALUES
    ('2024-11-01', 'USD', 1.000000),
    ('2024-11-01', 'CAD', 0.721000),
    ('2024-11-01', 'EUR', 1.084000),
    ('2024-11-01', 'GBP', 1.262000),
    ('2024-12-01', 'USD', 1.000000),
    ('2024-12-01', 'CAD', 0.718000),
    ('2024-12-01', 'EUR', 1.079000),
    ('2024-12-01', 'GBP', 1.258000);

-------------------------------------------------------------------------------
-- RAW: SAP Sales Orders (simulates SAP extract landing)
-------------------------------------------------------------------------------
USE SCHEMA RAW;

INSERT INTO RAW.SAP_SALES_ORDERS (RECORD_ID, SALES_ORG, DISTRIBUTION_CHANNEL, MATERIAL_NUMBER, PLANT, CUSTOMER_NUMBER, ORDER_DATE, DELIVERY_DATE, ORDER_QTY, ORDER_QTY_UOM, NET_VALUE, CURRENCY, ORDER_TYPE, _FILE_NAME)
VALUES
    ('SO-2024-000001', '1000', '10', 'MAT-001', 'PL01', 'CUST-R01', '20241101', '20241103', '500',  'EA', '3250.00', 'USD', 'ZSTD', 'sap_extract_20241101.csv'),
    ('SO-2024-000002', '1000', '10', 'MAT-002', 'PL01', 'CUST-R01', '20241101', '20241103', '2000', 'EA', '1494.00', 'USD', 'ZSTD', 'sap_extract_20241101.csv'),
    ('SO-2024-000003', '1000', '10', 'MAT-003', 'PL02', 'CUST-R02', '20241101', '20241104', '300',  'EA', '3240.00', 'USD', 'ZSTD', 'sap_extract_20241101.csv'),
    ('SO-2024-000004', '1000', '10', 'MAT-005', 'PL01', 'CUST-R03', '20241102', '20241105', '1200', 'EA', '2160.00', 'USD', 'ZSTD', 'sap_extract_20241102.csv'),
    ('SO-2024-000005', '1000', '10', 'MAT-001', 'PL01', 'CUST-R02', '20241102', '20241105', '750',  'EA', '4875.00', 'USD', 'ZSTD', 'sap_extract_20241102.csv'),
    ('SO-2024-000006', '1000', '20', 'MAT-004', 'PL03', 'CUST-R01', '20241103', '20241106', '4000', 'EA', '5880.00', 'USD', 'ZPRM', 'sap_extract_20241103.csv'),
    ('SO-2024-000007', '1000', '10', 'MAT-006', 'PL01', 'CUST-R03', '20241103', '20241106', '200',  'EA', '1100.00', 'USD', 'ZSTD', 'sap_extract_20241103.csv'),
    ('SO-2024-000008', '1000', '10', 'MAT-007', 'PL01', 'CUST-R02', '20241104', '20241107', '1500', 'EA', '1200.00', 'USD', 'ZSTD', 'sap_extract_20241104.csv');

-------------------------------------------------------------------------------
-- RAW: Retailer POS Data (simulates retailer file drops)
-------------------------------------------------------------------------------

INSERT INTO RAW.RETAILER_POS (RETAILER_CODE, STORE_ID, UPC, TRANSACTION_DATE, UNITS_SOLD, REVENUE, CURRENCY_CODE, PROMO_FLAG, _FILE_NAME)
VALUES
    ('WMT', 'WMT-4201', '028000000012', '2024-11-01', '45',  '292.50',  'USD', 'N', 'walmart_pos_20241101.csv'),
    ('WMT', 'WMT-4201', '028000000029', '2024-11-01', '120', '179.40',  'USD', 'Y', 'walmart_pos_20241101.csv'),
    ('WMT', 'WMT-4502', '028000000012', '2024-11-01', '38',  '247.00',  'USD', 'N', 'walmart_pos_20241101.csv'),
    ('WMT', 'WMT-4502', '028000000050', '2024-11-01', '95',  '171.00',  'USD', 'N', 'walmart_pos_20241101.csv'),
    ('WMT', 'WMT-3108', '028000000036', '2024-11-01', '22',  '237.60',  'USD', 'N', 'walmart_pos_20241101.csv'),
    ('KRO', 'KRO-0531', '028000000012', '11/01/2024', '30',  '195.00',  'USD', 'N', 'kroger_pos_20241101.csv'),
    ('KRO', 'KRO-0531', '028000000043', '11/01/2024', '85',  '124.95',  'USD', 'Y', 'kroger_pos_20241101.csv'),
    ('KRO', 'KRO-0842', '028000000074', '11/01/2024', '60',  '89.40',   'USD', 'N', 'kroger_pos_20241101.csv'),
    ('TGT', 'TGT-1892', '028000000012', '20241101',   '52',  '338.00',  'USD', 'N', 'target_pos_20241101.csv'),
    ('TGT', 'TGT-1892', '028000000081', '20241101',   '40',  '42.50',   'USD', 'N', 'target_pos_20241101.csv'),
    ('TGT', 'TGT-2104', '028000000050', '20241101',   '110', '198.00',  'USD', 'Y', 'target_pos_20241101.csv'),
    -- Day 2 data (for incremental demo)
    ('WMT', 'WMT-4201', '028000000012', '2024-11-02', '52',  '338.00',  'USD', 'N', 'walmart_pos_20241102.csv'),
    ('WMT', 'WMT-4201', '028000000029', '2024-11-02', '95',  '141.60',  'USD', 'N', 'walmart_pos_20241102.csv'),
    ('KRO', 'KRO-0531', '028000000012', '11/02/2024', '28',  '182.00',  'USD', 'N', 'kroger_pos_20241102.csv'),
    ('TGT', 'TGT-1892', '028000000012', '20241102',   '48',  '312.00',  'USD', 'N', 'target_pos_20241102.csv');

-------------------------------------------------------------------------------
-- RAW: Inventory Snapshots
-------------------------------------------------------------------------------

INSERT INTO RAW.RETAILER_INVENTORY (RETAILER_CODE, STORE_ID, UPC, SNAPSHOT_DATE, ON_HAND_QTY, IN_TRANSIT_QTY, ON_ORDER_QTY, _FILE_NAME)
VALUES
    ('WMT', 'WMT-4201', '028000000012', '2024-11-01', '120', '50',  '200', 'walmart_inv_20241101.csv'),
    ('WMT', 'WMT-4201', '028000000029', '2024-11-01', '350', '100', '0',   'walmart_inv_20241101.csv'),
    ('WMT', 'WMT-4502', '028000000012', '2024-11-01', '85',  '50',  '200', 'walmart_inv_20241101.csv'),
    ('WMT', 'WMT-3108', '028000000036', '2024-11-01', '15',  '0',   '100', 'walmart_inv_20241101.csv'),
    ('KRO', 'KRO-0531', '028000000012', '2024-11-01', '60',  '30',  '150', 'kroger_inv_20241101.csv'),
    ('KRO', 'KRO-0531', '028000000043', '2024-11-01', '200', '0',   '0',   'kroger_inv_20241101.csv'),
    ('TGT', 'TGT-1892', '028000000012', '2024-11-01', '0',   '75',  '200', 'target_inv_20241101.csv'),
    ('TGT', 'TGT-2104', '028000000050', '2024-11-01', '5',   '0',   '500', 'target_inv_20241101.csv');

-------------------------------------------------------------------------------
-- RAW: Promotional Calendar
-------------------------------------------------------------------------------

INSERT INTO RAW.PROMO_CALENDAR (PROMO_ID, PROMO_NAME, RETAILER_CODE, MATERIAL_NUMBER, START_DATE, END_DATE, PROMO_MECHANIC, DISCOUNT_PCT, TRADE_SPEND_USD, _FILE_NAME)
VALUES
    ('PRM-2024-001', 'Holiday Coffee Blitz',     'WMT', 'MAT-001', '2024-11-01', '2024-11-14', 'TPR',         '15', '25000', 'promo_cal_q4.csv'),
    ('PRM-2024-002', 'ChocoCrunch BOGO Nov',          'WMT', 'MAT-002', '2024-11-01', '2024-11-07', 'BOGO',        '50', '18000', 'promo_cal_q4.csv'),
    ('PRM-2024-003', 'QuickBite Family Pack Deal',   'KRO', 'MAT-004', '2024-11-01', '2024-11-10', 'MULTI_BUY',   '20', '12000', 'promo_cal_q4.csv'),
    ('PRM-2024-004', 'CrystalSpring Sparkling Holiday', 'TGT', 'MAT-005', '2024-11-01', '2024-11-21', 'DISPLAY',     '10', '8000',  'promo_cal_q4.csv');

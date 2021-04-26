DROP DATABASE IF EXISTS AITI_JEWELS;

CREATE DATABASE IF NOT EXISTS AITI_JEWELS;

USE AITI_JEWELS;


/* ----------- TABLES CREATION ---------------- */

/* CAMPAIGN TABLE - TO SAVE A SPECIAL DISCOUNT FOR THE FIRST ORDER TO CUSTOMERS THAT ARE FROM THE NEW STORE (FROM THE EXCEL) */
CREATE TABLE IF NOT EXISTS `CAMPAIGN` (                    
  `NEW_CLIENT_SPENDING_CATEGORY` VARCHAR(20) NOT NULL,
  `C_DISCOUNT` DECIMAL(3,2) DEFAULT 0,
  PRIMARY KEY (`NEW_CLIENT_SPENDING_CATEGORY`)
);

/* CUSTOMER TABLE - INFORMATIONS ABOUT OUR CUSTOMERS */
CREATE TABLE IF NOT EXISTS `CUSTOMER` (                
  `CUSTOMER_ID` INTEGER AUTO_INCREMENT NOT NULL,
  `NAME` VARCHAR(45) NOT NULL,
  `BIRTH_YEAR` INTEGER NOT NULL,
  `PHONE_NUMBER` VARCHAR(20) DEFAULT NULL,
  `EMAIL` VARCHAR(100) NOT NULL,
  `TIMES_ORDER` INTEGER DEFAULT 0,
  `MONEY_SPENT` DECIMAL(8,2) DEFAULT 0, 
  `NEW_CLIENT_SPENDING_CATEGORY` VARCHAR(20) NOT NULL, 
  PRIMARY KEY (`CUSTOMER_ID`),
  FOREIGN KEY(`NEW_CLIENT_SPENDING_CATEGORY`) 
  REFERENCES `CAMPAIGN` (`NEW_CLIENT_SPENDING_CATEGORY`)
  ON DELETE CASCADE
  ON UPDATE CASCADE
);

/* CATEGORY TABLE - REFERS TO THE PRODUCT CATEGORY */
CREATE TABLE IF NOT EXISTS `CATEGORY` (
  `CATEGORY_ID` INTEGER NOT NULL,
  `NAME` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`CATEGORY_ID`)
);

/* PRODUCT TABLE - OUR PRODUCT DETAILS */
CREATE TABLE IF NOT EXISTS `PRODUCT` (
  `PRODUCT_ID` INTEGER NOT NULL,
  `CATEGORY_ID` INTEGER NOT NULL,
  `NAME` VARCHAR(45) NOT NULL,
  `PRICE` DECIMAL(8,2) NOT NULL,
  `DISCOUNT` DECIMAL(3,2) NOT NULL,
  `DESCRIPTION` VARCHAR(50) DEFAULT NULL,
  `STOCK` INTEGER UNSIGNED NOT NULL, 
  PRIMARY KEY (`PRODUCT_ID`),
  FOREIGN KEY(`CATEGORY_ID`) 
  REFERENCES `CATEGORY` (`CATEGORY_ID`)
  ON DELETE CASCADE
  ON UPDATE CASCADE 
);

/* PRODUCT RADTING TABLE - SAVES THE PRODUCT RATING MADE BY A CUSTOMER (IT IS NOT NECESSARY THAT THE CUSTOMER HAVE BOUGHT THE PRODUCT 
BECAUSE IT CAN BE AN OPINION BASED ON A PURCHASE OF THE SAME PRODUCT MADE IN ANOTHER STORE */ 
CREATE TABLE IF NOT EXISTS `PRODUCT_RATING` (
  `CUSTOMER_ID` INTEGER NOT NULL,
  `PRODUCT_ID` INTEGER NOT NULL,
  `RATING` INTEGER UNSIGNED NOT NULL,
  CHECK (`RATING` <= 5), 
  PRIMARY KEY (`CUSTOMER_ID`, `PRODUCT_ID`),
  FOREIGN KEY (`CUSTOMER_ID`)
  REFERENCES `CUSTOMER` (`CUSTOMER_ID`)
  ON DELETE CASCADE
  ON UPDATE CASCADE,
  FOREIGN KEY(`PRODUCT_ID`) 
  REFERENCES `PRODUCT` (`PRODUCT_ID`)
  ON DELETE CASCADE
  ON UPDATE CASCADE
);

/* LOCATION TABLE - LOCATION FOR THE DELIVERY OF AN ORDER */ 
CREATE TABLE IF NOT EXISTS `LOCATION` (
  `LOCATION_ID` INTEGER NOT NULL,
  `COUNTRY` VARCHAR(50) NOT NULL,
  `CITY` VARCHAR(50) NOT NULL,
  `STREET_NAME` VARCHAR(50) NOT NULL,
  `DOOR_NUMBER` INTEGER NOT NULL,
  `FLOOR` VARCHAR(20) DEFAULT NULL,
  `ZIP_CODE` VARCHAR(10) NOT NULL, 
  PRIMARY KEY (`LOCATION_ID`)
);

/* SHIPPING TYPE TABLE - SHIPPING DETAILS OF AN ORDER */
CREATE TABLE IF NOT EXISTS `SHIPPING_TYPE` (
  `SHIPPING_ID` INTEGER NOT NULL,
  `TYPE` VARCHAR(20) NOT NULL,
  `COST` DECIMAL(4,2) NOT NULL, 
  PRIMARY KEY (`SHIPPING_ID`)
);

/* ORDER DETAIL TABLE - INFORMATION ABOUT THE ORDERS MADE */
CREATE TABLE IF NOT EXISTS `ORDER_DETAIL` (
  `ORDER_ID` INTEGER NOT NULL,
  `CUSTOMER_ID` INTEGER NOT NULL,
  `LOCATION_ID` INTEGER NOT NULL,
  `SHIPPING_ID` INTEGER NOT NULL,
  `TOTAL_PRICE` DECIMAL(8,2) DEFAULT 0,
  `ORDER_DATE` DATE NOT NULL,
  `EXPECTED_DATE` DATE NOT NULL,
  `DISCOUNT`  DECIMAL(3,2) NOT NULL,
  `ORDER_STATUS` VARCHAR(4) DEFAULT NULL,
  PRIMARY KEY (`ORDER_ID`),
  FOREIGN KEY(`CUSTOMER_ID`) 
  REFERENCES `CUSTOMER` (`CUSTOMER_ID`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE,
  FOREIGN KEY (`LOCATION_ID`)
  REFERENCES `LOCATION` (`LOCATION_ID`)
  ON DELETE CASCADE
  ON UPDATE CASCADE,
  FOREIGN KEY (`SHIPPING_ID`)
  REFERENCES `SHIPPING_TYPE` (`SHIPPING_ID`)
  ON DELETE RESTRICT
  ON UPDATE CASCADE
);

/* ORDER ITEM TABLE - CONNECTION BETWEEN THE ORDER_DETAIL TABLE AND THE PRODUCT TABLE. AN ORDER CAN HAVE SEVERAL PRODUCTS AND 
	WITH DIFFERENT QUANTITIES OF EACH PRODUCT */
CREATE TABLE IF NOT EXISTS `ORDER_ITEM` (
  `ORDER_ID` INTEGER NOT NULL,
  `PRODUCT_ID` INTEGER NOT NULL,
  `QUANTITY` INTEGER NOT NULL,
  PRIMARY KEY (`ORDER_ID`, `PRODUCT_ID`),
  FOREIGN KEY (`ORDER_ID`)
  REFERENCES `ORDER_DETAIL` (`ORDER_ID`)
  ON DELETE CASCADE
  ON UPDATE CASCADE,
  FOREIGN KEY(`PRODUCT_ID`) 
  REFERENCES `PRODUCT` (`PRODUCT_ID`)
  ON DELETE CASCADE
  ON UPDATE CASCADE
);


/* ------------------------------------------- SOME TRIGGERS TO APPLY TO OUR TABLES ----------------------------------- */ 

/* TRIGGER TO CALCULATE THE PRICE OF ALL PRODUCTS IN AN ORDER: 
			HERE WE CONSIDER THE AMOUNT, THE PRICE AND THE DISCOUNT OF EACH PROCUCT ORDERED */ 
DELIMITER $$
CREATE TRIGGER UPDATE_TOTAL_PRICE_ORDER
AFTER INSERT ON ORDER_ITEM FOR EACH ROW
BEGIN 
	DECLARE PRODUCT_PRICE DECIMAL(8,2);
    DECLARE PRODUCT_DISCOUNT DECIMAL(3,2);
    
    SELECT PRICE, DISCOUNT INTO PRODUCT_PRICE, PRODUCT_DISCOUNT
    FROM PRODUCT 
    WHERE PRODUCT.PRODUCT_ID = NEW.PRODUCT_ID;
    
	UPDATE ORDER_DETAIL
		SET ORDER_DETAIL.TOTAL_PRICE = ORDER_DETAIL.TOTAL_PRICE + (PRODUCT_PRICE*(1-PRODUCT_DISCOUNT)*NEW.QUANTITY)
        WHERE NEW.ORDER_ID = ORDER_DETAIL.ORDER_ID;
END$$
DELIMITER ; 

/* WHEN AN ORDER IS PAID, THIS TRIGGER UPDATES THE MONEY SPENT AND THE TIMES ORDER 
			AND IF IT IS A NEW CLIENT ALSO UPDATES THE SPENDING_CATEGORY */
 
DELIMITER $$
CREATE TRIGGER UPDATE_MONEY_TIMES_AND_CATEGORY
AFTER UPDATE ON ORDER_DETAIL FOR EACH ROW
BEGIN
	DECLARE SHIPPING_COST DECIMAL(4,2) ;
    DECLARE CAMPAIGN_DISCOUNT DECIMAL(3,2) ;
    DECLARE NEW_CLIENT_SPENDING_CATEGORY VARCHAR(20) ;
    
    SELECT COST INTO SHIPPING_COST
    FROM SHIPPING_TYPE
    WHERE SHIPPING_TYPE.SHIPPING_ID = NEW.SHIPPING_ID;
    
    SELECT C_DISCOUNT, NEW_CLIENT_SPENDING_CATEGORY INTO CAMPAIGN_DISCOUNT, NEW_CLIENT_SPENDING_CATEGORY
    FROM CAMPAIGN, CUSTOMER
    WHERE CUSTOMER.CUSTOMER_ID = NEW.CUSTOMER_ID AND CAMPAIGN.NEW_CLIENT_SPENDING_CATEGORY = CUSTOMER.NEW_CLIENT_SPENDING_CATEGORY ;
    
    IF NEW.ORDER_STATUS LIKE 'Paid' THEN 
		IF NEW_CLIENT_SPENDING_CATEGORY LIKE 'Not a new client' THEN
			UPDATE CUSTOMER 
			SET CUSTOMER.MONEY_SPENT = CUSTOMER.MONEY_SPENT + SHIPPING_COST + (NEW.TOTAL_PRICE * (1-NEW.DISCOUNT))
			WHERE NEW.CUSTOMER_ID = CUSTOMER.CUSTOMER_ID ;
			UPDATE CUSTOMER 
			SET CUSTOMER.TIMES_ORDER = CUSTOMER.TIMES_ORDER + 1 
			WHERE NEW.CUSTOMER_ID = CUSTOMER.CUSTOMER_ID ;
		ELSE
			UPDATE CUSTOMER 
			SET CUSTOMER.MONEY_SPENT = CUSTOMER.MONEY_SPENT + SHIPPING_COST + ((NEW.TOTAL_PRICE * (1-NEW.DISCOUNT)) * (1-CAMPAIGN_DISCOUNT))
			WHERE NEW.CUSTOMER_ID = CUSTOMER.CUSTOMER_ID ;
			UPDATE CUSTOMER 
			SET CUSTOMER.TIMES_ORDER = CUSTOMER.TIMES_ORDER + 1
			WHERE NEW.CUSTOMER_ID = CUSTOMER.CUSTOMER_ID ;
            UPDATE CUSTOMER 
			SET CUSTOMER.NEW_CLIENT_SPENDING_CATEGORY = 'Not a new client'
			WHERE NEW.CUSTOMER_ID = CUSTOMER.CUSTOMER_ID ;
		END IF ; 
	END IF ;
END$$
DELIMITER ; 

/* --------------------------------------------    LITERAL  C (TRIGGERS)   ---------------------------------------------------------- */

/* ----------     (1) one that updates the stock of products after the customer completes an order     -------------------------------*/
/* In order to make it more funcional, we made 3 triggers to update the stock: */

/* after insert a product into an order, the stock of that product decreases by the quantity ordered of that product */ 
DELIMITER $$
CREATE TRIGGER UPDATE_STOCK_1
AFTER INSERT ON ORDER_ITEM FOR EACH ROW
BEGIN 
	UPDATE PRODUCT
		SET PRODUCT.STOCK = PRODUCT.STOCK - NEW.QUANTITY
        WHERE NEW.PRODUCT_ID = PRODUCT.PRODUCT_ID;
END$$
DELIMITER ; 

DELIMITER $$

/* after update the order of a product (this means changing the quantity ordered), we sum the old quantity and subtract 
	the new quantity to the stock */ 
CREATE TRIGGER UPDATE_STOCK_2
AFTER UPDATE ON ORDER_ITEM FOR EACH ROW
BEGIN 
	UPDATE PRODUCT
		SET PRODUCT.STOCK = PRODUCT.STOCK + OLD.QUANTITY
        WHERE OLD.PRODUCT_ID = PRODUCT.PRODUCT_ID;
	UPDATE PRODUCT
		SET PRODUCT.STOCK = PRODUCT.STOCK - NEW.QUANTITY
        WHERE NEW.PRODUCT_ID = PRODUCT.PRODUCT_ID;
END$$
DELIMITER ; 

/* after delete a product from an order, the stock of that product increases by the quantity ordered of that product */ 
DELIMITER $$
CREATE TRIGGER UPDATE_STOCK_3
AFTER DELETE ON ORDER_ITEM FOR EACH ROW
BEGIN 
	UPDATE PRODUCT
		SET PRODUCT.STOCK = PRODUCT.STOCK + OLD.QUANTITY
        WHERE OLD.PRODUCT_ID = PRODUCT.PRODUCT_ID;
END$$
DELIMITER ; 

/* (2) a trigger that inserts a row in a “log” table if the price of a product is updated */

CREATE TABLE IF NOT EXISTS `LOG` (            
  `LOG_ID` INTEGER UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `TS` DATETIME, 
  `USER` VARCHAR(30),
  `PRODUCT_ID` INTEGER NOT NULL
);

DELIMITER $$
CREATE TRIGGER UPDATE_PRICE
AFTER UPDATE ON PRODUCT FOR EACH ROW
BEGIN 
	IF NEW.PRICE != OLD.PRICE THEN                      /* we only add a register to the log table if the price of a product changes */ 
		INSERT INTO `LOG`(`TS`, `USER`, `PRODUCT_ID`) VALUES
		(NOW(), USER(), NEW.PRODUCT_ID);
	END IF ;
END$$
DELIMITER ; 

/* ----------------------------------------       INSERTS       --------------------------------------------------------------------*/

  INSERT INTO `CAMPAIGN` (`NEW_CLIENT_SPENDING_CATEGORY`, `C_DISCOUNT`) VALUES
  ('Not a new client', 0),
  ('Very Low Spender', 0.05),
  ('Low Spender', 0.07),
  ('Average Spender', 0.10),
  ('High Spender', 0.12),
  ('Very High Spender', 0.15);

  INSERT INTO `CUSTOMER` (`CUSTOMER_ID`, `NAME`, `BIRTH_YEAR`, `PHONE_NUMBER`, `EMAIL`, `NEW_CLIENT_SPENDING_CATEGORY`) VALUES
  (1, 'Diana', 1974, '914738778', 'diana_1974@outlook.com', 'Not a new client'),
  (2, 'José Marques', 1998, '+351962592262', 'jose_marques@gmail.com', 'Not a new client'),
  (3, 'Mariana Luís', 2005, '+351921893869', 'marianaluis@outlook.com', 'Not a new client'),
  (4, 'Elisabete', 2002, '964638666', 'elisabete_pessoal@gmail.com', 'Not a new client'),
  (5, 'Maria Francisca', 2000, '+351911891169', 'maria_francisca@gmail.com', 'Not a new client'),
  (6, 'Justina', 1940, '925535655', 'justina_et40_@gmail.com', 'Not a new client'),
  (7, 'Manel', 1986, '935755779', 'manel_1986@gmail.com', 'Not a new client'),
  (8, 'Sara', 1988, '914535678', 'sara_lopes@outlook.pt', 'Not a new client'),
  (9, 'Rose Charles', 1999, '+1202-555-0418', 'rose_charles@gmail.com', 'Not a new client'),
  (10, 'Kléber Petrus', 1979, '+4902685953332', 'kleber79@outlook.com', 'Not a new client'),
  (11, 'Amber', 2002, '+1020-555-0675', 'amber_02@gmail.com', 'Not a new client'),
  (12, 'Luna', 1997, '+34755731182', 'luna.97_@gmail.com', 'Not a new client'),
  (13, 'Diego', 1969, '+34755731989', 'diego_es69_@gmail.com', 'Not a new client'),
  (14, 'Santiago', 1976, '+34755731333', 'santi_garcia@gmail.com', 'Not a new client'),
  (15, 'Julieta', 1999, '+352918675444', 'julieta99@outlook.com', 'Not a new client'),
  (16, 'Ambrósio', 2000, '+1065-535-0123', 'ambrosio00@gmail.com', 'Not a new client'),
  (17, 'Margarida', 1965, '+351917342789', 'magui65_@gmail.com', 'Not a new client'),
  (18, 'Tiago Pinto', 1983, '+347545674654', 'tigui774@gmail.com', 'Not a new client'),
  (19, 'Samuel', 1997, '+34755754311', 'samuuuel_hk@gmail.com', 'Not a new client'), 
  (20, 'Carla', 1960, '+34733154311', 'carla_sgc@hotmail.com', 'Not a new client'), 
  (21, 'Pedro', 1985, '962589463', 'pedro@gmail.com', 'Not a new client'),
  (22, 'Joana', 1971, '919665784', 'joana.gomes@gmail.com', 'Not a new client'),
  (23, 'Raquel', 1993, '+351921593864', 'raquel_magalhaes21@gmail.com', 'Not a new client'),
  (24, 'Violeta', 1964, '962848412', 'violetarocha@gmail.com', 'Not a new client'),
  (25, 'Ricardo', 1996, '962516247', 'riccgf@gmail.com', 'Not a new client'),
  (26, 'Gonçalo', 1999, '932599662', 'goncaloferreira99@gmail.com', 'Not a new client'),
  (27, 'Mariana', 1968, '912886579', 'mariana_123@gmail.com', 'Not a new client');

  INSERT INTO `CATEGORY` (`CATEGORY_ID`, `NAME`) VALUES
  (1, 'Necklaces'),
  (2, 'Rings'),
  (3, 'Earrings'),
  (4, 'Watches'),
  (5, 'Bracelets');
  
  INSERT INTO `PRODUCT` (`PRODUCT_ID`, `CATEGORY_ID`, `NAME`, `PRICE`, `DISCOUNT`, `DESCRIPTION`, `STOCK`) VALUES
  (1, 1,'Bird Necklace', 72, 0, '12k Gold Necklace', 100),
  (2, 2,'Pandora Heart Ring', 150, 0, '12k Diamont Ring', 320),
  (3, 3,'Pearls', 140, 0.05, 'Ring with Silver Pearls', 30),
  (4, 4,'Nixon Watch A124', 350, 0, 'Gold Watch for man', 120),
  (5, 5,'Pandora Bracelet', 60, 0.1, 'Silver Bracelet model D463',  75),
  (6, 2,'Diamond Ring', 1000, 0, 'New 18CT White Gold, 1.42 Carat Diamond',  50),
  (7, 2,'Attract Ring', 200, 0.1, 'Rhodium-plated',  40),
  (8, 2,'Silpada Ring', 80, 0, 'Triple-Bar Ring in Sterling Silver', 65),
  (9, 3,'Round 3-Stone Ring', 1145, 0,  'Gold Plated Sterling Silver', 40),
  (10, 4,'Michael Kors Watch', 175, 0, 'Watch with Stainless Steel Quartz', 90),
  (11, 1,'Forever Lover Necklace', 120, 0, '14k White Gold Plated', 32),
  (12, 1,'Bead Pendant Necklace', 130, 0, '18k Gold Paperclip Chain Choker', 25),
  (13, 2,'Open Ring', 30, 0.15, 'Jewever S925 Sterling Silver Fox Tail', 120),
  (14, 5,'Classic Tennis Bracelet', 2300, 0, 'PAVOI 14K Gold Plated Cubic Zirconia',  70),
  (15, 1,'Galileo', 978, 0.05, '18K White Gold Solitaire with a look Diamond', 90),
  (16, 2,'Radiant Wedding Band', 728, 0, '37 diamonds, 9KT White gold', 17),
  (17, 3,'Teardrop Earrings', 146, 0, 'Sterling Silver', 29),
  (18, 4,'Audemars Piguet Royal', 3000, 0, '18kt Gold, Stainless Steel, Sapphire Glass', 50),
  (19, 5,'Bangle Swarovski Infinity Bracelet', 200, 0, 'Rhodium-plated',  90),
  (20, 1,'Heart Pendant Necklace', 180, 0, '0.10 Carat Diamond, 9K White Gold',  70),
  (21, 1, 'White Sapphire Trio Necklace', 100, 0.1, '14k Yellow Gold, White Sapphire', 50),
  (22, 1, 'Organic Pearl Bead Necklace', 84, 0, '14k Yellow Gold, Pearl', 60),
  (23, 2, 'Be Mine Ring', 76, 0, 'Rhodium plated sterling silver 925 with onyx', 35),
  (24, 3, 'Bold Hoops', 55, 0, '14k Yellow Gold', 65),
  (25, 4, 'Citizen Calendrier Men', 3200, 0.2, 'Watch BU2020-29X', 80),
  (26, 4, 'Casio G-SHOCK EDIFICE Men', 2250, 0.05, 'Watch EQB1000XD-1A', 30),
  (27, 5, 'Solo Diamond Bracelet', 1196, 0, '14k Yellow Gold, Diamond', 55);

  INSERT INTO `LOCATION` (`LOCATION_ID`, `COUNTRY`, `CITY`, `STREET_NAME`, `DOOR_NUMBER`, `FLOOR`, `ZIP_CODE`) VALUES
  (00, 'Portugal', 'Lisboa', 'Av. da Liberdade', 7, '', '1600-044'),
  (1, 'Portugal', 'Águeda', 'Praça do Município', 20, '2Esq.', 3754-500),
  (2, 'Portugal', 'Santarém', 'Avenida Bernardo Santareno', 1, '', 2009-004),
  (3, 'Portugal', 'Lagoa', 'Rua do Portinho de São Pedro', 50,'', 9560-008),
  (4, 'Portugal', 'Funchal', 'Bairro Ajuda', 27, '', 9000-117),
  (5, 'Lëtzebuerg', 'Mamer', 'Place de l Indépendance', 50, '', 8201),
  (6, 'Italy','Rome', 'Viale Europa', 22, '' , 00144),
  (7, 'Portugal','Afife', 'Travessa da Lapa', 432, '3D', 4900-001),
  (8, 'USA', 'New York', '47 W 13th Street', 11, '2nd Floor', 10011),
  (9, 'Germany','Essen', 'Leimkugelstr', 13, '', 38170),
  (10, 'Spain','Madrid', 'Fuente del Gallo 58', 7,'segundo piso', 15151),
  (11, 'Spain','Barcelona', 'Sanchón de la Sagrada', 27, '', 37466),
  (12, 'Spain','Sevilha', 'Lapuebla de Labarca', 89, 'primer piso', 01306),
  (13, 'USA','New York', '400 Broome Street', 2, '' , 10013),
  (14, 'Portugal','Leiria', 'Rua Valasso Carneiro', 432, '3D', 4006-003),
  (15, 'Portugal','Loulé', 'Rua Principe Filipe', 55,'4E', 7000-226),
  (16, 'Portugal','Lisboa', 'Rua Jacinta Marto', 4, '', 1500),
  (17, 'Spain','Sevilha', 'Lapuebla de Fuerca', 45, '6D', 01506),
  (18, 'USA','California', '600 Birds Street', 4, '' , 60013),
  (19, 'Portugal','Setúbal', 'Rua António Aguiar', 66, '1º esquerdo', 5000-053), 
  (20, 'Portugal','Guimaraes', 'Rua Cesario Verde', 43, '2º esquerdo', 3589-053), 
  (21, 'Portugal', 'Guarda', 'Rua Antonio Sergio', 4, '1º direito', '1166-254'),
  (22, 'Portugal', 'Braga', 'Rua das Fontaínhas', 16, 'R/C direito', '4715-428'),
  (23, 'Portugal', 'Lagos', 'Estrada da Ponta da Piedade', 24, '2º esquerdo', '8601-851'),
  (24, 'Portugal', 'Portalegre', 'Rua do Poco', 2, '', '7370-004'),
  (25, 'Portugal', 'Lisboa', 'Rua Garcia', 38, '4º direito', '1070-136'),
  (26, 'Portugal', 'Castelo Branco', 'Rua Alfredo Moreira', 6, '1º esquerdo', '6160-001'),
  (27, 'Portugal', 'Viana do Castelo', 'Rua de Monserrate', 12, '', '4904-860');

  INSERT INTO `SHIPPING_TYPE` (`SHIPPING_ID`, `TYPE`, `COST`) VALUES
  (1, 'Store', 0),      /* since we acquired the new store it became possible to pick the products at the store */
  (2, 'Express', 0),
  (3, 'Urgent', 4);
  
  INSERT INTO `ORDER_DETAIL` (`ORDER_ID`, `CUSTOMER_ID`, `LOCATION_ID`, `SHIPPING_ID`, `ORDER_DATE`, `EXPECTED_DATE`, `DISCOUNT`) VALUES
  (1, 7, 7, 2, '2020-02-01', '2020-02-14', 0),
  (2, 6, 2, 2, '2018-02-12', '2018-02-18', 0),
  (3, 5, 6, 3, '2019-06-29', '2019-07-01', 0),
  (4, 4, 4, 2, '2016-11-03', '2016-11-07', 0),
  (5, 3, 1, 2, '2018-04-22', '2018-04-29', 0),
  (6, 2, 3, 3, '2019-06-06', '2019-06-11', 0.11),
  (7, 1, 5, 2, '2020-03-24', '2020-03-30', 0.06),
  (8, 8, 8, 2, '2017-02-01', '2017-02-14', 0),
  (9, 10, 11, 2, '2018-07-12', '2018-07-18', 0),
  (10, 9, 9, 3, '2018-05-20', '2018-05-29', 0.1),
  (11, 11, 10, 2, '2017-11-27', '2017-12-05', 0),
  (12, 14, 12, 2, '2018-10-22', '2018-10-29', 0),
  (13, 12, 13, 3, '2019-08-06', '2019-08-7', 0.12),
  (14, 13, 14, 2, '2020-03-22', '2020-03-27', 0.07),
  (15, 15, 17, 3, '2016-12-10', '2016-12-12', 0),
  (16, 16, 18, 2, '2016-11-27', '2016-12-05', 0.6),
  (17, 18, 15, 2, '2019-04-22', '2019-04-29', 0),
  (18, 17, 16, 2, '2020-08-05', '2020-08-10', 0.14),
  (19, 19, 19, 2, '2020-01-22', '2020-01-30', 0.10), 
  (20, 20, 20, 2, '2020-03-22', '2020-03-30', 0.05),
  (21, 21, 21, 2, '2018-03-12', '2018-03-25', 0),
  (22, 21, 21, 2, '2018-06-15', '2018-06-29', 0.2),
  (23, 22, 22, 2, '2019-07-10', '2019-07-20', 0),
  (24, 23, 23, 2, '2019-10-03', '2019-10-09', 0),
  (25, 24, 24, 3, '2018-09-14', '2018-09-16', 0),
  (26, 24, 24, 2, '2020-03-10', '2020-03-17', 0),
  (27, 25, 25, 2, '2017-05-12', '2017-05-25', 0.1),
  (28, 26, 26, 3, '2016-11-04', '2016-11-07', 0.05),
  (29, 26, 26, 2, '2020-12-03', '2020-12-11', 0),
  (30, 27, 27, 2, '2019-06-20', '2019-06-28', 0.25);
  
INSERT INTO `ORDER_ITEM` (`ORDER_ID`, `PRODUCT_ID`, `QUANTITY`) VALUES
  (1, 17, 1), 
  (1, 19, 1),
  (2, 16, 3),
  (3, 9, 1),
  (4, 23, 1),
  (5, 18, 1),
  (6, 20, 1),
  (6, 15, 1),
  (6, 17, 2),
  (7, 18, 4),
  (7, 2, 3),
  (8, 10, 1), 
  (8, 9, 1),
  (9, 23, 2),
  (10, 14, 1),
  (10, 12, 1),
  (10, 13, 1),
  (12, 26, 1),
  (11, 8, 1),
  (14, 11, 2),
  (15, 1, 6),
  (15, 2, 9),
  (15, 3, 1), 
  (16, 5, 2),
  (17, 5, 2),
  (18, 5, 1),
  (18, 1, 8),
  (18, 4, 1),
  (18, 11, 2),
  (19, 8, 1),
  (19, 13, 1), 
  (20, 21, 1),
  (20, 16, 2),
  (21, 22, 1),
  (21, 26, 2),
  (22, 21, 2),
  (22, 24, 2), 
  (22, 27, 2), 
  (23, 23, 3),
  (23, 24, 1),
  (24, 27, 1),
  (25, 21, 1),
  (26, 22, 2),
  (27, 22, 1),
  (27, 26, 2),
  (28, 21, 1),
  (28, 22, 1),
  (28, 25, 2),
  (29, 23, 1),
  (29, 26, 1),
  (30, 21, 1),
  (30, 22, 2),
  (30, 25, 1),
  (30, 27, 1);
  
INSERT INTO `PRODUCT_RATING` (`CUSTOMER_ID`, `PRODUCT_ID`, `RATING`) VALUES
  (1, 20, 4), 
  (3, 14, 5), 
  (4, 21, 4),
  (7, 25, 4), 
  (11, 9, 5),
  (15, 23, 4),
  (10, 17, 5),
  (14, 10, 5),
  (21, 22, 4), 
  (21, 26, 5), 
  (24, 21, 4),
  (27, 25, 4), 
  (27, 27, 5), 
  (8, 9, 5),
  (9, 23, 4),
  (10, 14, 3),
  (8, 10, 5),
  (15, 5, 3),
  (18, 1, 5),
  (15, 4, 5),
  (19, 5, 4),
  (19, 3, 3);

/* AN ORDER IS ONLY CONSIDERED FINISHED WHEN IT IS PAID */
UPDATE ORDER_DETAIL 
SET ORDER_STATUS='Paid'
WHERE ORDER_DETAIL.ORDER_ID BETWEEN 1 AND 30;

/* --------------------------------------------    LITERAL  H (VIEWS)   ---------------------------------------------------------- */

CREATE VIEW INVOICE_HEADS_AND_TOTALS AS 
SELECT OD.ORDER_ID AS `INVOICE NUMBER`, OD.ORDER_DATE AS `DATE OF ISSUE`, C.`NAME` AS `CLIENT NAME`, 
	CONCAT(L.STREET_NAME, ', ', L.DOOR_NUMBER) AS `STREET ADDRESS`, CONCAT(L.CITY, ', ', L.COUNTRY) AS `CITY, COUNTRY`, 
    L.ZIP_CODE AS `ZIP CODE`, CONCAT(COMPANY_LOCATION.COUNTRY, ', ', COMPANY_LOCATION.CITY, ', ',  COMPANY_LOCATION.STREET_NAME,
    ', ', COMPANY_LOCATION.DOOR_NUMBER, ', ', COMPANY_LOCATION.ZIP_CODE) AS `COMPANY ADDRESS`,
    CONCAT(OD.TOTAL_PRICE, '€') AS SUBTOTAL, CONCAT(ROUND(OD.DISCOUNT*100,0),'%') AS DISCOUNT, 
    CONCAT(ST.COST, '€') AS `SHIPPING COST`, CONCAT(ROUND((OD.TOTAL_PRICE*(1-OD.DISCOUNT))+ ST.COST, 2), '€') AS TOTAL 
FROM (SELECT * FROM LOCATION L1 WHERE L1.LOCATION_ID = 00) AS COMPANY_LOCATION, ORDER_DETAIL OD
JOIN CUSTOMER C ON C.CUSTOMER_ID = OD.CUSTOMER_ID
JOIN LOCATION L ON L.LOCATION_ID = OD.LOCATION_ID
JOIN SHIPPING_TYPE ST ON ST.SHIPPING_ID = OD.SHIPPING_ID
WHERE OD.ORDER_ID = 30
GROUP BY OD.ORDER_ID;

CREATE VIEW INVOICE_DETAILS AS
SELECT P.`NAME` AS `DESCRIPTION`, CONCAT(P.PRICE, '€') AS `UNIT COST`, CONCAT(ROUND(P.DISCOUNT*100,0),'%') AS `DISCOUNT`, 
OI.QUANTITY AS `QUANTITY`, CONCAT(ROUND( (P.PRICE*(1-P.DISCOUNT))*OI.QUANTITY , 2), '€') AS `AMOUNT`
FROM ORDER_DETAIL OD
JOIN ORDER_ITEM OI ON OI.ORDER_ID = OD.ORDER_ID
JOIN PRODUCT P ON P.PRODUCT_ID = OI.PRODUCT_ID 
WHERE OD.ORDER_ID = 30;
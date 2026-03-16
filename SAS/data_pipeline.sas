/*
Programmed by: Quincy Cornish
Programmed on: 2025-04-05
Programmed to: Final Project 1

Modified by: 
Modified on:
Modified to: 
*/

x "cd L:\"; 
libname InputDS "ST445\Data\BookData\BeverageCompanyCaseStudy";
libname Results "ST445\Results";
libname axDB2016 access "ST445\Data\BookData\BeverageCompanyCaseStudy\2016data.accdb";

x "cd S:\st445\final";
libname final ".";

filename RawData "L:\st445\Data\BookData\BeverageCompanyCaseStudy";

* Load and clean the Counties dataset from Access DB, dropping and renaming variables;
data final.Counties;
	set axDB2016.counties(drop = region
						  rename = (state=StateFIPS county=CountyFIPS));
run;
libname axDB2016 clear;

* Read in Non-Cola sales data for NC, SC, GA from a fixed-width DAT file;
data final.NonColaSouth;
	infile RawData ('Non-Cola--NC,SC,GA.dat') firstobs=7;
	input 
		stateFips     2.
		countyFips    3.
		productname  $20.
		size     	 $10.
		unitSize      3.
		@39 date      mmddyy10.
		unitssold     7.;
run;

* Read in Energy drink sales for NC, SC, GA from a tab-delimited TXT file;
data final.EnergySouth;
	infile RawData ('Energy--NC,SC,GA.txt') dlm='09'x dsd firstobs=2;
	input stateFips 
		  countyFips 
		  productName : $50. 
		  size : 		$10. 
		  unitSize 
		  date : 		date9. 
		  unitssold;
run;

* Read in Other beverage sales for NC, SC, GA from a CSV file;
data final.OtherSouth;
	infile RawData ('Other--NC,SC,GA.csv') dlm=',' dsd firstobs=2;
	input stateFips 
		  countyFips 
		  productName : $50.
		  size $
		  unitSize 
		  date : 		date9. 
		  unitssold;
run; 

* Read in Non-Cola sales for DC, MD, VA from a DAT file, parsing flexible date formats;
data final.NonColaNorth (drop=_date);
	infile RawData ('Non-Cola--DC-MD-VA.dat') firstobs=5;
	input 
        stateFips     2.
        countyFips    3.
        _code  		 $25.
        _date      	 $10.
        unitssold     7.;

	if index(_date, '/') then 
        date = input(_date, mmddyy10.);
    else 
        date = input(_date, date9.);
run;

* Read in Energy drink sales for DC, MD, VA from a tab-delimited TXT file, flexible date parsing;
data final.EnergyNorth (drop=_date);
	infile RawData ('Energy--DC-MD-VA.txt') dlm='09'x dsd firstobs=2;
	input
		stateFips
		countyFips
		_code : 	$15.
		_date :   	$10.
		unitssold;

	if index(_date, '/') then 
        date = input(_date, mmddyy10.);
    else 
        date = input(_date, date9.);
run;

* Read in Other beverage sales for DC, MD, VA from a CSV file, handling multiple date formats;
data final.OtherNorth (drop=_date);
	infile RawData ('Other--DC-MD-VA.csv') dlm=',' dsd firstobs=2;
	input 
    	stateFips
    	countyFips
    	_code : 	$25.
    	date : 		$20.
    	unitssold;
	if not missing(_date) then do;
    	if index(_date, '/') then
            date = input(_date, mmddyy10.);
    	else if index(rawdate, ',') then
            date = input(_date, worddate.);
        else
            date = input(_date, date9.);
    end;
run;

* Combine all beverage data sets into one, standardize product info and region, and clean variables;
data final.AllDrinks (drop=_:);
	length productName $30;
	set InputDS.ColaNCSCGA(in=cS)
    	InputDS.ColaDCMDVA(in=cN rename=(code=_code))
    	final.NonColaSouth(in= ncS)
    	final.NonColaNorth(in= ncN)
    	final.EnergySouth(in= eS)
    	final.EnergyNorth(in= eN)
    	final.OtherSouth(in=oS)
    	final.OtherNorth(in= oN);

	format date date9.
		   unitssold comma7.;

	if cS or ncS or eS or oS then
		region = "South";
	else if cN or ncN or eN or oN then
		region = "North";
	
	if not missing(_code) then do;
		_seo = scan(_code, 1, '-');        
    	_num = scan(_code, 2, '-');      
    	_vol = scan(_code, 3, '-');     
    	_amt = scan(_code, 4, '-'); 

		productName = catx('-', _seo, _num); 
    	size = _vol; 
    	unitSize = _amt;
	end;

	if index(lowcase(size), 'o') > 0 then do;
		_num = input(scan(size, 1, ' '), best.);
    	size = catx(' ', _num, 'oz');
	end;
	else do;
	    _num = input(scan(size, 1, ' '), best.);
	    size = catx(' ', _num, 'liter');
	end;

	productName = propcase(productName, ' -');
run;

* Sort the combined beverage dataset by state and county FIPS;
proc sort data=final.AllDrinks out=final.sortAllDrinks;
	by stateFips countyFips;
run;

* Sort the counties dataset to prepare for merging;
proc sort data=final.Counties out=final.sortCounties;
	by stateFips countyFips;
run;

* Import soda product reference data from CSV file;
proc import datafile="L:\st445\Data\BookData\BeverageCompanyCaseStudy\sodas.csv"
	out=energyGuide
	dbms=csv
	replace;
	guessingrows=MAX;
run;

* Merge sorted drink and county data, compute sales per 1,000 population, and add derived variables;
data final.AllData (drop=_:);

	retain 
			stateName
			stateFips
			countyName
			countyFips
			region
			popestimate2016
			popestimate2017
			productname 
			type
			flavor
			productCategory
			productSubCategory
			size
			unitSize
			container
			date
			unitssold
			salesPerThousand;

	length 
		type $8
		productSubCategory $10;

	label
			stateName             = "State Name"
			stateFips             = "State FIPS"
			countyName            = "County Name"
			countyFips            = "County FIPS"
			region                = "Region"
			popestimate2016       = "Estimated Population in 2016"
			popestimate2017       = "Estimated Population in 2017"
			productname           = "Beverage Name"
			type                  = "Beverage Type"
			flavor                = "Beverage Flavor"
			productCategory       = "Beverage Category"
			productSubCategory    = "Beverage Sub-Category"
			size                  = "Beverage Volume"
			unitSize              = "Beverage Quantity"
			container             = "Beverage Container"
			date                  = "Sale Date"
			unitssold             = "Units Sold"
			salesPerThousand      = "Sales per 1,000";

	merge final.sortAllDrinks (in=a)
	      final.sortCounties  (in=b);
	by stateFips countyFips;

	if a;

	if index(lowcase(productName), "diet") then 
		type = "Diet";
	else 
		type = "Non-Diet";

	flavor              = "";
	productCategory     = "";

	productSubCategory = "";

	container           = "";
	_avgPop = mean(popestimate2016, popestimate2017);
	salesPerThousand = (unitssold / _avgPop) * 1000;

	format salesPerThousand 7.4
		   popestimate2016 comma10.
		   popestimate2017 comma10.;

	_count + 1;
		if _count > 10000 then stop;
run;

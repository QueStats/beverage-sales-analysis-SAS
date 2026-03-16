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


/*
Programmed by: Quincy Cornish
Programmed on: 2025-04-22
Programmed to: Final Project 2

Modified by: 
Modified on:
Modified to: 
*/

x "cd L:\"; 
libname Results "L:\st445\Results\FinalProjectPhase1";

x "cd S:\st445\final";
libname final ".";

*switching to Duggins p1 data;
data final.alldata;
    set Results.fp01dugginsalldata;
run;

*PHASE 2 START;

*Activity 2.1;
proc sort data=final.alldata out=final.sorteddata(obs=10000);
    where unitSize = 1 and index(lowcase(flavor), 'cola') > 0;
    by statefips flavor size;
run;

ods noproctitle;

title "Activity 2.1: Summary of Units Sold for Single Unit Packages";

proc means data=final.sorteddata noprint;
    by statefips flavor size unitSize;
    var unitssold;
    output out=final.sum(drop=_type_ _freq_)
        sum= min= max= / autoname;
run;

proc print data=final.sum label noobs;
    label 
        statefips = "State FIPS"
        productname = "Product Name"
        size = "Container Size"
        unitsize = "Containers per Unit"
        unitssold_Sum = "Sum"
        unitssold_Min = "Minimum"
        unitssold_Max = "Maximum";
    title "Activity 2.1: Summary of Units Sold for Single Unit Packages";
run;

*Activity 2.3;

title "Cross Tabulation of Single Unit Product Sales in Various States";

proc freq data=final.alldrinks;
where index(lowcase(productName), "cola") > 0 and size in ("1 liter", "12 oz", "2 liter", "20 oz") and stateFips in (13, 37, 45);
tables size*stateFips / nopercent norow nocol;
by productName;
run;

title;

*Activity 3.1;
proc sgplot data=final.AllData(obs 
    where=(
        type='Non-Diet' and 
        productCategory='Non-Cola' and 
        size='12 oz' and 
        unitSize=1));
    hbar stateName /
        response=unitssold
        stat=sum
        group=productName
        groupdisplay=cluster
        dataskin=sheen;
    xaxis label='Total Sold';
    yaxis discreteorder=data;
    keylegend / down=3;
    title1 'Activity 3.1';
    title2 'Single-Unit 12 oz Sales';
    title3 'Regular, Non-Cola Sodas';
run;


*Activity 3.3;
proc sgplot data=final.AllData(
    where=(
        stateName='Georgia' and
        type='Non-Diet' and
        productCategory='Energy' and
        size='8 oz'));
    vbar productName /
        response=unitssold
        stat=mean
        group=unitSize
        groupdisplay=cluster
        dataskin=sheen;
    xaxis discreteorder=data;
    yaxis label='Weekly Average Sales';
    keylegend / title='Containers per Unit';
    title1 'Activity 3.3';
    title2 'Average Weekly Sales, Non-Diet Energy Drinks';
    title3 'For 8 oz Cans in Georgia';
run;

*Activity 3.6;
ods noproctitle;
title1 "Activity 3.6";
title2 "Weekly Average Sales, Nutritional Water Single-Unit Packages";

proc sgplot data=final.AllData( where=(
    productCategory="Nutritional Water" and
    unitSize=1 and
    region="South"
));
   hbar productname / response=unitssold stat=mean    name="Mean"   fillattrs=(color=blue) outlineattrs=(color=blue);
   hbar productname / response=unitssold stat=median  name="Median" barwidth=0.6  fillattrs=(color=red transparency=0.4) outlineattrs=(color=red);
   xaxis label="Georgia, North Carolina, and South Carolina";
   keylegend "Mean" "Median" / title="Weekly Sales";
run;

*Activity 4.4;
ods noproctitle;

title "Monthly Sales Trends by Product Category";
footnote "Data Source: Beverage Company Case Study";

proc sgpanel data=final.alldata(obs=10000);
  panelby productCategory / layout=panel columns=2 rows=2 novarname;
  series x=date y=salesPerThousand / group=productname;
  colaxis interval=month type=time valuesformat=monyy.;
  rowaxis label="Sales per 1,000 People";
run;

*activity 5.5;
title 'Activity 5.5';
title2 'North and South Carolina Sales in August';
title3 '12 oz, Single-Unit, Cola Flavor';
footnote 'Activity 5.5: North and South Carolina Sales in August 12 oz, Single-Unit, Cola Flavor';

proc sgpanel data=final.AllData;
   where stateName in ('North Carolina','South Carolina')
     and flavor     = 'Cola'
     and size       = '12 oz'
     and unitSize   = 1
	 and date between '01AUG2016'd and '31AUG2016'd
   ;
   panelby type / columns=1;
   hbar date / response=unitssold
               group=stateName
               groupdisplay=cluster;
   colaxis type=linear valuesformat=mmddyy8. label=' ';
   rowaxis label='Sales';
run;

*activity 6.2;
title "Quarterly Sales Summaries for 12oz Single-Unit Products";
footnote;

proc report data=final.AllData nowd;
    where container = "single" and size = "12 oz" and stateName = "Maryland";
    column productCategory productname qtr 
           median_units total_units min_units max_units;
    define productCategory / group 'Product Type';
    define productname / group 'Name';
    define qtr / group format=qtrr. 'Quarter';
    define median_units / median alias='unitssold' 'Median Weekly Sales';
    define total_units / sum alias='unitssold' 'Total Sales';
    define min_units / min alias='unitssold' 'Lowest Weekly Sales';
    define max_units / max alias='unitssold' 'Highest Weekly Sales';
run;

*activity 7.1;
data final.sodas;
    infile "L:\st445\Data\BookData\BeverageCompanyCaseStudy\Sodas.csv" dsd firstobs=2;
    length productname $30 type $10 flavor $20 productCategory $20 productSubCategory $20 size $10 container $10;
    input raw_line $200.;
    array sizes[9] $50 _temporary_ ('12 oz' '20 oz' '1 liter' '2 liter' '12 oz' '12 oz' '12 oz' '20 oz' '20 oz');
    array units[9] $50 _temporary_ ('1' '1' '1' '1' '6' '12' '24' '8' '12');
    array containers[9] $10 _temporary_ ('can' 'bottle' 'bottle' 'bottle' 'can' 'can' 'can' 'bottle' 'bottle');

    do i = 1 to 9;
        if _n_ = 1 then do;
            productname = 'Cola';
            type = 'Non-Diet';
            flavor = 'Cola';
            productCategory = 'Soda';
            productSubCategory = '';
        end;

        size = sizes[i];
        container = containers[i];
        unitSize = units[i];
        output;
    end;
    drop raw_line i;
run;

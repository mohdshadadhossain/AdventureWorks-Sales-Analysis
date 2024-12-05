
/**create a permanent sas dataset using libname statement **/

libname AW "/home/u63249491/Adventure_Works";

/*import dataset */

proc import datafile= "/home/u63249491/Adventure_Works/aw_calendar.csv"
dbms =csv out=aw.aw_calendar replace; run;

proc import datafile= "/home/u63249491/Adventure_Works/aw_customers.csv"
dbms =csv out=aw.aw_customer replace; run;

proc import datafile= "/home/u63249491/Adventure_Works/aw_products.csv"
dbms =csv out=aw.aw_products replace; run;

proc import datafile= "/home/u63249491/Adventure_Works/AdventureWorks_Territories.csv"
dbms =csv out=aw.aw_territories replace; run;

proc import datafile= "/home/u63249491/Adventure_Works/aw_product_categories.csv"
dbms =csv out=aw.aw_product_categories replace; run;

proc import datafile= "/home/u63249491/Adventure_Works/aw_product_subcategories.csv"
dbms =csv out=aw.aw_product_subcategories replace; run;

proc import datafile= "/home/u63249491/Adventure_Works/aw_sales_2015.csv"
dbms =csv out=aw.aw_sales_2015 replace; run;

proc import datafile= "/home/u63249491/Adventure_Works/aw_sales_2016.csv"
dbms =csv out=aw.aw_sales_2016 replace; run;

proc import datafile= "/home/u63249491/Adventure_Works/aw_sales_2017.csv"
dbms =csv out=aw.aw_sales_2017 replace; run;

proc print data=aw.aw_territories (obs=4); run;
proc print data=aw.aw_product_categories (obs=4); run;
proc print data=aw.aw_product_subcategories (obs=4); run;
proc print data=aw.aw_customer (obs=4); run;
proc print data=aw.aw_products (obs=4); run;
proc print data=aw.aw_sales_2015 (obs=4); run;
proc print data=aw.aw_sales_2016 (obs=4); run;
proc print data=aw.aw_sales_2017 (obs=4); run;

/* combine sales_2015, sales_2016 and sales 2017 in one datafile sales_2015*/
proc append
    base=aw.aw_sales_2015
    data=aw.aw_sales_2016 force;
run;

proc append
    base=aw.aw_sales_2015
    data=aw.aw_sales_2017;
run;

/*create new dataset that removes rows with missing values from existing dataset*/
data aw.aw_sales;
    set aw.aw_sales_2015;
    if cmiss(of _all_) then delete;
run;

/*get year from order date*/
data aw.aw_sales_15_17; 
set aw.aw_sales; 
OrderYear = year(OrderDate); 
run;

/* making join of all tables and create some calculatable columns*/
proc sql;
create table aw.profit as 
select pc.CategoryName, ps.SubcategoryName,prod.ProductKey,
    prod.ProductName,prod.ProductCost,prod.ProductPrice,sale.OrderDate,
    sale.OrderYear,sale.Month,sale.CustomerKey,sale.TerritoryKey,sale.OrderQuantity,
    (sale.OrderQuantity * prod.ProductCost) as TotalCost,
    (sale.OrderQuantity * prod.ProductPrice) as SaleAmount,
    ((sale.OrderQuantity* prod.ProductPrice)-(sale.OrderQuantity*prod.ProductCost)) as NetProfit
from aw.aw_products as prod,aw.aw_product_subcategories as ps,aw.aw_product_categories as pc,aw.aw_sales_15_17 as sale
where ps.ProductCategoryKey=pc.ProductCategoryKey
    and prod.ProductSubcategoryKey=ps.ProductSubcategoryKey 
    and prod.ProductKey=sale.ProductKey;
Quit;

/*summary statistics */
title 'Adventure Work Summary Statistics';
proc MEANS data=aw.profit N NMISS MIN MAX SUM MEAN MEDIAN STDDEV P1 P25 P50 P75 P99 Q1 Q3;
 VAR ProductKey CustomerKey OrderQuantity TotalCost SaleAmount netprofit;
RUN;

/* creating procedure for territory wise profit, order quantity */
proc sql;
create table aw.territory as 
select tr.continent, pro.CategoryName, pro.OrderQuantity, pro.NetProfit
from aw.profit as pro,aw.aw_territories as tr
where pro.TerritoryKey=tr.SalesTerritoryKey;
Quit;

/*create format*/
proc format ;
	value bkg low - 10000 ="red"
			  10001 - 30000="yellow" 
			  30001 - 10000000="green";
	value bkgN low - 100000 ="red"
			  100001 - 500000="yellow" 
			  500001 - 10000000="green"
			  10000001 - 20000001="tan";
	value bkgP low - 10000 ="red"
			  10001 - 20000="yellow" 
			  20001 - 30000="magenta"
			  30001 - 50001="green";
run;

TITLE 'Adventure Works Sales 2015-2017';
proc tabulate data = aw.territory;
	class continent CategoryName/  style={background= white} ;
	var OrderQuantity/ style={background= white};
	classlev  continent CategoryName / style={background=white};
	table continent *CategoryName, OrderQuantity * {style={background=bkg.}};   
run;

TITLE 'Adventure Works Sales 2015-2017';
proc tabulate data = aw.territory;
	class continent CategoryName/  style={background= white} ;
	var NetProfit/ style={background= white};
	classlev continent CategoryName / style={background= white};
	table continent *CategoryName, NetProfit * {style={background=bkgN.}};   
run;

TITLE 'Adventure Works Sales 2015-2017';
proc tabulate data = aw.profit;
	class OrderYear CategoryName/  style={background= white} ;
	var NetProfit/ style={background=  white};
	classlev OrderYear CategoryName / style={background= white};
	table OrderYear *CategoryName, NetProfit * {style={background=bkgN.}};   
run;

/* sort data according to subcategoryname*/
proc sort data=aw.profit;
by CategoryName;
run;

/* print frequency of subcategory according to category*/
title 'Details of SubCategory by Category of Products';
proc FREQ data = aw.profit ;
tables SubcategoryName; 
by CategoryName;
run;

proc sort data=aw.profit ;
by OrderYear;
run;

/* print frequency of subcategory according to Year*/
title 'Details of Unique Products by Year';
proc FREQ data = aw.profit ;
tables SubCategoryName; 
by OrderYear;
run;

title 'Cummulative Distribution of NetProfit';
proc capability data=aw.profit noprint;
   spec lsl=6.8;
   cdf NetProfit / normal (color=chocolate)
                  odstitle=title;
   inset n mean std pctlss / format = 5.2 header = "Summary Statistics";
run;

/* scatter plot product cost vs net profit over years*/
PROC sgplot data=aw.profit;
title 'Scatter Plot of Product Cost vs NetProfit Over Years';
styleattrs datasymbols=(circlefilled squarefilled starfilled);
scatter x=ProductCost y=NetProfit / group=OrderYear markerattrs=(size=8px);
xaxis grid;
yaxis grid;
run;
ODS GRAPHICS/ RESET;

/* histogram of sale amount */
PROC UNIVARIATE data=aw.profit noprint;
histogram NetProfit/normal(noprint) kernel;
inset mean median std var skewness n/position=nw;
RUN;
Quit;

/* yearly scatter plot*/
proc sgscatter data=aw.profit;
title 'Yearly Scatter Plot Matrix';
matrix TotalCost SaleAmount NetProfit / group=OrderYear diagonal=(histogram kernel);
run;


/* monthly profit*/
proc sql ;
create table aw.sales_monthly as 
select OrderYear,Month,sum(OrderQuantity) as TotalQuantity,sum(TotalCost) as MonthlyCost,sum(SaleAmount) as MonthlySale,
 sum(NetProfit) as MonthlyProfit
from aw.profit
group by 1,2
order by 5 desc;
Quit;


proc print data=aw.sales_monthly noobs;
format MonthlyCost dollar15.2;
format MonthlySale dollar15.2;
format MonthlyProfit dollar15.2;
run;


/* using sgplot to create a bar plot of the monthly sales profit*/
proc sgplot data=aw.sales_monthly;
  title 'Bar Plot of Monthly Sales Profit';
  vbar Month / response=MonthlyProfit categoryorder=respdesc datalabel=MonthlyProfit datalabelpos=data dataskin=matte;
  yaxis label="Sale Month" display= all;
  xaxis grid label="Net Profit";
run;
quit; 

/* using sgplot to create a bar plot of the monthly sale quantity*/
proc sgplot data=aw.sales_monthly;
  title 'Bar Plot of Monthly Sale Quantity';
  vbar Month / response=TotalQuantity categoryorder=respdesc datalabel=TotalQuantity datalabelpos=data dataskin=matte;
  xaxis label="Sale Month" display= all;
  yaxis grid label="Total Quantity";
run; 
quit;
 
/* category wise sale*/
proc sql ;
create table aw.sales_category as 
select CategoryName,SubcategoryName,sum(OrderQuantity) as TotalQuantity,sum(TotalCost) as Total_Cost,
 sum(SaleAmount) as Total_Sale,
 sum(NetProfit) as Total_Profit
from aw.profit_2015
group by 1 , 2;
Quit;

proc print data=aw.sales_category noobs;
format Total_Cost dollar15.2;
format Total_Sale dollar15.2;
format Total_Profit dollar15.2;
run;


proc sgplot data=aw.sales_category;
  title 'Category wise Total Sold Quantity';
  vbar CategoryName /response=TotalQuantity datalabel=TotalQuantity datalabelpos=data dataskin=matte;
  xaxis display= all;
  yaxis grid label=" Total Quantity";
run;
quit;


proc sgplot data=aw.sales_category;
  title 'Subcategory wise Total Sold Quantity';
  vbar SubcategoryName /response=TotalQuantity datalabel=TotalQuantity datalabelpos=data dataskin=matte;
  xaxis display= all;
  yaxis grid label=" Total Quantity";
run;
quit;


/* Net profit time series*/
title 'Net Profit over Time';
proc sgplot data=aw.profit noborder subpixel noautolegend;
  vbar orderdate / response=NetProfit nostatlabel colorresponse=orderdate
                colormodel=(green yellow red) barwidth=1 nooutline;
  xaxis type=time display=(nolabel);
  yaxis display=(noline noticks nolabel) label="Net Profit" grid;
run;

/* correlation between numeric variables*/
proc corr data=aw.profit; 
 VAR  OrderYear OrderQuantity SaleAmount NetProfit;
run;


/* Boxplot for product price */
PROC SGPLOT  DATA = aw.profit;
   VBOX ProductPrice / group = OrderYear;
   title 'Boxplot for Year vs Product Price';
RUN; 

/* Boxplot for product cost */
PROC SGPLOT  DATA = aw.profit;
   VBOX ProductCost / category = Month;
    keylegend / title="Month";
   title 'Boxplot for Month vs Product Cost';
RUN;

/* Boxplot for product price */
PROC SGPLOT  DATA = aw.profit;
   VBOX OrderQuantity / group = OrderYear;
    keylegend / title="OrderYear";
   title 'Boxplot for OrderYear vs Order Quantity';
RUN;  

/* boxplot for netprofit vs month and year */
proc sgpanel data=aw.profit;   
panelby OrderYear / columns=1; 
vbox NetProfit / category=Month;
title 'Net Profit by Month and Year';
run;


/* procedure for finding netprofit for territories*/
proc sql;
create table aw.territory_15_17 as 
select pro.NetProfit ,tr.continent
from aw.profit as pro,aw.aw_territories as tr
where pro.TerritoryKey=tr.SalesTerritoryKey;
Quit;


/* pie chart for displaying continent wise total netprofit for products*/
PROC TEMPLATE;
   DEFINE STATGRAPH pie;
      BEGINGRAPH;
         ENTRYTITLE "Continent Wise NetProfit" / textattrs=(size=14);
         LAYOUT REGION;
            PIECHART CATEGORY = continent / stat=pct dataskin=gloss
            DATALABELLOCATION = OUTSIDE
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie';
            DISCRETELEGEND 'pie';
         ENDLAYOUT;
      ENDGRAPH;
   END;
RUN;

ods graphics / reset width=6.5 in height=4.9 in imagemap;
PROC SGRENDER DATA = aw.territory_15_17 TEMPLATE = pie;
RUN;
Quit;

/* procedure for finding saleamount for territories*/
proc sql;
create table aw.territory1 as 
select pro.SaleAmount,tr.country
from aw.profit as pro,aw.aw_territories as tr
where pro.TerritoryKey=tr.SalesTerritoryKey;
Quit;

/* pie chart for displaying country wise sale amount of products*/
PROC TEMPLATE;
   DEFINE STATGRAPH pie1;
      BEGINGRAPH;
         ENTRYTITLE "Country Wise Sale Amount" / textattrs=(size=14);
         LAYOUT REGION;
            PIECHART CATEGORY = country / stat=pct dataskin=gloss
            DATALABELLOCATION = OUTSIDE
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie1';
            DISCRETELEGEND 'pie1';
         ENDLAYOUT;
      ENDGRAPH;
   END;
RUN;

ods graphics / reset width=6.5 in height=4.9 in imagemap;
PROC SGRENDER DATA = aw.territory1 TEMPLATE = pie1;
RUN;
Quit;

/* procedure for finding totalcost for countries*/
proc sql;
create table aw.territory2 as 
select pro.TotalCost, tr.Country
from aw.profit as pro,aw.aw_territories as tr
where pro.TerritoryKey=tr.SalesTerritoryKey;
Quit;

/* pie chart for displaying country wise total cost of products*/
PROC TEMPLATE;
   DEFINE STATGRAPH pie2;
      BEGINGRAPH;
         ENTRYTITLE "Country Wise TotalCost" / textattrs=(size=14);
         LAYOUT REGION;
            PIECHART CATEGORY = country / stat=pct dataskin=gloss
            DATALABELLOCATION = OUTSIDE
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie2';
            DISCRETELEGEND 'pie2';
         ENDLAYOUT;
      ENDGRAPH;
   END;
RUN;

ods graphics / reset width=6.5 in height=4.9 in imagemap;
PROC SGRENDER DATA = aw.territory2 TEMPLATE = pie2;
RUN;
Quit;

proc sql;
create table aw.yearprofit as 
select NetProfit, OrderYear
from aw.profit as pro;
Quit;

/* pie chart for displaying Year wise total profits*/
PROC TEMPLATE;
   DEFINE STATGRAPH pie3;
      BEGINGRAPH;
         ENTRYTITLE "Year wise Total Profit" / textattrs=(size=14);
         LAYOUT REGION;
            PIECHART CATEGORY = OrderYEar / stat=pct dataskin=gloss
            DATALABELLOCATION = OUTSIDE
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie3';
            DISCRETELEGEND 'pie3';
         ENDLAYOUT;
      ENDGRAPH;
   END;
RUN;

ods graphics / reset width=6.5 in height=4.9 in imagemap;
PROC SGRENDER DATA = aw.yearprofit TEMPLATE = pie3;
RUN;
Quit;

/* procedure for finding order quantity for continent and region*/
proc sql;
create table aw.territory3 as 
select sl.OrderQuantity, tr.Continent,tr.region
from aw.aw_sales as sl,aw.aw_territories as tr
where sl.TerritoryKey=tr.SalesTerritoryKey;
Quit;

/* grouped bar plot for displaying order quantity for continent and region*/
PROC SGPLOT DATA =aw.territory3;
 VBAR Continent / GROUP = Region GROUPDISPLAY = CLUSTER;
TITLE 'Total Sale Quantity by Continent and Region';
RUN;
Quit;

/* making table for customers*/
proc sql;
create table aw.customer as 
select cs.CustomerKey,cs.MaritalStatus,cs.Gender,cs.AnnualIncome,cs.TotalChildren,cs.EducationLevel,cs.Occupation,
 pr.CategoryName, pr.SubcategoryName,pr.ProductName,pr.ProductCost,pr.ProductPrice,pr.Month,pr.OrderQuantity,
    pr.TotalCost,pr.SaleAmount,pr.NetProfit
  from aw.profit as pr,aw.aw_customer as cs
   where pr.CustomerKey=cs.CustomerKey;
Quit;

/* cleaing data */
data aw.cust;
    set aw.customer;
    if gender = "N" then delete;
run;

/* procedure for finding order quantity for occupation and gender*/
proc sql;
create table aw.cust1 as 
select CustomerKey,occupation,gender from aw.cust
Quit;

/* grouped bar plot for displaying order quantity for gender and occupation*/
PROC SGPLOT DATA =aw.cust1;
 VBAR Occupation / GROUP = Gender GROUPDISPLAY = CLUSTER dataskin=matte;
TITLE 'Customers by Occupation and Gender Group';
RUN;
Quit;


/* procedure for finding order quantity for education level and gender*/
proc sql;
create table aw.cust2 as 
select CustomerKey,EducationLevel,gender from aw.cust
order by 3,2;
Quit;

/* grouped bar plot for displaying customers for gender and EducationLevel*/
PROC SGPLOT DATA =aw.cust2;
 VBAR Gender / GROUP = EducationLevel GROUPDISPLAY = CLUSTER dataskin=matte;
TITLE 'Customers by EducationLevel and Gender Group';
RUN;
Quit;



title 'Net Profit by Gender and Occupation';
proc sgplot data=aw.cust;
  vbar Gender / response=NetProfit stat=sum group=Occupation nostatlabel;
  xaxis display=(nolabel);
  yaxis grid;
  run;

/* procedure for finding total order quantity for Subcategory name and gender*/
proc sql;
create table aw.cust3 as 
select gender,SubCategoryName,sum(OrderQuantity) as TotalQuantity from aw.cust
group by 1,2
having TotalQuantity>5000
order by 3,2,1;
Quit;

/* displaying most selling products according to gender */
TITLE 'Adventure Works Valuable Products 2015-2017';
proc tabulate data = aw.cust3;
	class gender subCategoryName/  style={background= orange} ;
	var TotalQuantity/ style={background= pink};
	classlev gender SubCategoryName / style={background=gold};
	table gender *SubCategoryName, TotalQuantity * {style={background=bkgP.}};   
run;

proc sql;
create table aw.cust4 as 
select gender,SubCategoryName,OrderQuantity from aw.cust
order by 3,2,1;
Quit;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=AW.CUST4;
    title 'Bar Graph for Order Frequency';
	vbar Gender / group=SubcategoryName groupdisplay=cluster;
	yaxis grid;
run;

ods graphics / reset;


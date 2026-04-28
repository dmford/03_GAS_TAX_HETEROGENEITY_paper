* full.do

clear all

* (1) HPCC cluster, and (2) personal machine: 
*cd "\bigdata\mbateslab\dford013\coding\03_GAS_TAX_HETEROGENEITY_paper"
cd "~\coding\03_GAS_TAX_HETEROGENEITY_paper\"

********************************************************************************

*ssc install statastates
*ssc install asdocx

capture log close
log using "3000_code\SMCL_logs\full", smcl replace

**************************************************
* ELASTICITY FROM TABLE 9 (Bates & Kim, JAE 2022)
**************************************************
set obs 51

gen state_abbrev = ""

statastates, abbrev(state_abbrev)
keep if state_abbrev != ""
drop _merge

gen elasticity = .

replace elasticity = -0.61 if state_abbrev == "AK"
replace elasticity = -0.57 if state_abbrev == "AL"
replace elasticity = -0.25 if state_abbrev == "AZ"
replace elasticity = -0.66 if state_abbrev == "AR"
replace elasticity = -0.55 if state_abbrev == "CA"
replace elasticity = -0.44 if state_abbrev == "CO"
replace elasticity = -0.60 if state_abbrev == "CT"
replace elasticity = -0.62 if state_abbrev == "DE"
replace elasticity = -1.55 if state_abbrev == "DC"
replace elasticity = -0.49 if state_abbrev == "FL"
replace elasticity = -0.49 if state_abbrev == "GA"
replace elasticity = -0.34 if state_abbrev == "HI"
replace elasticity = -0.28 if state_abbrev == "ID"
replace elasticity = -0.61 if state_abbrev == "IL"
replace elasticity = -0.57 if state_abbrev == "IN"
replace elasticity = -0.78 if state_abbrev == "IA"
replace elasticity = -0.57 if state_abbrev == "KS"
replace elasticity = -0.64 if state_abbrev == "KY"
replace elasticity = -0.46 if state_abbrev == "LA"
replace elasticity = -0.74 if state_abbrev == "ME"
replace elasticity = -0.54 if state_abbrev == "MD"
replace elasticity = -0.66 if state_abbrev == "MA"
replace elasticity = -0.64 if state_abbrev == "MI"
replace elasticity = -0.58 if state_abbrev == "MN"
replace elasticity = -0.45 if state_abbrev == "MS"
replace elasticity = -0.60 if state_abbrev == "MO"

replace elasticity = -0.15 if state_abbrev == "MT"
replace elasticity = -0.64 if state_abbrev == "NE"
replace elasticity = -0.31 if state_abbrev == "NV"
replace elasticity = -0.44 if state_abbrev == "NH"
replace elasticity = -0.66 if state_abbrev == "NJ"
replace elasticity = -0.56 if state_abbrev == "NM"
replace elasticity = -0.59 if state_abbrev == "NY"
replace elasticity = -0.51 if state_abbrev == "NC"
replace elasticity = -0.48 if state_abbrev == "ND"
replace elasticity = -0.68 if state_abbrev == "OH"
replace elasticity = -0.60 if state_abbrev == "OK"
replace elasticity = -0.56 if state_abbrev == "OR"
replace elasticity = -0.98 if state_abbrev == "PA"
replace elasticity = -0.62 if state_abbrev == "RI"
replace elasticity = -0.38 if state_abbrev == "SC"
replace elasticity = -0.56 if state_abbrev == "SD"
replace elasticity = -0.67 if state_abbrev == "TN"
replace elasticity = -0.40 if state_abbrev == "TX"
replace elasticity = -0.42 if state_abbrev == "UT"
replace elasticity = -0.33 if state_abbrev == "VT"
replace elasticity = -0.59 if state_abbrev == "VA"
replace elasticity = -0.52 if state_abbrev == "WA"
replace elasticity = -0.34 if state_abbrev == "WV"
replace elasticity = -0.51 if state_abbrev == "WI"
replace elasticity = -0.32 if state_abbrev == "WY"

**************************************************
* ELASTICITY FROM M1 + M2
**************************************************
* b1_logprice is from model 1 (without covariates)
* b2_logprice is from model 2 (with covariates)
	* note: neither of these match the table, nor does the resulting output from "Table 2. Main Results.do" match JAE paper
merge 1:1 state_fips using "2000_data\bk_elasticities.dta", nogen
drop statename 

**************************************************
* COVARIATES FROM B&K
**************************************************
* public_tran_average was missing for AK, DC, HI 
	* re-pulled the data using 1980 5pct sample, replacing 
merge 1:m state_name using "2000_data\gastax_merged_dataset", keepusing(year flattest flatter flat not_flat min_temp avg_temp max_temp rain_inches)

* HI and DC have 1obs/ea, without year info
keep if (year==1980 | state_abbrev=="HI" | state_abbrev=="DC")

duplicates drop
drop _merge

* Missing DC flatness (double-checked Dobson & Campbell 2014)
replace flattest = .1 if state_abbrev=="DC"
replace flatter = .4 if state_abbrev=="DC"
replace flat = .20 if state_abbrev=="DC"
replace not_flat = .75 if state_abbrev=="DC"

* Missing DC temperatures (doesn't exist on ncei.noaa.gov, used "extremeweatherwatch.com" and "weather.gov")
replace min_temp = 12 if state_abbrev=="DC"
replace avg_temp = 59.5 if state_abbrev=="DC"
replace max_temp = 103 if state_abbrev=="DC"
replace rain_inches = 29.32 if state_abbrev=="DC"

* Missing HI temperatures (double-checked ncei.noaa.gov + verified other states for consistency)
	* had to use 1991, data wasn't available beforehand
	* same for precipitation, also verified
replace min_temp = 77 if state_abbrev=="HI"
replace avg_temp = 65.625 if state_abbrev=="HI"
replace max_temp = 53.4 if state_abbrev=="HI"
replace rain_inches = 66.78 if state_abbrev=="HI"

merge 1:1 state_fips using "2000_data\TRANWORK_1980_5pct", nogen

rename pub_tran_average_1980 pub_tran_average

save "2000_data\base_data", replace

**************************************************
* ADDING LICENSE + ROAD MILE INFO 
**************************************************
import excel "2000_data\highway_stats_1980_extra.xlsx", sheet("Sheet1") firstrow clear

gen urban_roadshare = urban_mileage / total_mileage
gen rural_roadshare = rural_mileage / total_mileage

merge 1:1 state_fips using "2000_data\base_data", nogen

**************************************************
* USING PCA TO GENERATE FLATNESS_INDEX 
**************************************************
gen Flat = flat
gen Flatter = flatter
gen Flattest = flattest
*gen NotFlat = not_flat

local flatness_list = "Flat Flatter Flattest" 
corr `flatness_list' 

pca `flatness_list'

local ncomp 2

*screeplot, yline(1) saving("6000_LaTeX\flatness_index_screeplot", replace) name("flatness_index_screeplot")
*graph export "6000_LaTeX\flatness_index_screeplot.eps", replace
*graph export "6000_LaTeX\flatness_index_screeplot.pdf", replace

pca `flatness_list', comp(`ncomp')

rotate, varimax 

estat loadings 
predict flatness_index, score
gen FlatnessIndex = flatness_index

estpost correlate FlatnessIndex `flatness_list', matrix label 
esttab using "6000_LaTeX\flatness_index_correlation.tex", unstack not noobs compress replace

drop Flat Flatter Flattest FlatnessIndex

save "2000_data\base_data", replace

**************************************************
* USING PCA TO GENERATE WEATHER_INDEX 
**************************************************
gen MinTemp = min_temp
gen AvgTemp = avg_temp
gen MaxTemp = max_temp
gen Rain = rain_inches

local weather_list = "MinTemp AvgTemp MaxTemp Rain" 
corr `weather_list' 

pca `weather_list'

local ncomp 3

*screeplot, yline(1) saving("6000_LaTeX\weather_index_screeplot", replace) name("weather_index_screeplot")
*graph export "6000_LaTeX\weather_index_screeplot.eps", replace
*graph export "6000_LaTeX\weather_index_screeplot.pdf", replace

pca `weather_list', comp(`ncomp')

rotate, varimax 

estat loadings 
predict weather_index, score
gen WeatherIndex = weather_index

estpost correlate WeatherIndex `weather_list', matrix label 
esttab using "6000_LaTeX\weather_index_correlation.tex", unstack not noobs compress replace

drop WeatherIndex MinTemp AvgTemp MaxTemp Rain

save "2000_data\base_data", replace

**************************************************
* TOTAL, LAND, AND WATER AREAS 
**************************************************
import delimited "2000_data\state_area_measures.txt", clear 

drop v3 v5 v7 v8 v9 v10 v11 v12 v13 v14 v15 v16 v17 
rename v1 state_name 
rename v2 total_area 
rename v4 land_area 
rename v6 water_area 

destring total_area, replace ignore(",") 
destring land_area, replace ignore(",") 
destring water_area, replace ignore(",") 

statastates, name(state_name)
drop _merge

merge 1:1 state_fips using "2000_data\base_data"
drop _merge

save "2000_data\base_data", replace

**************************************************
* IDENTIFYING STATE BORDER-PAIRS 
**************************************************
import delimited "2000_data\census_county_adjacency_file_2025.txt", clear 

gen state_fips = int(countygeoid/1000)
rename countygeoid FIPSCode
drop if state_fips > 56

gen neighbor_state = substr(neighborname, -2, 2)
statastates, fips(state_fips)
drop _merge

* keeping only border counties 
	* HI has blanks for neighborname, causing issues
keep if (state_abbrev != neighbor_state) | (state_abbrev=="AK") | (state_abbrev=="HI")
*drop if state_fips==15

* generating "border_states" dataset, used to determine border state pricewise-dominance 
keep state_abbrev neighbor_state 

drop if state_abbrev == neighbor_state

duplicates drop 

order state_abbrev neighbor_state
sort state_abbrev

save "2000_data\border_states", replace

**************************************************
* DETERMINING BORDER STATE PRICEWISE DOMINANCE 
**************************************************
use "pciv\PCIV\Application\EstimationData\temp_all.dta", replace

drop state_abbrev state_name 
statastates, name(state)

keep state_abbrev year month price

order state_abbrev year month price
sort state_abbrev year month 

save "2000_data\state_year_month_prices", replace

joinby state_abbrev using "2000_data\border_states"

rename state_abbrev state_main 
rename price price_main 

order state_main year month price_main 
sort state_main year month price_main 

gen state_abbrev = neighbor_state 

joinby state_abbrev year month using "2000_data\state_year_month_prices"

drop state_abbrev 
rename price neighbor_price 

* identifying (+ counting) year-month obs where neighbor is cheaper
gen neighbor_cheaper = neighbor_price < price_main 

* counting number of cheaper neighbors for each yearmo 
bysort state_main year month: egen yearmo_n_cheaper = total(neighbor_cheaper)

* majority rule: neighbor is cheaper in most months 
bysort state_main neighbor_state: egen months_total = count(neighbor_price) 
bysort state_main neighbor_state: egen months_cheaper = total(neighbor_cheaper)
gen pct_cheaper = months_cheaper / months_total 
gen consistently_cheaper = pct_cheaper >= 0.75 

* identifying if neighbor is cheaper in ALL months 
gen always_cheaper = (months_cheaper == months_total) 

* calculating average price differences 
gen price_diff = price_main - neighbor_price 

bysort state_main neighbor_state: egen avg_pdiff = mean(price_diff)
gen avg_neighbor_cheaper = avg_pdiff > 0 

* ranking neighboring-states by median price advantage 
bysort state_main neighbor_state: egen median_pdiff = median(price_diff)

* collapsing back to state+neighbor combinations 
collapse (mean) pct_cheaper ///
	(sum) months_cheaper (count) months_total ///
	(mean) avg_pdiff ///
	(median) median_pdiff, ///
	by(state_main neighbor_state) 

drop months_total months_cheaper 
	
* labeling variables 
la var pct_cheaper "State-Neighbor Pairs: Percentage of Months Where Neighbor Is Cheaper"
la var avg_pdiff "State-Neighbor Pairs: Average Price Above Neighbor"
la var median_pdiff "State-Neighbor Pairs: Median Price Above Neighbor"

rename state_main state_abbrev 

* repeating for state-neighbor pairs 
bysort state_abbrev neighbor_state: egen temp_frequently_cheaper = mean(pct_cheaper)
sum temp_frequently_cheaper 
gen frequently_cheaper = temp_frequently_cheaper < r(mean)

bysort state_abbrev neighbor_state: egen temp_avg_cheaper = mean(avg_pdiff)
sum temp_avg_cheaper 
gen avg_cheaper = temp_avg_cheaper < r(mean)

bysort state_abbrev neighbor_state: egen temp_median_cheaper = mean(median_pdiff)
sum temp_median_cheaper 
gen median_cheaper = temp_median_cheaper < r(mean)

drop temp*

save "2000_data\state_price_dominance", replace

**************************************************
* POPULATIONS BY COUNTY
**************************************************
import excel "2000_data\e8089co.xls", sheet("E8089CO") cellrange(A14:C6703) firstrow clear
drop if FIPSCode == "" | FIPSCode == "FIPS Code"
*xls file has two of each row, because they stack two tables (1980-1984est) and (1985est-1989est)
	*duplicates drop keeps first obs, so I simple drop repeat observations (should lose half of dataset)
duplicates drop FIPSCode AreaName, force
gen state_fips = substr(FIPSCode, 1,2)
destring state_fips, replace
destring FIPSCode, replace
destring Census1980, replace
statastates, fips(state_fips)
drop if state_fips==0
drop _merge

*Shannon County renamed to Oglala Lakota County in 2015, new FIPS
replace FIPSCode = 46102 if FIPSCode == 46113

save "2000_data\county_pop", replace

**************************************************
* BORDER COUNTY POPULATION SHARES
**************************************************
import delimited "2000_data\census_county_adjacency_file_2025.txt", clear 

gen state_fips = int(countygeoid/1000)
rename countygeoid FIPSCode
drop if state_fips > 56

gen neighbor_state = substr(neighborname, -2, 2)
statastates, fips(state_fips)
drop _merge

* keeping only border counties 
	* HI has blanks for neighborname, causing issues
keep if (state_abbrev != neighbor_state) | (state_abbrev=="AK") | (state_abbrev=="HI")
*drop if state_fips==15

gen is_border_county = 1

bysort FIPSCode: egen county_border = sum(length)
bysort state_fips: egen border_county_length = sum(length)

* correction for AK, HI (no bordering states at all, mis-dropped above)
replace is_border_county = 0 if inlist(state_abbrev, "AK", "HI")
replace county_border = 0 if inlist(state_abbrev, "AK", "HI")
replace border_county_length = 0 if inlist(state_abbrev, "AK", "HI")

*(note that border_county_length is 529291 for CT)
save "2000_data\border_county_info", replace

* generating "border_states" dataset, used to determine border state pricewise-dominance 
keep state_abbrev neighbor_state 

drop if state_abbrev == neighbor_state

duplicates drop 

order state_abbrev neighbor_state
sort state_abbrev

save "2000_data\border_states", replace

use "2000_data\border_county_info", replace

*keep if is_border==1 
*keep state_abbrev neighbor_state 
*duplicates drop 
*use "2000_data\border_states", replace 

drop countyname neighborname neighborgeoid length neighbor_state 

duplicates drop 

merge 1:m FIPSCode using "2000_data\county_pop" 

*CT changed from "counties" to "planning regions", recognized by the Census in 2023
	*I can look, and all counties from 1980 census are border counties
	*Naugatuck Valley is the only non-border planning region, but not recognized by census in 1980
		*point: I can have border info by county for CT (100%) 
drop if _merge==1
drop _merge
replace is_border_county = 1 if state_fips == 9

* DC is an exception to this drop, all border 
bysort state_fips: egen state_pop = max(Census1980)
drop if (state_pop == Census1980) & (state_abbrev!="DC")

bysort state_fips: egen border_pop = sum(Census1980) if is_border==1
replace border_pop=0 if inlist(state_abbrev, "AK", "HI")

gen border_pop_share = border_pop / state_pop
drop if border_pop_share == .

duplicates drop state_fips, force

drop FIPSCode is_border_county county_border 

*noted that border_county_length is 529291 for CT
replace border_county_length = 529291 if state_fips==9

merge 1:1 state_fips using "2000_data\base_data", nogen

drop AreaName Census1980 year

rename licensed_adult_rate licensure

gen pop_density = ((state_pop / land_area)/100)
gen any_flat = flat + flatter + flattest

replace land_area = (land_area / 1000000)
replace urban_mileage = (urban_mileage / 100000)
replace total_mileage = (total_mileage / 100000)
replace state_pop = state_pop/1000000
replace licensure = (licensure / 1000)
replace licensed_drivers = licensed_drivers/1000000

order state_fips state_abbrev state_name elasticity b1_logprice b2_logprice pub_tran_average rain_inches min_temp avg_temp max_temp flattest flatter flat not_flat total_area land_area water_area border_county_length border_pop state_pop border_pop_share
sort state_fips

drop rural_mileage rural_roadshare 
drop licensed_rate 
drop total_area water_area
drop border_county_length

save "2000_data\gas_elasticity_dataset", replace

**************************************************
* LABELING VARIABLES + CORRELATION MATRICES
**************************************************
use "2000_data\gas_elasticity_dataset", replace

* outcomes
local outcomes = "b1_logprice b2_logprice elasticity"
la var b1_logprice "Elasticity, Without Controls"
la var b2_logprice "Elasticity, With Controls"
la var elasticity "Elasticity"

* environmental predictors 
local environmental_predictors = "land_area" 
la var land_area "Land Area (M Sq. Miles)"
la var min_temp "Min. Temp. (F)"
la var avg_temp "Avg. Temp. (F)"
la var max_temp "Max. Temp. (F)"
la var rain_inches "Annual Rain (Inches)"
la var weather_index "Weather Quality Index"
la var flat "Flat Area"
la var flatter "Flatter Area"
la var flattest "Flattest Area"
la var any_flat "Non-Steep"
la var flatness_index "Flatness Ind."

* transportation predictors 
local transportation_predictors = "urban_mileage total_mileage urban_roadshare pub_tran_average"
la var urban_mileage "Urban Road-Miles"
la var total_mileage "Total Road-Miles"
la var urban_roadshare "Road Urbanization"
la var pub_tran_average "Pub. Trans. Usage"

* demographic predictors
local demographic_predictors = "state_pop pop_density border_pop_share licensure"
la var state_pop "State Pop. (M)"
la var pop_density "Pop. Per 100 Sq. Miles"
la var border_pop_share "Border Pop. Share"
la var licensure "Licensure Rate"

* analytical weight
local aweight = "licensed_drivers"
la var licensed_drivers "Licensed Drivers (M)"

local x_list = "`environmental_predictors' `transportation_predictors' `demographic_predictors' `aweight'"

**************************************************
* DSTATS + REGRESSIONS + ESTIMATES TABLES
**************************************************
* main regressions: 
local y = 1
foreach outcome of local outcomes {
	collect clear 
	dtable b1_logprice b2_logprice land_area min_temp avg_temp max_temp rain_inches `transportation_predictors' `demographic_predictors' `aweight', ///
		name(dstats_`outcome') nosample title("Raw Differences") 
	collect export "6000_LaTeX\dstats_y`y'.tex", replace tableonly 
	
	reg `outcome' land_area, robust
	eststo y`y'_m1
	estadd local weighted "No"

	reg `outcome' land_area [aweight=`aweight'], robust 
	eststo y`y'_m1_w
	estadd local weighted "Yes"
	
	reg `outcome' weather_index, robust
	eststo y`y'_m2
	estadd local weighted "No"
	reg `outcome' weather_index [aweight=`aweight'], robust 
	eststo y`y'_m2_w
	estadd local weighted "Yes"
	
	reg `outcome' urban_roadshare, robust
	eststo y`y'_m3
	estadd local weighted "No"
	reg `outcome' urban_roadshare [aweight=`aweight'], robust 
	eststo y`y'_m3_w
	estadd local weighted "Yes"
	
	reg `outcome' pop_density, robust
	eststo y`y'_m4
	estadd local weighted "No"
	reg `outcome' pop_density [aweight=`aweight'], robust 
	eststo y`y'_m4_w
	estadd local weighted "Yes"
	
	reg `outcome' border_pop_share, robust
	eststo y`y'_m5
	estadd local weighted "No"
	reg `outcome' border_pop_share [aweight=`aweight'], robust 
	eststo y`y'_m5_w
	estadd local weighted "Yes"
	
	reg `outcome' land_area weather_index urban_roadshare pop_density border_pop_share, robust
	eststo y`y'_m6
	estadd local weighted "No"
	reg `outcome' land_area weather_index urban_roadshare pop_density border_pop_share [aweight=`aweight'], robust 
	eststo y`y'_m6_w
	estadd local weighted "Yes"
	
	esttab y`y'_m1 y`y'_m2 y`y'_m3 y`y'_m4 y`y'_m5 y`y'_m6 using "6000_LaTeX\etable_y`y'_main.tex", replace ///
		drop(_cons) star(* 0.1 ** 0.05 *** 0.01) b(%4.3f) se(%4.3f) nolegend nonotes ///
		coef(land_area "Land Area" weather_index "Weather Ind." urban_roadshare "Urbanization" pop_density "Pop. Density" border_pop_share "Border Pop.") ///
		mlabels(none) mgroups("Gas Price Elasticity", span prefix(\multicolumn{@span}{c}{) suffix(})) stats(weighted N, label("Weights" "States:"))

	esttab y`y'_m1_w y`y'_m2_w y`y'_m3_w y`y'_m4_w y`y'_m5_w y`y'_m6_w using "6000_LaTeX\etable_y`y'_main_w.tex", replace ///
		drop(_cons) star(* 0.1 ** 0.05 *** 0.01) b(%4.3f) se(%4.3f) nolegend nonotes ///
		coef(land_area "Land Area" weather_index "Weather Ind." urban_roadshare "Urbanization" pop_density "Pop. Density" border_pop_share "Border Pop.") ///
		mlabels(none) mgroups("Gas Price Elasticity", span prefix(\multicolumn{@span}{c}{) suffix(})) stats(weighted N, label("Weights" "States:"))
	
	local ++y
}

* environmental regressions: 
local y = 1
foreach outcome of local outcomes {
	reg `outcome' land_area, robust
	eststo y`y'_m1
	estadd local weighted "No"
	reg `outcome' land_area [aweight=`aweight'], robust 
	eststo y`y'_m1_w
	estadd local weighted "Yes"
	
	reg `outcome' weather_index, robust
	eststo y`y'_m2
	estadd local weighted "No"
	reg `outcome' weather_index [aweight=`aweight'], robust 
	eststo y`y'_m2_w
	estadd local weighted "Yes"
	
	reg `outcome' flatness_index, robust
	eststo y`y'_m3
	estadd local weighted "No"
	reg `outcome' flatness_index [aweight=`aweight'], robust 
	eststo y`y'_m3_w
	estadd local weighted "Yes"
	
	reg `outcome' land_area weather_index, robust
	eststo y`y'_m4
	estadd local weighted "No"
	reg `outcome' land_area weather_index [aweight=`aweight'], robust 
	eststo y`y'_m4_w
	estadd local weighted "Yes"
	
	reg `outcome' land_area flatness_index, robust
	eststo y`y'_m5
	estadd local weighted "No"
	reg `outcome' land_area flatness_index [aweight=`aweight'], robust 
	eststo y`y'_m5_w
	estadd local weighted "Yes"
	
	reg `outcome' land_area weather_index flatness_index, robust
	eststo y`y'_m6
	estadd local weighted "No"
	reg `outcome' land_area weather_index flatness_index [aweight=`aweight'], robust 
	eststo y`y'_m6_w
	estadd local weighted "Yes"
	
	esttab y`y'_m1 y`y'_m2 y`y'_m3 y`y'_m4 y`y'_m5 y`y'_m6 using "6000_LaTeX\etable_y`y'_environmental.tex", replace ///
		drop(_cons) star(* 0.1 ** 0.05 *** 0.01) b(%4.3f) se(%4.3f) nolegend nonotes ///
		coef(land_area "Land Area" weather_index "Weather Ind." flatness_index "Flatness Ind.") ///
		mlabels(none) mgroups("Gas Price Elasticity", span prefix(\multicolumn{@span}{c}{) suffix(})) stats(weighted N, label("Weights" "States:"))

	esttab y`y'_m1_w y`y'_m2_w y`y'_m3_w y`y'_m4_w y`y'_m5_w y`y'_m6_w using "6000_LaTeX\etable_y`y'_environmental_w.tex", replace ///
		drop(_cons) star(* 0.1 ** 0.05 *** 0.01) b(%4.3f) se(%4.3f) nolegend nonotes ///
		coef(land_area "Land Area" weather_index "Weather Ind." flatness_index "Flatness Ind.") ///
		mlabels(none) mgroups("Gas Price Elasticity", span prefix(\multicolumn{@span}{c}{) suffix(})) stats(weighted N, label("Weights" "States:"))
	
	local ++y
}

* transportation regressions: 
local y = 1
foreach outcome of local outcomes {
	reg `outcome' urban_mileage, robust
	eststo y`y'_m1
	estadd local weighted "No"
	reg `outcome' urban_mileage [aweight=`aweight'], robust 
	eststo y`y'_m1_w
	estadd local weighted "Yes"
	
	reg `outcome' total_mileage, robust
	eststo y`y'_m2
	estadd local weighted "No"
	reg `outcome' total_mileage [aweight=`aweight'], robust 
	eststo y`y'_m2_w
	estadd local weighted "Yes"
	
	reg `outcome' urban_mileage total_mileage, robust
	eststo y`y'_m3
	estadd local weighted "No"
	reg `outcome' urban_mileage total_mileage [aweight=`aweight'], robust 
	eststo y`y'_m3_w
	estadd local weighted "Yes"
	
	reg `outcome' urban_roadshare, robust
	eststo y`y'_m4
	estadd local weighted "No"
	reg `outcome' urban_roadshare [aweight=`aweight'], robust 
	eststo y`y'_m4_w
	estadd local weighted "Yes"
	
	reg `outcome' pub_tran_average, robust
	eststo y`y'_m5
	estadd local weighted "No"
	reg `outcome' pub_tran_average [aweight=`aweight'], robust 
	eststo y`y'_m5_w
	estadd local weighted "Yes"
	
	reg `outcome' urban_mileage total_mileage urban_roadshare pub_tran_average, robust
	eststo y`y'_m6
	estadd local weighted "No"
	reg `outcome' urban_mileage total_mileage urban_roadshare pub_tran_average [aweight=`aweight'], robust 
	eststo y`y'_m6_w
	estadd local weighted "Yes"
	
	esttab y`y'_m1 y`y'_m2 y`y'_m3 y`y'_m4 y`y'_m5 y`y'_m6 using "6000_LaTeX\etable_y`y'_transportation.tex", replace ///
		drop(_cons) star(* 0.1 ** 0.05 *** 0.01) b(%4.3f) se(%4.3f) nolegend nonotes ///
		coef(urban_mileage "Urban Roads" total_mileage "All Roads" urban_roadshare "Urbanization" pub_tran_average "Pub. Trans.") ///
		mlabels(none) mgroups("Gas Price Elasticity", span prefix(\multicolumn{@span}{c}{) suffix(})) stats(weighted N, label("Weights" "States:"))

	esttab y`y'_m1_w y`y'_m2_w y`y'_m3_w y`y'_m4_w y`y'_m5_w y`y'_m6_w using "6000_LaTeX\etable_y`y'_transportation_w.tex", replace ///
		drop(_cons) star(* 0.1 ** 0.05 *** 0.01) b(%4.3f) se(%4.3f) nolegend nonotes ///
		coef(urban_mileage "Urban Roads" total_mileage "All Roads" urban_roadshare "Urbanization" pub_tran_average "Pub. Trans.") ///
		mlabels(none) mgroups("Gas Price Elasticity", span prefix(\multicolumn{@span}{c}{) suffix(})) stats(weighted N, label("Weights" "States:"))
	
	local ++y
}

* demographic regressions: 
local y = 1
foreach outcome of local outcomes {
	reg `outcome' state_pop, robust
	eststo y`y'_m1
	estadd local weighted "No"
	reg `outcome' state_pop [aweight=`aweight'], robust 
	eststo y`y'_m1_w
	estadd local weighted "Yes"
	
	reg `outcome' pop_density, robust
	eststo y`y'_m2
	estadd local weighted "No"
	reg `outcome' pop_density [aweight=`aweight'], robust 
	eststo y`y'_m2_w
	estadd local weighted "Yes"
	
	reg `outcome' border_pop_share, robust
	eststo y`y'_m3
	estadd local weighted "No"
	reg `outcome' border_pop_share [aweight=`aweight'], robust 
	eststo y`y'_m3_w
	estadd local weighted "Yes"
	
	reg `outcome' licensure, robust
	eststo y`y'_m4
	estadd local weighted "No"
	reg `outcome' licensure [aweight=`aweight'], robust 
	eststo y`y'_m4_w
	estadd local weighted "Yes"
	
	reg `outcome' state_pop pop_density border_pop_share, robust
	eststo y`y'_m5
	estadd local weighted "No"
	reg `outcome' state_pop pop_density border_pop_share [aweight=`aweight'], robust 
	eststo y`y'_m5_w
	estadd local weighted "Yes"
	
	reg `outcome' state_pop pop_density border_pop_share licensure, robust
	eststo y`y'_m6
	estadd local weighted "No"
	reg `outcome' state_pop pop_density border_pop_share licensure [aweight=`aweight'], robust 
	eststo y`y'_m6_w
	estadd local weighted "Yes"
	
	esttab y`y'_m1 y`y'_m2 y`y'_m3 y`y'_m4 y`y'_m5 y`y'_m6 using "6000_LaTeX\etable_y`y'_demographic.tex", replace ///
		drop(_cons) star(* 0.1 ** 0.05 *** 0.01) b(%4.3f) se(%4.3f) nolegend nonotes ///
		coef(state_pop "Population" pop_density "Pop. Density" border_pop_share "Border Pop." licensure "Licensure") ///
		mlabels(none) mgroups("Gas Price Elasticity", span prefix(\multicolumn{@span}{c}{) suffix(})) stats(weighted N, label("Weights" "States:"))

	esttab y`y'_m1_w y`y'_m2_w y`y'_m3_w y`y'_m4_w y`y'_m5_w y`y'_m6_w using "6000_LaTeX\etable_y`y'_demographic_w.tex", replace ///
		drop(_cons) star(* 0.1 ** 0.05 *** 0.01) b(%4.3f) se(%4.3f) nolegend nonotes ///
		coef(state_pop "Population" pop_density "Pop. Density" border_pop_share "Border Pop." licensure "Licensure") ///
		mlabels(none) mgroups("Gas Price Elasticity", span prefix(\multicolumn{@span}{c}{) suffix(})) stats(weighted N, label("Weights" "States:"))
	
	local ++y
	drop _est*
}

log close

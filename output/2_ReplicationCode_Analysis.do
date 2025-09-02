/* Ec191 Analysis 

VA
Last Edited: 2023-03-23
*/

cd "/Users/vivekadury/Dropbox/UC Berkeley/sp2022/econ 191/analysis_and_maps"
graph set window fontface "Times New Roman"

********************************************************************************
**************** CLEANING, RESHAPING DATASET, SUMMARY STATS ********************
********************************************************************************
clear
import excel "intermediate/dataset/dataset.xlsx", firstrow

rename (L M) (later_2020 later_2021) // renaming 2020 and 2021 for later analysis 
rename (_covs C D E F G H I J K) (covs2010 covs2011 covs2012 covs2013 covs2014 covs2015 covs2016 covs2017 covs2018 covs2019)
rename (_crimes O P Q R S T U V W) (crimes2010 crimes2011 crimes2012 crimes2013 crimes2014 crimes2015 crimes2016 crimes2017 crimes2018 crimes2019)

drop if POP <= 50

save "intermediate/dataset_clean.dta", replace
// Mean block crime rates in Los Angeles per 100 persons, by year 
collapse (mean) crimes2010 crimes2011 crimes2012 crimes2013 crimes2014 crimes2015 crimes2016 crimes2017 crimes2018 crimes2019
export excel using "outputs/mean_block_crime_rates.xlsx", sheetreplace firstrow(variables)

// Mean block distance from affordable housing covenent,by year 
use "intermediate/dataset_clean.dta", replace
collapse (mean) d2010 d2011 d2012 d2013 d2014 d2015 d2016 d2017 d2018 d2019
export excel using "outputs/mean_block_dist.xlsx", sheetreplace firstrow(variables)

// Number of blocks that received an affordable housing covenent, by year
use "intermediate/dataset_clean.dta", replace
tab yfirst_cov 

***************************** RESHAPING THE DATA *******************************
reshape long covs crimes d, i(GEOID10) j(year) // long covs inc, i(GEOID10) j(year)
rename covs treated_in_yeart
rename d dist_from_cov 
	// distance is 0 if block contains an afforable housing covenent in year t!
egen blocknum = group(GEOID10)
save "intermediate/dataset_reshaped.dta", replace

// Number of blocks with special characteristics 
use "intermediate/dataset_clean.dta", replace
tab perm_SF
tab perm_MF
tab perm_MIX
tab cont_small 
tab cont_large

tab perm_SF cont_small 
tab perm_SF cont_large

tab perm_MF cont_small 
tab perm_MF cont_large



// Evolution of average block crime rate by treatment status for specified years
use "intermediate/dataset_reshaped.dta", replace
collapse (mean) crimes, by(year yfirst_cov)
twoway (connected crimes year if yfirst_cov == "2017") (connected crimes year if yfirst_cov == "2018") (connected crimes year if yfirst_cov == "2019") (connected crimes year if yfirst_cov == "not_treated"), legend(order(1 "Treated in 2017" 2 "Treated in 2018" 3 "Treated in 2019" 4 "Never treated")) graphregion(fc(white)) ytitle(Average block crime rate per 100 persons) xlabel(2010 2011 2012 2013 2014 2015 2016 2017 2018 2019) xtitle(Years)
graph export "outputs/timeseries_2017-19-nt.pdf", replace

********************************************************************************
**************************** VARIABLE CONSTRUCTION *****************************
********************************************************************************
use "intermediate/dataset_reshaped.dta", replace

gen first_cov_es = yfirst_cov
replace first_cov_es = "." if first_cov_es == "2020"
replace first_cov_es = "." if first_cov_es == "2021"
replace first_cov_es = "." if first_cov_es == "not_treated"
gen ever_treated = 0
replace ever_treated = 1 if first_cov_es != "."
destring first_cov_es, replace ignore(",")

// Generating dummies:
gen y2010 = (year == 2010)
gen y2011 = (year == 2011)
gen y2012 = (year == 2012)
gen y2013 = (year == 2013)
gen y2014 = (year == 2014)
gen y2015 = (year == 2015)
gen y2016 = (year == 2016)
gen y2017 = (year == 2017)
gen y2018 = (year == 2018)
gen y2019 = (year == 2019)
global years "y2010 y2011 y2012 y2013 y2014 y2015 y2016 y2017 y2018"

// Generating distance dummy variables:
gen lp25mile = 0
replace lp25mile = 1 if dist_from_cov <= 1320
replace lp25mile = 0 if treated_in_yeart == 1 
gen  p25top5mile = 0
replace p25top5mile = 1 if (dist_from_cov > 1320) & (dist_from_cov <= 2640)
gen p5to1mile = 0 
replace p5to1mile = 1 if (dist_from_cov > 2640) & (dist_from_cov <= 5280)
gen gt1mile = 0 
replace gt1mile = 1 if (dist_from_cov > 5280) 

tab lp25mile
tab p25top5mile
tab p5to1mile
tab gt1mile

****************************** FOR EVENT STUDY *********************************
// Non-negative indicies:
forvalues i = 0/3{
gen dtreat`i' = 0
replace dtreat`i' = 1 if `i' == year - first_cov_es 
// & ever_treated == 1
}
// Negative incidies 
forvalues i = 1/3{
gen dtreatminus`i' = 0
replace dtreatminus`i' = 1 if `i' == first_cov_es - year 
// & ever_treated == 1
}
gen aux1 = 0
replace aux1 = 1 if year>= first_cov_es - 3 & year <= first_cov_es + 3
replace aux1 = 1 if ever_treated == 0

save "intermediate/dataset_reshaped.dta", replace // Overrides existing dataset.

********* Calculation variation in spatial concentration over time: ************
use "intermediate/dataset_reshaped.dta", clear
collapse (sum) lp25mile p25top5mile p5to1mile gt1mile, by(year)
export excel using "outputs/DUMMIESblockdist.xlsx", sheetreplace firstrow(variables)
twoway (connected lp25mile year) (connected p25top5mile year) (connected p5to1mile year) (connected gt1mile year), legend(pos(1) ring(0) col(1) order(1 "Less than a .25 mile away" 2 "Between .25 and .5 mile away" 3 "Between .5 and 1 mile away" 4 "Greater than 1 mile away") subtitle("Block Distance from Covenant")) graphregion(fc(white)) ytitle(Number of blocks) xlabel(2010 2011 2012 2013 2014 2015 2016 2017 2018 2019) xtitle(Years)
graph export "outputs/timeseriesdist.pdf", replace

********************************************************************************
******************************* DID ANALYSIS ***********************************
********************************************************************************
use "intermediate/dataset_reshaped.dta", clear
xtset blocknum year

est clear
eststo a1: xtreg crimes treated_in_yeart ${years}, fe robust 
outreg2 a1 using "outputs/DID.doc", keep(treated_in_yeart) replace ctitle(A) lab nocons
eststo a2: xtreg crimes treated_in_yeart lp25mile p25top5mile p5to1mile ${years}, fe robust 
outreg2 a2 using "outputs/DID.doc", keep(treated_in_yeart lp25mile p25top5mile p5to1mile) append ctitle(B) lab nocons



********************************************************************************
***************************** EVENT STUDY **************************************
********************************************************************************
drop dtreatminus1
gen dtreatminus1 = 0 
est clear
eststo a1: reghdfe crimes dtreat* lp25mile p25top5mile p5to1mile if (aux1 == 1), absorb(GEOID10 year)

label var dtreatminus3 "-3"
label var dtreatminus2 "-2"
label var dtreatminus1 "-1"
label var dtreat0 "0"
label var dtreat1 "1"
label var dtreat2 "2"
label var dtreat3 "3"

outreg2 a1 using "outputs/ESresults.doc", keep(dtreat*) sortvar(dtreatminus3 dtreatminus2 dtreatminus1 dtreat0 dtreat1 dtreat2 dtreat3) replace ctitle(A) lab nocons

coefplot, omitted vertical drop(_cons lp25mile p25top5mile p5to1mile)  yline(0) graphregion(fc(white)) order(dtreatminus3 dtreatminus2 dtreatminus1 dtreat0 dtreat1 dtreat2 dtreat3) xtitle("Year From Treatment") ytitle("Coefficient")
graph export "outputs/EScoeffplot.pdf", replace 


********************************************************************************
***************************** MF, SF ANALYSIS **********************************
********************************************************************************
est clear
eststo a1: xtreg crimes treated_in_yeart ${years} if perm_SF == 1, fe robust
outreg2 a1 using "outputs/ZONING_DID.doc", keep(treated_in_yeart) replace ctitle(Permits SF) lab nocons
eststo a2: xtreg crimes treated_in_yeart ${years} if perm_MF == 1, fe robust
outreg2 a2 using "outputs/ZONING_DID.doc", keep(treated_in_yeart) append ctitle(Permits MF) lab nocons

est clear
eststo a1: reghdfe crimes dtreat*  if (aux1 == 1) & (perm_SF == 1), absorb(GEOID10 year)
outreg2 a1 using "outputs/ESZONINGresults.doc", keep(dtreat*) sortvar(dtreatminus3 dtreatminus2 dtreat0 dtreat1 dtreat2 dtreat3) replace ctitle(Permits SF) lab nocons
eststo a2: reghdfe crimes dtreat* if (aux1 == 1) & (perm_MF == 1), absorb(GEOID10 year)
outreg2 a2 using "outputs/ESZONINGresults.doc", keep(dtreat*) sortvar(dtreatminus3 dtreatminus2 dtreat0 dtreat1 dtreat2 dtreat3) append ctitle(Permits MF) lab nocons

coefplot (a1, label(Permits SF)) (a2, label(Permits MF)), omitted vertical drop(_cons lp25mile p25top5mile p5to1mile)  yline(0) graphregion(fc(white)) order(dtreatminus3 dtreatminus2 dtreatminus1 dtreat0 dtreat1 dtreat2 dtreat3) xtitle("Year From Treatment") ytitle("Coefficient")
graph export "outputs/ESZONINGcoeffplot.pdf", replace 


// What are the types of projects being approved in SF versus multi family?
use "intermediate/dataset_clean.dta", replace
label var Treated_TOT_Units "Total Units Received"
label var Treated_Aff_Units "Total Affordable Units Received"

hist Treated_TOT_Units if covs2019 == 1, normal
graph export "outputs/hist_units_all.pdf", replace 
hist Treated_TOT_Units if (covs2019 == 1) & (perm_SF == 1), normal
graph export "outputs/hist_units_sf.pdf", replace 
hist Treated_TOT_Units if (covs2019 == 1) & (perm_MF == 1), normal
graph export "outputs/hist_units_mf.pdf", replace 
hist Treated_Aff_Units if covs2019 == 1, normal
graph export "outputs/hist_affunits_all.pdf", replace 
hist Treated_Aff_Units if (covs2019 == 1) & (perm_SF == 1), normal
graph export "outputs/hist_affunits_sf.pdf", replace 
hist Treated_Aff_Units if (covs2019 == 1) & (perm_MF == 1), normal
graph export "outputs/hist_affunits_mf.pdf", replace 


********************************************************************************
**************************  ROBUSTNESS CHECKS **********************************
********************************************************************************
use "intermediate/dataset_reshaped.dta", clear
xtset blocknum year

drop if year == 2012
drop if year == 2016
global yearsrc "y2010 y2011 y2013 y2014 y2015 y2017 y2018"

est clear
eststo r1: xtreg crimes treated_in_yeart ${yearsrc}, fe robust 
outreg2 r1 using "outputs/DID_RB1.doc", keep(treated_in_yeart) replace ctitle(A) lab nocons
eststo r2: xtreg crimes treated_in_yeart lp25mile p25top5mile p5to1mile ${yearsrc}, fe robust 
outreg2 r2 using "outputs/DID_RB1.doc", keep(treated_in_yeart lp25mile p25top5mile p5to1mile) append ctitle(B) lab nocons


********************************************************************************
******************************** APPENDIX *************************************
********************************************************************************
use "intermediate/dataset_reshaped.dta", replace

collapse (mean) crimes, by(year yfirst_cov)
twoway (connected crimes year if yfirst_cov == "2010") (connected crimes year if yfirst_cov == "2011") (connected crimes year if yfirst_cov == "2012") (connected crimes year if yfirst_cov == "not_treated"), legend(order(1 "Treated in 2010" 2 "Treated in 2011" 3 "Treated in 2012"  4 "Never treated")) graphregion(fc(white)) ytitle(Average block crime rate per 100 persons) xlabel(2010 2011 2012 2013 2014 2015 2016 2017 2018 2019) xtitle(Years)
graph export "outputs/APPENDIXTIMESERIES1.pdf", replace 


twoway (connected crimes year if yfirst_cov == "2013") (connected crimes year if yfirst_cov == "2014") (connected crimes year if yfirst_cov == "2015") (connected crimes year if yfirst_cov == "2016") (connected crimes year if yfirst_cov == "not_treated"), legend(order(1 "Treated in 2013" 2 "Treated in 2014" 3 "Treated in 2015" 4 "Treated in 2016"  5 "Never treated")) graphregion(fc(white)) ytitle(Average block crime rate per 100 persons) xlabel(2010 2011 2012 2013 2014 2015 2016 2017 2018 2019) xtitle(Years)
graph export "outputs/APPENDIXTIMESERIES2.pdf", replace 


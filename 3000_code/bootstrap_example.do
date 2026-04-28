timer clear
timer on 1



capture program drop name
program name, rclass
*generate variable for coef =.

*pciv regression
*your loops {
 reg elast het_var
 return scalar b_hetvar=_b[hetvar]
*}

end
****Check program

bootstrap b_hetvar=r(b_hetvar)  etc,
reps(500) seed(444) saving(filename444.dta, replace) cluster(distid) idcluster(newid): name

timer off 1
timer list

use filename.dta, clear
tabstat b_hetvar, stat(sd)

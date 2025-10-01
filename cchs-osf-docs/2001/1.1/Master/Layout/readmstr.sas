/******************************************/
/*                                        */
/* use this for English labels and format */
/*                                        */
/******************************************/


%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\hs_pfe.sas";

data master;
	%let datafid="\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Data\hs.txt";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\hs_i.sas";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\hs_fmt.sas";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\hs_lbe.sas";
run;

data inc;
	%let datafid="\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Data\inc.txt";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\inc_i.sas";
run;

data incratio;
	%let datafid="\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Data\inc_ratio.txt";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\inc_ratio_i.sas";
run;

/******************************************/
/*                                        */
/* use this for French labels and format */
/*                                        */
/******************************************/

%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\hs_pff.sas";

data master;
	%let datafid="\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Data\hs.txt";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\hs_i.sas";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\hs_fmt.sas";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\hs_lbf.sas";
run;

data inc;
	%let datafid="\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Data\inc.txt";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\inc_i.sas";
run;

data incratio;
	%let datafid="\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Data\inc_ratio.txt";
	%include "\\hlth5wnt\cchsdata\Cycle 1.1\Core\Final\Master\Layout\inc_ratio_i.sas";
run;

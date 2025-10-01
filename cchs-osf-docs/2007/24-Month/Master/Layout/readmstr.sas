/******************************************/
/*                                        */
/* use this for English labels and format */
/*                                        */
/******************************************/

%include "\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Layout\hs_pfe.sas";

data HS;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Data\hs.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Layout\hs_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Layout\hs_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Layout\hs_lbe.sas";
run;


/******************************************/
/*                                        */
/* use this for French labels and format */
/*                                        */
/******************************************/

%include "\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Layout\hs_pff.sas";

data HS;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Data\hs.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Layout\hs_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Layout\hs_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 4.1\2007-2008\24-month\Master\Layout\hs_lbf.sas";
run;



/******************************************/
/*                                        */
/* use this for English labels and format */
/*                                        */
/******************************************/

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs_pfe.sas";

data HS;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\hs.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss1_pfe.sas";

data HSS1;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\hss1.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss1_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss1_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss1_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss2_pfe.sas";

data HSS2;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\hss2.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss2_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss2_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss2_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss3_pfe.sas";

data HSS3;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\hss3.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss3_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss3_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss3_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INC_pfe.sas";

data INC;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\INC.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INC_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INC_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INC_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS1_pfe.sas";

data INCS1;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\INCS1.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS1_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS1_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS1_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS2_pfe.sas";

data INCS2;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\INCS2.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS2_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS2_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS2_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS3_pfe.sas";

data INCS3;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\INCS3.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS3_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS3_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS3_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\wst_pfe.sas";

data WST;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\wst.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\wst_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\wst_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\wst_lbe.sas";
run;

/******************************************/
/*                                        */
/* use this for French labels and format */
/*                                        */
/******************************************/

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs_pff.sas";

data HS;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\hs.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs1_pff.sas";

data HSS1;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\hss1.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss1_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss1_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss1_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss2_pff.sas";

data HSS2;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\hss2.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss2_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss2_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss2_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss3_pff.sas";

data HSS3;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\hss3.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss3_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss3_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hss3_lbf.sas";
run;


%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INC_pff.sas";

data INC;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\INC.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INC_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INC_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INC_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\hs1_pff.sas";

data INCS1;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\INCS1.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS1_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS1_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS1_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS2_pff.sas";

data INCS2;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\INCS2.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS2_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS2_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS2_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS3_pff.sas";

data INCS3;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\INCS3.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS3_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS3_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\INCS3_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\wst_pff.sas";

data WST;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Data\wst.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\wst_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\wst_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 3.1\Final\12-month\Master\Layout\wst_lbf.sas";
run;

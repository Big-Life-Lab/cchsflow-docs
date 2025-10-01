/******************************************/
/*                                        */
/* use this for English labels and format */
/*                                        */
/******************************************/

%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hs_pfe.sas";

data HS;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hs.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hs_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hs_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hs_lbe.sas";
run;


%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss1_pfe.sas";

data hs_s1;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hs_s1.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss1_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss1_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss1_lbe.sas";
run;


%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss2_pfe.sas";

data hs_S2;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hs_s2.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss2_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss2_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss2_lbe.sas";
run;


%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss3_pfe.sas";

data hs_S3;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hs_s3.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss3_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss3_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss3_lbe.sas";
run;


%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hsg_pfe.sas";

data hsg;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hsg.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hsg_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hsg_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hsg_lbe.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\wst_pfe.sas";

data wst;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\wst.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\wst_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\wst_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\wst_lbe.sas";
run;

data inc;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\inc.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\inc_i.sas";
run;

data incs1;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs1.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs1_i.sas";
run;

data incs2;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs2.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs2_i.sas";
run;

data incs3;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs3.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs3_i.sas";
run;
data incratio;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\inc_ratio.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\inc_ratio_i.sas";
run;

data incs1ratio;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs1_ratio.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs1_ratio_i.sas";
run;

data incs2ratio;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs2_ratio.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs2_ratio_i.sas";
run;

data incs3ratio;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs3_ratio.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs3_ratio_i.sas";
run;

/******************************************/
/*                                        */
/* use this for French labels and format */
/*                                        */
/******************************************/

%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hs_pff.sas";

data HS;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hs.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hs_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hs_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hs_lbf.sas";
run;


%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss1_pff.sas";

data HS_S1;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hs_s1.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss1_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss1_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss1_lbf.sas";
run;


%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss2_pff.sas";

data HS_S2;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hs_s2.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss2_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss2_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss2_lbf.sas";
run;


%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss3_pff.sas";

data HS_S3;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hs_s3.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss3_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss3_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hss3_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hsg_pff.sas";
data hsg;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\hsg.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hsg_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hsg_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\hsg_lbf.sas";
run;

%include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\wst_pff.sas";

data wst;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\wst.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\wst_i.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\wst_fmt.sas";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\wst_lbf.sas";
run;

data inc;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\inc.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\inc_i.sas";
run;

data incs1;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs1.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs1_i.sas";
run;

data incs2;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs2.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs2_i.sas";
run;

data incs3;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs3.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs3_i.sas";
run;
data incratio;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\inc_ratio.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\inc_ratio_i.sas";
run;

data incs1ratio;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs1_ratio.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs1_ratio_i.sas";
run;

data incs2ratio;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs2_ratio.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs2_ratio_i.sas";
run;

data incs3ratio;
        %let datafid="\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Data\incs3_ratio.txt";
        %include "\\HLTH5WNT\CCHSDATA\Cycle 2.1\Core\Final\Master - December 2004\Layout\incs3_ratio_i.sas";
run;

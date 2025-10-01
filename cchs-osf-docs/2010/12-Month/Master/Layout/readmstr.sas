/******************************************/
/*   CCHS Master file,			          */
/* Use this for English labels and format */
/*                                        */
/******************************************/

%include "D:\Layout\hs_pfe.sas";

data HS;
        %let datafid="D:\Data\hs.txt";
        %include "D:\Layout\hs_i.sas";
        %include "D:\Layout\hs_fmt.sas";
        %include "D:\Layout\hs_lbe.sas";
run;

/************************************************/
/* Fichier maître de l'ESCC,				     */
/* Utiliser pour les étiquettes et le formattage*/
/*  des données                                 */
/*                                              */
/************************************************/

%include "D:\Layout\hs_pff.sas";

data HS;
        %let datafid="D:\Data\hs.txt";
        %include "D:\Layout\hs_i.sas";
        %include "D:\Layout\hs_fmt.sas";
        %include "D:\Layout\hs_lbf.sas";
run;

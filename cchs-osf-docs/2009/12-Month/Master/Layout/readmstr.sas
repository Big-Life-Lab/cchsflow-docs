/******************************************/
/*   CCHS 2009 Share file, June 15th 2010 */
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

%include "D:\Layout\HSS1_pfe.sas";

data HSS1;
        %let datafid="D:\Data\HSS1.txt";
        %include "D:\Layout\HSS1_i.sas";
        %include "D:\Layout\HSS1_fmt.sas";
        %include "D:\Layout\HSS1_lbe.sas";
run;


/************************************************/
/* Fichier partagé 2009 de l'ESCC, 15 juin 2010 */
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

%include "D:\Layout\HSS1_pff.sas";

data HSS1;
        %let datafid="D:\Data\HSS1.txt";
        %include "D:\Layout\HSS1_i.sas";
        %include "D:\Layout\HSS1_fmt.sas";
        %include "D:\Layout\HSS1_lbf.sas";
run;

/**********************************************/
/*   CCHS Master file                          */
/* Use this for English labels and format     */
/*                                          
/* Where pathnames correspond to the directory */
/* structure on the original CD-ROM, where D: is*/
/* the CD-ROM drive (modify as necessary to suit*/
/* your directory structure).                   */
/************************************************/

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
/* Fichier maître de l'ESCC                     */
/* Utiliser pour les étiquettes et le formattage*/
/*  des données                                 */
/* Où les noms de répertoires correspondent à la structure*/
/* des répertoires du CD-ROM originel, où D: est le lecteur*/
/* de CR-DOM (modifiez tel que nécessaire pour refléter*/
/* la structure de vos répertoires).			*/
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

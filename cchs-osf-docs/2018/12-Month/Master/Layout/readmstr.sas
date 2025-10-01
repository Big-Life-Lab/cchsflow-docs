/******************************************************/
/*   CCHS Master file                    		      */
/* Use this for English labels and format     		  */
/*                                         			  */ 
/* Where pathnames correspond to the directory 		  */
/* structure on the original ?electronic file transfer */
/* Modify as necessary to suit your directory 		  */
/* structure                   						  */
/******************************************************/

%include "D:\Layout\hs_pfe.sas";

data HS;
        %let datafid="D:\Data\hs.txt";
        %include "D:\Layout\hs_i.sas";
        %include "D:\Layout\hs_fmt.sas";
        %include "D:\Layout\hs_lbe.sas";
run;




/*************************************************************/
/* Fichier maître de l'ESCC                     			 */
/* Utiliser pour les étiquettes et le formattage			 */
/* des données                                 			 	 */
/* Où les noms de répertoires correspondent à la structure   */
/* des répertoires du ?transfert électronique de fichiers 	 */
/* Modifiez tel que nécessaire pour refléter      			 */
/* la structure de vos répertoires.							 */
/*************************************************************/

%include "D:\Layout\hs_pff.sas";

data HS;
        %let datafid="D:\Data\hs.txt";
        %include "D:\Layout\hs_i.sas";
        %include "D:\Layout\hs_fmt.sas";
        %include "D:\Layout\hs_lbf.sas";
run;



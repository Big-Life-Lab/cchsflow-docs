/*******************************************************/
/*   CCHS Share file                    		   */
/* Use this for English labels and format     	   */
/*                                         		   */ 
/* Where pathnames correspond to the directory 	   */
/* structure on the original electronic file transfer */
/* Modify as necessary to suit your directory 	   */
/* structure                   				   */
/******************************************************/

file handle infile/name = 'D:\DATA\hs.txt'.
data list file = infile notable/.
include file = "D:\Layout\hs_i.sps".
include file = "D:\Layout\hs_vale.sps".
include file = "D:\Layout\hs_vare.sps".
include file = "D:\Layout\hs_miss.sps".

execute.


/*************************************************************/
/* Fichier de partage de l'ESCC                     	    */
/* Utiliser pour les étiquettes et le formattage		    */
/* des données                                 		    */
/* Où les noms de répertoires correspondent à la structure   */
/* des répertoires du transfert électronique de fichiers 	    */
/* Modifiez tel que nécessaire pour refléter      		    */
/* la structure de vos répertoires.				    */
/*************************************************************/

file handle infile/name = 'D:\DATA\hs.txt'.
data list file = infile notable/.
include file = "D:\Layout\hs_i.sps".
include file = "D:\Layout\hs_valf.sps".
include file = "D:\Layout\hs_varf.sps".
include file = "D:\Layout\hs_miss.sps".

execute.

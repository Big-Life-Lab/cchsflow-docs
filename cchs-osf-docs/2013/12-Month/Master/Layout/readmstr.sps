/**********************************************/
/*   CCHS Master file                          */
/* Use this for English labels and format      */
/*                                          
/* Where pathnames correspond to the directory */
/* structure on the original CD-ROM, where D: is*/
/* the CD-ROM drive (modify as necessary to suit*/
/* your directory structure).                   */
/************************************************/


file handle infile/name = 'D:\DATA\hs.txt'.
data list file = infile notable/.
include file = "D:\Layout\hs_i.sps".
include file = "D:\Layout\hsvale.sps".
include file = "D:\Layout\hsvare.sps".
include file = "D:\Layout\hsmiss.sps".

execute.


/************************************************/
/* Fichier maître de l'ESCC                     */
/* Utiliser pour les étiquettes et le formattage*/
/*  des données                                 */
/* Où les noms de répertoires correspondent à la structure*/
/* des répertoires du CD-ROM originel, où D: est le lecteur*/
/* de CR-DOM (modifiez tel que nécessaire pour refléter*/
/* la structure de vos répertoires).			*/
/************************************************/

file handle infile/name = 'D:\DATA\hs.txt'.
data list file = infile notable/.
include file = "D:\Layout\hs_i.sps".
include file = "D:\Layout\hsvalf.sps".
include file = "D:\Layout\hsvarf.sps".
include file = "D:\Layout\hsmiss.sps".

execute.


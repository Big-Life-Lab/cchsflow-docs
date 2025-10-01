/****************************************************************/
/* CCHS Master File,					        */
/* Use the following statements to read, label and format	*/
/* the ASCII format data file into SPSS format,			*/
/* 								*/
/* for ENGLISH labels and formats,				*/
/* 								*/
/* Where pathnames correspond to the directory			*/
/* structure, modify as necessary to suit		        */
/* your directory structure.					*/
/* 								*/
/****************************************************************/


file handle infile/name = 'D:\DATA\hs.txt'.
data list file = infile notable/.
include file = "D:\Layout\hs_i.sps".
include file = "D:\Layout\hsvale.sps".
include file = "D:\Layout\hsvare.sps".
include file = "D:\Layout\hsmiss.sps".

execute.


/******************************************************************/
/* Fichier maître de l'ESCC,		 		          */  
/* Utilisez les énoncés suivant pour lire, étiqueter et formatter */
/* le fichier de données de format ASCII en format SPSS,	  */
/* 								  */
/* pour étiquettes et formats en FRANÇAIS,			  */
/* 								  */
/* Les noms de répertoires correspondent à la structure	          */
/* des répertoires de travail, modifiez si nécessaire             */
/* pour refléter la structure de vos répertoires.		  */
/* 								  */
/******************************************************************/

file handle infile/name = 'D:\DATA\hs.txt'.
data list file = infile notable/.
include file = "D:\Layout\hs_i.sps".
include file = "D:\Layout\hsvalf.sps".
include file = "D:\Layout\hsvarf.sps".
include file = "D:\Layout\hsmiss.sps".

execute.



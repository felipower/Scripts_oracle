

/* 
 * Clone locally a PDB easy way
 * author: Felipe Donoso, felipe@felipedonoso.cl, felipe.donoso@oracle.com
 */

[oracle@lab-db12-2-ol7 u01]$ sqlplus "/as sysdba"

SQL*Plus: Release 12.2.0.1.0 Production on Wed Aug 11 12:56:35 2021

Copyright (c) 1982, 2016, Oracle.  All rights reserved.


Connected to:
Oracle Database 12c Enterprise Edition Release 12.2.0.1.0 - 64bit Production

SQL> show pdbs

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 PDB1 			  READ WRITE NO


SQL> /* script for clone local PDB , remember change the folfer for the new datafiles for new pdb*/
CREATE PLUGGABLE DATABASE PDB2 FROM PDB1
FILE_NAME_CONVERT=('/u01/app/oracle/oradata/cdb1/pdb1/','/u01/app/oracle/oradata/cdb1/pdb2/')
-- Remember you can omit or include in the except list some tablespaces if you need
-- USER_TABLESPACES=('xxx', 'yyyy')
-- omit the clause USER_TABLESPACE is the same that use USER_TABLESPACES=ALL
--
-- Also remember you can clone only metadata if you need (no rows)
-- using NO DATA option
-- the NO DATA option above is valid only when you aren't using:
;  2    3    4  

Pluggable database created.

SQL> ALTER PLUGGABLE DATABASE pdb2 OPEN;

Pluggable database altered.

SQL> ALTER PLUGGABLE DATABASE pdb2 save state;

Pluggable database altered.

SQL> show pdbs

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 PDB1 			  READ WRITE NO
	 4 PDB2 			  READ WRITE NO
SQL> 

DONE! :D
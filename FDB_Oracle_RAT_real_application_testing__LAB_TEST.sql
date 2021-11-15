
/*
 ****** RAT LAB TESTING (Real Application Testing) ******
 *
 * author: felipe.donoso@oracle.com
 * Link for documentation: 
 * CAPTURE PROCESS: https://docs.oracle.com/database/121/ARPLS/d_workload_capture.htm#ARPLS69044
 * REPLAY  PROCESS: https://docs.oracle.com/database/121/ARPLS/d_workload_replay.htm#ARPLS208
 *
 * DocID for RAT on PDBs (multitenant): 
 * "How to Setup and Run a Database Testing Replay 
 * in an Oracle Multitenant Environment 
 * (Real Application Testing - RAT) (Doc ID 1937920.1)"
 *
 *
 * NOTE: It's not possible capture RAT directly on PDB 
 * (for now until 18c, maybe on 19c it will be possible)
 *
 * This test it was done on DB ver. 12.2
 */


/*
 * 1.- CREATE NEW DIRECTORY FOR CAPTURE FILES
 * this it'll be for the source database
 * or for the capture environments
 */

-- create DB capture directory
mkdir /u01/RAT_DIR_PDB1_20190821

alter session set container=cdb$root ;
CREATE OR REPLACE DIRECTORY RAT_DIR_PDB1_20190821 AS '/u01/RAT_DIR_PDB1_20190821';
-- NOTE: For determine how much disk space you need for
-- storage the capture files you have 2 alternatives:. 
-- 1.- testing a little capture process:
-- (https://docs.oracle.com/cd/E18283_01/server.112/e16540.pdf)
-- Page 3-3: "To estimate the amount of disk space that is required, you can 
-- run a test capture on your workload for a short duration 
-- (such as a few minutes) to extrapolate how much space you will need for a full capture."
--
-- 2.- Using the next doc id: 
-- Real Application Testing: Database Capture FAQ (Doc ID 1920275.1)
-- Check the AWR metric: "Bytes received via SQL*Net from client"
-- (for the same hour to capture)
-- the formule is = 2 * (Bytes received via SQL*Net from client)
-- On the AWR report , you need to go:
-- "Instance activity stats" --> "Ordered by statistic name" ---> "Bytes received via SQL*Net from client" ---> "Total"
-- that "total" multiply by 2 and get the estimate disk space for capture (that is aprox) 


/*
 * 2.- DEFINE FILTER FOR CAPTURE
 * Add the next for PDB capture
 * put the pdb's name on the fvalue
 * note: for delete filter use DELETE_FILTER proedure
 * For more information about the use of filter 
 * review the next Support note:
 * [ How to Create Filters for Either a Capture or Replay 
 * with Real Application Testing (RAT) (Doc ID 2285287.1) ]  
 *
 * PRIOR 19c you only can capture from all CDB LEVEL:
 * 19c New Feature Workload Capture and Replay in a PDB(Doc ID 2644357.1
 *, but if you need capture only for PDB prior 19c you can use this:

alter session set container=cdb$root ;
BEGIN
    DBMS_WORKLOAD_CAPTURE.ADD_FILTER (
        fname => 'RAT_FILTER_PDB1_20190821', 
        fattribute => 'PDB_NAME', 
        fvalue => 'PDB1'
    );
END;
/

-- This is the command for delete filter:
-- exec DBMS_WORKLOAD_CAPTURE.DELETE_FILTER('RAT_FILTER_PDB1_20190821');
--
-- This is import regarding delete filter:
-- (from https://docs.oracle.com/database/121/ARPLS/d_workload_capture.htm#ARPLS69044)
-- The DELETE_FILTER Procedure only affects filters 
-- that have not been used by any previous capture.
-- Consequently, filters can be deleted only if 
-- they have been added using the ADD_FILTER Procedures 
-- after any capture has been completed. 
-- Filters that have been added using ADD_FILTER 
-- before a START_CAPTURE and FINISH_CAPTURE 
-- cannot be deleted anymore using this subprogram.

 *
 */



/*
 * 3.- CREATE USER FOR TEST LOAD ON SOURCE OR CAPTURE DATABASE
 */
alter session set container=PDB1 ;
drop user rat_test cascade ;
create user rat_test identified by rat_test ;
grant create session, create table to rat_test ;
alter user rat_test quota unlimited on users ;


/*
 * 4.- BEGIN CAPTURE
 * we need to use a name for capture and the directory's name
 *
 * NOTE: Real Application Testing: Database Capture FAQ (Doc ID 1920275.1)
 * Database Capture DOES NOT capture workload from dbms_jobs or scheduler jobs. 
 * They are excluded from capture. The assumption is that in the 
 * test database where the replay is done, these jobs will be already setup.
 *
 * 
 * From note: Master Note for Real Application Testing Option (Doc ID 1464274.1)
 * Workload Capture Restrictions
 * The following types of client requests are not supported:
 * - Direct path load of data from external files using utilities such as SQL*Loader
 * - Non-PL/SQL based Advanced Queuing (AQ)
 * - Flashback queries
 * - Oracle Call Interface (OCI) based object navigations
 * - Non SQL-based object access
 * - Distributed transactions (any distributed transactions that are captured will be replayed as local transactions)
 * - Oracle Streams/Advanced Replication workload is not supported prior to 11.2.
 * - Database session migration
 * - Database Resident Connection Pooling ( DRCP )
 * - XA transactions
 * - Workloads having Object Out Bind
 */

alter session set container=cdb$root ;
BEGIN
    DBMS_WORKLOAD_CAPTURE.start_capture (
        name     => 'RAT_CAPTURE_PDB1_20190821', 
        dir      => 'RAT_DIR_PDB1_20190821',
        duration => NULL,
        -- the next is for include the above defined filter
        default_action =>'INCLUDE'
    );
END;
/



/*
 * 4.- EXECUTE SOME LOAD ON DATABASE FOR CAPTURE
 * In my example the name of capture PDB is called "PDB1"
 */
sqlplus "rat_test/rat_test@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=lab-db12-2-ol7)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=pdb1)))" <<EOF
CREATE TABLE rat_test.rat_test_table (
  num           NUMBER,
  text  VARCHAR2(100)
) tablespace users ;
BEGIN
  FOR x IN 1 .. 20000 LOOP
    INSERT INTO rat_test.rat_test_table (num, text)
    VALUES (x, 'rat test number: ' || x);
  END LOOP;
  COMMIT;
END;
/
exit;
EOF


/*
 * 5.- STOP CAPTURE
 * We finish capture (BTW the associate filter 
 * is not available anymore)
 */
alter session set container=cdb$root ;
exec DBMS_WORKLOAD_CAPTURE.FINISH_CAPTURE(timeout  => 30, reason   => 'STOP CAPTURE');



/*
 * 6.- REVIEW CAPTURE INFO AND REPORTING
 * with this querys we can review basic 
 * information about the captures
 */
SELECT DBMS_WORKLOAD_CAPTURE.get_capture_info('RAT_DIR_PDB1_20190821')
FROM   dual;

COLUMN name FORMAT a70
SELECT id capture_id, name,to_char(start_time,'dd/mm/yy hh24:mi') start_time FROM dba_workload_captures;

-- We can generate detailed info about capture
-- in HTML or TEXT format using the next one
set serveroutput on size unlimited
set pagesize 0 long 30000000 longchunksize 2000 linesize 600
--col output format a600
spool report_capture.html
-- capture_id is get from above query on dba_workload_captures view 
-- (you need get for the last capture id, my example is capture_id = 101 )
select dbms_workload_capture.report ( capture_id => 101,format => 'HTML') output from dual;
spool off
-- Now you can open report_capture.html with web browser

/*
 * the capture report example (in this example is on TEXT mode):
 							       Avg Active
Event				    Event Class        % Event	 Sessions
----------------------------------- --------------- ---------- ----------
CPU + Wait for CPU		    CPU 		  4.17	     0.01
db file sequential read 	    User I/O		  4.17	     0.01
	  -------------------------------------------------------------

Top Service/Module Filtered Out 			  DB: CDB1  Snaps: 2-3

Service        Module			% Activity Action		% Action
-------------- ------------------------ ---------- ------------------ ----------
pdb1	       sqlplus@lab-db12-2-ol7 (       8.33 UNNAMED		    8.33
	  -------------------------------------------------------------

Top SQL Filtered Out					  DB: CDB1  Snaps: 2-3

		 SQL ID     % Activity Event			      % Event
----------------------- -------------- ------------------------------ -------
	  ab8xx2hrk1rku 	  8.33 CPU + Wait for CPU		 4.17
** SQL Text Not Available **

				       db file sequential read		 4.17

 */


-- NOTE: Also remember the capture process generate a HTML report 
-- on this directory when we finish capture
-- (Remember for my example the name of my directory is RAT_DIR_PDB1_20190821):
/u01/RAT_DIR_PDB1_20190821/cap/wcr_cr.html


-- After finish or stop catpure we can see 
-- the next files (*.rec) generated (Example)
[oracle@oraclelab RAT_DIR_PDB1_20190821]$ ls -lptrR /u01/RAT_DIR_PDB1_20190821/capfiles/
/u01/RAT_DIR_PDB1_20190821/capfiles/:
....
/u01/RAT_DIR_PDB1_20190821/capfiles/inst1/aa:
total 4
-rw-r--r-- 1 oracle asmadmin 2423 Aug  6 13:59 wcr_0uxm9h000000u.rec


-- NOTE: BTW if you want you can export the AWR file generated during this capture using capture_id:
BEGIN
  DBMS_WORKLOAD_CAPTURE.export_awr (capture_id => 1;
END;
/




/*
 * 7.- REPLAY CAPTURE
 *
 */

 -- create new directory on the target database server
mkdir /u01/RAT_REPLAY_DIR_PDB2_20190821
alter session set container=cdb$root ;
CREATE OR REPLACE DIRECTORY RAT_REPLAY_DIR_PDB2_20190821 AS '/u01/RAT_REPLAY_DIR_PDB2_20190821';


-- We need copy on this new folder /u01/RAT_REPLAY_DIR_PDB2_20190821 
-- the capture files from the source.
-- So please copy the content source folder /u01/RAT_DIR_PDB1_20190821
-- to this new target folder /u01/RAT_REPLAY_DIR_PDB1_20190821
-- NOTE: It's very good idea to have the same
-- date between the source and target database server 



/*
 * 8.- CREATE USER FOR TEST LOAD ON THE DATABASE TARGET
 *
 * So we need to connect to TARGET ENVIRONMENT
 * in my example the name of PDB target is called PDB2
 */
alter session set container=PDB2 ;
drop user rat_test cascade ;
create user rat_test identified by rat_test ;
grant create session, create table to rat_test ;
alter user rat_test quota unlimited on users ;


/*
 * 9.-CONFIGURE REPLAY PROCESS CAPTURE
 *
 * NOTE: for procedure process_capture there are bugs on 12.1 and 11.2
 * regarding lots of time spent on DML to WRR$_REPLAY_LOGIN_QUEUE_TMP table.
 * (specially with INSERT-intensive operations)
 *  Bug 9742032 - Database replay: dbms_workload_replay.process_capture takes a lot of time (Doc ID 9742032.8)
 */
-- The parallel_level leave with null (default value for auto-compute)
alter session set container=cdb$root ;
-- we need to use the directory's name
exec  DBMS_WORKLOAD_REPLAY.process_capture('RAT_REPLAY_DIR_PDB2_20190821');

-- For review percent progress for process_capture:
alter session set container=cdb$root ;
set server output on size unlimited
DECLARE
 retval VARCHAR2(100);
BEGIN
  retval := '-'||dbms_workload_replay.process_capture_completion||'-';
  dbms_output.put_line(retval);
END;
/ 

-- For review remaining minutes
alter session set container=cdb$root ;
DECLARE
     retval VARCHAR2(100);
    BEGIN
      retval := '-'||dbms_workload_replay.process_capture_remaining_time||'-';
      dbms_output.put_line(retval);
   END;
/


/*
 * 10.-INITIALIZE REPLAY
 *
 */
alter session set container=cdb$root ;
-- we need to indicate a replay_name and the directory
exec DBMS_WORKLOAD_REPLAY.initialize_replay (replay_name => 'RAT_REPLAY_PDB2_20190821',replay_dir  => 'RAT_REPLAY_DIR_PDB2_20190821');


/*
 * 11.- PREPARE  REPLAY
 *
 * NOTE: Remember the note: Doc ID 1937920.1 about for replay on PDB database.
 * Is not possible replay directly RAT files on PDB. In the above note is describe 
 * in detail how you can replay RAT on PDB, and the next step
 * i describe how you can do that using REMAP_CONNECTION Function
 *
 * IF you execute DBMS_WORKLOAD_CAPTURE directly on a PDB you'll receive this error:
 * ORA-20222: Running the DBMS_WORKLOAD_CAPTURE or the DBMS_WORKLOAD_REPLAY
 * package within a PDB is not allowed. Please run both packages in either the
 * root container or a non-consolidated database
 */

-- Remap connection to a PDB for our test
-- we need get conn_id and replay_connection string (this will have  null value)
alter session set container=cdb$root ;
select REPLAY_ID,conn_id,capture_conn,replay_conn  from dba_workload_connection_map;

-- The connection_id also is get from above query: dba_workload_connection_map (last row).
-- so we need put our connection string for our pdb target in this case called pdb2
exec DBMS_WORKLOAD_REPLAY.REMAP_CONNECTION (connection_id => 2,replay_connection =>'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=lab-db12-2-ol7)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=pdb2)))');
-- Verify remapping.
select conn_id,capture_conn,replay_conn from dba_workload_connection_map;

-- finally preplay replay
exec  DBMS_WORKLOAD_REPLAY.prepare_replay (synchronization => TRUE);



/*
 * 12.- DEPLOY AND START THE WRC CLIENTS
 *
 * First do recalibrate (connecting to cdb root or 
 * if want you can ommit directly the alias @CDB_ROOT )
 */
wrc system/oracle mode=calibrate replaydir=/u01/RAT_REPLAY_DIR_PDB2_20190821


/* OUTPUT:
Report for Workload in: /u01/RAT_REPLAY_DIR_PDB2_20190821
-----------------------

Recommendation:
Consider using at least 1 clients divided among 1 CPU(s)
You will need at least 3 MB of memory per client process.
If your machine(s) cannot match that number, consider using more clients.

Workload Characteristics:
- max concurrency: 1 sessions
- total number of sessions: 2

Assumptions:
- 1 client process per 100 concurrent sessions
- 4 client processes per CPU
- 256 KB of memory cache per concurrent session
- think time scale = 100
- connect time scale = 100
- synchronization = TRUE

*/


-- Now Replay
-- this terminal it will be paused until we execute DBMS_WORKLOAD_REPLAY.start_replay
-- and it will be there until the complete replay is finished
wrc system/oracle mode=replay replaydir=/u01/RAT_REPLAY_DIR_PDB2_20190821
/* EXAMPLE OUTPUT:
Workload Replay Client: Release 12.2.0.1.0 - Production on Wed Aug 11 18:26:56 2021
Copyright (c) 1982, 2017, Oracle and/or its affiliates.  All rights reserved.

Wait for the replay to start (18:26:56)
*/


/*
 * 13.- START REPLAY
 *
 * Now actually we begin the replay process
 */
alter session set container=cdb$root ;
EXEC DBMS_WORKLOAD_REPLAY.start_replay;

-- and from the other terminal we can see that display show us:
Replay client 1 started (18:32:08)

-- we can see after minutes (or hours) the replay is finished from that terminal
Replay client 1 finished (18:36:59)



/*
 * 14.- TEST REPLAY LOAD
 *
 * Now we can check if the test load it was applied successfully
 * connecting to target pdb or target database
 * (in my example is called PDB2)
 */
sqlplus "rat_test/rat_test@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=lab-db12-2-ol7)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=pdb2)))"<<EOF
select count(*) from  rat_test.rat_test_table ;
exit;
EOF


/*
 * 15.- REPORT REPLAY PROCESS
 *
 * Now we can examine a replay report using the next query :)
 */
alter session set container=cdb$root ;
set serveroutput on size unlimited
set echo off head off feedback off linesize 200 pagesize 1000
set long 1000000 longchunksize 10000000
VARIABLE rep_id number;
BEGIN
   SELECT max(id) INTO :rep_id FROM dba_workload_replays;
END;
/
spool replay_report_single_pdb.html
select dbms_workload_replay.report( :rep_id, 'HTML') from dual;
spool off


/* DONE!! that is all, thanks  
 * Cheers Felipe!
 *
 * Questions and comments to felipe@felipedonoso.cl
 * and felipe.donoso@oracle.com
 */
/*****************************************************************************************
 *
 * @author: Felipe Donoso Bastias, correos: felipe.donoso@oracle.com, felipe@felipedonoso.cl  
 *          (cualquier modificacion al script enviar mail)
 * @date  : 2016-10-18
 * @desc  : Permite generar un reporte con los aspectos
 *			mas importantes de la base de datos.
 *			Es un resumen de status general de la plataforma.
 *
 * @ejecucion: se debe ejecutar como un script normal, ejemplo:
 * sqlplus -s "ogg_mdm/ogg_mdm@BCOCHILE_QA_ODIN"  @Levantamiento_BD_ver.2.3.sql
 *
 * @obs   : Se debe ejecutar con usuario de que pueda acceder
 *			 a todas las vistas del diccionario:
 *			 (o en lo posible ejecutar con usuario con rol DBA)      
 *
 *			Los scripts de generacion de graficos son sacados de los ejemplos
 *
 *			https://carlos-sierra.net/2014/07/28/free-script-to-generate-a-line-chart-on-html
 *			Carlos Sierra, carlos.sierra.usa@gmail.com
 *
 *			https://warninglog.wordpress.com/2014/08/24/generating-svg-graphics-with-sqlplus-part-xi-pie-chart/
 *			Arnaud Fargues
 *
 *			Favor en caso de modificar los scripts para generar graficos
 *			Hacer llegar nota a los autores.                   										 
 *
 * @mod   : 2017-06-16 con el fin de evitar ver errores en los graficos numeros con el
 *          codigo: NaN se anade lo siguiente:
 *         ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. ';
 *
 *****************************************************************************************/


-- reseteamos todas las configuraciones
@clear
--clear scr


set feedback off
--exec dbms_lock.sleep( 1 );
prompt  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
prompt  * Iniciando reporte de levantamiento y estado de base de datos *
prompt  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
prompt  
--exec dbms_lock.sleep( 1 );
prompt          *********************************************
prompt          * Comentarios o sugerencias a los correos:  *
prompt			* felipe@felipedonoso.cl                    *
prompt          * felipe.donoso@oracle.com                  * 
prompt          *********************************************
prompt  
--exec dbms_lock.sleep( 1 );
prompt  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
prompt  *                  Inicio del reporte ...                      *
prompt  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--exec dbms_lock.sleep( 1 );
set lines 1024 termout off



/**************************************************************
 * No modificar lo siguiente				      *
 *                                                            *
 **************************************************************/

ALTER SESSION SET NLS_DATE_FORMAT = 'yyyy/mm/dd hh24:mi:ss';
-- Esto es para errores de los graficos SVG con el codigo NAN
-- al obtener valores porcentuales o decimales con el valor: ";"
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. ';
-- lo siguiente es para paralelizar las consultas:
alter session force parallel QUERY parallel 2;

column instance_name new_value i
select instance_name from V$instance
;
column host_name new_value h
select host_name from V$instance
;
column name new_value d
select name from V$database
;

column database_role new_value d_role
select database_role from V$database
;
column platform_name new_value d_platform
select platform_name from V$database
;
column banner new_value d_version
select banner from V$version
;

column cores new_value d_cores
select nvl(to_char(value),'null')||' Cores' cores from V$OSSTAT
where stat_name = 'NUM_CPU_CORES'
;

column sockets new_value d_sockets
select nvl(to_char(value),'null')||' Sockets' sockets  from V$OSSTAT
where stat_name = 'NUM_CPU_SOCKETS'
;

column memoria new_value d_memoria
select nvl(to_char(round(value/1024/1024,2)),'null')||' MB' memoria from V$OSSTAT
where stat_name = 'PHYSICAL_MEMORY_BYTES'
;





-- no editar esta variable pues la utilizaremos
-- para senalar el rango de fecha fin por defecto para revisar AWR
column f_ini_2 new_value f2
select to_char(sysdate-1,'yyyymmdd_hh24mi') f_ini_2 from dual
;

column fecha new_value f
select to_char(sysdate,'yyyymmdd_hh24mi') fecha from dual
;

column fecha_completa new_value f_completa
select to_char(sysdate,'dd-mm-yyyy hh24:mi') fecha_completa from dual
;

column solo_anio new_value anio
select to_char(sysdate,'yyyy') solo_anio from dual
;

/**************************************************************
 * Variables a definir y que daran nombre a los archivos      *
 *                                                            *
 **************************************************************/

define page_start  =FDB_Oracle_status_db_&h._&d._&i._&f..html
define page_index  =&page_start
define page_body   =&page_start
-- no borrar esto si no dara errores
-- cuando intentemos extraer el codigo fuente de un trigger especial
-- ej: onlogon, on startup, etc. etc.
set define off
define espacio_en_blanco = "&nbsp;"
set define on


-- No borrar esta variable es para definir si se debe ejecutar la consulta complicada
-- sobre el alert log de la base de datos
set termout on
-- prompt .... Revisar log de Alerta de las instancias? [S/N]: .... 
-- define leer_alert_log = &1
accept leer_alert_log char default N prompt '* Revisar log de Alerta de las instancias? [S/N] (valor por default: N):  '
accept rescatar_scripts char default N prompt '* Rescatar scripts de base de datos tablespaces/usuarios/dblinks? [S/N] (valor por default: N):  '

-- No borrar nunca estas dos variables
accept fecha_ini_awr char default &f2 prompt '* Fecha INI de datos de AWR [yyyymmdd_hh24mi] (valor por default: &f2):  '
accept fecha_fin_awr char default &f prompt '* Fecha FIN de datos de AWR [yyyymmdd_hh24mi] (valor por default: &f):  '

set termout off

COLUMN snap_id_ini NEW_VALUE snap_ini
COLUMN snap_id_fin NEW_VALUE snap_fin
SELECT min(snap_id) snap_id_ini, max(snap_id) snap_id_fin
FROM dba_hist_snapshot
WHERE 
        (begin_interval_time >= TO_DATE('&fecha_ini_awr','yyyymmdd_hh24mi') OR end_interval_time >= TO_DATE('&fecha_ini_awr','yyyymmdd_hh24mi') )
    AND (begin_interval_time <= TO_DATE('&fecha_fin_awr','yyyymmdd_hh24mi') OR end_interval_time <= TO_DATE('&fecha_fin_awr','yyyymmdd_hh24mi') )
;

set termout on
prompt  
prompt            * Al finalizar el script abrir el siguiente archivo con explorador web
prompt            * que soporte HTML5:
prompt            * &page_start
prompt  
set termout off
exec dbms_lock.sleep( 2 );

set feedback off heading off VERIFY    off




/**************************************************************
 * Creacion de la hoja de estilo para el reporte              *
 *                                                            *
 **************************************************************/
SPOOL ON ENTMAP ON PREFORMAT OFF
set pagesize 20
set serveroutput on size unlimited
SET VERIFY    off



spool &page_start

set markup html off
set define off 
prompt <html>


prompt <head>
prompt <script>
prompt </script>

set define on
prompt <TITLE>Levantamiento y estado base de datos &d</TITLE> 
set define off
prompt <STYLE type='text/css'> 
prompt html, body {height:100%;} 
prompt html {display:table; width:100%;} 
prompt body {display:table-cell; text-align:left; vertical-align:top;} 
prompt             table { margin-left: 5px;  } 
prompt         table { 
prompt                 font-family: verdana, arial, sans-serif; /* */
prompt                 font-size: 10px; /* */
prompt					/* color para letras*/
prompt                 color: #333333; /* */
prompt                 border-width: 1px; /* */
prompt				   /* color para las lineas de la tabla*/
prompt				   border-color: #000000; /* */
prompt                 /*border-color: #FF0000;*/ /* */
prompt                 border-collapse: collapse; /* */
prompt                 width:90% /* */
prompt         }
prompt         table th { 
prompt                 border-width: 1px; /* */
prompt					/* color para letras*/
prompt 				   color: #ffffff; /* */
prompt                 padding: 4px; /* */
prompt                 border-style: solid; /* */
prompt				/* color para las lineas del encabezado de tabla*/
prompt                 border-color: #000000; /* */
prompt                 background-color: #FF0000; /* */
prompt         } 
prompt         table tr:hover td { 
prompt                 background-color: #F6F39F; /* */
prompt         } 
prompt         table td { 
prompt                 border-width: 1px; /* */
prompt                 padding: 4px; /* */
prompt                 border-style: solid; /* */
prompt					/* color para las lineas de la tabla (cuerpo)*/
prompt                 border-color: #000000; /* */
prompt                 background-color: #ffffff; /* */
prompt         } 
prompt h1{ 
prompt font-family: verdana, arial, sans-serif; /* */
prompt color:#6E6E6E; /* */
prompt font-size:14px; /* */
prompt } 
prompt h2{ 
prompt font-family: verdana, arial, sans-serif; /* */
prompt color:#6E6E6E; /* */
prompt font-size:13px; /* */
prompt } 
prompt h4{ 
prompt font-family: verdana, arial, sans-serif; /* */
prompt color:#6E6E6E; /* */
prompt font-size:12px; /* */
prompt } 
prompt body{ 
prompt font-family: Century Gothic, Trebuchet MS, verdana,arial,sans-serif; /* */
prompt color:#3C3A3A; /* */
prompt font-size:11px; /* */
prompt } 
prompt a{ 
prompt font-family: Century Gothic, Trebuchet MS, verdana,arial,sans-serif; /* */
prompt color:#3463D0; /* */
prompt font-size:11px; /* */
prompt } 
prompt .critical {  color:#F0E910} 
prompt .fatal {  color:#FF0000} 
prompt .ok {  color:#41C63F} 
prompt #nav{ 
prompt 			position: absolute; /* */
prompt 			top: 0; /* */
prompt 			bottom: 0; /* */
prompt 			left: 0; /* */
prompt 			width: 300px; /* Width of navigation frame */ 
prompt 			/*height: 100%;*/ /* */
prompt 			/*overflow: hidden;  */
prompt			/*Color del menu izquierdo;  */
prompt 			background: #ffffff; /* original: background: #cccccc;*/
prompt 		} 
prompt 		main{ 
prompt 			position: fixed; /* */
prompt 			top: 0; /* */
prompt 			left: 250px; /* Set this to the width of the navigation frame */ 
prompt 			right: 0; /* */
prompt 			bottom: 0; /* */
prompt 			overflow: auto; /* */
prompt 			/*Color del cuerpo en gris claro;  */
prompt 			background: #f2f2f2; /* */
prompt 		} 
prompt 		.innertube{ 
prompt 			margin: 15px; /* Provides padding for the content */ 
prompt			 /*overflow-y: scroll; */
prompt 		} 
prompt 		nav ul { 
prompt 			list-style-type: none; /* */
prompt 			margin: 0; /* */
prompt 			padding: 0; /* */
prompt 		} 
prompt 		nav ul a { 
prompt 			color: darkgreen; /* */
prompt 			text-decoration: none; /* */
prompt 		} 
prompt 		/*IE6 fix*/
prompt 		* html body{ 
prompt 			padding: 0 0 0 250px; /* Set the last value to the width of the navigation frame */ 
prompt 		} 
prompt 		* html main{ 
prompt 			height: 100%; /* */
prompt 			width: 100%; /* */
prompt 		} 
prompt 		@keyframes fadeIn {
prompt 			0% {
prompt 				opacity: 0;/* */
prompt 				transform: translateY(-1.25em);/* */
prompt 			}
prompt 			100% {
prompt 				opacity: 1;/* */
prompt 				transform: translateY(0);/* */
prompt 			}
prompt 		}
prompt 		details[open] summary ~ * {
prompt 			animation-name: fadeIn;/* */
prompt 		  animation-duration: 1.0s;/* */
prompt 		}
prompt </style> 
prompt  </head>

set define on

prompt <body>

prompt		<nav id=nav>
prompt			<div class=innertube>
			
set define off
prompt <img 
prompt src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHEAAAA4CAIAAABFS4AjAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAEnQAABJ0Ad5mH3gAABFoSURBVHhe7VoLeFTVtd6PmQSSMAl5J5AEDBDA8pJ+IkHAigVa0fIJ9sIV6BWpiIgghSpyC5aAaMRIFVAolCsIAr4AQVFEQC8vW6ByVdCiPCUhCeT9nHP2uv85ZxhOZiaPltxbPjv/dz48Zz/WXuvfa6+19kTeq0f32lo34yyIa4dSqlWrVjIhIV7TNU9bENcGcBoaGsp7dO9WW1srhPA0B3EN0HUdfhqksvkR5LT5EeS0+RHktPkR5LT5EeS0+RHktPkhExMSUFVx3vhFyhpRy8hNDJcEn0dnzIExNjnEWDUR2n1Geh8McNS/LjowvZqxkAbHAPWphAcDoECtuZZoipGml9Un0G0OkJxVQZzx4iuPiP6Omh9CzpOqIdaF8TBufNqByeWMfc1YKFEbIbAUBriJ2oIXzxBfYEoeY98RdYGtfldjfBcQpTKWwNgBoiQhfFa0UEjqErHOjEdypjxtV9HS1ApEtDJo4kWcHH4L2YG+UqKzjDoQTwgkEE4TxthRxm5mPJ/RRc4jPD0eWDV/kziFv2CxmVz8RjoaGFfD2HJST+laDOdOzisVnXY4wWkLT38AfElqgK5HcxZq23O8FSmVzvle6cTnYlK/07V2dWnViC4S/YrLRVLUx1Q+sQTd/Scu75diB6lJuhZm7nc9oDyiTMaXcmdK/Ub+SHf/iLGRXH7H2WZdvyw4iPaiqZzC3XSiLdJ5I+fY82+IqvzCMLa0JePpjFpw/i3RT3VNCU6KzjicuYaDk/QMvApMSYMHcZ5LdIfudgpQ4wGOaoWiw9JpERDPWA+9togLl9lrgi4rtlHI/kLgSGJF+KMPWTGMPaC0XYyWMsevpdjF1K91zcUDc4pGnMJ5XE4RhqZniQr8BEYy9jqpuaT/gvMHmPyEqaOMTjMe4uk30CRO0fo/Sh2Rzm6cK6LxSj9O5PY7qyAohPE+jGUJ6eJ8p1IPks6JnXM40dVd08CwzxSN2A2C/5eQEcSfVNpGzqI8PaxQqWnCMA/H/xtG/bg4qdQg0uM5hz54TpBay+W9QsJ1J5J2VFG1n0rYocuMFXM2n+SDUnzE1ERdaxWIU7QUkBrM5Rou8bFCqdWkV3o6rwJHBkSHcR5OhG2G/K84jmAdeU267xczGs55L85xrocpfSdTpdzwI3zaH/hvKaONjMYqcMUGCdGPcUstLFDJDdfGLPtDgm1T6iNFoZxlwEmVso52DVE7zsFpOGPPKH2a0jVGnYWYwgUohgVYLonxfxNIFWyscr+pVFEgleC5OAQBo7APsOvFxJcIUcuNOPOo0k4TFfk9CDWSEJENySdBqBHT/DfIQEOcYgYywHguofFmUscYxXGBwIdk7f+gvS3n7xMdVSoUUZxfDX84TpBQxFiJ7Skyu5NMraoU6cJYjhPBnteEE07xNyJEZxzD5eCdsWlCpHIjjBYyethUezepvYiYIrBKCOhNIRSoZDSEG0c4jxEOxM+kHCBlX7+nv5S3CkepUhCOUgRRzjPfDw1xCp1gjMvM8oh6iFz1ijGBDUcUgy/jPQWH8cpoeDFi/wTOh3F+t/ncxfkQzv4kZHfjBNBfmOLMiD6niH4jRAeTuzFK78B5e84fJ62MjHi9gjtOmGqkgXxEPQQQDne/ViCLpmBfmXHyc4R8h4mNgZ71THYyT0CjaMRPUdzpJjmoISw0sPkYVsZYG5N5ewkFj/2C1C+5fEU4FgjH00IuFI4lwjlKyCjGN+n0LnbOmEsdOZ8ljGORw9TnKN0YlTCKJjZUueHsvTkfK0SpIsswqCSb6IoNAhQgTEE+jEU5eDzQc5bYO6SWKS22fvf0opFtdnC2H97O2G1cxGJtM4NDqv8DQQg0sPOXQkC5Q4S0f
prompt 1VIhRC3KPcO0qMIBnAU1Z+Q+jOpyUobR1qqeU6riJ4RErnuhFJIjHifwuUjXD4u5BAuPiNCPfsHIREBVjMdK97GeDLnKPKEGWcDPl5Yn1DS2+V9XIzvYYTwjWITab2rXnujcnet+6SRG3pGoxRrAqeN5H2wk0eqSIZgJ0HTcFVbxQSW9/EPrANC4xhbhfqGi0KiEUq7QCzXYRSYHXU3YhDKhouMXuRynJCXGS1U+iKlx3IBXrAKqOnH+RqBipQP0d1nwKxf3Qnfx4PMNlbpJdKJ5PYNqTuVft50c4z10QomIXO+xBwTpNhOaoSR9wMwgmFIQRulxElCiHtY6ZuZas2MGsMrENMQ0fDgHgFX9VnIi6bWpyi/UQZuEI4KMlREZoAN3lrSgptRKnGke0RumDde17ajViWG+hS9FqdwcNB6geHuIGcLiSALdu5TOgps8Pgl8r4jBI17SP1M11Cs9BFigHkqLRpgTxjj04Vx3DN1N8qLP0tnJTeOzqdE3zJlJrk6wPVpE6mhTE6U4m9K7WBIngE4BdowmqzopHREcI4S5SjOkFKIeT6jkV0uMVqhKKqeq0NTOcXsXJSHnCMIJjPkO0+7PyrJWHKG0reSSheizKz50e7lFMDs40qNEmKlcOB+BfccqLRTRG9Lx+1cwF+66O5Y87ZTTqrCDOUWMB1OdFDIPijLiQm9NpOLZUhoTOCuHBC5jJJ1bRHD9U8is/n4gR0vK32u0lEqrBSiDxPR9R/wbrq7Cknf8+WLpnIKYIV8oihGQxkKGoMd/7OPVHaK1G6mLjFcljluX7hiP2HW2NlwIgRiU1FMhG1ncNdiHDEaohAo3mZqDJdQ9GPSj5h1tSXWB0SYTVPN2yDumnuZQjFwN+NQyTLSrlU442+R+pxREmPjuBSY7ac2ALNrGF9LCsUpQlAJqduY6MVxJoyjbx8PH/+a9FeNkuaaz74FWFlrXgExzu8nFANGAcU4chSqReMdBBArN1cPJ4Na70lCE4SUGz9ZGUqjMETxXM4Is5CgED0CM2oCOlSZq+NcI18gDZaa7aDM/O9VmJI5tgeXCExpQCYQxj03YyiN0gXkGmehLvANIyIbLHv/Pk7/72Cp2LDN/jAtvO5gcfpPo9ILUPMPsHMdEurFP5/THx4aP/voNX7HCMKEkI6QEPvPe3XQpHhaVVXZs1fv+DapepBWJC7pyP/+7F+PHm7Z0ntXr4MmcappWuvo6JZhEbhqepr+hcG5qKosL7p82eEIXOw2Ne/rmob7z/WcE/7fgGIDBZysh1Dgeqmlfki4XmqpHx4a//s+egFlAsMa9mhrMIb5C7S6LDkWcGkJONLtdqMXC/l3AXY5+JTS+iEhACBf0wxRDYwBqqura2pqsJZ/lIQE+3IAGhtgAONDQ0Mb8VPkKKfTGRYW1qJFS/xbUlxy4cIFzPR01wW4cDic4eFIaDCmTp0AtZzOEEuO9SB1tmjRAlr6SIN56HO1aoWI5GmyAeNheXhYOCSEh4fj8+zZswGph1iQ5XJFofQJKArAWt+fP982JaVnj55QBqbZ+YIEwFDUUNXQOSwsXEqh6bi7NoSG4il0hcaLX3xx0O2DYAmQl5e3adOmZUuXJiUl+liC5cF41vz5w4bdtfa1NU8vWJCYmIRmq/fSpUvzsrJGjRpdZgKKRkREXLjw/Yh77oETeVeHkDNnzp4+c5oUjbhnRN7FXJ9isKSkZMyYMZMfmeJApnDK4uKS99/b9uSTs9PS0jwjrqCqqqpTp05r1rxGjNJSU9LT0z0dVwDGsSWvLF9+++13OBzy/Lnzz2YvXL9ufXJyMtTAANMPHPN+n9Xzppuwf2gE79u2bZs08cHUtDRrjA8wpfF4CteLjopKTU19be3arKx5qSmp8+fPnz79seLiYs+IK0Alm9G509hx4+Li4+4deW+7du3c7qt/vGnZMnz3x7ufmjtn3br1GRkZx44dmz1r1isvv
prompt 4KN8e4NXrBnU6dNjY2Ni4uPX/DMglOnTnl7LcD9o2Ni2rZtu3jxC7NmzULLlEenTZgw4fLly9YAC9ik706dfj4nB8rEx8ffN3ZsUVGRp88EGKmoKF++YsXgwUOG/+LuiPCw+MSEhQuf7datG7j2DDLM19qkpMCWhydNyn722aefXvDO22+iuAxIqBeNcAqTwD1e3t+xY9UfV0DFwsLC//zdnOKSEmuAF1i+d+8fw5cz+/VNSU3t2Cmjquqqcjj0+/fvW7Vy5datW/B56LODK1as2LplM5zUzhpcePLkRw4dPJidnd3/1gGaHqAo1pWhz7JlS1euXPXcc9l4dzidPkbCFeJiY7p2vfHlZcv27t37xONPXMjNsy8Eo1JSUjt17IT3/fv3V1RWZd5yyws5zyMa2I+sYb4ZxN58660X/7B4UXb2vn374IlWb31ohFMvIl2u+ITENsmJm9/ZjM/kpCTN7ba6L
prompt GB7Jz406fCRIwf2H8Tn4CFDvQffAg57TGxspMtQCIE1Ni42MirKbmd5eXn/AQOTk5I/3Lnz2Oefo2X06NEIGlavD97f8cGHH36wbNnLC+bPX716devWrT0dJhG5ublTpk7F+5KlS/DeoUOHjIyO4MsaAGAvz50795fDh/H+xRdffLRz54CBA+fMfQqNPtHG+rPae+9t3/PJpwcOfTag/0DoaXXVh6ZyagHy3ZoR70NDnXbCcCRBEGLWc9mG46xds+b+//hVaWmZj/uYn2YLgpzf8YGT3jXsLsbZnDlz3t26Jf/ixZkzZ+bn59t598L6H58w5aFJk7p07YroabUDStelw4lDjYDw1VfHEbXQeN99Y3DCvKLw4nK57h05cuSIe+Czg+64Iycn5/jxEwkJCXbqDZgzwCwp1SI0tLqmOqA+djSVU2wOdCopLho69Of4PHf+exxzqwtrYHvnzpmL9w0bNoAsRFW8Dx
prompt 48uLTU+sm4ccCwuLi4WwcMwDsklJSVxyck4DT07t3bHuC8yMzsB9bgnjExMdMfm24vMyoqK/v369uzR49oM/Bt274djTff3CciwqgTrDFGnoiOnjNnLiYi4cCEDz/4oHPnDIittm0PYDF457Bht/bv371HjwMHDuDAWV31od5r1lWYDtWnTx+XK/KBCePbt2/3+vp1oSGh9u2qrKoGj0ePHkFaiAiPgAvA17Kysjp36QqzvZaYMGb5OylsQ6X84943Pf/8ohMnvoYf39Cu/ZOzZ/fr12/dunWg2zPuipHj77+/rKy0b2Ym3g0Xsi0BvrAu6sR/Hz0qOia2sLBgxsyZ2IDU1DTkQORujMFyUa1bP/X7p1AYJSfEV1VXuSIj0Z6fnydsxaz5K4ex3E8GDrwhPR0VSmFB4dG/HkFRZQ0IiEY4hfFgCC/zFyywjFn76qszZsyIjY01+w0gpT40cSJetmze8sbGjSizCgoKMzMzhw8f3uGG9ijUvB4NIJ/gX5QmPrxWlJdPmjcPL0teegmRGlcLHAVw+tPBQ97dtg1jrdXxr/W3iz+uWmn+OYZ/dfzLx3/7W0OgCZCL90enTisoKHh9w0ZUUZWVlShCP/3vfX379n3jjTesYSjmPjt06IWcnMemT8/Lz8cpQfmMzL5r18eJiYnWGFjvdIYKh0Hxrt27LQX27tk97M4727U3anBzTAA0ct/HYugyeiFCiFPffYv/orawFrCAMcg5iGIlpaV4QQu8AN3QG8vaMykMhiqhLVq6a6rhAKhLrXbArWnw6OKiIvicMyQE8hEisRmRka6ysnKDPHNFSx9kGIjCvyhXz5w91zmjE94tOQD8NCY2Ji83DwpYs0Cry9VKSgdkepXBy8mTJ9u2bYNDXVtV8/GePSUlRenpHewuD0OccAivsbhGclhUx0vsgHpN+g0Fcr3L4E6Fkf5bBFkAVvLKsWbZWyygEfdFmGdnwYIbtx3zgmgRYbS43VgLi3pbAGst6x3CkabtLACYgono8lru32IBYmF7RUUFuuANWMjHNHxiLbt8fyF2YHDwd6lmhsVpkMrmR5DT5keQ0+ZHkNPmR5DT5keQ0+ZHkNPmh0yMj8ed115UB/EPA7cD3EF475t64fqI+7WnOYhrAGp+l8v1vy6A+fAI8+tqAAAAAElFTkSuQmCC"
prompt />
set define on


prompt <br>* BD: &d <br>* Rol: &d_role<br>* Server: &h<br>* Plataforma: &d_platform<br>* &d_cores  &d_sockets <br>* Memoria: &d_memoria <br>* Version BD: &d_version <br>
prompt <br>Tildes omitidos intencionalmente<br>* Fecha ejecucion reporte:
prompt <br>* &f_completa<br>
prompt <br>Comentarios y sugerencias a:
prompt <br>* felipe.donoso@oracle.com
prompt <br>* felipe@felipedonoso.cl<br>
prompt  <h3 id="indice"><i>Indice:</i></h3>


prompt <details>
prompt <summary>
prompt +[INFORMACION GENERAL]</br>
prompt </summary>
	prompt ... <a    href="&page_body#18cnvm_1827fhc_cnvhGtdG">Arquitectura hardware </a></br>
	prompt ... <a    href="&page_body#Version_Djgyew56Terli0K">Version BD</a></br>
	prompt ... <a    href="&page_body#ParchesPSUCPUyactualizacionesaplicados_JfgT45Rdfrt67Hdf">Parches</a></br>
	prompt ... <a    href="&page_body#Informaciondelabasededatos_1kfhajd8642">Base de datos</a></br>
	prompt ... <a    href="&page_body#hay163940187vnblkpqufhvnsj231fhvjsmjvnbju38rh">Encarnaciones de bd</a></br>
	prompt ... <a    href="&page_body#Informaciondelasinstanciasdebasededatos_fusyrhey342">Instancias</a></br>
	prompt ... <a    href="&page_body#hasdhyn208vmabc816456100masshasd">Propiedades base de datos</a></br>
	prompt ... <a    href="&page_body#Datafiles_Hr5872dJrtposs">Datafiles</a></br>
	prompt ... <a    href="&page_body#Tempfiles_dhs64tr5Tdgwdj9">Tempfiles</a></br>
	prompt ... <a    href="&page_body#Redologs_ydte53gdksutcg153">Redologs</a></br>
	prompt ... <a    href="&page_body#asdasd726tfnvbcy1098uwycnbagx4_273">Redologs standby</a></br>
	prompt ... <a    href="&page_body#DBA_TABLESPACES__Hft4591Sqp9y">Tablespaces</a></br>
	prompt ... <a    href="&page_body#DBA_USERS_yr546Gte40nnn">Usuarios</a></br>
	prompt ... <a    href="&page_body#DBA_PROFILES__ufy5683hjfyMMcvat13e">Profiles</a></br>
	prompt ... <a    href="&page_body#DBA_FEATURE_USAGE_STATISTICS_jashfd72645Gsdgf">Opciones habilitadas</a></br>
	prompt ... <a    href="&page_body#hasy16e9fmhahsuhydh973rka927ehdjabmgpaj72">Daylight savings time zone</a></br>
	prompt ... <a    href="&page_body#kasju17dhaashdhashdhasdhH__jashf8109dkMha">Db_links</a></br>
prompt </details>


prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
prompt +[MULTITENANT CDB PDB]</br>
prompt </summary>
	prompt ... <a    href="&page_body#20191010_1821">PDBs</a></br>
	prompt ... <a    href="&page_body#20191010_1824">PDB_ALERTS</a></br>
	prompt ... <a    href="&page_body#20191010_1825">CDB_SERVICES</a></br>
prompt </details>


prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
prompt +[PARAMETROS DE BASE DE DATOS]</br>
prompt </summary>
	prompt ... <a    href="&page_body#20190726_100">Parametros (no-default)</a></br>
	prompt ... <a    href="&page_body#20190726_200">Parametros <> entre inst. Rac </a></br>
	prompt ... <a    href="&page_body#20190726_300">Parametros (Todos)</a></br>
	prompt ... <a    href="&page_body#20190726_400">Parametros ocultos</a></br>
	prompt ... <a    href="&page_body#20190726_500">Parametros modificados en el tiempo</a></br>
	prompt ... <a    href="&page_body#20190726_600">[PDB] Parametros por PDB (sys.pdb_spfile$)</a></br>
prompt </details>
prompt <hr>

prompt <details>
prompt <summary>
prompt +[ESTADISTICAS EXTRAS Y DATOS]</br>
prompt </summary>
	prompt ... <a    href="&page_body#Uahsy163hfy47163dgah_Resumen_sesiones">Resumen de sesiones</a></br>
	prompt ... <a    href="&page_body#jsduhsyqwye16238fmlos0182uensnds">Sesiones conectadas</a></br>
	prompt ... <a    href="&page_body#Objetosinvalidos___Hnchwter18264mshdyBvter5361">Objetos invalidos</a></br>
	prompt ... <a    href="&page_body#1udjd7ahHHyagTT__ahsyqTrqfav123Ggasbsdgga12312">Objetos modificados</a></br>
	prompt ... <a    href="&page_body#jashu172hdgaygasdyqgwgdaygsyw">Objetos con errores procedurales</a></br>
	prompt ... <a    href="&page_body#hahashahsashduh276263476efhdf_1838fnbavachqi">Triggers especiales (ej: onlogon)</a></br>
	prompt ... <a    href="&page_body#idjayt16dgdghja71ydgTTgdfaqPPiadhahsadhydd1v">Indices invisibles</a></br>
	prompt ... <a    href="&page_body#djahUjjhdhYATQGDRQFGDHAuqhdhaytqAFAFFd918283">Tablas con skip corrupt</a></br>
	prompt ... <a    href="&page_body#objectswithnoitdefaultuqyw61yt23twwv86">Objetos con buffer_pool</a></br>
	prompt ... <a    href="&page_body#201902191632">Objetos con read_only</a></br>
	prompt ... <a    href="&page_body#201902191643">Objetos con result_cache</a></br>
	prompt ... <a    href="&page_body#201902191649">Objetos con compression</a></br>
	prompt ... <a    href="&page_body#201902191652">Objetos con row_movement</a></br>
	prompt ... <a    href="&page_body#201902191657">Objetos con cell_flash_cache</a></br>
	prompt ... <a    href="&page_body#201902191700">Objetos con flash_cache</a></br>
	--prompt ... <a    href="&page_body#Objetosconmayoroverhead_Hvn37501MDrqwyT">Top Object overhead (tops)</a></br>
	prompt ... <a    href="&page_body#TablespacesEspacioutilizado_hshduJu1639857tgd">Espacio en tablespaces</a></br>
	prompt ... <a    href="&page_body#Tablespacestemporal_57YhbnEqpMnu">Espacio en tablespace temporal</a></br>
	prompt ... <a    href="&page_body#Tablespacesundo_Hvbt465qPmncfT">Espacio en tablespace undo</a></br>
	prompt ... <a    href="&page_body#hashasy187dHyahshdy1gdhaPidja8">Tamano de BD y por esquemas</a></br>
	prompt ... <a    href="&page_body#20190826_1038">Quotas de Espacio (DBA_TS_QUOTAS)</a></br>
	prompt ... <a    href="&page_body#20190304_1537">V$SYSAUX_OCCUPANTS</a></br>
	prompt ... <a    href="&page_body#flash_djsndhNshyue71634Tdget1lmBfsv">Flash recovery area </a></br>
    prompt ... <a    href="&page_body#Opcionesglobalesparaestadisticasdetablas__djN527O061">Opciones de gather stats</a></br>
    prompt ... <a    href="&page_body#Tablascandidatasaactualizaciondeestadisticas_fj127gr">DBA_TAB_MODIFICATIONS</a></br>
	--prompt ... <a    href="&page_body#DBA_TAB_MODIFICATIONS_vn12trt8936ry663">DBA_TAB_MODIFICATIONS (TABLE_OWNER NOT IN ('SYS','SYSTEM'))</a></br>
	prompt ... <a    href="&page_body#djancj_19fjhhy172_sofmbnbyt_auqeufh13fr4">Rutas de archivos de diag.</a></br>
	prompt ... <a    href="&page_body#Alertloglistener_jashNsh127Hdnssa12Lijsj">Errores en archivo de alerta</a></br>
prompt </details>


prompt <hr>
prompt <details>
prompt <summary>
--prompt <br>
	prompt +[JOBS Y SCHEDULER]</br>
prompt </summary>
	prompt ... <a    href="&page_body#uywe7038465346792mvnvgay7rijfhfy7272zbsgwaq018mvn7">DBA_AUTOTASK_CLIENT</a></br>
	prompt ... <a    href="&page_body#20190708_1220">DBA_ADVISOR_TASKS</a></br>
	prompt ... <a    href="&page_body#y1723yqyweywdfno19238hhdnauwhwujsdjahsh">Mantencion (dba_autotask_operation)</a></br>
	prompt ... <a    href="&page_body#8dj81jwdhKjhasjh71hdhYYhasyhCCzfarsTgfa">DBA_SCHEDULER_JOBS</a></br>
	prompt ... <a    href="&page_body#182ueh1hhdhYYghsgCCqeQQazxasqe91olmcbco">DBA_JOBS</a></br>	
prompt </details>	

prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
	prompt +[ASM]</br>
prompt </summary>
	prompt ... <a    href="&page_body#asm_dhNv1uf63yfGbcpyiushNB1wkG1">Espacio en discos ASM</a></br>
	prompt ... <a    href="&page_body#18dhHHaushh183d918dj_kajdhahahd">Atributos de disco ASM</a></br>
	prompt ... <a    href="&page_body#asm_UnB16fPskj6fyhb726RfgstfCdx1">discos y devices de ASM</a></br>
	prompt ... <a    href="&page_body#uashdyahsh_jahs6182uydjasgdbg__k">V$ASM_CLIENT</a></br>
	prompt ... <a    href="&page_body#jdjahHHgabQQwaxzsWsaoqjspkn81231">V$ASM_USER</a></br>
	prompt ... <a    href="&page_body#81jdhhHHgarqexcadrePPisudhnabsbg">V$ASM_USERGROUP</a></br>
	prompt ... <a    href="&page_body#kajcnbcgwWasqeFfgarG616235152308">V$ASM_USERGROUP_MEMBER</a></br>
	prompt ... <a    href="&page_body#TraeqdErtqysoOusuydhagGfafsafdf1">V$ASM_TEMPLATE</a></br>
	prompt ... <a    href="&page_body#jHhsgdgabcg1716gdbaGyaytsduyhasg">V$ASM_VOLUME</a></br>
	prompt ... <a    href="&page_body#hYtqtsrFfags1670KmnbvXzxasvnuhsa">V$ASM_VOLUME_STAT</a></br>
	prompt ... <a    href="&page_body#20190730_1410">V$ASM_ACFSVOLUMES</a></br>
	prompt ... <a    href="&page_body#hag16235gTfafsdff162LLLjajdhNNNh">V$ASM_OPERATION</a></br>
	prompt ... <a    href="&page_body#hayshHgagsg1728dpLkajsdnHGGffads">V$ASM_DISKGROUP_STAT</a></br>
	prompt ... <a    href="&page_body#haggsrRfarsfrqOidjm76142392746d6">V$ASM_DISK_STAT</a></br>
	prompt ... <a    href="&page_body#UtqrEoaplhFbcmakfhtqt12735481902">V$ASM_FILESYSTEM</a></br>
	prompt ... <a    href="&page_body#1uduahhgatTyaioPPPPkajsjdNNNN123">V$ASM_DISK_IOSTAT</a></br>
prompt </details>	
	
	
prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
	prompt +[EXADATA]</br>
prompt </summary>
	prompt ... <a    href="&page_body#817d7hdbhn__djadjay17dhBhasdhady1gddda">info V$CELL</a></br>
	prompt ... <a    href="&page_body#8djfhahdyGgdtag610dBvczxXXXXdfgadgaydd">info V$CELL_CONFIG</a></br>
	prompt ... <a    href="&page_body#yyyTTrqersfGUIsopMnjdhha__dhadg16321Hd">info V$CELL_OPEN_ALERTS</a></br>
	prompt ... <a    href="&page_body#19283udjajdn_kadjdhaau1827dahdhahhsdhh">Storage Index - Smart scanning usados</a></br>
prompt </details>

prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
	prompt +[NETWORK]</br>
prompt </summary>
	prompt ... <a    href="&page_body#201909121200">DBA_NETWORK_ACLS</a></br>
	prompt ... <a    href="&page_body#201909121202">DBA_HOST_ACLS</a></br>
prompt </details>

prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
prompt +[LATCHS]</br>
prompt </summary>
prompt ... <a    href="&page_body#spincountashdyt18450gkjsgft361t">spin_count (x$ksllclass)</a></br>
prompt </details>

prompt <hr>
prompt <details>
prompt <summary>
--prompt <br>
prompt +[PERFORMANCE ACTUAL]</br>
prompt </summary>
	prompt ... <a    href="&page_body#SesionesactivasordenadasporLAST_CALL_ET__Jdh13mndsewq8">Sesiones activas (10g)</a></br>
	--prompt ... <a    href="&page_body#SesionesactivasordenadasporLAST_CALL_ET_Jshdy264hfLo93">Sesiones activas ordenadas por LAST_CALL_ET (solo 9i)</a></br>
	prompt ... <a    href="&page_body#Sesionesenenqueue__Jdfhd7346fhshd">Sesiones en enqueue </a></br>
	prompt ... <a    href="&page_body#Arboldebloqueos__Jah376fhYd736T">Arbol de bloqueos</a></br>
	prompt ... <a    href="&page_body#sesiones_killed_Gbags6384MjdhcvaqRcsas187632kgs">Sesiones con status KILLED</a></br>
	prompt ... <a    href="&page_body#20190806_1130">MEMORY Status</a></br>
	prompt ... <a    href="&page_body#hs61twtGsfafs167491gfafsf_statusSGA">SGA Status</a></br>
	prompt ... <a    href="&page_body#hs61twtGsfafs167491gfafsf_statusPGA">PGA Status</a></br>
	prompt ... <a    href="&page_body#asdasdasdsdsad_actualizacion_estaditicas1231231sd">Status jobs de estadisticas</a></br>
	prompt ... <a    href="&page_body#redologswitch_Hsgdbcg506lPaq13Ncf7">Mapa de redolog switch generado</a></br>
	prompt ... <a    href="&page_body#1273ydyasasyhfbvbo0283_ajshdyqtw612tgdas">Parametros de perf.(General)</a></br>
	prompt ... <a    href="&page_body#182jhH_paisnUakajsj_91i2djasdhh172ud8dh7">Parametros de perf.(Exadata)</a></br>
	prompt ... <a    href="&page_body#18172hjdha99yad_ahsydsh_hahsyqy2717127273">Parametros de perf.(Set de caracteres)</a></br>
	prompt ... <a    href="&page_body#18237dhasyGtagGtqiwOOisuagGasvqy6172gaggs">Full database Caching</a></br>
	prompt ... <a    href="&page_body#27ry17fnvbbmp082ydgxbvagwtebabdj17egfhgnbku">SQL Profiles</a></br>
	prompt ... <a    href="&page_body#182fnvneu750tpjanxb1_18273hansh73h4b">Foreign Key (FK) sin indices</a></br>
	prompt ... <a    href="&page_body#jajsh__ajsjhdu1837fhHgags__18dj1u3da">dba_sql_plan_baselines</a></br>
prompt </details>

prompt <hr>
prompt <details>
prompt <summary>
--prompt <br>
prompt +[PEFORMANCE ASH]</br>
prompt </summary>
	prompt ... <a    href="&page_body#15twgcnkaief98284hfnbaka018347hnamdsjdh">ASH Resumen</a></br>
prompt </details>

			
prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
prompt +[PERFORMANCE AWR]</br>
prompt </summary>
	prompt ... <a    href="&page_body#20191206_1527">Resumen completo de AWR</a></br>
	prompt ... <a    href="&page_body#hasdhjasjdjqiuhjashjashduyqwhu1787834765439gmnvdiowe8482">Propiedades de AWR (retencion y uso)</a></br>
	prompt ... <a    href="&page_body#633642trfnvnjdhghtwte65hfhsh_ohpho968hjwhehrsdsaasnbwerw">Top query Elapsed time </a></br>
	prompt ... <a    href="&page_body#73723yhfmsdjsfuvnvbnvia083urhfjaiqwjdnafncvudnakdjqhqehq">Top query CPU time</a></br>
	prompt ... <a    href="&page_body#hjmbnzvwo385ynvs7_18374hdsjs_unfnahshd_81jnnajsjdjajsjdj">Top query logical reads</a></br>
	prompt ... <a    href="&page_body#vnmsas_91jejfdjajfusj_823urjfsgunbieuw7rywfhsfnshshehfhs">Top query physical reads</a></br>
	prompt ... <a    href="&page_body#hahayda71yIIuajsbxvqrEyajs813jdPdadpapdidJhahdydqy2hdhdh">Top query UNOPTIM. physical reads</a></br>
	prompt ... <a    href="&page_body#1828djahdh__jfhah17ehHHdgabsy1dOOiuahdhcb12d__jahbh1hed">Top query IO waits</a></br>		
	prompt ... <a    href="&page_body#201902191746">Top query IO_OFFLOAD_ELIG_BYTES</a></br>
	prompt ... <a    href="&page_body#201902191754">Top query IO_OFFLOAD_RETURN_BYTES</a></br>
	prompt ... <a    href="&page_body#201902191757">Top query IO_INTERCONNECT_BYTES</a></br>
	prompt ... <a    href="&page_body#201902191759">Top query CELL_UNCOMPRESSED_BYTES</a></br>
	prompt ... <a    href="&page_body#Crecimientodelabasededatos__dh50912eyds">Crecimiento BD ultimo periodo</a></br>
	prompt ... <a    href="&page_body#Crecimientodelabasededatos__fhsyrywqteGcbsg14Tknjsu">Crecimiento BD periodo seleccionado </a></br>
	prompt ... <a    href="&page_body#systime_model_ajsjd1832jBfjof93Hfuey67sj">SYS_TIME_MODEL analisis </a></br>
	prompt ... <a    href="&page_body#Objetostopenlecturaslogicas_HvnbfhThduwj58712Pmv">Top obj. lecturas logicas</a></br>
	prompt ... <a    href="&page_body#Objetostopenlecturasfisicas_Jvnm258PmvbaEqrwtTr2">Top obj. lecturas fisicas</a></br>
	prompt ... <a    href="&page_body#Objetostopenescrituras_hsdHbsdhsgassdsdsw2">Top obj. escrituras fisicas</a></br>
	prompt ... <a    href="&page_body#rowlockwaitsjashcnshd123twet3ytehasj">Top obj. row lock waits</a></br>
	prompt ... <a    href="&page_body#itlaysdg1632tetsdtqtwt1623tdf">Top obj. itl waits</a></br>
	prompt ... <a    href="&page_body#audhahbachhach172L_oaiscjnaPo">Top obj. block changes</a></br>
	prompt ... <a    href="&page_body#19djajdahsdhh1d__d91jdjahsdhh">Top obj. buffer busy waits</a></br>
	prompt ... <a    href="&page_body#18djhahshGGhahsh_paoisjhdy1hy">Top obj. GC buffer busy waits</a></br>
	prompt ... <a    href="&page_body#GraficodewaitseventsultimosminutosASS_JDnvg36fdhagsdas">chart waits events last minutes</a></br>
	prompt ... <a    href="&page_body#Sesionesesperaactivechart_jahsNbru70pNds">Wait sessions (+Active)</a></br>
prompt </details>


prompt <hr>
prompt <details>
prompt <summary>
--prompt <br>
prompt +[INDEXACION AUTOMATICA]</br>
prompt </summary>
	prompt ... <a    href="&page_body#20190706_131801">DBA_AUTO_INDEX_EXECUTIONS</a></br>
	prompt ... <a    href="&page_body#20190706_131802">DBA_AUTO_INDEX_STATISTICS</a></br>
	prompt ... <a    href="&page_body#20190706_131803">DBA_AUTO_INDEX_IND_ACTIONS</a></br>		
	prompt ... <a    href="&page_body#20190706_131804">DBA_AUTO_INDEX_SQL_ACTIONS</a></br>	
	prompt ... <a    href="&page_body#20190706_131805">DBA_AUTO_INDEX_CONFIG</a></br>
	prompt ... <a    href="&page_body#20190707_112700">DBA_AUTO_INDEX_VERIFICATIONS</a></br>
	prompt ... <a    href="&page_body#20190707_110900">cdb_auto_index_config</a></br>
prompt </details>


prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
	prompt +[BACKUP, SEGURIDAD Y AUDIT]</br>
prompt </summary>
	prompt ... <a    href="&page_body#as1722ujeqnqaq1wenwehqeh1_2737v_6">Bloques corruptos</a></br>
	prompt ... <a    href="&page_body#dhf1837fhjftsgat_usuarios_rol_DBA">Usuarios con rol DBA</a></br>
	prompt ... <a    href="&page_body#hasyqhd7Hgsagashy1hdu9jsd_jasjajs">Privilegios de sistema (dba_sys_privs)</a></br>
	prompt ... <a    href="&page_body#AuditoriaDBA_STMT_AUDIT_OPTS_ajvnhashy2623hgs">Auditoria DBA_STMT_AUDIT_OPTS</a></br>
	prompt ... <a    href="&page_body#AuditoriaDBA_PRIV_AUDIT_OPTS_ajdsnvh63hf712sd">Auditoria DBA_PRIV_AUDIT_OPTS</a></br>
	prompt ... <a    href="&page_body#EventosdeBackupsorestoreencolados__fjnm48657fhsgte">Respaldos encolados</a></br>
	prompt ... <a    href="&page_body#EventosdeBackupsorestoreenprogreso__fhB45yrTgdtw12j">Respaldos en progreso</a></br>
	prompt ... <a    href="&page_body#Backupsfulldelosultimosdias_bj57328hcbBdger4">Ultimos Respaldos full</a></br>
	prompt ... <a    href="&page_body#Backupsdiferencialesincrementalesdelosultimosdias_fjbndh564">Ultimos Respaldos inc/diff</a></br>
	prompt ... <a    href="&page_body#Backupsdearchivelogsdelosultimosdias__fhvnb6ur9912">Ultimos Respaldos Archivelog</a></br>
	prompt ... <a    href="&page_body#BACKUP_ASYNC_IO_sj5737fHshdy12">GV$BACKUP_ASYNC_IO</a></br>
prompt </details>

prompt <hr>
--prompt <br>
prompt <details>
prompt <summary>
	prompt +[GOLDENGATE]</br>
prompt </summary>
	prompt ... <a    href="&page_body#hasy1638fh_812_8273dbay1ndhs">Tamano streams pool</a></br>
	prompt ... <a    href="&page_body#18djdhahahshdh__981jdhahdgcs">Parametros BD GG</a></br>
	prompt ... <a    href="&page_body#djdhaUrqese8PldjanagF16sgs72">Supplemental log de BD</a></br>
	prompt ... <a    href="&page_body#3848f_auufisau37_q8hvbacbh58_21">Automatic Conflict Detection</a></br>
	prompt ... <a    href="&page_body#201902191712">DBA_LOG_GROUPS</a></br>
	prompt ... <a    href="&page_body#201907022014_01">DBA_GG_INBOUND_PROGRESS</a></br>
	prompt ... <a    href="&page_body#201907022014_02">DBA_GOLDENGATE_INBOUND</a></br>
	prompt ... <a    href="&page_body#201907022014_03">DBA_GOLDENGATE_PRIVILEGES</a></br>
	prompt ... <a    href="&page_body#201907022014_04">DBA_GOLDENGATE_RULES</a></br>
	prompt ... <a    href="&page_body#201907022014_05">DBA_GOLDENGATE_SUPPORT_MODE</a></br>
	prompt ... <a    href="&page_body#201907022014_06">CDB_GG_INBOUND_PROGRESS</a></br>
	prompt ... <a    href="&page_body#201907022014_07">CDB_GOLDENGATE_INBOUND</a></br>
	prompt ... <a    href="&page_body#201907022014_08">CDB_GOLDENGATE_PRIVILEGES</a></br>
	prompt ... <a    href="&page_body#201907022014_09">CDB_GOLDENGATE_RULES</a></br>
	prompt ... <a    href="&page_body#201907022014_10">CDB_GOLDENGATE_SUPPORT_MODE</a></br>
	prompt ... <a    href="&page_body#201907022014_12">DBA_CAPTURE</a></br>
	prompt ... <a    href="&page_body#201907022014_13">CDB_CAPTURE</a></br>
	prompt ... <a    href="&page_body#201907022014_14">DBA_APPLY</a></br>
	prompt ... <a    href="&page_body#201907022014_15">CDB_APPLY</a></br>
	prompt ... <a    href="&page_body#201907022014_16">GV_$GOLDENGATE_CAPABILITIES</a></br>
	prompt ... <a    href="&page_body#201907022014_17">GV_$GOLDENGATE_CAPTURE</a></br>
	prompt ... <a    href="&page_body#201907022014_18">GV_$GOLDENGATE_MESSAGETRACKING</a></br>
	prompt ... <a    href="&page_body#201907022014_19">GV_$GOLDENGATE_TABLE_STATS</a></br>
	prompt ... <a    href="&page_body#201907022014_20">GV_$GOLDENGATE_TRANSACTION</a></br>
prompt </details>

prompt <hr>
prompt <details>
prompt <summary>
--prompt <br>
	prompt +[FLASHBACK, RESTORE POINTS]</br>
prompt </summary>
	prompt ... <a    href="&page_body#usnhahs_o18238hbdy_sjshans12">Restore Point Creados</a></br>
prompt </details>
	
prompt <hr>
prompt <details>
prompt <summary>
--prompt <br>
	prompt +[SCRIPTS VARIOS]</br>
prompt </summary>
	prompt ... <a    href="&page_body#OHgshahsdhau17dydgatGags__ajushdyahqywdga13">Script de tablespaces</a></br>
	prompt ... <a    href="&page_body#19duuyauhashhy1uwhdahywd1udhhbdashghqw__182">Script de usuarios</a></br>
	prompt ... <a    href="&page_body#u1udhdhy_ajsdnha_kasjci81_jsjcHHagd_jasncah">Script de db_links</a></br>
prompt </details>
 
	prompt		</div>
	prompt	</nav>

set markup html on
set heading on feedback on  pages 100

set markup html off
prompt	<main>
prompt	<div class="innertube">


set markup html off
set define off
prompt <h3>
set define on
set termout off
prompt <br>
set termout on
prompt * Reporte de levantamiento y status para la base de datos : &d , Servidor: &h *
set termout off
prompt <br>
set termout off
prompt Este reporte tiene por objetivo mostrar un levantamiento, status y rendimiento general de la base de datos. Para esto usa informacion de vistas CDB_*, DBA_*, vistas dinamicas y de AWR. Hay consultas y resultados que se repetiran 2 veces en este reporte, pues se consultan tanto las vistas CDB_* como las DBA_* en caso de que la base de datos a la que nos  conectamos no sea multitenant.
set termout off
prompt <br><br>
set termout on
--prompt @author: Felipe Donoso, correciones y sugerencias al mail: felipe@felipedonoso.cl
set termout off
prompt <br>
set termout on
prompt Fecha: &f_completa
set termout off
set define off
set termout off
prompt </h3>
prompt <img
--logo 1
--logo 2
prompt src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAKIAAABCCAIAAABb1JrOAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAEnQAABJ0Ad5mH3gAAA2qSURBVHhe7Z0JbBVVFIZfpSyW0ha0FgWsBdxQXCkEV2JBUQJYFREKIkhxBQEFUQQNi0SRBFE0YgyuUTZXSFCKGKGaEJeIBS0tu0BR1CCWspRe/5lz3p07d94yb8orMTNfTpo355575r355945dx5vCIkAHxDI7AsCmX1BILMvCGT2BfFk3rlTvPKKKC4Ww4aJe+6JY0OHismTxeefc18nJSXizjv1XrENOWfPNt5Gotx/v8jLE5ddJn74gT3u+e03MX9+Ap968GBx/LjRccgQowv+Pvqomaje4GBOnWrsQttpRCssFB9+aPSqrhZFRaJXL/HGG2aWGDKXlRnHKBTyYs2aGW/Oydy5eqR7GziQk7jh5pttfbdtY39cNm4U+fm2vm5s1iyjb12d5cnONtPVAxzApk2thG4sJUUcPWr07dfPkBwnx6BBYsUKOKLI/NRTegoPlpsr/viDExKYGLSYhOySSzhPbD791GPH557TO7qxc8/l7kA6zzmHPR7Yv1+ceaaVyr19/bXRvaZG3HefmDBBtGkjtm4VTz8NXySZMe1o/WHNm4sWLUR6elRDa+PGei/4//yT0wJV5lNPFRkZtgxOQ4CMJ3v4YU4VA7wTrRcMu47NuHF6F1jsT43W1FRRUcEZgOzoWeaqKmNQ
prompt yjxkOLCxDz7eBq6GEkxm+DiLF4ubbhKffQaHQ+a33rLtICtLvPuu+Ocfbo0LJr0BA2wZzj6bm4Aq8/Ll7IxNba0YP97qBTtwgJsiMny4FYkzSb6G4TSPxgcf2CLT0gyPeoK6RGbwLDMOl0wCw8HE1TNRcG3GeBgxQrz2GjnsMh88aNvHDTewP1FWrbLlef559qsyL13KTjegxpEdFyxgp5MNG6wwGCqpggJrs2dPDnMiY2A33shOD8gk3mR+5hkrA8zlSHCBXeYpU6x9nH8+O72xbJmVCqOKUGVesoSdbli/3uqIq0401KGAShugOJAe2Mcfm3F2UFTLgPbt2ekNmcebzKecYmVIaBjEwy5zx47Wbn7+mZ2eUQv1tWsNj2eZsSiSHR97jJ0aqDVkDC5mErWcxGzs5OKLrQAPqy8VmceDzOvWWd1xcT2hKDL/9Ze1G7V69Ix6wcOxBp5lVqtCJHGya5cVAEOxraIWrpj/VY4ds8bQGWew0zNyLx5kVk/Ta681qmVtWRzbsIiKfsdCkXnHDms3997LzvqwfbuVEJUR8CazdsXC6eikc2croFcvdkrUgQL77jv2A/VNOjsmikzlQWa1ePRgqM+jo8i8c6fV55FH2FkfUKnKhDSGnDLjFMZSIS9PdOgQwTCptGxpdYHhtHXyzju2GKw7ndx2mxXQujU7wZYtll9dk3hDpmp4mUtKOE8kFJl377b69OjBzvqA1bpMOGaM4Yk4midPtpyxrV077qJy6JAtZu5c9mscP24Lkzfp1EtVp07s9IxM5UFmLIFkd9QWjRoZA9S
prompt NIX7QIE4SBXsJpt5YwEWrnowcaWXD4htEm7RRAEt/NIu2zunTx4rJzWVnRBYutCJhuEgRWVmWk24Wekbm8SDze+9Z3SdONDy1ta7MxXu2y9y/v7WnsWPZ6Q1tkO3bZzhjXJtRissmsssvN0qEvn3F44+LH3/kMA1tgV5ZacxDGAc4XzXLyBA5ObZgFNhEcbHldHOXLQYyjweZ//7b6g47eJD9JwK7zFqpgoPomYg1UewSbPNm4zsPGQC1Yl5vDNT7XCNGGJ5t2yxPXMNF3dnFvDvoEZnEg8zg6qutDFiOnjjsMoPeva09wWbMYL97fv1VtG1rS1JVxU2xZQa4Umh37SdN4iYno0dbYbiY1dWxX73JE9cw64Bbb7U5US54Q2ZA/eiBvXutDDAcxl9+4ab64ZAZc732DURamvGVFlY1M2fGslmzjC9Zu3Sx9YW9/DJnBnFlJrp3t8Jgd9zBfpWyMlvMJ5+wn8A6G1UJynun4UKAS7jsiOsUgUWzdMIwTyB42jT9YzoNIwGX0k2bjCSye6tWxtfkWmQMQ5IJE4wzFYdLJiG74grjrj4Or9bFadBozhzzw+g4ZAYouSGttjNvRl/ESlzKDIqKrEjYpZfy9/aS886zWvPz2ekSdREFo2sTln/Z2Ta/e5M31zR/QoZPRGj3CRKyKDf8I8lMFBbqKRKy9HS+wami3j1evJid0cAQkcGwJk2s2hjnvtoUcaEcG3X1giJAgqWz9Ls3GspA8ydk6jdvq1cbZaMWENcKCri7g+gyg40bjSoU1YSWLoahoL3uOvH225xBQ52RFi
prompt 1iZwzefNOKJ1uzxnbXBfbCCxycKOqNlwceYCeoqDBW+e4/9ahR3BFg3ai1urR58ziDCirEa64RmZl6cDSL/n1xTJklhw8bX2GiWolt//7L8dFAhYV1AiLxF0WAG9Rd43yHxkeOGC/I4/6LcCdYblJm/I341XJNTfxP7Vz24DO6OVaqxV074cBqXTTDHnGgouNO5oD/OYHMviCQ2RcEMvuCQGZfEMjsCwKZfUEgsy+wZK6srFy5cuXqgP8tJSUlULC6upoVVbBknjJlSmpqalbA/5bMzMyUlJSySL/SCCZtXxDI7AsCmX1BILMvCGT2BYHMviCQ2RcEMvuCQGZfkHSZDx8+XFNTg7/g0CHz377HA2HO4KNHj8o8GvAfOXKE40woMtruqqurqSOh9XVC7wfwdiT27dv3i8k2x8Op6urqZAYVOI9r/yo5aSRd5oEDB4YUmjVr1rZt21GjRm3fvp0j7EybNo1DQ6EflZ9O9enTh72RuEF5TMq6devYGwq99NJL7A2zefNmblM4/fTTJ0R51sWQIUM4KBT6K9JPq3/66acOHTpwhEl2dvZXX33FzcYPQ7/mBgevhR8Bk2ySLvPgwYP5Mzl4h37CZCcnJ4ebQ6Fx48axV4iCggL2RuKqq67iOCHuvvtu9oZCF1xwAXvDYLRxWyiUkpLCr0z6y19gKHCbyfz589kbBhpzWyjUsWPHzp0780YohCaK+eabb9jl4NVXX6WYZJN0meVoWL169f79+0tLSx988EHyAG1Ml5eXc4MJhgU3CLF169bvv/8ex27Tpk1paWlobdmyJe
prompt Lhgb+yspLjhMCEQd0JbQhKmZ988klsYsauqKjAaCbnv/Z/g/zFF1+Qn+jWrRs3hLn++uupSY5LnLvk6d27N3mkzEVFRbW1tTgIBOZ5TN0Uk2waTuYNGzawy/w2jJw325+lMnbsWDgzMjLmzZtHAd+pD5AIk56ejqbTTjuNtxVWrFhBHV9//XV68eKLL3KbiSYzMXXqVHLu2rWLXSa33HILnJ06dXriiScoAPJwm0lubi75edukb9++PXr0eCD8T/ylzPeekEd9eKLhZP7B/pCeRo0awYlpk7dNIDCct99+O8oWs1No6NCh3KbQvHlzNLVq1Yq3FXr27ImmFi1a4DWNUcyl1ERImZ82n3JIXHTRReTkbROMbHJOmjQJI55ez549m5tN5FV59OjRqPvYa0fKPHLkSHaZ4DPyq+Rz0mSWR/b3338nz5o1a8jz0UcfYTMvLw+vMQNTq0o0mY8dO2YmCBUXF2Nz2LBhtKmOUSkzumOY4uJN5xY2MflzkImcD2geatq0KV6fY//hMko8iiHy8/PHjx+/fv16bjaRMjdp0iQzMxOnIMBHwKVHu0Ykj5MmM4om8mOgkOeuu+7CZuPwI72mT59OAd9++y15JNFkfv/996nLz+ZDzWSJi1QUANQSTKV79+5btmzhIBNoBn+bNm1oU1Z2f9p/iSPPBhWcPbImiFGCHTyhjySIwUmTuXXr1uSXq1uaxu80H+eDCU2ufCA/BUiiydylSxf4zzafEopiB38p8lzlMWdSZshWVlaGkbds2TJ5iZXnXFVVFXnkJXzlypXkmTlzJnlUli9
prompt fPnz4cNSMFAPODz8mUcqMSh71I85aAgu/Bpu3T47MGBDkzMrKIs/SpUvJ4wSzJcVIIsq8Z88eio+I1E/K/BQ9kc4EhTo5saAnj7p815Dz9t69e5csWYJ3jjOSPACiynUaDeho1+aGpOFkxonMLuNRNv3J+Wj4KfJyZRIRjBUKIyLK/Oyzz1JwROTdDykzqn3yADl25SqoXbt25IkIrd+wRKRNFOTUi8A4Jr8mszyHGp6GkxlrpFWrVmF9Sdc8gu72VVdX02ZhYSE2/zZBeSJvPqD2NpMxEWXGIIMTMzYq3gMHDiAD/iIJlU5nhB/UKGUeMGDAl19+iRNo0aJF7du3J+dc87Fi8nqBsxDvkN4P0mJ6J/9k8+EkshQHmIHN9GLBggXkQX1HHikzLv8LFy58OcycOXNQPVBMskm6zNrNTglK6PLycoqR9WppaSl5JFRvA/VOQmpqKjxYPfO2cjeKBFDBxZ6a6NYp6izadHJe+LEQDz30EHl2795NHgn5c3JyaFNGAtTPqKV5IxSS/8JSvfmqcT89Jjj5JF3miRMnYqxg+URceOGFV1555YwZM9S79hisiOnatStvK2D0Y4CeddZZJcrDozAfoKrC4OBtsyxHGQV2Ov7zk7Vr12KgI8kL5nMNduzYgdf8bkzwlpBKXRBjE+9Hm4qJMWPGYK2M8luW5UiLCoN1M1cK/fr1+0P53x9QlGh7JPCutFV48ki6zD4BFwicQCgtG/Kmh3sCmX1BILMvCGT2BYHMviCQ2RcEMvsAIf4D6cyh9AvkD4oAAAAASUVORK5CYII="

prompt />

set markup html on

set pages 20

set markup html off
prompt <h1 id="Informaciongeneraldebasededatos__NsjdsT5372Jf">
set termout on
prompt Informacion General
set termout off
prompt </h1>
set markup html on

set markup html off
prompt <h2 id="18cnvm_1827fhc_cnvhGtdG">
set termout on
prompt * Arquitectura hardware (GV$OSSTAT)
set termout off
prompt </h2>
set markup html on
select * from GV$OSSTAT order by 2,1 ;



set markup html off
prompt <h2 id="Version_Djgyew56Terli0K">
set termout on
prompt * Version (GV$version)
set termout off
prompt </h2>
set markup html on
select * from GV$version;

set markup html off
prompt <h2 id="ParchesPSUCPUyactualizacionesaplicados_JfgT45Rdfrt67Hdf">
set termout on
prompt * Parches, PSU, CPU y SPU: REGISTRY$HISTORY
set termout off
prompt </h2>
prompt <p>
prompt Se deben aplicar los PSU de acuerdo a las fechas de aparicion. 
prompt Cada 3 meses aparecen nuevos PSU que se recomiendan aplicar constantemente:
prompt <a href=https://www.oracle.com/technetwork/topics/security/alerts-086861.html>https://www.oracle.com/technetwork/topics/security/alerts-086861.html</a>
prompt </p>
set markup html on
SELECT * FROM sys.registry$history;


set markup html off
prompt <h2 id="">
set termout on
prompt * Parches, PSU, CPU y SPU: DBA_REGISTRY_SQLPATCH
set termout off
prompt </h2>
set markup html on
select * from DBA_REGISTRY_SQLPATCH;
select * from CDB_REGISTRY_SQLPATCH;

set markup html off
prompt <h2 id="Informaciondelabasededatos_1kfhajd8642">
set termout on
prompt * Base de datos (V$DATABASE)
set termout off
prompt </h2>
set markup html on
select * from V$database;


set markup html off
prompt <h2 id="hay163940187vnblkpqufhvnsj231fhvjsmjvnbju38rh">
set termout on
prompt * Encarnaciones de bd (V$DATABASE_INCARNATION)
set termout off
prompt </h2>
set markup html on
select * from V$DATABASE_INCARNATION order by 1;


set markup html off
prompt <h2 id="Informaciondelasinstanciasdebasededatos_fusyrhey342">
set termout on
prompt * Instancias (GV$INSTANCE)
set termout off
prompt </h2>
set markup html on
select * from GV$instance;



set markup html off
prompt <h2 id="hasdhyn208vmabc816456100masshasd">
set termout on
prompt * Propiedades base de datos (DATABASE_PROPERTIES)
set termout off
prompt </h2>
set markup html on
SELECT *
FROM DATABASE_PROPERTIES
ORDER BY PROPERTY_NAME; 


set markup html off
prompt <h2 id="Datafiles_Hr5872dJrtposs">
set termout on
prompt * Datafiles (DBA_DATA_FILES)
set termout off
prompt </h2>
set markup html on
select * from dba_data_files;


set markup html off
prompt <h2 id="Tempfiles_dhs64tr5Tdgwdj9">
set termout on
prompt * Tempfiles (DBA_TEMP_FILES)
set termout off
prompt </h2>
set markup html on
select * from dba_temp_files;

set markup html off
prompt <h2 id="Redologs_ydte53gdksutcg153">
set termout on
prompt * Redologs (V$LOG V$LOGFILE)
set termout off
prompt </h2>
set markup html on
--select * from GV$log;
--select * from GV$logfile;
SELECT a.GROUP#, a.THREAD#, a.SEQUENCE#,
 a.ARCHIVED, a.STATUS, b.MEMBER AS REDOLOG_FILE_NAME,
 b.type,
 (a.BYTES/1024/1024) AS SIZE_MB FROM v$log a
JOIN v$logfile b ON a.Group#=b.Group#
ORDER BY a.GROUP#;

set markup html off
prompt <h2 id="asdasd726tfnvbcy1098uwycnbagx4_273">
set termout on
prompt * Redologs standby
set termout off
prompt </h2>
set markup html on

SELECT a.GROUP#, a.THREAD#--, a.SEQUENCE#,
 --a.ARCHIVED, a.STATUS
 , b.MEMBER AS REDOLOG_FILE_NAME,
 --b.type,
 (a.BYTES/1024/1024) AS SIZE_MB FROM v$standby_log a
JOIN v$logfile b ON a.Group#=b.Group#
where type = 'STANDBY'
and a.group# not in (select group# from V$log)
ORDER BY a.GROUP#;

select GROUP#,THREAD#,BYTES/1024/1024 MB_size,ARCHIVED,STATUS--,CON_ID 
from v$standby_log order by group#;


set markup html off
prompt <h2 id="DBA_TABLESPACES__Hft4591Sqp9y">
set termout on
prompt * Tablespaces (DBA_TABLESPACES)
set termout off
prompt </h2>
set markup html on
select * from DBA_TABLESPACES order by 1;


set markup html off
prompt <h2 id="DBA_USERS_yr546Gte40nnn">
set termout on
prompt * Usuarios (DBA_USERS)
set termout off
prompt </h2>
set markup html on
select * from DBA_USERS order by 1;

set markup html off
prompt <h2 id="DBA_PROFILES__ufy5683hjfyMMcvat13e">
set termout on
prompt * Profiles (DBA_PROFILES)
set termout off
prompt </h2>
set markup html on
select * from DBA_PROFILES order by 1;



set markup html off
prompt <h2 id="DBA_FEATURE_USAGE_STATISTICS_jashfd72645Gsdgf">
set termout on
prompt * Opciones habilitadas (dba_feature_usage_statistics, High watermark options usage)
set termout off
prompt </h2>
set markup html on
select  --d.host_name ,
d.NAME DBNAME,fus.name product_name, LAST_USAGE_DATE,CURRENTLY_USED,TOTAL_SAMPLES,SAMPLE_INTERVAL
from    dba_feature_usage_statistics fus, V$database d
where fus.dbid=d.dbid
    --and lower(fus.name) like '%automatic%sql%tuning%' or lower(fus.name) like '%compress%'
order by fus.name;



set markup html off
prompt <h2 id="hasy16e9fmhahsuhydh973rka927ehdjabmgpaj72">
set termout on
prompt * Daylight savings time zone (DST)
set termout off
prompt </h2>
set markup html on
select * from GV$timezone_file ;

 SELECT PROPERTY_NAME, SUBSTR(property_value, 1, 30) value
FROM DATABASE_PROPERTIES
WHERE PROPERTY_NAME LIKE 'DST_%'
ORDER BY PROPERTY_NAME; 



set markup html off
prompt <h2 id="kasju17dhaashdhashdhasdhH__jashf8109dkMha">
set termout on
prompt * Lista de db_links (DBA_DB_LINKS)
set termout off
prompt </h2>
set markup html on
select * from dba_db_links
order by 1,2 
;




set markup html off
prompt <h1 id="">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Multitenant CDB PDB
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="20191010_1821">
set termout on
prompt * PDBs (CDB_PDBs)
set termout off
prompt </h2>
set markup html on
select * from CDB_PDBS 
;

set markup html off
prompt <h2 id="20191010_1824">
set termout on
prompt * PDB_ALERTS
set termout off
prompt </h2>
set markup html on
select * from PDB_ALERTS 
;

set markup html off
prompt <h2 id="20191010_1825">
set termout on
prompt * CDB_SERVICES
set termout off
prompt </h2>
set markup html on
select * from CDB_SERVICES 
;


set markup html off
prompt <h1 id="20190726_000">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Parametros de base de datos
set termout off
prompt </h1>
set markup html on

set markup html off
prompt <h2 id="20190726_100">
set termout on
prompt * Parametros de instancia con valores distintos a los por defecto (GV$PARAMETER)
set termout off
prompt </h2>
set markup html on
select * from (
select inst_id, name parametro, value from GV$parameter p
where isdefault = 'FALSE'
order by name,inst_id
)
pivot 
(
min (value)
for (inst_id) in (1,2,3,4,5,6,7,8,9,10)
) order by 1
;
--select p1.inst_id, p1.name, p1.value  from GV$parameter p1 where isdefault = 'FALSE' order by name,inst_id;



set markup html off
prompt <h2 id="20190726_200">
set termout on
prompt * Parametros con valores <> entre instancias RAC
set termout off
prompt </h2>
set markup html on
select * from (
select p1.inst_id, p1.name, p1.value from GV$parameter p1, GV$parameter p2
where p1.name = p2.name and p1.inst_id != p2.inst_id and p1.value != p2.value
order by name,inst_id
)
pivot 
(
min (value)
for (inst_id) in (1,2,3,4,5,6,7,8,9,10)
) order by 1
;
/*
select p1.inst_id, p1.name, p1.value from GV$parameter p1, GV$parameter p2
where p1.name = p2.name and p1.inst_id != p2.inst_id and p1.value != p2.value
order by name, inst_id;
*/


set markup html off
prompt <h2 id="20190726_300">
set termout on
prompt * Parametros de instancia (todos sin filtro)
set termout off
prompt </h2>
set markup html on
select * from GV$parameter order by name,inst_id;


set markup html off
prompt <h2 id="20190726_400">
set termout on
prompt * Parametros ocultos
set termout off
prompt </h2>
prompt <p>
prompt Atencion con los siguientes parametros ocultos (aun asi la tabla trae la columna x$ksppi.ksppdesc de descripcion) :
prompt <br> * _small_table_threshold:  Defines the number of blocks to consider a table as being small. (Recordar el limite de 2% del tamano de buffer cache para intentar mantener esta en memoria, por default)
prompt <br> * _very_large_table_threshold: (esta métrica tambien influye mucho en el exadata relacionado al punto anterior).Revisar esta nota al respecto: direct path read Reference Note (Doc ID 50415.1)
prompt <br> * _kcfis_storageidx_disabled: atencion con este parametro que si esta en TRUE deshabilita el uso de storage index
prompt <br> * _serial_direct_read: para forzar el direct path read de las consultas (Direct path reads are generally used by Oracle when reading directly into PGA memory (as opposed to into the buffer cache).
prompt <br> * _ash_sample_all: Permitirá que ASH recolecte información tanto para las sesiones activas como las inactivas. Por defecto esta en FALSE. Revisar lo siguiente: https://blog.orapub.com/20180215/how-to-see-unseen-activity-using-ash-and-sqlnet-message-from-client.html
prompt <br>* _high_priority_processes (por defecto da prioridad a LMS*) y _highest_priority_processes (este ultimo para asignar prioridad a VKTM en 12.1.0.2.0 por default ). Permite establecer la prioridad para ciertos procesos background. Ejemplo de valores: _high_priority_processes='LMS*|LGWR|PMON'. En algunos ambientes se ha observado una mejora notable en los eventos de espera log sync * al incrementar la prioridad del log writer.
prompt <br>* _dlm_stats_collect   este parametro en 12.2 hay un problema y ocasiona que el proceso background SCMn consuma mucha CPU innecesariamente (Bug 24590018 ). Revisar lo siguiente: 12.2 RAC DB Background process SCM0 consuming excessive CPU (Doc ID 2373451.1) y tambien revisar: https://www.felipedonoso.cl/2019/09/bug-24590018-on-exadata-scm0-on-top.html
prompt <br>* _dlm_stats_collect   este parametro en 12.2 hay un problema y ocasiona que el proceso background SCMn consuma mucha CPU innecesariamente (Bug 24590018 ). Revisar lo siguiente: 12.2 RAC DB Background process SCM0 consuming excessive CPU (Doc ID 2373451.1) y tambien revisar: https://www.felipedonoso.cl/2019/09/bug-24590018-on-exadata-scm0-on-top.html
prompt <br>* _use_adaptive_log_file_sync: Se recomienda ponerlo en TRUE solo si hay Log File Sync y el LGWR esta muy ocupado. En 11.2.0.3 se cambio a TRUE (metodo polling o encuestar). En modo polling es el foreground process el que pregunta si la info del redolog buffer ya ha sido escrita a archivos de redolog liberando carga de CPU y regursos al LGWR, mientras que en el modo FALSE (post/wait) es el metodo tradicional hasta antes de 11.2.0.2 en donde el LGWR es el que informa si ha la info de logbuffer ya esta totalmente escrita a los archivos de redolog.
prompt <br>
prompt <br><b>Nota:</b> En el mundo NO exadata hay mejores tiempos de acceso usando db scattered read que un direct path read.
prompt <br> * _optimizer_compute_index_stats: Por default en true permite que durante la creación de un indice se calculen estadisticas automaticamente. Si le ponemos false al crear un indice no se calcularan estadisticas.
prompt </p>
set markup html on

select * from TABLE(GV$(CURSOR(select * from
 (SELECT a.INST_ID,a.ksppinm "Parameter"
       --b.ksppstvl "Session Value",
       ,c.ksppstvl "Instance Value"
       ,a.ksppdesc "Description"
FROM    x$ksppi a,
       x$ksppcv b,
       x$ksppsv c
WHERE  a.indx = b.indx
AND    a.indx = c.indx
AND    a.ksppinm LIKE '/_%' escape '/'
AND  (
            lower(a.ksppinm) like '%_cleanup_rollback_entries%'
        or  lower(a.ksppinm) like '%_log_deletion_policy%'
        or  lower(a.ksppinm) like '%_optim_peek_user_binds%'
        or  lower(a.ksppinm) like '%_optimizer_compute_index_stats%'
        or  lower(a.ksppinm) like '%_datafile_write_errors_crash_instance%'
        or  lower(a.ksppinm) like '%_spin_count%'
        or  lower(a.ksppinm) like '%_kks_use_mutex%'
        or  lower(a.ksppinm) like '%_enable_reliable_latch_waits%'
        or  lower(a.ksppinm) like '%_latch_class_%'
        or  lower(a.ksppinm) like '%_enqueue_locks%'
          or  lower(a.ksppinm) like '%_optimizer_autostats_job%'
          -- Numero por default de LRU latches (db_lock_lru_latches 48 por default)
          or  lower(a.ksppinm) like '%_db_block_lru%'
        or  lower(a.ksppinm) like '%_db_block_write_batch%'
        or  lower(a.ksppinm) like '%_db_writer_chunk_writes%'
        or  lower(a.ksppinm) like '%_db_writer_max_writes%'
          or  lower(a.ksppinm) like '%_always_anit_join%'
          or  lower(a.ksppinm) like '%_always_semi_join%'
          or lower(a.ksppinm) like '%_cluster_library%'
          or lower(a.ksppinm) like '%_sqlexec_progression_cost%'
          or lower(a.ksppinm) like '%_small_table_threshold%'
          or lower(a.ksppinm) like '%_very_large_table_threshold%'
          or lower(a.ksppinm) like '%_kcfis_storageidx_disabled%'
          or lower(a.ksppinm) like '%_enable_NUMA_optimization%'
          or lower(a.ksppinm) like '%_bct_public_dba_buffer_size%'
          or lower(a.ksppinm) like '%_serial_direct_read%'    
          or lower(a.ksppinm) like '%_cpu_to_io%'
          or lower(a.ksppinm) like '%_exadata_feature_on%'
          or lower(a.ksppinm) like '%_ash_sample_all%'
          or lower(a.ksppinm) like '%_high_priority_processes%'
          or lower(a.ksppinm) like '%_highest_priority_processes%'
          or lower(a.ksppinm) like '%_use_adaptive_log_file_sync%'
    ))
    )))
;


set markup html off
prompt <h2 id="20190726_500">
set define on
set termout on
prompt * Parametros que han cambiado en el tiempo (dba_hist_parameter) para el periodo de tiempo entre: &fecha_ini_awr y &fecha_fin_awr
set termout off
prompt </h2>
set markup html on
WITH pa as (select /*+ MATERIALIZE */ INST_ID,hash,VALUE,DISPLAY_VALUE from 
gv$PARAMETER)
select sn.begin_interval_time, ph.instance_number,ph.parameter_name, pa.value valor_actual,ph.value valor_anterior  
from dba_hist_parameter ph, dba_hist_snapshot sn, pa
where sn.snap_id  =ph.snap_id AND  sn.dbid=ph.dbid AND   sn.instance_number=ph.instance_number 
and ph.instance_number = pa.inst_id and ph.parameter_hash = pa.hash
and ph.value != pa.value
and (sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
and (sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
order by sn.begin_interval_time, ph.parameter_name, ph.instance_number
;
set define off


set markup html off
prompt <h2 id="20190726_600">
set define on
set termout on
prompt * Parametros configurados solo a nivel de PDBs (sys.pdb_spfile$)
set termout off
prompt </h2>
set markup html on
select * from sys.pdb_spfile$
;
set define off



set markup html off
prompt <h1 id="Performance_shdh673Jhbmpoq1">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Estadisticas extras y datos adicionales
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="Uahsy163hfy47163dgah_Resumen_sesiones">
set termout on
prompt * Resumen de sesiones
set termout off
prompt </h2>
set markup html on
select INST_ID, nvl(username, '[B.G. Process]') username,machine,count(*) total from GV$session
group by inst_id,username,machine
order by 1, 2;

set markup html off
prompt <br>Numero de sesiones por cada instancia:
set markup html on
select inst_id, count(*) total_sesiones from GV$session
group by inst_id
;


set markup html off
prompt <h2 id="jsduhsyqwye16238fmlos0182uensnds">
set termout on
prompt * Sesiones conectadas (GV$session)
set termout off
prompt </h2>
set markup html on
select * from GV$session
;


set markup html off
prompt <h2 id="Objetosinvalidos___Hnchwter18264mshdyBvter5361">
set termout on
prompt * Objetos invalidos (dba_objects)
set termout off
prompt </h2>
set markup html on
select * from dba_objects where status != 'VALID' order by LAST_DDL_TIME;

set markup html off
prompt <h2 id="1udjd7ahHHyagTT__ahsyqTrqfav123Ggasbsdgga12312">
set define on
set termout on
prompt * Objetos modificados desde 1 dia antes de la fecha: &fecha_ini_awr
set termout off
prompt </h2>
set markup html on
select * from dba_objects where LAST_DDL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') -1 
order by LAST_DDL_TIME desc
;
set define off

set markup html off
prompt <h2 id="jashu172hdgaygasdyqgwgdaygsyw">
set termout on
prompt * Objetos con errores procedurales (dba_errors)
set termout off
prompt </h2>
set markup html on
select owner,name,type--,sequence
,line,position,text desc_error
--,attribute,message_number
,(select text from dba_source where err.owner=owner and   err.name=name and err.line=line and err.type = type) codigo_fuente
 from dba_errors err
order by owner,name,line,position;

set markup html off
prompt <h2 id="hahashahsashduh276263476efhdf_1838fnbavachqi">
set termout on
prompt * Triggers especiales poco frecuentes (onlogon, startup, etc) DBA_TRIGGERS
set termout off
prompt </h2>
set markup html on
select * from dba_triggers 
where 
lower(triggering_event) like '%logon%'
or lower(triggering_event) like '%servererror%'
or lower(triggering_event) like '%logoff%'
or lower(triggering_event) like '%startup%'
or lower(triggering_event) like '%shutdown%'
or lower(triggering_event) like '%suspend%'
or lower(triggering_event) like '%db_role_change%'
order by owner,trigger_name
;

set markup html off
set termout off
prompt * A continuacion el codigo fuente de los triggers en caso de que existan:
set termout off
set markup html on
set heading off termout off
set markup html off
set define on
--col script_source format a120
prompt <p style=font-family:courier;color:#3463D0>
prompt <pre>
set feedback off
SET SERVEROUTPUT ON SIZE UNLIMITED
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',false);
execute DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
exec DBMS_METADATA.SET_TRANSFORM_PARAM (DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE',FALSE);
exec DBMS_METADATA.SET_TRANSFORM_PARAM (DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES',TRUE);
set long 2000000 longchunksize 2000000 pagesize 0 linesize 1000 feedback off verify off trimspool on
select 
--replace(replace(DBMS_METADATA.get_ddl('TRIGGER',TRIGGER_NAME,OWNER),' ','&espacio_en_blanco'),chr(10),'</br>')||'</br></br>' script_source 
DBMS_METADATA.get_ddl('TRIGGER',TRIGGER_NAME,OWNER) script_source 
from DBA_TRIGGERS
where 
lower(triggering_event) like '%logon%'
or lower(triggering_event) like '%servererror%'
or lower(triggering_event) like '%logoff%'
or lower(triggering_event) like '%startup%'
or lower(triggering_event) like '%shutdown%'
or lower(triggering_event) like '%suspend%'
or lower(triggering_event) like '%db_role_change%'
order by owner,trigger_name
;
prompt </pre>
prompt </p>


set heading on pages 999
set markup html off
prompt <h2 id="idjayt16dgdghja71ydgTTgdfaqPPiadhahsadhydd1v">
set termout on
prompt * Indices invisibles
set termout off
prompt </h2>
set markup html on
select * from dba_indexes
where visibility != 'VISIBLE'
;

set markup html off
prompt <h2 id="djahUjjhdhYATQGDRQFGDHAuqhdhaytqAFAFFd918283">
set termout on
prompt * Tablas con skip corrupt habilitado
set termout off
prompt </h2>
set markup html on
select * from dba_tables
where skip_corrupt <> 'DISABLED'
;


set markup html off
prompt <h2 id="objectswithnoitdefaultuqyw61yt23twwv86">
set termout on
prompt * Objetos con buffer_pool  habilitado (tablas, indices, particiones)
set termout off
prompt </h2>
set markup html on
-- tabla normal
select owner,table_name,buffer_pool,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.table_name and segment_type='TABLE') MB
from dba_tables t where buffer_pool != 'DEFAULT'
order by 4 desc
;

-- tabla particionada
select table_owner,table_name,partition_name,buffer_pool,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.table_owner and segment_name = t.table_name and t.partition_name = partition_name and segment_type='TABLE PARTITION') MB
from dba_tab_partitions t where buffer_pool != 'DEFAULT'
order by 5 desc
;

-- indice normal
select owner,index_name, table_name,buffer_pool,num_rows,last_analyzed,sample_size
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.index_name and segment_type='INDEX') MB
from dba_indexes t where buffer_pool != 'DEFAULT'
order by 5 desc
;

-- indices particionados
select index_owner,index_name,partition_name,buffer_pool,num_rows,last_analyzed,sample_size
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.index_owner and segment_name = t.index_name and t.partition_name = partition_name and segment_type='INDEX PARTITION') MB
from dba_ind_partitions t where buffer_pool != 'DEFAULT'
order by 5 desc
;

set markup html off
prompt <h2 id="201902191632">
set termout on
prompt * Objetos con read_only habilitado (tablas)
set termout off
prompt </h2>
set markup html on
-- tabla normal
select owner,table_name,read_only,num_rows,last_analyzed,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.table_name and segment_type='TABLE') MB
from dba_tables t where read_only != 'NO'
order by 4 desc
;


set markup html off
prompt <h2 id="201902191643">
set termout on
prompt * Objetos con result_cache habilitado (tablas)
set termout off
prompt </h2>
set markup html on
select owner,table_name,result_cache,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.table_name and segment_type='TABLE') MB
from dba_tables t where result_cache != 'DEFAULT'
order by 4 desc
;


set markup html off
prompt <h2 id="201902191649">
set termout on
prompt * Objetos con compression habilitado (tablas,particiones,indices)
set termout off
prompt </h2>
set markup html on
-- tabla normal
select owner,table_name,compression,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.table_name and segment_type='TABLE') MB
from dba_tables t where compression not in ('DISABLED','NONE') 
order by 4 desc
;
-- tabla particionada
select table_owner,table_name,partition_name,compression,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.table_owner and segment_name = t.table_name and t.partition_name = partition_name and segment_type='TABLE PARTITION') MB
from dba_tab_partitions t where compression not in ('DISABLED','NONE') 
order by 5 desc
;
-- indice normal
select owner,index_name, table_name,compression,num_rows,last_analyzed,sample_size
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.index_name and segment_type='INDEX') MB
from dba_indexes t where compression not in ('DISABLED','NONE') 
order by 5 desc
;
-- indices particionados
select index_owner,index_name,partition_name,compression,num_rows,last_analyzed,sample_size
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.index_owner and segment_name = t.index_name and t.partition_name = partition_name and segment_type='INDEX PARTITION') MB
from dba_ind_partitions t where compression not in ('DISABLED','NONE') 
order by 5 desc
;


set markup html off
prompt <h2 id="201902191652">
set termout on
prompt * Objetos con row_movement habilitado (tablas)
set termout off
prompt </h2>
set markup html on
select owner,table_name,row_movement,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.table_name and segment_type='TABLE') MB
from dba_tables t where row_movement != 'DISABLED' 
order by 4 desc
;



set markup html off
prompt <h2 id="201902191657">
set termout on
prompt * Objetos con cell_flash_cache habilitado (tablas,particiones,indices)
set termout off
prompt </h2>
set markup html on
-- tabla normal
select owner,table_name,cell_flash_cache,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.table_name and segment_type='TABLE') MB
from dba_tables t where cell_flash_cache != 'DEFAULT' 
order by 4 desc
;
-- tabla particionada
select table_owner,table_name,partition_name,cell_flash_cache,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.table_owner and segment_name = t.table_name and t.partition_name = partition_name and segment_type='TABLE PARTITION') MB
from dba_tab_partitions t where cell_flash_cache != 'DEFAULT'  
order by 5 desc
;
-- indice normal
select owner,index_name, table_name,cell_flash_cache,num_rows,last_analyzed,sample_size
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.index_name and segment_type='INDEX') MB
from dba_indexes t where cell_flash_cache != 'DEFAULT'  
order by 5 desc
;
-- indices particionados
select index_owner,index_name,partition_name,cell_flash_cache,num_rows,last_analyzed,sample_size
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.index_owner and segment_name = t.index_name and t.partition_name = partition_name and segment_type='INDEX PARTITION') MB
from dba_ind_partitions t where cell_flash_cache != 'DEFAULT'  
order by 5 desc
;



set markup html off
prompt <h2 id="201902191700">
set termout on
prompt * Objetos con flash_cache habilitado (tablas,particiones,indices)
set termout off
prompt </h2>
set markup html on
-- tabla normal
select owner,table_name,flash_cache,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.table_name and segment_type='TABLE') MB
from dba_tables t where flash_cache != 'DEFAULT' 
order by 4 desc
;
-- tabla particionada
select table_owner,table_name,partition_name,flash_cache,num_rows,last_analyzed,sample_size,
round(avg_row_len * num_rows/1024/1024,2) "MB(from_avg_row_len)"
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.table_owner and segment_name = t.table_name and t.partition_name = partition_name and segment_type='TABLE PARTITION') MB
from dba_tab_partitions t where flash_cache != 'DEFAULT'  
order by 5 desc
;
-- indice normal
select owner,index_name, table_name,flash_cache,num_rows,last_analyzed,sample_size
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.owner and segment_name = t.index_name and segment_type='INDEX') MB
from dba_indexes t where flash_cache != 'DEFAULT'  
order by 5 desc
;
-- indices particionados
select index_owner,index_name,partition_name,flash_cache,num_rows,last_analyzed,sample_size
--(select sum(bytes)/1024/1024 from dba_segments where owner = t.index_owner and segment_name = t.index_name and t.partition_name = partition_name and segment_type='INDEX PARTITION') MB
from dba_ind_partitions t where flash_cache != 'DEFAULT'  
order by 5 desc
;





/*
set markup html off
prompt <h2 id="Objetosconmayoroverhead_Hvn37501MDrqwyT">
set termout on
prompt * Top Object overhead (tops)
set termout off
prompt </h2>

set markup html on
select * from (
select owner,table_name, '-' partition_name,
       to_char(last_analyzed,'dd/mm/yy') last_analyzed,
       num_rows,
       avg_row_len Avg_row_len,
       avg_space   Avg_space,
--       empty_blocks Empty,
       round((empty_blocks * (select value from v$parameter where name = 'db_block_size'))/1048576,1) Empty_bm,
--       blocks,
       round((blocks * (select value from v$parameter where name = 'db_block_size'))/1048576,1) Used_space_blocks_mb,
--       round( ((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0) Blk_Reales ,
       round((round( ((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0)* (select value from v$parameter where name = 'db_block_size')/1048576),1) MB_Reales,
--       blocks - round(((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0) Overhead,
       round((blocks - round(((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0))* (select value from v$parameter where name = 'db_block_size')/1048576,1) Overhead_mb,
       round((blocks-(ROUND(((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0)))*100/blocks,2) "Overhead_%"
FROM dba_tables t
WHERE (
    (blocks> ROUND( ((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0) +1000)
       OR
    (avg_space > (select value from v$parameter where name = 'db_block_size')-((select value from v$parameter where name = 'db_block_size')*.3) )
      )
AND ROUND( ((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0) !=0
and blocks > 150
--and owner not in ('SYS','SYSTEM','MDSYS','ORDSYS','CTXSYS','PERFSTAT','AURORA$JIS$UTILITY$','OUTLN')
--and owner not like ('PORTAL%')
--and owner not like ('EUL%')
and partitioned='NO'
--and    table_name = 'EDIDS'
and temporary='N'
--and not exists (select 1 from dba_tab_columns c
--                where c.owner = t.owner
--                and c.table_name = t.table_name
--                and c.data_type in ('LONG','BLOB','CLOB','NCLOB'))
union all
select table_owner owner,table_name, partition_name,
       to_char(last_analyzed,'dd/mm/yy') last_analyzed,
       num_rows,
       avg_row_len arl,
       avg_space   avsp,
--       empty_blocks Empty,
       round((empty_blocks * (select value from v$parameter where name = 'db_block_size'))/1048576,1) Empty,
--       blocks,<
       round((blocks * (select value from v$parameter where name = 'db_block_size'))/1048576,1) blocks_mb,
--       round( ((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0) Blk_Reales ,
       round((round( ((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0)* (select value from v$parameter where name = 'db_block_size')/1048576),1) MB_Reales ,
--       blocks - round(((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0) Overhead,
       round((blocks - round(((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0))* (select value from v$parameter where name = 'db_block_size')/1048576,1) Overhead_mb,
       round((blocks-(ROUND(((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0)))*100/blocks,2) "Overhead_%"
--       (1- ((round(((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0))/blocks))*100 OHPct
from dba_tab_partitions t
where (
    (blocks> round( ((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0) +1000)
       OR
    (avg_space > (select value from v$parameter where name = 'db_block_size')-((select value from v$parameter where name = 'db_block_size')*.3) )
      )
AND ROUND( ((num_rows*avg_row_len) + (2*num_rows))/(((select value from v$parameter where name = 'db_block_size') -(ini_trans*24)-57-4)* (1-(pct_free/100))),0) !=0
--and table_owner not in ('SYS','SYSTEM','MDSYS','ORDSYS','CTXSYS','PERFSTAT','AURORA$JIS$UTILITY$','OUTLN')
--and table_owner not like ('PORTAL%')
--and table_owner not like ('EUL%')
--and not exists (select 1 from dba_tab_columns c
--                where c.owner = t.table_owner
--                and c.table_name = t.table_name
--                and c.data_type in ('LONG','BLOB','CLOB','NCLOB'))
union all
select  dl.owner,
        dl.segment_name || '(T:' || dl.table_name || ')',
        '-' partition_name,
        to_char(dt.last_analyzed,'dd/mm/yy') last_analyzed,
        dt.num_rows,
        null avg_row_len,
        null avg_space,
        null empty_bm,
        round(ds.bytes/1024/1024,2) "used_space_blocks_mb",
        null mb_reales,
        null overhead_mb,
        null "Overhead_%"
from    dba_segments    ds,
        dba_lobs        dl,
        dba_tables      dt
where
ds.segment_type = 'LOBSEGMENT'
and     dl.segment_name = ds.segment_name
and     dl.owner = ds.owner
and     dl.table_name = dt.table_name
and     dl.owner = dt.owner
and     dl.owner = ds.owner
--and ds.bytes/1024/1024 > 2
--order by 9 desc, 11 desc
order by 11 desc  NULLS LAST
)
where used_space_blocks_mb > 500 and rownum <= 20;
*/


set markup html off
prompt <h2 id="TablespacesEspacioutilizado_hshduJu1639857tgd">
set termout on
prompt * Espacio en tablespaces
set termout off
prompt </h2>



set FEEDBACK ON
SET PAGESIZE 20
SET HEADING ON
SET DEFINE  ON
set markup html on
SELECT   tm.tbs Tablespace,
           to_char((tm.mb - free.mb),'99999999999990D00') UsadoMB,
         to_char(free.mb,'99999999999990D00') LibreMB,
           to_char(tm.mb,'99999999999990D00') TotalMB,
         to_char(((tm.mb - free.mb) / tm.mb) * 100,'990D00') pct
    FROM (SELECT   tablespace_name tbs, SUM (BYTES) / 1024 / 1024 mb
              FROM dba_data_files GROUP BY tablespace_name) tm,
         (SELECT   tablespace_name tbs, SUM (BYTES) / 1024 / 1024 mb
              FROM dba_free_space GROUP BY tablespace_name  ) free
   WHERE tm.tbs = free.tbs(+)
--and (upper(tm.tbs) like '%TTL_LA_SCL001%' or upper(tm.tbs) like '%TBL_CLL_CONSUMOS_20_201501%')
 --and ((tm.mb - free.mb) / tm.mb)*100 > 85
ORDER BY 5 DESC;
set markup html off


set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
set define off


prompt <table  autosize="1" width="5%" border="0" cellspacing="0" cellpadding="0" alignt="left"><tr><td width="2%">
--prompt <div style = "transform: scale(1.4);margin-left: 260px;margin-top: 65px;" >
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      ('SELECT DTFL.TABLESPACE_NAME
       ,      (SELECT MAX(LENGTH(TABLESPACE_NAME)) FROM DBA_DATA_FILES) LEN_TABLESPACE_NAME
       ,      DTFL.TOTAL_SIZE/1024/1024 TOTAL_SPACE_MO
       ,      FRSP.TOTAL_SIZE/1024/1024 FREE_SPACE_MO
       ,      (DTFL.TOTAL_SIZE-FRSP.TOTAL_SIZE)/1024/1024 USED_SPACE_MO
       ,      TRUNC((DTFL.TOTAL_SIZE-FRSP.TOTAL_SIZE)/DTFL.TOTAL_SIZE*100,2) USED_PERCENT
       FROM (
          SELECT TABLESPACE_NAME
          ,      SUM(BYTES) total_size
          FROM DBA_DATA_FILES
          GROUP BY TABLESPACE_NAME) DTFL
       LEFT OUTER JOIN (
          SELECT TABLESPACE_NAME
          ,      SUM(BYTES) total_size
          FROM DBA_FREE_SPACE
          GROUP BY TABLESPACE_NAME) FRSP
       ON FRSP.TABLESPACE_NAME=DTFL.TABLESPACE_NAME
       ORDER BY 6 desc')
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="bar_length">300</xsl:variable>
     <xsl:variable name="tablespace_nb"><xsl:value-of select="count(/descendant::TABLESPACE_NAME)"/></xsl:variable>
     <xsl:variable name="len_tblsp_name"><xsl:value-of select="/descendant::LEN_TABLESPACE_NAME[position()=1]"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="{($margin_left)+5}" y="{($margin_top)-5}" style="fill:#000000; stroke: none;font-size:12px;text-anchor=start">Lista de tablespace</text>
           <xsl:for-each select="ROWSET/ROW">
             <xsl:variable name="color_bar">
               <xsl:choose>
                 <xsl:when test="(descendant::USED_PERCENT)&gt;= 97">
                   <xsl:text>red</xsl:text>
                 </xsl:when>
                 <xsl:when test="(descendant::USED_PERCENT)&gt;= 85">
                   <xsl:text>orange</xsl:text>
                 </xsl:when>
                 <xsl:otherwise>
                   <xsl:text>lightgreen</xsl:text>
                 </xsl:otherwise>
               </xsl:choose>
             </xsl:variable>
             <text x="{($margin_left)+5}" y="{($margin_top)+(12*(position()))}" style="fill:#000000; stroke: none;font-size:10px;text-anchor=start"><xsl:value-of select="(descendant::TABLESPACE_NAME)"/></text>
             <rect x="{($margin_left)+($len_tblsp_name)*7}" y="{($margin_top)+(12*(position()-1))+3}" width="{(descendant::USED_PERCENT) * (($bar_length) div 100)}" height="9" fill="{$color_bar}" stroke="black"/>
             <rect x="{($margin_left)+($len_tblsp_name)*7}" y="{($margin_top)+(12*(position()-1))+3}" width="{($bar_length)}" height="9" fill="none" stroke="black"/>
             <text x="{($margin_left)+(($len_tblsp_name)*7)+($bar_length)+4}" y="{($margin_top)+(12*(position()))}" style="fill: #000000; stroke: none;font-size:10px;text-anchor=end"><xsl:value-of select="format-number((descendant::USED_PERCENT),''00.00'')"/>%</text>
           </xsl:for-each>
           <rect x="{($margin_left)+3}" y="{($margin_top)}" width="{($margin_left)+(($len_tblsp_name)*7)+($bar_length)+25}" height="{5+(($tablespace_nb)*12)}" fill="none" stroke="blue"/>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;
--prompt </div>
prompt </td></tr></table>
set heading on
set pagesize 20
set feedback on


set markup html off
prompt <h2 id="Tablespacestemporal_57YhbnEqpMnu">
set termout on
prompt * Espacio en tablespace temporal
set termout off
prompt </h2>
set markup html on
select TABLESPACE_NAME "TABLESPACE_TEMPORAL",
 to_char(sum(BYTES_USED)/1024/1024,'99999990D00') "USADO_MB",
 to_char(sum(BYTES_FREE)/1024/1024,'99999990D00') "LIBRE_MB",
 to_char(sum(BYTES_USED+BYTES_FREE)/1024/1024,'99999990D00') "TOTAL_MB",
 to_char(sum(bytes_used)*100/(sum(BYTES_FREE)+sum(BYTES_USED)),'990D00') "PCT_USADO"
from V$TEMP_SPACE_HEADER
group by tablespace_name
;


set markup html off
prompt <h2 id="Tablespacesundo_Hvbt465qPmncfT">
set termout on
prompt * Espacio en tablespace undo (exp-unexpired)
set termout off
prompt </h2>
set markup html on
select TABLESPACE_NAME,status,
  round(sum_bytes / (1024*1024), 0) as MB,
  round((sum_bytes / undo_size) * 100, 0) as PERC
from
(select TABLESPACE_NAME,status, sum(bytes) sum_bytes
  from dba_undo_extents
  group by TABLESPACE_NAME,status)
,(select sum(a.bytes) undo_size
  from dba_tablespaces c
    join v$tablespace b on b.name = c.tablespace_name
    join v$datafile a on a.ts# = b.ts#
  where c.contents = 'UNDO'
    and c.status = 'ONLINE'
);


set markup html off
prompt <h2 id="hashasy187dHyahshdy1gdhaPidja8">
set termout on
prompt * Tamano de BD y por esquemas
set termout off
prompt </h2>
set markup html on
select owner,round(sum(bytes)/1024/1024,2) MB_ocupado from dba_segments
group by owner
order by 2 desc
;

set markup html off
prompt <h2 id="20190826_1038">
set termout on
prompt * Quotas de espacio por usuario (DBA_TS_QUOTAS)
set termout off
prompt </h2>
set markup html on
select * from DBA_TS_QUOTAS
;

select round(sum(bytes)/1024/1024,2) MB_segmentos from dba_segments
;
select round(sum(bytes)/1024/1024,2) MB_datafile from V$datafile
;


set markup html off
prompt <h2 id="20190304_1537">
set termout on
prompt * Espacio ocupado en tablespace V$SYSAUX_OCCUPANTS
set termout off
prompt </h2>
set markup html on
select * from V$SYSAUX_OCCUPANTS
order by SPACE_USAGE_KBYTES desc
;


set markup html off
prompt <h2 id="flash_djsndhNshyue71634Tdget1lmBfsv">
set termout on
prompt * Flash recovery area (V$RECOVERY_FILE_DEST V$FLASH_RECOVERY_AREA_USAGE)
set termout off
prompt </h2>
set markup html on
/*
SELECT
NAME flash_recovery_area_usage,
SPACE_LIMIT/1024/1024/1024 AS SPACE_LIMIT_GB ,
(SPACE_LIMIT - SPACE_USED + SPACE_RECLAIMABLE)/1024/1024/1024 AS SPACE_AVAILABLE_GB,
ROUND((SPACE_USED - SPACE_RECLAIMABLE)/greatest(SPACE_LIMIT,1) * 100, 1) AS PERCENT_FULL
, number_of_files
FROM V$RECOVERY_FILE_DEST;
*/
select * from V$FLASH_RECOVERY_AREA_USAGE;



set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
set define off


prompt <table  autosize="1" width="5%" border="0" cellspacing="0" cellpadding="0" alignt="left"><tr><td width="2%">
--prompt <div style = "transform: scale(1.4);margin-left: 260px;margin-top: 65px;" >
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      ('SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(stat_name,''FREE SPACE'',''lightgreen'',''CONTROL FILE'',''lightblue'',
                                ''REDO LOG'',''red'',''ARCHIVED LOG'',''orange'',
                                ''BACKUP PIECE'',''blue'',''IMAGE COPY'',''yellow'',
                                ''FLASHBACK LOG'',''grey'',''FOREIGN ARCHIVED LOG'',''lightgrey'',''black'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY percent_space_used DESC, stat_name) AS cumulative_percent_prev
          ,      percent_space_used percent_value
          FROM (
             SELECT SUM(percent_space_used) OVER ( ORDER BY percent_space_used DESC, file_type) cumulative_percent
             ,   file_type stat_name
             ,   percent_space_used
             FROM (
                SELECT file_type
                ,      percent_space_used
                FROM v$flash_recovery_area_usage
               UNION ALL
                SELECT ''FREE SPACE''
                ,      100-SUM(percent_space_used) percent_space_used
                FROM v$flash_recovery_area_usage
                  )
             ORDER BY percent_space_used DESC
               )
      )')
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:10px;text-anchor=start">Recovery areas usage</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/>%</text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;
--prompt </div>
prompt </td></tr></table>
set heading on
set pagesize 20
set feedback on






set markup html off
prompt <h2 id="Opcionesglobalesparaestadisticasdetablas__djN527O061">
set termout on
prompt * Opciones de gather stats (DBMS_STATS.GET_PREFS)
set termout off
prompt </h2>
prompt <p>consultar SELECT extension_name, extension FROM   dba_stat_extensions WHERE  table_name = 'X'</p>
prompt <p>Para ver si la tabla en cuestion esta trabajando con AUTO_STAT_EXTENSIONS</p>

set markup html on
select   dbms_stats.get_prefs('AUTOSTATS_TARGET') AUTOSTATS_TARGET 
         ,dbms_stats.get_prefs('CASCADE') CASCADE 
         ,dbms_stats.get_prefs('CONCURRENT') CONCURRENT 
         ,dbms_stats.get_prefs('DEGREE') DEGREE
         ,dbms_stats.get_prefs('ESTIMATE_PERCENT') ESTIMATE_PERCENT
         ,dbms_stats.get_prefs('METHOD_OPT') METHOD_OPT 
         ,dbms_stats.get_prefs('NO_INVALIDATE') NO_INVALIDATE 
         ,dbms_stats.get_prefs('GRANULARITY') GRANULARITY
         ,dbms_stats.get_prefs('PUBLISH') PUBLISH 
         ,dbms_stats.get_prefs('INCREMENTAL') INCREMENTAL 
         ,dbms_stats.get_prefs('STALE_PERCENT') STALE_PERCENT
         ,dbms_stats.get_prefs('TABLE_CACHED_BLOCKS') TABLE_CACHED_BLOCKS
         -- Estas variables son para 12c
         --,dbms_stats.get_prefs('INCREMENTAL_STALENESS') INCREMENTAL_STALENESS
         --,dbms_stats.get_prefs('INCREMENTAL_LEVEL') INCREMENTAL_LEVEL
         --,dbms_stats.get_prefs('GLOBAL_TEMP_TABLE_STATS') GLOBAL_TEMP_TABLE_STATS
         --,dbms_stats.get_prefs('OPTIONS') OPTIONS 
from dual;






set markup html off
prompt <h2 id="Tablascandidatasaactualizaciondeestadisticas_fj127gr">
set termout on
prompt * Tablas candidatas a ser tomadas por el actualizador de estadisticas, DBA_TAB_MODIFICATIONS (revisar dbms_stats.get_prefs('STALE_PERCENT') )
set termout off
prompt </h2>
set markup html on


SELECT t.owner,t.table_name, t.monitoring,m.timestamp, m.inserts, m.updates, m.deletes,(m.inserts + m.updates + m.deletes) nb_modif, t.num_rows,
round(((m.inserts + m.updates + m.deletes)*100)/greatest(t.num_rows,1),2) percent_modif, t.last_analyzed
FROM dba_tab_modifications m, dba_tables t
WHERE t.table_name=m.table_name (+)
and owner not in
(
 'APEX_PUBLIC_USER'
,'C##DBAAS_BACKUP'
,'CTXSYS'
,'DBSNMP'
,'DIP'
,'EXFSYS'
,'MDDATA'
,'LDAPUSER'
,'MDSYS'
,'MGMT_VIEW'
,'ORACLE_OCM'
,'OLAPSYS'
,'SCOTT'
,'SYS'
,'SYSMAN'
,'SYSTEM'
,'WMSYS'
,'XDB'
,'XS$NULL'
,'APPQOSSYS'
,'OUTLN'
,'ORDDATA'
,'ORDSYS'
)
;



/*
set markup html off
prompt <h2 id="DBA_TAB_MODIFICATIONS_vn12trt8936ry663">
set termout on
prompt * DBA_TAB_MODIFICATIONS (TABLE_OWNER NOT IN ('SYS','SYSTEM'))
set termout off
prompt </h2>
set markup html on
/*
select * from dba_tab_modifications where TABLE_OWNER NOT IN ('SYS','SYSTEM');
*/




set markup html off
set define on
prompt <h2 id="djancj_19fjhhy172_sofmbnbyt_auqeufh13fr4">
set termout on
prompt * Rutas de archivos de diagnostico (gv$diag_info)
set termout off
prompt </h2>
--set termout on
--prompt lower('&leer_alert_log') = 's'
--set termout off
set markup html on
select * from gv$diag_info
order by 2, 1
;


set markup html off
set define on
prompt <h2 id="Alertloglistener_jashNsh127Hdnssa12Lijsj">
set termout on
prompt * Errores en archivo de alerta (v$diag_alert_ext)
set termout off
prompt </h2>
--set termout on
--prompt lower('&leer_alert_log') = 's'
--set termout off
set markup html on
select * from TABLE(GV$(CURSOR(
select *
from v$diag_alert_ext
where
-- esto es para sabe si el archivo de alerta debe leerse o no
lower('&leer_alert_log') = 's'
--(lower(message_text) like '%ora-%' or lower(message_text) like '%tns-%' )
and (MESSAGE_TYPE in (2,3) OR MESSAGE_LEVEL in (1,2) OR PROBLEM_KEY like 'ORA-%')
--(lower(message_text) like '%ora-%' or lower(message_text) like '%tns-%' or lower(message_text) like '%timed%')
--(message_text like '%ORA-%' )
and originating_timestamp > sysdate -1
order by originating_timestamp
)));
--set define off






set markup html off
set heading on feedback on pagesize 20
prompt <h1 id="hasduqywehdaysdhyqwhd1720gmbncgagscuerow08431">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Jobs y scheduler
set termout off
prompt </h1>
set markup html on




set markup html off
prompt <h2 id="uywe7038465346792mvnvgay7rijfhfy7272zbsgwaq018mvn7">
set termout on
prompt * Mantencion de bd (dba_autotask_client)
set termout off
prompt </h2>
set markup html on
select * from dba_autotask_client ;


set markup html off
prompt <h2 id="20190708_1220">
set termout on
prompt * Mantencion de bd (DBA_ADVISOR_TASKS)
set termout off
prompt </h2>
set markup html on
select * from DBA_ADVISOR_TASKS ;

set markup html off
prompt <h2 id="y1723yqyweywdfno19238hhdnauwhwujsdjahsh">
set termout on
prompt * Mantencion de bd (dba_autotask_operation)
set termout off
prompt </h2>
set markup html on
SELECT * FROM dba_autotask_operation;


set markup html off
prompt <h2 id="8dj81jwdhKjhasjh71hdhYYhasyhCCzfarsTgfa">
set termout on
prompt * Schedulers de base de datos (DBA_SCHEDULER_JOBS)
set termout off
prompt </h2>
set markup html on
select * from DBA_SCHEDULER_JOBS
;

set markup html off
prompt <h2 id="182ueh1hhdhYYghsgCCqeQQazxasqe91olmcbco">
set termout on
prompt * Jobs de base de datos (DBA_JOBS)
set termout off
prompt </h2>
set markup html on
select * from DBA_JOBS
;




set markup html off
set heading on feedback on pagesize 20
prompt <h1 id="1ddjdjsdhajs__jahch19djNhahsdgagqidoajsdjsj">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Informacion de ASM
set termout off
prompt </h1>
set markup html on




set markup html off
prompt <h2 id="asm_dhNv1uf63yfGbcpyiushNB1wkG1">
set termout on
prompt * Espacio en discos ASM (V$ASM_DISKGROUP)
set termout off
prompt </h2>
set markup html on
SELECT
    name                                     group_name
  , allocation_unit_size                     allocation_unit_size
  , type                                     type
  , total_mb/1024                                 total_gb
  , (total_mb - free_mb)/1024                     used_gb
  , ROUND((1- (free_mb / greatest(total_mb,1)))*100, 2)  pct_used
FROM    v$asm_diskgroup
ORDER BY    6 desc
;

select * from V$ASM_DISKGROUP
;


set markup html off
prompt <h2 id="18dhHHaushh183d918dj_kajdhahahd">
set termout on
prompt * Atributos de disco ASM (V$ASM_ATTRIBUTE)
set termout off
prompt </h2>
prompt <p>
prompt Recordar que el atributo: cell.smart_scan_capable tiene que estar seteado en TRUE para que Smart Scan funcione
prompt </p>
set markup html on
select aa.group_number,ad.name diskgroup_name,aa.name attribute_name,aa.value attribute_value 
,ad.state, ad.compatibility, ad.database_compatibility, ad.voting_files
from V$ASM_ATTRIBUTE aa
, V$asm_diskgroup ad
where aa.group_number = ad.group_number
;


set markup html off
prompt <h2 id="asm_UnB16fPskj6fyhb726RfgstfCdx1">
set termout on
prompt * Discos y devices de ASM (V$ASM_DISK)
set termout off
prompt </h2>
set markup html on
SELECT
    NVL(a.name, '[CANDIDATE]')                       disk_group_name
  , b.path                                           disk_file_path
  , b.name                                           disk_file_name
  , b.failgroup                                      disk_file_fail_group
  , b.total_mb/1024                                       total_gb
  ,(b.total_mb - b.free_mb)/1024                         used_gb
  ,decode(b.total_mb,0,0 ,ROUND((1- (b.free_mb / greatest(b.total_mb,1)))*100, 2)  )    pct_used
  ,b.redundancy                                      disk_redundancy
FROM v$asm_diskgroup a RIGHT OUTER JOIN v$asm_disk b USING (group_number)
ORDER BY a.name
;


set markup html off
prompt <h2 id="uashdyahsh_jahs6182uydjasgdbg__k">
set termout on
prompt * V$ASM_CLIENT
set termout off
prompt </h2>
set markup html on
SELECT * FROM GV$ASM_CLIENT
;


set markup html off
prompt <h2 id="jdjahHHgabQQwaxzsWsaoqjspkn81231">
set termout on
prompt * V$ASM_USER
set termout off
prompt </h2>
set markup html on
select * from V$ASM_USER
;


set markup html off
prompt <h2 id="81jdhhHHgarqexcadrePPisudhnabsbg">
set termout on
prompt * V$ASM_USERGROUP
set termout off
prompt </h2>
set markup html on
SELECT * FROM V$ASM_USERGROUP
;


set markup html off
prompt <h2 id="kajcnbcgwWasqeFfgarG616235152308">
set termout on
prompt * V$ASM_USERGROUP_MEMBER
set termout off
prompt </h2>
set markup html on
SELECT * FROM V$ASM_USERGROUP_MEMBER
;


set markup html off
prompt <h2 id="TraeqdErtqysoOusuydhagGfafsafdf1">
set termout on
prompt * V$ASM_TEMPLATE
set termout off
prompt </h2>
set markup html on
SELECT * FROM V$ASM_TEMPLATE
;


set markup html off
prompt <h2 id="jHhsgdgabcg1716gdbaGyaytsduyhasg">
set termout on
prompt * V$ASM_VOLUME
set termout off
prompt </h2>
set markup html on
SELECT * FROM V$ASM_VOLUME
;


set markup html off
prompt <h2 id="hYtqtsrFfags1670KmnbvXzxasvnuhsa">
set termout on
prompt * V$ASM_VOLUME_STAT
set termout off
prompt </h2>
set markup html on
SELECT * FROM V$ASM_VOLUME_STAT
;

set markup html off
prompt <h2 id="20190730_1410">
set termout on
prompt * V$ASM_ACFSVOLUMES
set termout off
prompt </h2>
set markup html on
SELECT * FROM V$ASM_ACFSVOLUMES
;

set markup html off
prompt <h2 id="hag16235gTfafsdff162LLLjajdhNNNh">
set termout on
prompt * V$ASM_OPERATION
set termout off
prompt </h2>
set markup html on
SELECT * FROM GV$ASM_OPERATION
;


set markup html off
prompt <h2 id="hayshHgagsg1728dpLkajsdnHGGffads">
set termout on
prompt * V$ASM_DISKGROUP_STAT
set termout off
prompt </h2>
set markup html on
SELECT * FROM V$ASM_DISKGROUP_STAT
;


set markup html off
prompt <h2 id="haggsrRfarsfrqOidjm76142392746d6">
set termout on
prompt * V$ASM_DISK_STAT
set termout off
prompt </h2>
set markup html on
select * from V$ASM_DISK_STAT
;



set markup html off
prompt <h2 id="UtqrEoaplhFbcmakfhtqt12735481902">
set termout on
prompt * V$ASM_FILESYSTEM
set termout off
prompt </h2>
set markup html on
select * from V$ASM_FILESYSTEM
;


set markup html off
prompt <h2 id="1uduahhgatTyaioPPPPkajsjdNNNN123">
set termout on
prompt * V$ASM_DISK_IOSTAT
set termout off
prompt </h2>
set markup html on
SELECT * FROM V$ASM_DISK_IOSTAT
;



set markup html off
set heading on feedback on pagesize 20
prompt <h1 id="28djHJhaydgagsydbgqydgaydbsgdbay172__ajah">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Informacion de configuracion de Exadata
set termout off
prompt </h1>
set markup html on




set markup html off
prompt <h2 id="817d7hdbhn__djadjay17dhBhasdhady1gddda">
set termout on
prompt * Informacion de V$CELL
set termout off
prompt </h2>
set markup html on
select * from V$CELL ;


set markup html off
prompt <h2 id="8djfhahdyGgdtag610dBvczxXXXXdfgadgaydd">
set termout on
prompt * Informacion de V$CELL_CONFIG
set termout off
prompt </h2>
set markup html on
select * from V$CELL_CONFIG
order by 1,2
;


set markup html off
prompt <h2 id="yyyTTrqersfGUIsopMnjdhha__dhadg16321Hd">
set termout on
prompt * Informacion de V$CELL_OPEN_ALERTS
set termout off
prompt </h2>
set markup html on
select * from V$CELL_OPEN_ALERTS
;


set markup html off
prompt <h2 id="19283udjajdn_kadjdhaau1827dahdhahhsdhh">
set termout on
prompt * Storage Index y Smart scanning ocupados por la actual sesion (v$mystat y v$statname)
set termout off
prompt </h2>
prompt SI Savings (cell physical IO bytes saved by storage index)
prompt Smart scans(cell physical IO interconnect bytes returned by smart scan)
set markup html on
select
    decode(name,
    'cell physical IO bytes saved by storage index',
    'SI Savings',
    'cell physical IO interconnect bytes returned by smart scan',
    'Smart Scan'
    ) as stat_name,
    value/1024/1024 as stat_value
from v$mystat s, v$statname n
where
    s.statistic# = n.statistic#
and
    n.name in (
    'cell physical IO bytes saved by storage index',
    'cell physical IO interconnect bytes returned by smart scan'
    )
;



set markup html off
prompt <h1>
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt NETWORK
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="201909121200">
set termout on
prompt *  DBA_NETWORK_ACLS
set termout off
prompt </h2>
prompt <p>
prompt Recordar que esta vista quedó obsoleta en 12.1
prompt </p>
set markup html on
select * from DBA_NETWORK_ACLS
;

set markup html off
prompt <h2 id="201909121202">
set termout on
prompt *  DBA_HOST_ACLS
set termout off
prompt </h2>
prompt <p>
prompt Recordar que esta vista quedó obsoleta en 12.1
prompt </p>
set markup html on
select * from DBA_HOST_ACLS
;


set markup html off
prompt <hr>
set markup html on




set markup html off
prompt <h1 id="Latchau2y236et15Gdytqr312">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Latch Information
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="spincountashdyt18450gkjsgft361t">
set termout on
prompt *  spin_count (x$ksllclass)
set termout off
prompt </h2>
prompt <p>
prompt Mutexes. Abreviación de mutual exclusión. Son más eficientes que los Latch (un latch ocupa en promedio 112 bytes mientras que un mutex ocupa 16 bytes). Oracle a nivel de kernel desde 10g ha grabado en el codigo fuente un máximo de 255 spin para mutex (junto con sleeps), versus lo que tenia el latch en 9i que podia hacer hasta 2000 spins entre cada “backoff” o descanso. Por eso ocupa más cpu un latch que un mutex. El Mutex puede esperar un máximo de 255 veces iterando entre  con los sleeps, evitando así los intentos reiterados que poseia un latch (max 2000 spins entre cada intento o “backoff”). El backoff es el descanso que tiene el latch entre cada 2000 intentos.
prompt </p>
prompt <p>
prompt     Atencion con los eventos de espera:
prompt <br>cursor: pin s wait on x hay un bug que afecta desde 10.2.0.3, support: 401435.1 , 5907779.8 , bug: 5907779
prompt </p>
prompt <p>
prompt	Revisar el valor del parametro oculto: _kks_use_mutex Por default esta en true, si esta en false los pin trabajan en modo no mutex (latch antiguo)
prompt </p>
set markup html on


select * from TABLE(GV$(CURSOR(select * from
 (
	select * from x$ksllclass
)
    )))
order by inst_id,indx
;

set markup html off
prompt <hr>
set markup html on








set markup html off
prompt <h1 id="PerformanceActual_ajfds71ydhGq">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Performance General
set termout off
prompt </h1>
set markup html on



set markup html off
prompt <h2 id="SesionesactivasordenadasporLAST_CALL_ET__Jdh13mndsewq8">
set termout on
prompt * Sesiones activas ordenadas por LAST_CALL_ET (10g o superior)
set termout off
prompt </h2>
set markup html on
select /*+rule */ * from (
select  s.sid,s.serial# serial,s.inst_id ins, p.pid, p.spid spid, s.module
, s.machine, s.osuser,s.username
--, s.action
, s.program, s.status,  s.seq#, s.event, to_char(s.logon_time,'dd/mm hh24:mi') logon, s.last_call_et
,sysdate -  (s.last_call_et / (24 * 60 * 60)) last_call_et_date
  ,s.p1,s.p1text,s.p2,s.p2text,s.p3,s.p3text
  ,s.ROW_WAIT_BLOCK#,s.ROW_WAIT_FILE#,s.ROW_WAIT_OBJ#,s.ROW_WAIT_ROW#
--, s.resource_consumer_group
--,(select round(sstat.value/100,3) from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'CPU used by this session') cpu_total_usada_SEC
--,(select round(sstat.value/100,3) from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'CPU used when call started') cpu_usada_call_start_SEC
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'consistent gets') consistent_gets
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'physical reads') physical_reads
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'physical writes') physical_writes
,s.sql_id,(select SUBSTR(sql_text,0,65) from Gv$sql where sql_id = s.sql_id and child_number = 0 and rownum=1) sql_text
from  gv$session s, gv$process p where   s.paddr = p.addr
and   s.inst_id = p.inst_id
and   s.status='ACTIVE'
--and (select sql_text from v$sql where sql_id = s.sql_id and child_number = 0)
)
--where
--UPPER(sql_text) like '%ALTER%'
--where lower(module) like '%excel%'
order by last_call_et asc,spid
;

/*

set markup html off
prompt <h2 id="SesionesactivasordenadasporLAST_CALL_ET_Jshdy264hfLo93">
set termout on
prompt * Sesiones activas ordenadas por LAST_CALL_ET (solo 9i)
set termout off
prompt </h2>
set markup html on
select  * from (
select  s.sid,s.serial# serial,s.inst_id ins, p.pid, p.spid spid, s.module
, s.machine, s.osuser,s.username
--, s.actio
, s.program, s.status
, to_char(s.logon_time,'dd/mm hh24:mi') logon, s.last_call_et
,sysdate -  (s.last_call_et / (24 * 60 * 60)) last_call_et_date
  ,s.ROW_WAIT_BLOCK#,s.ROW_WAIT_FILE#,s.ROW_WAIT_OBJ#,s.ROW_WAIT_ROW#
--, s.resource_consumer_group
--,(select round(sstat.value/100,3) from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'CPU used by this session') cpu_total_usada_SEC
--,(select round(sstat.value/100,3) from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'CPU used when call started') cpu_usada_call_start_SEC
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'consistent gets') consistent_gets
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'physical reads') physical_reads
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'physical writes') physical_writes
,sa.hash_value,SUBSTR(sa.sql_text, 1, 65)  sql_text
from    gv$session s, gv$process p, gv$sqlarea sa
where   s.paddr = p.addr
  AND s.sql_address    =  sa.address(+)
  AND s.sql_hash_value =  sa.hash_value(+)
  AND s.sql_hash_value =  sa.hash_value(+)
and     s.inst_id = p.inst_id
and    s.status = 'ACTIVE'
--and (select sql_text from v$sql where sql_id = s.sql_id and child_number = 0)
)
--where
--UPPER(sql_text) like '%ALTER%'
--where lower(module) like '%sql%' or  lower(program) like '%sql%'
--order by last_call_et desc
order by last_call_et asc,SPID
;
*/


/*
set markup html off
prompt <h2 id="Sesionesenenqueue__Jdfhd7346fhshd">
set termout on
prompt * Sesiones en enqueue (encolamiento)
set termout off
prompt </h2>
set markup html on
SELECT
--    i.instance_name                 instance_name
   s.sid                            sid
  ,s.serial#                        serial
  ,s.inst_id                        ins
  ,p.PID                            pid
  ,p.spid                           spid
  ,s.username                       username
  ,s.module                         module
  ,s.program                        program
  ,to_char(s.logon_time,'dd/mm hh24:mi')  logon
  ,s.machine                        machine
  ,s.osuser                         osuser
  ,sw.state                         state
  ,sw.event                         event
  ,sw.seconds_in_wait               wait_time_sec
  ,sysdate -  (sw.seconds_in_wait / (24 * 60 * 60)) wait_time_sec_date
  ,sw.p1,sw.p1text,sw.p2,sw.p2text,sw.p3,sw.p3text
  ,s.ROW_WAIT_BLOCK#,s.ROW_WAIT_FILE#,s.ROW_WAIT_OBJ#,s.ROW_WAIT_ROW#
  --,s.last_call_et
  --,sysdate -  (s.last_call_et / (24 * 60 * 60)) last_call_et_date
  --,(select round(sstat.value/100,3) from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'CPU used by this session') cpu_total_usada_SEC
  --,(select round(sstat.value/100,3) from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'CPU used when call started') cpu_usada_call_start_SEC
  --,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'consistent gets') consistent_gets
  --,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'physical reads') physical_reads
  --,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'physical writes') physical_writes
  --,sa.sql_id
  ,sa.hash_value
  ,sa.sql_text                      last_sql
FROM gv$session_wait sw
      INNER JOIN gv$session s   ON  ( sw.inst_id = s.inst_id AND sw.sid     = s.sid)
      INNER JOIN gv$sqlarea sa  ON  ( s.inst_id     = sa.inst_id  AND s.sql_address = sa.address  AND s.sql_hash_value =  sa.hash_value )
      INNER JOIN gv$instance i  ON  ( s.inst_id = i.inst_id)
      INNER JOIN GV$PROCESS p   ON  (s.paddr = p.addr and   s.inst_id = p.inst_id)
     WHERE    sw.event NOT IN (   'rdbms ipc message'
                        , 'smon timer'
                        , 'pmon timer'
                        , 'SQL*Net message from client'
                        , 'lock manager wait for remote message'
                        , 'ges remote message'
                        , 'gcs remote message'
                        , 'gcs for action'
                        , 'client message'
                        , 'pipe get'
                        , 'null event'
                        , 'PX Idle Wait'
                        , 'single-task message'
                        , 'PX Deq: Execution Msg'
                        , 'KXFQ: kxfqdeq - normal deqeue'
                        , 'listen endpoint status'
                        , 'slave wait'
                        , 'wakeup time manager')
      AND sw.seconds_in_wait > 0
ORDER BY      wait_time_sec DESC
             ,i.instance_name;
*/

set markup html off
prompt <h2 id="Arboldebloqueos__Jah376fhYd736T">
set termout on
prompt * Arbol de bloqueos (solo si existen bloqueos en curso)
set termout off
prompt </h2>
set markup html on

select * from (
with lk as (
SELECT /*+rule */
        ih.inst_id||'.'||lh.sid blocker,
        iw.inst_id||'.'||lw.sid waiter
    FROM
        gv$lock     lw
      , gv$lock     lh
      , gv$instance iw
      , gv$instance ih
      , gv$session  sw
      , gv$session  sh
      , gv$process  pw
      , gv$process  ph
      , gv$sqlarea  aw
    WHERE
          iw.inst_id  = lw.inst_id
      AND ih.inst_id  = lh.inst_id
      AND sw.inst_id  = lw.inst_id
      AND sh.inst_id  = lh.inst_id
      AND pw.inst_id  = lw.inst_id
      AND ph.inst_id  = lh.inst_id
      AND aw.inst_id  = lw.inst_id
      AND sw.sid      = lw.sid
      AND sh.sid      = lh.sid
      AND lh.id1      = lw.id1
      AND lh.id2      = lw.id2
      AND lh.request  = 0
      AND lw.lmode    = 0
      AND (lh.id1, lh.id2) IN ( SELECT id1,id2
                                FROM   gv$lock
                                WHERE  request = 0
                                INTERSECT
                                SELECT id1,id2
                                FROM   gv$lock
                                WHERE  lmode = 0
                              )
      AND sw.paddr  = pw.addr (+)
      AND sh.paddr  = ph.addr (+)
      AND sw.sql_address  = aw.address
    ORDER BY
        iw.instance_name
      , lw.sid
-- blocking_instance is not null and blocking_session is not null
)
select /*+rule */ lpad('|___________',9*(level-1))||waiter "inst_id.sid"
,s.sid,s.serial# serial,s.inst_id ins
--, p.pid
, p.spid spid, s.module
, s.machine, s.osuser,s.username
--, s.program
, s.status
, to_char(s.logon_time,'dd/mm hh24:mi') logon, s.last_call_et
--,sysdate -  (s.last_call_et / (24 * 60 * 60)) last_call_et_date
  ,s.ROW_WAIT_BLOCK#,s.ROW_WAIT_FILE#,s.ROW_WAIT_OBJ#,s.ROW_WAIT_ROW#
, s.resource_consumer_group
--,(select round(sstat.value/100,3) from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'CPU used by this session') cpu_total_usada_SEC
--,(select round(sstat.value/100,3) from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'CPU used when call started') cpu_usada_call_start_SEC
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'consistent gets') consistent_gets
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'physical reads') physical_reads
--,(select sstat.value from GV$sesstat sstat,GV$statname statname where statname.inst_id = S.INST_ID and sstat.inst_id = S.INST_ID and s.sid = sstat.sid AND statname.statistic# = sstat.statistic# AND statname.name = 'physical writes') physical_writes
,sa.hash_value,SUBSTR(sa.sql_text, 1, 80)  sql_text
from
    (select * from lk
    union all
    select distinct 'root', blocker from lk
    where blocker not in (select waiter from lk))
    ,gv$session s, gv$process p, gv$sqlarea sa
where
            s.paddr = p.addr
          AND s.sql_address    =  sa.address(+)
          AND s.sql_hash_value =  sa.hash_value(+)
        and     s.inst_id = p.inst_id
        and waiter = s.inst_id||'.'||s.sid
connect by prior waiter=blocker start with blocker='root'
)
;


set markup html off
prompt <h2 id="sesiones_killed_Gbags6384MjdhcvaqRcsas187632kgs">
set termout on
prompt * Sesiones con status en killed
set termout off
prompt </h2>
set markup html on
select * from GV$session where status = 'KILLED';
SELECT s.inst_id,
       s.sid,
       s.status,
       s.serial#,
       p.spid,
       p.pid,
       s.username,
       s.program,
       s.LOGON_TIME
FROM   gv$session s,
        gv$process p
WHERE
   (p.addr = s.paddr AND p.inst_id = s.inst_id)
and s.status = 'KILLED';

set markup html off
prompt <h2 id="20190806_1130">
set termout on
prompt * MEMORY Status (gv$memory_dynamic_components)
set termout off
prompt </h2>
set markup html on
SELECT*
FROM
    gv$memory_dynamic_components
ORDER BY
     component , inst_id
;


set markup html off
prompt <h2 id="hs61twtGsfafs167491gfafsf_statusSGA">
set termout on
prompt * SGA Status (Gv$sga_dynamic_components)
set termout off
prompt </h2>
set markup html on
SELECT*
FROM
    Gv$sga_dynamic_components
ORDER BY
     component , inst_id
;


set markup html off
prompt <h2 id="hs61twtGsfafs167491gfafsf_statusPGA">
set termout on
prompt * PGA Status (GV$PGASTAT)
set termout off
prompt </h2>
set markup html on
select * from GV$PGASTAT
;


set markup html off
prompt <h2 id="asdasdasdsdsad_actualizacion_estaditicas1231231sd">
set termout on
prompt * Status de los jobs de estadisticas (GATHER_STATS_JOB)
set termout off
prompt </h2>
set markup html on
 select (select host_name from V$instance) servidor, (select instance_name from V$instance) instancia
--,?  CRITICIDAD
 ,job_name, status, actual_start_date
 ,error#,additional_info
from dba_SCHEDULER_JOB_RUN_DETAILS
 where job_name like 'GATHER_STATS%'
--and status !=  'SUCCEEDED'
 --where job_name = 'PURGE_LOG'
  --and status = 'SUCCEEDED'
  order by actual_start_date desc
;


set markup html off
prompt <h2 id="redologswitch_Hsgdbcg506lPaq13Ncf7">
set define on
set termout on
prompt * Mapa de redolog switch generado (para rango de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
prompt <p> (Este grafico no mostrara las horas durante las cuales no se haya generado redolog switch) </p>
set markup html on




set markup html off
SET LINESIZE      1000
SET LONGCHUNKSIZE 30000
SET LONG          30000
SET FEEDBACK OFF
SET VERIFY   OFF
SET PAGESIZE 0
SET DEFINE OFF
SET HEADING OFF
set serveroutput on size unlimited

set define on
declare
	v_contenido xmltype;
begin
 FOR instancia IN (SELECT INST_ID,instance_name from GV$instance order by INST_ID )
  LOOP
    BEGIN
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      ('with tabla as
		(
				SELECT count(*) YVAL
				,      ''[Instancia: '||instancia.instance_name||'] -  Numero de redolog switch generado por hora'' METRIC_NAME
				,      ''Hora (formato hh24)'' METRIC_UNIT
				,      TO_CHAR(first_time,''yyyymmdd hh24'') datetime
				FROM v$loghist
				WHERE thread# = '||instancia.inst_id||' 
				and first_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'')
  				and first_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') 
				GROUP BY TO_CHAR(first_time,''yyyymmdd hh24'')
				ORDER BY TO_CHAR(first_time,''yyyymmdd hh24'')
		)
		select yval,metric_name,metric_unit, to_char(to_date(datetime,''yyyymmdd hh24''),''hh24'') begin_time, ( select greatest(max(yval),10) from tabla) YVAL_MAX, (select greatest(min(yval),0) from tabla) YVAL_MIN from tabla
		order by datetime asc
	  ')
,      XMLTYPE.CREATEXML
   (TO_CLOB(
    '<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">40</xsl:variable>
     <xsl:variable name="bar_width">5</xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="315+$margin_left"/></xsl:variable>
     <xsl:variable name="graph_height"><xsl:value-of select="100+$margin_top+$margin_bottom"/></xsl:variable>
     <xsl:variable name="graph_name"><xsl:value-of select="/descendant::METRIC_NAME[position()=1]"/></xsl:variable>
     <xsl:variable name="graph_unit"><xsl:value-of select="/descendant::METRIC_UNIT[position()=1]"/></xsl:variable>
     <xsl:variable name="yval_max"><xsl:value-of select="/descendant::YVAL_MAX[position()=1]"/></xsl:variable>
     <xsl:variable name="yval_min"><xsl:value-of select="/descendant::YVAL_MIN[position()=1]"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_height}">
           <text x="{$margin_left+1}" y="{($margin_top)-5}" style="fill: #000000; stroke: none;font-size:11px;text-anchor=start"><xsl:value-of select="$graph_name"/></text>
		   <text x="{$margin_left+80}" y="{($margin_top)+125}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="$graph_unit"/></text>
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-0}"   x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-0}"  style="stroke:cornflowerblue;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-25}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-25}" style="stroke:cornflowerblue;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-50}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-50}" style="stroke:cornflowerblue;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-75}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-75}" style="stroke:cornflowerblue;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-100}" x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:cornflowerblue;stroke-width:1" />
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-2}"   style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round($yval_min)"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-25}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+(1*(($yval_max)-($yval_min)) div 4))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-50}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+((($yval_max)-($yval_min)) div 2))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-75}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+(3*(($yval_max)-($yval_min)) div 4))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-100}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round($yval_max)"/></text>
           <line x1="{$margin_left}" y1="{($graph_height)-($margin_bottom)}" x2="{$margin_left}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:cornflowerblue;stroke-width:1" />'
           )
    ||
	-- OJO que donde dice mod 3=0 eso quiere decir que mostrara como eje X un intervalo de 3 valores
    TO_CLOB(
          '<xsl:for-each select="ROWSET/ROW/BEGIN_TIME">
             <xsl:choose>
               <xsl:when test="(position()-1) mod 2=0">
                 <text x="{($margin_left)-9+($bar_width*(position()-1))}" y="{($graph_height)-($margin_bottom)+12}" style="fill: #000000; stroke: none;font-size:7px;text-anchor=start"><xsl:value-of select="self::node()"/></text>
                 <line x1="{($margin_left)+($bar_width*(position()-1))}" y1="{($graph_height)-($margin_bottom)+4}" x2="{($margin_left)+($bar_width*(position()-1))}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:cornflowerblue;stroke-width:1" />
               </xsl:when>
             </xsl:choose>
           </xsl:for-each>
           <xsl:for-each select="ROWSET/ROW/YVAL">
             <rect x="{$margin_left+$bar_width*(position()-1)}" y="{round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))}" width="{$bar_width}" height="{round(((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))}" fill="lightgreen" stroke="black"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>'
           )
   )
   )
		into v_contenido from dual;
		dbms_output.put_line(v_contenido.getClobVal);
		end;
	end loop;
end;
/




set markup html on
set heading on
set feedback on
set pagesize 20
set define on

prompt ESTO ES PARA EL RANGO DE FECHA SELECCIONADO ENTRE &fecha_ini_awr y &fecha_fin_awr:

select to_char(first_time,'yyyymmdd') "DIA",(select instance_name from GV$instance where inst_id = lh.THREAD# ) instance_name,
count(*) "total_switch_dia",
decode(sum(decode(to_char(first_time,'HH24'),'00',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'00',1,0))) "00",
decode(sum(decode(to_char(first_time,'HH24'),'01',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'01',1,0))) "01",
decode(sum(decode(to_char(first_time,'HH24'),'02',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'02',1,0))) "02",
decode(sum(decode(to_char(first_time,'HH24'),'03',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'03',1,0))) "03",
decode(sum(decode(to_char(first_time,'HH24'),'04',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'04',1,0))) "04",
decode(sum(decode(to_char(first_time,'HH24'),'05',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'05',1,0))) "05",
decode(sum(decode(to_char(first_time,'HH24'),'06',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'06',1,0))) "06",
decode(sum(decode(to_char(first_time,'HH24'),'07',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'07',1,0))) "07",
decode(sum(decode(to_char(first_time,'HH24'),'08',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'08',1,0))) "08",
decode(sum(decode(to_char(first_time,'HH24'),'09',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'09',1,0))) "09",
decode(sum(decode(to_char(first_time,'HH24'),'10',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'10',1,0))) "10",
decode(sum(decode(to_char(first_time,'HH24'),'11',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'11',1,0))) "11",
decode(sum(decode(to_char(first_time,'HH24'),'12',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'12',1,0))) "12",
decode(sum(decode(to_char(first_time,'HH24'),'13',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'13',1,0))) "13",
decode(sum(decode(to_char(first_time,'HH24'),'14',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'14',1,0))) "14",
decode(sum(decode(to_char(first_time,'HH24'),'15',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'15',1,0))) "15",
decode(sum(decode(to_char(first_time,'HH24'),'16',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'16',1,0))) "16",
decode(sum(decode(to_char(first_time,'HH24'),'17',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'17',1,0))) "17",
decode(sum(decode(to_char(first_time,'HH24'),'18',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'18',1,0))) "18",
decode(sum(decode(to_char(first_time,'HH24'),'19',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'19',1,0))) "19",
decode(sum(decode(to_char(first_time,'HH24'),'20',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'20',1,0))) "20",
decode(sum(decode(to_char(first_time,'HH24'),'21',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'21',1,0))) "21",
decode(sum(decode(to_char(first_time,'HH24'),'22',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'22',1,0))) "22",
decode(sum(decode(to_char(first_time,'HH24'),'23',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'23',1,0))) "23"
from v$log_history lh
where first_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi')
  	and first_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') 
group by to_char(first_time,'yyyymmdd'),THREAD#
order by to_char(first_time,'yyyymmdd') desc, THREAD#
;

SELECT to_char(first_time,'yyyymmdd') DAY,
   count(*) switch_total,
   round(count(*)*log_size/1024/1024/1024,2) Aprox_GB_por_dia,
   round(count(*)*log_size/1024/1024/1024/24,2) Aprox_GB_por_hora,
   to_char(count(*)/24,'99999999.9') switch_total_x_dia
FROM v$loghist,
(select avg(bytes) log_size from v$log)
where 	first_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi')
  	and first_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') 
GROUP BY to_char(first_time,'yyyymmdd'),log_size
order by 1  desc ;
set define off


prompt Esto es para los ultimos dias recientes:
select to_char(first_time,'yyyymmdd') "DIA",(select instance_name from GV$instance where inst_id = lh.THREAD# ) instance_name,
count(*) "total_switch_dia",
decode(sum(decode(to_char(first_time,'HH24'),'00',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'00',1,0))) "00",
decode(sum(decode(to_char(first_time,'HH24'),'01',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'01',1,0))) "01",
decode(sum(decode(to_char(first_time,'HH24'),'02',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'02',1,0))) "02",
decode(sum(decode(to_char(first_time,'HH24'),'03',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'03',1,0))) "03",
decode(sum(decode(to_char(first_time,'HH24'),'04',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'04',1,0))) "04",
decode(sum(decode(to_char(first_time,'HH24'),'05',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'05',1,0))) "05",
decode(sum(decode(to_char(first_time,'HH24'),'06',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'06',1,0))) "06",
decode(sum(decode(to_char(first_time,'HH24'),'07',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'07',1,0))) "07",
decode(sum(decode(to_char(first_time,'HH24'),'08',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'08',1,0))) "08",
decode(sum(decode(to_char(first_time,'HH24'),'09',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'09',1,0))) "09",
decode(sum(decode(to_char(first_time,'HH24'),'10',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'10',1,0))) "10",
decode(sum(decode(to_char(first_time,'HH24'),'11',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'11',1,0))) "11",
decode(sum(decode(to_char(first_time,'HH24'),'12',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'12',1,0))) "12",
decode(sum(decode(to_char(first_time,'HH24'),'13',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'13',1,0))) "13",
decode(sum(decode(to_char(first_time,'HH24'),'14',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'14',1,0))) "14",
decode(sum(decode(to_char(first_time,'HH24'),'15',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'15',1,0))) "15",
decode(sum(decode(to_char(first_time,'HH24'),'16',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'16',1,0))) "16",
decode(sum(decode(to_char(first_time,'HH24'),'17',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'17',1,0))) "17",
decode(sum(decode(to_char(first_time,'HH24'),'18',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'18',1,0))) "18",
decode(sum(decode(to_char(first_time,'HH24'),'19',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'19',1,0))) "19",
decode(sum(decode(to_char(first_time,'HH24'),'20',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'20',1,0))) "20",
decode(sum(decode(to_char(first_time,'HH24'),'21',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'21',1,0))) "21",
decode(sum(decode(to_char(first_time,'HH24'),'22',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'22',1,0))) "22",
decode(sum(decode(to_char(first_time,'HH24'),'23',1,0)),0,'.',sum(decode(to_char(first_time,'HH24'),'23',1,0))) "23"
from v$log_history lh
where first_time > sysdate -30
group by to_char(first_time,'yyyymmdd'),THREAD#
order by to_char(first_time,'yyyymmdd') desc, THREAD#
;

SELECT to_char(first_time,'yyyymmdd') DAY,
   count(*) switch_total,
   round(count(*)*log_size/1024/1024/1024,2) Aprox_GB_por_dia,
   round(count(*)*log_size/1024/1024/1024/24,2) Aprox_GB_por_hora,
   to_char(count(*)/24,'99999999.9') switch_total_x_dia
FROM v$loghist,
(select avg(bytes) log_size from v$log)
where 	first_time > sysdate -30
GROUP BY to_char(first_time,'yyyymmdd'),log_size
order by 1  desc ;
set define off




set markup html off
prompt <h2 id="1273ydyasasyhfbvbo0283_ajshdyqtw612tgdas">
set termout on
prompt * Parametros que inciden en performance (sobre todo para el optimizador)
set termout off
prompt </h2>
prompt <p> 
prompt (Doc ID 2187449.1) Recommendations for Adaptive Features in Oracle Database 12c Release 1 (Adaptive Features, Adaptive Statistics & 12c SQL Performance)
prompt <br>Ojo con esto cuando se migra un ambiente desde onprem hacia cloud 12c: Disable adaptive statistics. Oracle recommends disabling adaptive statistics to increase query plan stability. For more information, you can see My Oracle Support node 2312911.1 
prompt <br>consultar SELECT extension_name, extension FROM  dba_stat_extensions WHERE  table_name = 'X';
prompt <br>Para ver si la tabla en cuestion esta trabajando con AUTO_STAT_EXTENSIONS.
prompt Leer lo siguiente: https://blogs.oracle.com/optimizer/optimizer-adaptive-features-in-oracle-database-12c-release-2
prompt <br>(Doc ID 2053877.1) Wrong Results (0 Rows) Returned for Query that Includes Subquery Containing AND ROWNUM when OPTIMIZER_ADAPTIVE_FEATURES = TRUE.
prompt <br>el parametro OPTIMIZER_ADAPTIVE_FEATURES es para 12cR1, para 12cR2 ese parametro queda obsoleto y es reemplazado por optimizer_adaptive_plans and optimizer_adaptive_statistics.
prompt <br>optimizer_use_sql_plan_baselines to false mejora de rendimiento observada en Siebel	(cliente CCLA)</p>
prompt <br>db_file_multiblock_read_count en 32 para Siebel.
prompt <br>Para mas detalle conviene revisar la nota de Siebel: Performance Tuning Guidelines for Siebel CRM Application on Oracle Database (Doc ID 2077227.2)
prompt <br>En esta nota recomiendan fuertemente apagar ese parametro optimizer_adaptive_features para bd siebel en 12c
prompt <br>Ver otros ejemplos donde pasan estos problemas performance por ese parametro: (Doc ID 2058932.1).
prompt <br>Revisar si hay sql_profilers creados ya que la activacion de optimizer_capture_sql_plan_baselines puede causar problemas
prompt <br>https://petesdbablog.wordpress.com/2013/09/14/sql-profiles-and-sql-baseline-what-the-optimizer-uses/
prompt <br>El valor por default de FILESYSTEMIO_OPTIONS es NONE pero ojo con lo siguiente:
prompt <br>* FILESYSTEMIO_OPTIONS is ignored with ASM (pero el mejor valor deberia ser set_all para permitir Async y direct IO)
prompt <br>* In ASM make sure DISK_ASYNC_IO is set to TRUE (default)
prompt <br>
prompt <br><b>* db_file_multiblock_read_count (MBRC)</b> solo se usa en lecturas Non-buffer cache (o sea disco u otros), no se ocupa para leer bloques en buffer cache, y sólo leera por cada operación I/O hasta el máximo de I/O indicado como valor en el parámetro (bloques de 8k). Ver ejemplo expuesto en la figura 5-2 en el libro <b><i>"Troubleshooting Oracle Performance, Christian Atonigni"</i></b> Pagina 176. Valores demaciados altos forzaran full table scans.
prompt <br><b>* optimizer_index_cost_adj</b> permite ajusta el costo del acceso a la tabla por medio de index scan. Valores desde 1 10000. Valores mas altos que 100 haran que el costo de acceso por índice sea mas alto, mientras que valores más bajo que 100 haran parecer los index scan mas baratos en costos. Leer libro <b><i>"Troubleshooting Oracle Performance, Christian Atonigni"</i></b> Pagina 184, funcionamiento de optimizer_index_cost_adj.
prompt <br><b>* optimizer_index_caching</b> es para especificar  (en porcentaje) la cantidad de bloques de indices a mantener en buffer cache solo durante la ejecucion de las operaciones de in-list-iteration y nested loop joins, ver libro <b><i>"Troubleshooting Oracle Performance, Christian Atonigni"</i></b> Pagina 186.
prompt <br>
prompt <br>Consultar lo siguiente para mas informacion:
prompt <br>* Wolfgang Breitling’s paper "A Look under the Hood of CBO: The 10053 Event"
prompt <br>* Metalink note "CASE STUDY: Analyzing 10053 Trace Files (338137.1)"
prompt <br>* Chapter 14 of Jonathan Lewis’s book Cost-Based Oracle Fundamentals
prompt <br>
prompt <br> Valor por defecto del db_file_multiblock_read_count:
prompt <br> db_file_multiblock_read_count= MIN[ 1048576/db_block_size , db_cache_size/(sessions * db_block_size) ]
prompt <br> Pagina 178 "Troubleshooting Oracle Performance, Christian Atonigni"
prompt <br><b>* _optimizer_compute_index_stats</b> true por default, permite que al momento de crear indices se recolecten enseguida las estadisticas. SI esta en false no se capturarán estadísticas.
prompt <br>
prompt <br>Ojo con el parametro oculto en 11g _optimizer_ignore_hint y parámetro nuevo en 18c optimizer_ignore_hint.
prompt <br>Si esta en true permitira que el optimizador ignore todos los Hints del motor.
prompt <br>
prompt <br>Ojo con el parametro optimizer_ignore_parallel_hint.
prompt <br>Si esta en true permitira que el optimizador ignore todos los Hints de paraleismo.
prompt <br>
prompt <br>Atención con este parámetro _ash_sample_all:
prompt <br>Permitirá que ASH recolecte información tanto para las sesiones activas como las inactivas. Por defecto esta en FALSE. Revisar lo siguiente: https://blog.orapub.com/20180215/how-to-see-unseen-activity-using-ash-and-sqlnet-message-from-client.html
prompt <br>
prompt <br>Atención con este parámetro _high_priority_processes (por defecto da prioridad a LMS*) y _highest_priority_processes (este ultimo para asignar prioridad a VKTM en 12.1.0.2.0 por default )
prompt <br>Permite establecer la prioridad para ciertos procesos background. Ejemplo de valores: _high_priority_processes='LMS*|LGWR|PMON'. En algunos ambientes se ha observado una mejora notable en los eventos de espera log sync * al incrementar la prioridad del log writer.
prompt <br> 
prompt <br> Este parametro _use_adaptive_log_file_sync: Se recomienda ponerlo en TRUE solo si hay Log File Sync y el LGWR esta muy ocupado. En 11.2.0.3 se cambio a TRUE (metodo polling o encuestar). En modo polling es el foreground process el que pregunta si la info del redolog buffer ya ha sido escrita a archivos de redolog liberando carga de CPU y regursos al LGWR, mientras que en el modo FALSE (post/wait) es el metodo tradicional hasta antes de 11.2.0.2 en donde el LGWR es el que informa si ha la info de logbuffer ya esta totalmente escrita a los archivos de redolog.
prompt <br>
prompt <b> Ojo con este parametro _dlm_stats_collect en 12.2 hay un problema y ocasiona que el proceso background SCMn consuma mucha CPU innecesariamente (Bug 24590018 ). Revisar lo siguiente: 12.2 RAC DB Background process SCM0 consuming excessive CPU (Doc ID 2373451.1) y tambien revisar: https://www.felipedonoso.cl/2019/09/bug-24590018-on-exadata-scm0-on-top.html
prompt </p>
set markup html on
SELECT * from GV$parameter
where
	lower(name) like '%db_file_multiblock_read_count%'
	or lower(name) like '%optimizer%'
	--or lower(name) like '%optimizer_index_cost_adj%'
	--or lower(name) like '%optimizer_index_caching%'
	or lower(name) like '%cursor_sharing%'
	or lower(name) like '%optimizer_%_sql_plan_baselines%'
	or lower(name) like '%optimizer_dynamic_sampling%'
	or lower(name) like '%query_rewrite_enabled%'
	or lower(name) like '%statistics_level%'
	or lower(name) like '%optimizer_features_enable%'
	or lower(name) like '%filesystemio_options%'
	or lower(name) like '%disk_async_io%'
	or lower(name) like '%_cpu_to_io%'
	or lower(name) like '%start_%'
	or lower(name) like '_optim%'
	or lower(name) like 'optim%'
	or lower(name) like '_ash_sample_all%'
    or lower(name) like '_high_priority_processes%'
    or lower(name) like '_highest_priority_processes%'
    or lower(name) like '_dlm_stats_collect%'
    or lower(name) like '_use_adaptive_log_file_sync'
order by name,inst_id;


set markup html off
prompt <h2 id="182jhH_paisnUakajsj_91i2djasdhh172ud8dh7">
set termout on
prompt * Parametros que inciden en performance sobre Exadata
set termout off
prompt </h2>
prompt <p>
prompt <br>CELL_OFFLOAD_PROCESSING recomendado TRUE (de lo contrario Deshabilita "Smart Scan")
prompt <br>_KCFIS_STORAGEIDX_DISABLED recomendado FALSE ( de lo contrario Deshabilita "Storage index")
prompt </p>
set markup html on
SELECT * from GV$parameter
where
	lower(name)    like '%cell_offload_processing%'
	or lower(name) like '%_kcfis_storageidx_disabled%'
	or lower(name) like '%resource_manager_plan%'
order by name,inst_id;


set markup html off
prompt <h2 id="18172hjdha99yad_ahsydsh_hahsyqy2717127273">
set termout on
prompt * Parametros que afectan a la performance relacionados a Set de caracteres (NLS_DATABASE_PARAMETERS)
set termout off
prompt </h2>
prompt <p>
prompt <br>Atencion con los parametros como por ejemplo (ignorar mayusculas y minusculas en comparaciones del where):
prompt <br>... ALTER SESSION SET nls_comp = LINGUISTIC
prompt <br>... ALTER SESSION SET nls_sort = BINARY_CI
prompt <br>Pueden hacer que los planes de ejecucion varien sobre todo en el predicando
prompt <br>Ej: filter(NLSSORT
prompt       ("OWNER",'nls_sort=''BINARY_CI''')
prompt         >HEXTORAW('7300’) )
prompt <br>Revisar paper smart scan en exadata de Tanel_Poder_Drilling_Deep_Into_Exadata_Performance.pdf pagina 34
prompt <br>Esos parametros inciden mucho en performance sobre todo en los where revisar aquello
prompt </p>
set markup html on
select * from nls_database_parameters 
;

set markup html off
prompt <h2 id="18237dhasyGtagGtqiwOOisuagGasvqy6172gaggs">
set termout on
prompt * Full database caching
set termout off
prompt </h2>
prompt <p>Recordar lo siguiente (por default) cuando no se ocupa database caching:
prompt <br>Las tablas pequenas son alojadas en memoria  solamente si el tamano total de la tabla es menor del 2% del tamano total del Buffer Cache.
prompt <br>Para las tablas medianas (Algunos dicen que mediano es entre el 2% y el 10% del tamano del Buffer Cache, pero no esta confirmado), Oracle analiza la fecha en que la tabla fue escaneada por ultima vez, la fecha de la ultima utilizacion de los bloques que ya estan en el Buffer cache, el tamano de la tabla y el espacio libre en el Buffer Cache; en base a esta informacion Oracle decide si poner los bloques de esta tabla en el Buffer Cache o no.
prompt <br>Las tablas grandes No son puestas en el Buffer Cache a menos que se indique explicitamente que estos bloques deberian ser puestos en el Buffer cache mediante la clausula "KEEP". Podriamos llegar a ver algunos bloques de estas tablas pero mas bien son de metadatos.
prompt <br><b> con full database caching Oracle ya no le interesa si la tabla es pequena (menos del 2% del tamano del buffer cache), mediana o grande, simple y sencillamente aloja todos sus bloques en memoria. (es como si usaramos keep buffer pool para toda la base de datos, excepto que keep buffer pool tambien tiene su propio espacio de memoria asignado)</b>
prompt </p>
set markup html on

SELECT FORCE_FULL_DB_CACHING FROM V$DATABASE;

set markup html off
prompt <h2 id="27ry17fnvbbmp082ydgxbvagwtebabdj17egfhgnbku">
set termout on
prompt * SQL Profiles (DBA_SQL_PROFILES)
set termout off
prompt </h2>
set markup html on
select * from   DBA_SQL_PROFILES;


set markup html off
prompt <h2 id="182fnvneu750tpjanxb1_18273hansh73h4b">
set termout on
prompt * Foreign Key sin indices
set termout off
prompt </h2>
prompt <p>
prompt (90% de la causa raiz de waits Enq TM : Contention)
prompt (Doc ID 1475340.1) Resolving Issues Where Lock Contention for enq: TM - contention.
prompt (There are no 'Missing' Indexes on Foreign Key columns)
prompt <br>
prompt Como ejemplo se exponen las siguientes situaciones de issue cuando no hay indices sobre Foreign Keys:
prompt <br>Si se realiza algun tipo de delete sobre tablas padres (parent) se provocara que se realice un full table scan sobre la tabla hija (child). Como esto puede ser muy lento se pueden generar bloqueos innecesarios por el dml en ejecucion.
prompt <br>Si se realiza algun update sobre algun campo de un indice unico/primario de la tabla padre.
prompt <br>Si se realiza algun join entre la tabla hija/padre involucrando al campo foreign key de la hija en el Join.
prompt </p>
set markup html on
select * from (SELECT DISTINCT
       parent_owner,
       parent_table,
       child_owner,
       child_table,
       constraint_name,
       constraint_columns
  FROM (SELECT parent_owner,
               parent_table,
               child_owner,
               child_table,
               constraint_name,
               index_owner,
               index_name,
               MAX(CASE WHEN (cons_column_list = indx_column_list) THEN 1 ELSE 0 END)
                 OVER (PARTITION BY child_owner, child_table, parent_owner, parent_table, constraint_name) AS fk_indexed_p
          FROM (SELECT p.owner AS parent_owner,
                       p.table_name AS parent_table,
                       r.owner AS child_owner,
                       r.table_name AS child_table,
                       r.constraint_name,
                       i.index_owner,
                       i.index_name,
                       -- ordered list of columns for the constraint
                       LISTAGG(c.column_name, ',')
                         WITHIN GROUP (ORDER BY c.column_name)
                         OVER (PARTITION BY r.owner, r.table_name, r.r_owner, c.table_name, r.constraint_name, i.index_owner, i.index_name) AS cons_column_list,
                       -- ordered list of columns for the index
                       LISTAGG(i.column_name, ',')
                         WITHIN GROUP (ORDER BY i.column_name)
                         OVER (PARTITION BY r.owner, r.table_name, r.r_owner, c.table_name, r.constraint_name, i.index_owner, i.index_name) AS indx_column_list
                  FROM DBA_CONSTRAINTS r
                  JOIN DBA_CONSTRAINTS p ON (p.owner = r.r_owner AND p.constraint_name = r.r_constraint_name)
                  JOIN DBA_CONS_COLUMNS c ON (c.owner = r.r_owner AND c.constraint_name = r.constraint_name)
                  LEFT OUTER
                  JOIN DBA_IND_COLUMNS i ON (c.owner = i.table_owner AND r.table_name = i.table_name AND c.position = i.column_position)
                 --WHERE r.r_owner NOT IN ('SYS', 'DBSNMP', 'OUTLN', 'PERFSTAT', 'SYSTEM', 'XDB')
                       -- only referential constraints
                   AND r.constraint_type = 'R'
                       -- Tanel Poder uses this user/table selection in his scripts
                   ))
  JOIN (SELECT DISTINCT
               owner AS child_owner,
               table_name AS child_table,
               constraint_name,
               LISTAGG(column_name, ',')
                 WITHIN GROUP (ORDER BY position)
                 OVER (PARTITION BY owner, constraint_name, table_name) AS constraint_columns
          FROM DBA_CONS_COLUMNS) USING (child_owner, child_table, constraint_name)
 WHERE fk_indexed_p = 0
 ORDER BY parent_owner, parent_table, child_owner, child_table, constraint_name
 )-- where parent_table like '%BOPERS_MAE%' 
 ;
 
 
 set markup html off
prompt <h2 id="jajsh__ajsjhdu1837fhHgags__18dj1u3da">
set termout on
prompt * SQL Lineas bases (dba_sql_plan_baselines)
set termout off
prompt </h2>
set markup html on
select * from dba_sql_plan_baselines
order by 2,4
;



set markup html off
prompt <h1 id="ash12ydtqter3253232">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt ASH
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="15twgcnkaief98284hfnbaka018347hnamdsjdh">
set termout on
prompt * ASH Resumen
set termout off
prompt </h2>
set markup html on


with top_ash as (
    select /*+ MATERIALIZE */
        inst_id,session_id,session_serial#
        ,sql_id ,sql_plan_hash_value,session_type,program,module
        --,sum(decode(session_state,'ON CPU',1,0)) as cpu
        --,sum(decode(session_state,'WAITING',1,0)) - sum(decode(session_state,'WAITING', decode(wait_class, 'User I/O',1,0),0)) as wait
        --,sum(decode(session_state,'WAITING', decode(wait_class, 'User I/O',1,0),0)) as io
        ,user_id
        ,sum(decode(session_state,'ON CPU',1,1)) as total
    from Gv$active_session_history
    where
        session_state = 'ON CPU'   and
        sql_id is not null
        and sample_time > (sysdate-1/24)
    group by sql_id,sql_plan_hash_value,session_type,program,module,user_id,session_id,session_serial#,inst_id
    order by sum(decode(session_state,'ON CPU',1,1))   desc
) select
         --top_ash.inst_id
         (select instance_name from GV$instance where inst_id = top_ash.inst_id) instance_name
         ,session_id sid,session_serial# serial#
         ,nvl((select machine from GV$session where inst_id = top_ash.inst_id and session_id = sid and session_serial# = serial#),'[sesion_desconectada]') machine
         --,nvl((select terminal from GV$session where inst_id = top_ash.inst_id and session_id = sid and session_serial# = serial#),'[sesion_desconectada]') terminal
         ,nvl((select osuser from GV$session where inst_id = top_ash.inst_id and session_id = sid and session_serial# = serial#),'[sesion_desconectada]') osuser
         ,top_ash.sql_id,top_ash.sql_plan_hash_value,session_type
         ,(select username from dba_users where user_id = top_ash.user_id) username
         --,top_ash.program
         ,top_ash.module
        --,cpu,wait,io,
        ,total
        ,round(ratio_to_report(total) over ()*100,2) "TOTAL_%"
        ,nvl((select  substr(sql_text,0,40) sql_text from GV$sql where sql_id = top_ash.sql_id and rownum=1),'Consulta no esta en shared_pool' ) sql_text_full
		,nvl((select sql_profile  from GV$sql where sql_id = top_ash.sql_id and rownum=1),'Consulta no esta en shared_pool' ) sql_profile
from top_ash
where rownum <=15;


/*******************************************************************************
* ASH - Querys mas ejecutadas (Solo de las sesiones activas, session_state * ON CPU)
* TOP 15 ultimos 60 minutos
*
* @autor	: Felipe Donoso, felipe@felipedonoso.cl
* @release	: 10g en adelante
* @date		: 2017-02-03
********************************************************************************/
with top_ash as (
    select /*+ MATERIALIZE */
         sql_id ,sql_plan_hash_value,session_type,program,module
        ,sum(decode(session_state,'ON CPU',1,1)) as total
		,user_id
    from GV$active_session_history
    where
        session_state = 'ON CPU'   and
        sql_id is not null
        and sample_time > (sysdate-1/24)
    group by sql_id,sql_plan_hash_value,session_type,program,module,user_id
    order by sum(decode(session_state,'ON CPU',1,1))   desc
) select
         sql_id,sql_plan_hash_value,session_type
		 ,(select username from dba_users where user_id = top_ash.user_id) username,program,module
        ,total
        ,round(ratio_to_report(total) over ()*100,2) "TOTAL_%"
        ,nvl((select  substr(sql_text,0,40) sql_text from GV$sql where sql_id = top_ash.sql_id and rownum=1),'Consulta no esta en shared_pool' ) sql_text_full
from top_ash
where rownum <=15;


/*******************************************************************************
* ASH - Querys mas ejecutadas (incluyendo las que experimentan waits)
* TOP 15 ultimos 60 minutos
*
* @autor	: Felipe Donoso, felipe@felipedonoso.cl
* @release	: 10g en adelante
* @date		: 2017-02-03
********************************************************************************/
with top_ash as (
    select /*+ MATERIALIZE */
         sql_id ,sql_plan_hash_value,session_type,program,module
        ,sum(decode(session_state,'ON CPU',1,0)) as cpu
        ,sum(decode(session_state,'WAITING',1,0)) - sum(decode(session_state,'WAITING', decode(wait_class, 'User I/O',1,0),0)) as wait
        ,sum(decode(session_state,'WAITING', decode(wait_class, 'User I/O',1,0),0)) as io
        ,sum(decode(session_state,'ON CPU',1,1)) as total
		,user_id
    from GV$active_session_history
    where
        --lower(session_state) = 'on cpu'   and
        sql_id is not null
        and sample_time > (sysdate-1/24)
    group by sql_id,sql_plan_hash_value,session_type,program,module,sql_id,user_id
    order by sum(decode(session_state,'ON CPU',1,1))   desc
) select
         sql_id,sql_plan_hash_value,session_type
		 ,(select username from dba_users where user_id = top_ash.user_id) username,program,module
        ,cpu,wait,io,total
        ,round(ratio_to_report(total) over ()*100,2) "TOTAL_%"
		,nvl((select  substr(sql_text,0,40) sql_text from GV$sql where sql_id = top_ash.sql_id and rownum=1),'Consulta no esta en shared_pool' ) sql_text_full
from top_ash
where rownum <=15;


/*******************************************************************************
* ASH - Eventos de espera con mayor ocurrencia
* TOP 15 ultimos 60 minutos
*
* @autor	: Felipe Donoso, felipe@felipedonoso.cl
* @release	: 10g en adelante
* @date		: 2017-02-03
********************************************************************************/
with top_ash as (
    select /*+ MATERIALIZE */
         wait_class,event,session_state,session_type
        ,sum(decode(session_state,'WAITING',1,1)) as total
    from GV$active_session_history
    where
        session_state = 'WAITING'
        and sample_time > (sysdate-1/24)
    group by wait_class,event,session_state,session_type
    order by sum(decode(session_state,'WAITING',1,1))   desc
) select
         wait_class,event,session_state,session_type
         ,total
        ,round(ratio_to_report(total) over ()*100,2) "TOTAL_%"
from top_ash
where rownum <=15;



/*******************************************************************************
* ASH - Eventos de espera de la clase Concurrency - Application y otros enqueues con mayor ocurrencia
* TOP 15 ultimos 60 minutos
*
* @autor	: Felipe Donoso, felipe@felipedonoso.cl
* @release	: 10g en adelante
* @date		: 2017-02-03
********************************************************************************/
with top_ash as (
    select /*+ MATERIALIZE */
         wait_class,event,session_state,session_type
        ,sum(decode(session_state,'WAITING',1,1)) as total
    from GV$active_session_history
    where
        session_state = 'WAITING'  and
		(wait_class in ('Concurrency','Application','Commit') or lower(event) like '%contention%' or lower(event) like '%enq%'  or lower(event) like '%lock%' or lower(event) like '%latch%' )
        and sample_time > (sysdate-1/24)
    group by wait_class,event,session_state,session_type
    order by sum(decode(session_state,'WAITING',1,1))   desc
) select
         wait_class,event,session_state,session_type
         ,total
        ,round(ratio_to_report(total) over ()*100,2) "TOTAL_%"
from top_ash
where rownum <=15;


/*******************************************************************************
* ASH - Eventos de espera de la clase Concurrency - Application y otros enqueues con mayor ocurrencia
*		Agrupados por Modulo
* TOP 15 ultimos 60 minutos
*
* @autor	: Felipe Donoso, felipe@felipedonoso.cl
* @release	: 10g en adelante
* @date		: 2017-02-03
********************************************************************************/
with top_ash as (
    select /*+ MATERIALIZE */
         wait_class,event,session_state,session_type,module,user_id
        ,sum(decode(session_state,'WAITING',1,1)) as total
    from GV$active_session_history
    where
        session_state = 'WAITING'  and
		(wait_class in ('Concurrency','Application','Commit') or lower(event) like '%contention%' or lower(event) like '%enq%'  or lower(event) like '%lock%' or lower(event) like '%latch%' )
        and sample_time > (sysdate-1/24)
    group by wait_class,event,session_state,session_type,module,user_id
    order by sum(decode(session_state,'WAITING',1,1))   desc
) select
         wait_class,event,session_state,session_type,module
		 ,(select username from dba_users where user_id = top_ash.user_id) username
         ,total
        ,round(ratio_to_report(total) over ()*100,2) "TOTAL_%"
from top_ash
where rownum <=15;






set markup html off
prompt <h1 id="AWR_dhNvh2745Ufjti9wd">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Performance AWR
set termout off
prompt </h1>
prompt <p>
prompt <br>Si no existiese posiblidad de conectarse directamente a la instancia de base de datos para usar la herramienta:
prompt <br>MTV_AWR_Analyzer.xlsm
prompt <br>Solicitar al cliente que nos envie el archivo DMP con las tablas y metricas de AWR
prompt <br>haciendo uso de la siguiente nota de soporte:
prompt <br>How to Export and Import the AWR Repository From One Database to Another (Doc ID 785730.1)
prompt </p>
set markup html on



set markup html off
prompt <h2 id="20191206_1527">
set define on
set termout on
prompt * Resumen completo de AWR (revisar este capitulo antes de ver performance en general) (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>


set markup html off
set heading off
prompt <p style=font-family:courier;color:#3463D0>
prompt <pre>
/*
 * El siguiente script es parte del archivo de resumen awr filtrado
 * No modificar sin permiso del autor:
 * https://github.com/felipower/scripts_oracle/blob/master/FDB_Oracle_AWR_summary_filtered.sql
 *
 * @autor: Felipe Donoso Batias, felipe@felipedonoso.cl felipe.donoso@oracle.com
 * @fecha: 2019-10-29
 * 
 * Some additional examples:
 * @FDB_Oracle_AWR_summary_filtered 20191028_1100 20191101_1500 "Time Model - % of D%"
 * @FDB_Oracle_AWR_summary_filtered 20191028_1100 20191101_1500 "Top Timed Foregro%"  
 * @FDB_Oracle_AWR_summary_filtered 20191126_1100 20191127_1100 "SQL ordered by CPU%" 
 * @FDB_Oracle_AWR_summary_filtered 20191126_1100 20191127_1100 "SQL ordered by%"     
 * 
 */
SELECT 
--seccion,
--replace(replace(replace(salida,' ','&espacio_en_blanco'),chr(10),'</br>'),',',',</br>')||'</br>' FROM (
 salida  FROM (
    SELECT
         LAST_VALUE(seccion IGNORE NULLS) OVER (ORDER BY linea) seccion
        ,salida
    FROM(
        SELECT  ROWNUM linea
            ,CASE
                WHEN ROWNUM = 1 THEN TRIM(output)
                WHEN TRIM(output) = 'Database Summary' THEN TRIM(output)
                WHEN TRIM(output) = 'Cache Sizes' THEN TRIM(output)
                WHEN output like ('%DB/Inst%') THEN TRIM(REGEXP_REPLACE(output,' *DB/Inst.*$'))
                ELSE NULL
             END seccion
            ,output salida
                    FROM TABLE(
                            DBMS_WORKLOAD_REPOSITORY.AWR_GLOBAL_REPORT_TEXT(l_dbid=>(SELECT dbid FROM v$database),l_inst_num=>'',l_bid=>&snap_ini,l_eid=>&snap_fin,l_options=>1+4+8)
                    )
         ORDER BY 1
    ) 
) WHERE seccion  IN
    (
    'Cache Sizes'
    ,'Time Model'
    ,'Time Model - % of DB time'
    ,'Foreground Wait Classes -  % of Total DB time'
    ,'Foreground Wait Classes'
    ,'Foreground Wait Classes -  % of DB time'
    ,'Top Timed Events'
    ,'Top Timed Foreground Events'
    ,'Foreground Wait Events (Global)'
    )
;
prompt </pre>
prompt </p>
set markup html on
set heading on



set markup html off
prompt <h2 id="hasdhjasjdjqiuhjashjashduyqwhu1787834765439gmnvdiowe8482">
set termout on
prompt * Propiedades de AWR, retencion y uso (dba_hist_wr_control - sys.wrm$_wr_control)
set termout off
prompt </h2>
set markup html on
select * from   dba_hist_wr_control;
select
   extract( day from snap_interval) *24*60+
   extract( hour from snap_interval) *60+
   extract( minute from snap_interval ) "Snapshot Interval",
   extract( day from retention) *24*60+
   extract( hour from retention) *60+
   extract( minute from retention ) "Retention Interval"
from 
   dba_hist_wr_control;
select snap_interval, retention, most_recent_purge_time from sys.wrm$_wr_control;
SELECT name,       
       detected_usages detected,
       total_samples   samples,
       currently_used  used,
       to_char(last_sample_date,'MMDDYYYY:HH24:MI') last_sample,
       sample_interval interval
  FROM dba_feature_usage_statistics
 WHERE name = 'Automatic Workload Repository'     OR  name like 'SQL%';


set markup html off
prompt <h2 id="633642trfnvnjdhghtwte65hfhsh_ohpho968hjwhehrsdsaasnbwerw">
set define on
set termout on
prompt * Top querys Elapsed time (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
set define on
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
					,elapsed_time value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  						,sum(round(sql1.elapsed_time_delta/1000000,2))                elapsed_time
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						--and sn.begin_interval_time  > sysdate - 15
  						and (sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  						and (sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
 					having sum(sql1.executions_delta) > 0
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.elapsed_time_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% sql_id elapsed time</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes        
,invalidations
,iowait
,javexec_time
,loads
,parse_calls
,plsexec_time
,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  ,sum(sql1.invalidations_delta)               invalidations
  ,sum(sql1.iowait_delta)                      iowait
  ,sum(sql1.javexec_time_delta)                javexec_time
  ,sum(sql1.loads_delta)                       loads
  ,sum(sql1.parse_calls_delta)                 parse_calls
  ,sum(sql1.plsexec_time_delta)               plsexec_time
  ,sum(sql1.px_servers_execs_delta)            px_servers_execs
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
    and (sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  	and (sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.elapsed_time_delta) desc
  ) top_querys where rownum <= 15
;

set markup html off
prompt <h2 id="73723yhfmsdjsfuvnvbnvia083urhfjaiqwjdnafncvudnakdjqhqehq">
set define on
set termout on
prompt * Top querys CPU time (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
					,cpu_time value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  						,sum(round(sql1.cpu_time_delta/1000000,2))                cpu_time
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						and (sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  						and (sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
 					having sum(sql1.executions_delta) > 0  
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.cpu_time_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% sql_id CPU time</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes        
,invalidations
,iowait
,javexec_time
,loads
,parse_calls
,plsexec_time
,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  ,sum(sql1.invalidations_delta)               invalidations
  ,sum(sql1.iowait_delta)                      iowait
  ,sum(sql1.javexec_time_delta)                javexec_time
  ,sum(sql1.loads_delta)                       loads
  ,sum(sql1.parse_calls_delta)                 parse_calls
  ,sum(sql1.plsexec_time_delta)               plsexec_time
  ,sum(sql1.px_servers_execs_delta)            px_servers_execs
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
    and (sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  	and (sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.cpu_time_delta) desc
  ) top_querys where rownum <= 15
;

set markup html off
prompt <h2 id="hjmbnzvwo385ynvs7_18374hdsjs_unfnahshd_81jnnajsjdjajsjdj">
set define on
set termout on
prompt * Top querys logical reads (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
					,buffer_gets value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  						,sum(sql1.buffer_gets_delta)                buffer_gets
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						and ( sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') )
  						and ( sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') )
 					having sum(sql1.executions_delta) > 0  
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.buffer_gets_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% sql_id logical reads</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes        
,invalidations
,iowait
,javexec_time
,loads
,parse_calls
,plsexec_time
,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  ,sum(sql1.invalidations_delta)               invalidations
  ,sum(sql1.iowait_delta)                      iowait
  ,sum(sql1.javexec_time_delta)                javexec_time
  ,sum(sql1.loads_delta)                       loads
  ,sum(sql1.parse_calls_delta)                 parse_calls
  ,sum(sql1.plsexec_time_delta)               plsexec_time
  ,sum(sql1.px_servers_execs_delta)            px_servers_execs
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  	and ( sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR  sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  	and ( sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR  sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.buffer_gets_delta) desc
  ) top_querys where rownum <= 15
;

set markup html off
prompt <h2 id="vnmsas_91jejfdjajfusj_823urjfsgunbieuw7rywfhsfnshshehfhs">
set define on
set termout on
prompt * Top querys physical reads  (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
prompt <p>
prompt Una nota importante al respecto. Las <b>physical reads</b> son el <b>Numero de bloques leidos</b>, no son las operaciones IO. En este sentido es muy diferente a la metrica de AWR <b>Uoptimized physical reads</b> que si se refiere al numero de operaciones I/O.
prompt <br>Se recomienda la lectura de la siguiente nota de MOS: 
prompt <br><i>How to Interpret the "SQL ordered by Physical Reads (UnOptimized)" Section in AWR Reports (11.2 onwards) for Smart Flash Cache Database (Doc ID 1466035.1)</i>
prompt </p>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0	
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
					,disk_reads value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  						,sum(sql1.disk_reads_delta)                disk_reads
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						and (sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') )
  						and (sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') )
 					having sum(sql1.executions_delta) > 0  
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.disk_reads_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% sql_id physical reads</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes        
,invalidations
,iowait
,javexec_time
,loads
,parse_calls
,plsexec_time
,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  ,sum(sql1.invalidations_delta)               invalidations
  ,sum(sql1.iowait_delta)                      iowait
  ,sum(sql1.javexec_time_delta)                javexec_time
  ,sum(sql1.loads_delta)                       loads
  ,sum(sql1.parse_calls_delta)                 parse_calls
  ,sum(sql1.plsexec_time_delta)               plsexec_time
  ,sum(sql1.px_servers_execs_delta)            px_servers_execs
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  and ( sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') )
  and ( sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') )
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.disk_reads_delta) desc
  ) top_querys where rownum <= 15
;




set markup html off
prompt <h2 id="hahayda71yIIuajsbxvqrEyajs813jdPdadpapdidJhahdydqy2hdhdh">
set define on
set termout on
prompt * Top querys UNOPTIMIZED Physical reads  (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
prompt <p>
prompt Estas lecturas son las que se realizan fuera de las <b>smart flash cache</b> de Exadata, por lo que requieren ser revisadas siempre.
prompt <br>Una nota importante al respecto. Las <b>physical reads</b> son el <b>Numero de bloques leidos</b>, no son las operaciones IO. En este sentido es muy diferente a la metrica de AWR <b>Uoptimized physical reads</b> que si se refiere al numero de operaciones I/O.
prompt <br>Se recomienda la lectura de la siguiente nota de MOS: 
prompt <br><i>How to Interpret the "SQL ordered by Physical Reads (UnOptimized)" Section in AWR Reports (11.2 onwards) for Smart Flash Cache Database (Doc ID 1466035.1)</i>
prompt </p>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
                    ,value value
                    from (
                    SELECT /*+ RULE */
                          sql1.sql_id                            sql_id
                          ,sql1.plan_hash_value                   plan_hash_value
                          ,sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta)                value
                    FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
                    WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
                          and (sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
                          and (sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                     having sum(sql1.executions_delta) > 0  
                    group by  sql1.sql_id,sql1.plan_hash_value                  
                      -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
                      order by sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta) desc
                      ) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% sql_id UNOPTIMIZED physical reads</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,physical_read_requests_delta
,physical_read_requests_exec
,optimized_physical_reads_delta
,optimized_physical_reads_exec
,UNoptim_physical_reads_delta
,Unoptim_physical_reads_exec
--,sorts        
--,fetches
--,direct_writes        
--,invalidations
,iowait
,javexec_time
,loads
,parse_calls
--,plsexec_time
--,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
    ,sum(sql1.physical_read_requests_delta)      physical_read_requests_delta
  ,round(sum(sql1.physical_read_requests_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) physical_read_requests_exec
  ,sum(sql1.optimized_physical_reads_delta)    optimized_physical_reads_delta
  ,round(sum(sql1.optimized_physical_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) optimized_physical_reads_exec
  ,sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta)    UNoptim_physical_reads_delta
  ,round((sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta)) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) Unoptim_physical_reads_exec
  --,sum(sql1.sorts_delta)                       sorts        
  --,sum(sql1.fetches_delta)                     fetches
  --,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  --,sum(sql1.invalidations_delta)               invalidations
  ,sum(sql1.iowait_delta)                      iowait
  ,sum(sql1.javexec_time_delta)                javexec_time
  ,sum(sql1.loads_delta)                       loads
  ,sum(sql1.parse_calls_delta)                 parse_calls
  --,sum(sql1.plsexec_time_delta)               plsexec_time
  --,sum(sql1.px_servers_execs_delta)            px_servers_execs
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  and (sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  and (sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta) desc
  ) top_querys where rownum <= 15
;



set markup html off
prompt <h2 id="1828djahdh__jfhah17ehHHdgabsy1dOOiuahdhcb12d__jahbh1hed">
set define on
set termout on
prompt * Top querys IO WAITS   (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
                    -- aqui se debe indicar la columna a graficar
                    -- no  la cambiar la palabra llamada metrica ni value
					,metrica value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  					-- aqui se debe indicar la columna a graficar
  					-- no  la cambiar la palabra llamada metrica
  						,sum(round(sql1.iowait_delta/1000000,2))                metrica
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						and (sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  						and (sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
 					having sum(sql1.executions_delta) > 0  
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Aqui se debe ordenar la columna a graficar (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.iowait_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% sql_id IO waits</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )  
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes        
,invalidations
,IOWAIT_TIME_S
,IOWAIT_TIME_X_EXEC_MS
,javexec_time
,loads
,parse_calls
,plsexec_time
,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  ,sum(sql1.invalidations_delta)               invalidations
  ,sum(round(sql1.iowait_delta/1000000,2))                "IOWAIT_TIME_S"
  ,round(sum(sql1.iowait_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2)  "IOWAIT_TIME_X_EXEC_MS"  
  ,sum(sql1.javexec_time_delta)                javexec_time
  ,sum(sql1.loads_delta)                       loads
  ,sum(sql1.parse_calls_delta)                 parse_calls
  ,sum(sql1.plsexec_time_delta)               plsexec_time
  ,sum(sql1.px_servers_execs_delta)            px_servers_execs
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  and ( sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  and ( sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.iowait_delta) desc
  ) top_querys where rownum <= 15
;




set markup html off
prompt <h2 id="201902191746">
set define on
set termout on
prompt * Top querys IO_OFFLOAD_ELIG_BYTES   (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
                    -- aqui se debe indicar la columna a graficar
                    -- no  la cambiar la palabra llamada metrica ni value
					,metrica value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  					-- aqui se debe indicar la columna a graficar
  					-- no  la cambiar la palabra llamada metrica
  						,sum(sql1.io_offload_elig_bytes_delta)                metrica
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						and (sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  						and (sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
 					having sum(sql1.executions_delta) > 0  
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Aqui se debe ordenar la columna a graficar (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.io_offload_elig_bytes_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% io_offload_elig</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )  
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes
  ,IO_OFFLOAD_ELIG_MB
  ,IO_OFFLOAD_ELIG_BYTES_XEXEC
  ,IO_OFFLOAD_RETURN_MB
  ,IO_OFFLOAD_RETURN_BYTES_XEXEC
  ,IO_INTERCONNECT_MB
  ,IO_INTERCONNECT_BYTES_XEXEC
  ,CELL_UNCOMPRESSED_MB
  ,CELL_UNCOMPRESSED_BYTES_XEXEC
--,invalidations
--,IOWAIT_TIME_S
--,IOWAIT_TIME_X_EXEC_MS
--,javexec_time
--,loads
--,parse_calls
--,plsexec_time
--,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  --,sum(sql1.invalidations_delta)               invalidations
  --,sum(round(sql1.iowait_delta/1000000,2))                "IOWAIT_TIME_S"
  --,round(sum(sql1.iowait_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2)  "IOWAIT_TIME_X_EXEC_MS"  
  --,sum(sql1.javexec_time_delta)                javexec_time
  --,sum(sql1.loads_delta)                       loads
  --,sum(sql1.parse_calls_delta)                 parse_calls
  --,sum(sql1.plsexec_time_delta)               plsexec_time
  --,sum(sql1.px_servers_execs_delta)            px_servers_execs
  ,round(sum(sql1.io_offload_elig_bytes_delta)/1024/1024,2)       "IO_OFFLOAD_ELIG_MB"
  ,round(sum(sql1.io_offload_elig_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_OFFLOAD_ELIG_BYTES_XEXEC"
  ,round(sum(sql1.io_offload_return_bytes_delta)/1024/1024,2)     "IO_OFFLOAD_RETURN_MB"
  ,round(sum(sql1.io_offload_return_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_OFFLOAD_RETURN_BYTES_XEXEC"
  ,round(sum(sql1.io_interconnect_bytes_delta)/1024/1024,2)       "IO_INTERCONNECT_MB"
  ,round(sum(sql1.io_interconnect_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_INTERCONNECT_BYTES_XEXEC"
  ,round(sum(sql1.cell_uncompressed_bytes_delta)/1024/1024,2)     "CELL_UNCOMPRESSED_MB"
  ,round(sum(sql1.cell_uncompressed_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "CELL_UNCOMPRESSED_BYTES_XEXEC"
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  and ( sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  and ( sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi')) 
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.io_offload_elig_bytes_delta) desc
  ) top_querys where rownum <= 15
;



set markup html off
prompt <h2 id="201902191754">
set define on
set termout on
prompt * Top querys IO_OFFLOAD_RETURN_BYTES   (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
                    -- aqui se debe indicar la columna a graficar
                    -- no  la cambiar la palabra llamada metrica ni value
					,metrica value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  					-- aqui se debe indicar la columna a graficar
  					-- no  la cambiar la palabra llamada metrica
  						,sum(sql1.io_offload_return_bytes_delta)                metrica
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						and ( sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  						and ( sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
 					having sum(sql1.executions_delta) > 0  
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Aqui se debe ordenar la columna a graficar (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.io_offload_return_bytes_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% io_offload_return</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )  
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes
  ,IO_OFFLOAD_ELIG_MB
  ,IO_OFFLOAD_ELIG_BYTES_XEXEC
  ,IO_OFFLOAD_RETURN_MB
  ,IO_OFFLOAD_RETURN_BYTES_XEXEC
  ,IO_INTERCONNECT_MB
  ,IO_INTERCONNECT_BYTES_XEXEC
  ,CELL_UNCOMPRESSED_MB
  ,CELL_UNCOMPRESSED_BYTES_XEXEC
--,invalidations
--,IOWAIT_TIME_S
--,IOWAIT_TIME_X_EXEC_MS
--,javexec_time
--,loads
--,parse_calls
--,plsexec_time
--,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  --,sum(sql1.invalidations_delta)               invalidations
  --,sum(round(sql1.iowait_delta/1000000,2))                "IOWAIT_TIME_S"
  --,round(sum(sql1.iowait_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2)  "IOWAIT_TIME_X_EXEC_MS"  
  --,sum(sql1.javexec_time_delta)                javexec_time
  --,sum(sql1.loads_delta)                       loads
  --,sum(sql1.parse_calls_delta)                 parse_calls
  --,sum(sql1.plsexec_time_delta)               plsexec_time
  --,sum(sql1.px_servers_execs_delta)            px_servers_execs
  ,round(sum(sql1.io_offload_elig_bytes_delta)/1024/1024,2)       "IO_OFFLOAD_ELIG_MB"
  ,round(sum(sql1.io_offload_elig_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_OFFLOAD_ELIG_BYTES_XEXEC"
  ,round(sum(sql1.io_offload_return_bytes_delta)/1024/1024,2)     "IO_OFFLOAD_RETURN_MB"
  ,round(sum(sql1.io_offload_return_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_OFFLOAD_RETURN_BYTES_XEXEC"
  ,round(sum(sql1.io_interconnect_bytes_delta)/1024/1024,2)       "IO_INTERCONNECT_MB"
  ,round(sum(sql1.io_interconnect_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_INTERCONNECT_BYTES_XEXEC"
  ,round(sum(sql1.cell_uncompressed_bytes_delta)/1024/1024,2)     "CELL_UNCOMPRESSED_MB"
  ,round(sum(sql1.cell_uncompressed_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "CELL_UNCOMPRESSED_BYTES_XEXEC"
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  and ( sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') )
  and ( sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') )
 having sum(sql1.executions_delta) > 0
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.io_offload_return_bytes_delta) desc
  ) top_querys where rownum <= 15
;





set markup html off
prompt <h2 id="201902191757">
set define on
set termout on
prompt * Top querys IO_INTERCONNECT_BYTES   (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
                    -- aqui se debe indicar la columna a graficar
                    -- no  la cambiar la palabra llamada metrica ni value
					,metrica value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  					-- aqui se debe indicar la columna a graficar
  					-- no  la cambiar la palabra llamada metrica
  						,sum(sql1.io_interconnect_bytes_delta)                metrica
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						and ( sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  						and ( sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
 					having sum(sql1.executions_delta) > 0  
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Aqui se debe ordenar la columna a graficar (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.io_interconnect_bytes_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% io_interconnect_bytes</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )  
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes
  ,IO_OFFLOAD_ELIG_MB
  ,IO_OFFLOAD_ELIG_BYTES_XEXEC
  ,IO_OFFLOAD_RETURN_MB
  ,IO_OFFLOAD_RETURN_BYTES_XEXEC
  ,IO_INTERCONNECT_MB
  ,IO_INTERCONNECT_BYTES_XEXEC
  ,CELL_UNCOMPRESSED_MB
  ,CELL_UNCOMPRESSED_BYTES_XEXEC
--,invalidations
--,IOWAIT_TIME_S
--,IOWAIT_TIME_X_EXEC_MS
--,javexec_time
--,loads
--,parse_calls
--,plsexec_time
--,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  --,sum(sql1.invalidations_delta)               invalidations
  --,sum(round(sql1.iowait_delta/1000000,2))                "IOWAIT_TIME_S"
  --,round(sum(sql1.iowait_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2)  "IOWAIT_TIME_X_EXEC_MS"  
  --,sum(sql1.javexec_time_delta)                javexec_time
  --,sum(sql1.loads_delta)                       loads
  --,sum(sql1.parse_calls_delta)                 parse_calls
  --,sum(sql1.plsexec_time_delta)               plsexec_time
  --,sum(sql1.px_servers_execs_delta)            px_servers_execs
  ,round(sum(sql1.io_offload_elig_bytes_delta)/1024/1024,2)       "IO_OFFLOAD_ELIG_MB"
  ,round(sum(sql1.io_offload_elig_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_OFFLOAD_ELIG_BYTES_XEXEC"
  ,round(sum(sql1.io_offload_return_bytes_delta)/1024/1024,2)     "IO_OFFLOAD_RETURN_MB"
  ,round(sum(sql1.io_offload_return_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_OFFLOAD_RETURN_BYTES_XEXEC"
  ,round(sum(sql1.io_interconnect_bytes_delta)/1024/1024,2)       "IO_INTERCONNECT_MB"
  ,round(sum(sql1.io_interconnect_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_INTERCONNECT_BYTES_XEXEC"
  ,round(sum(sql1.cell_uncompressed_bytes_delta)/1024/1024,2)     "CELL_UNCOMPRESSED_MB"
  ,round(sum(sql1.cell_uncompressed_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "CELL_UNCOMPRESSED_BYTES_XEXEC"
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  and ( sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  and ( sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.io_interconnect_bytes_delta) desc
  ) top_querys where rownum <= 15
;





set markup html off
prompt <h2 id="201902191759">
set define on
set termout on
prompt * Top querys CELL_UNCOMPRESSED_BYTES   (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (
                    select /*+ MATERIALIZE */ sql_id ||'' plan:'' ||plan_hash_value stat_name
                    -- aqui se debe indicar la columna a graficar
                    -- no  la cambiar la palabra llamada metrica ni value
					,metrica value
					from (
					SELECT /*+ RULE */
  						sql1.sql_id                            sql_id
  						,sql1.plan_hash_value                   plan_hash_value
  					-- aqui se debe indicar la columna a graficar
  					-- no  la cambiar la palabra llamada metrica
  						,sum(sql1.cell_uncompressed_bytes_delta)                metrica
					FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
					WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  						and ( sn.begin_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  						and ( sn.begin_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR sn.end_interval_time <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
 					having sum(sql1.executions_delta) > 0  
					group by  sql1.sql_id,sql1.plan_hash_value                  
  					-- Aqui se debe ordenar la columna a graficar (ejemplo cputime,elapsedtime,lecturas,etc)
  					order by sum(sql1.cell_uncompressed_bytes_delta) desc
  					) top_querys where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">% cell_uncompressed</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )  
FROM dual;
set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20

set define on
select sql_id
,plan_hash_value
,modulo_programa_o_aplicativo
,optimizer_mode
,SQL_PROFILE
,PARSING_SCHEMA_NAME
,KB_SHARABLE_MEM
,executions
,rows_processed
,rows_processed_x_exec
,ELAPSED_TIME_S
,ELAPSED_TIME_X_EXEC_MS
,CPU_TIME_S
,CPU_TIME_X_EXEC_MS        
,buffer_gets
,buffer_gets_x_exec
,disk_reads
,disk_reads_x_exec
,sorts        
,fetches
,direct_writes
  ,IO_OFFLOAD_ELIG_MB
  ,IO_OFFLOAD_ELIG_BYTES_XEXEC
  ,IO_OFFLOAD_RETURN_MB
  ,IO_OFFLOAD_RETURN_BYTES_XEXEC
  ,IO_INTERCONNECT_MB
  ,IO_INTERCONNECT_BYTES_XEXEC
  ,CELL_UNCOMPRESSED_MB
  ,CELL_UNCOMPRESSED_BYTES_XEXEC
--,invalidations
--,IOWAIT_TIME_S
--,IOWAIT_TIME_X_EXEC_MS
--,javexec_time
--,loads
--,parse_calls
--,plsexec_time
--,px_servers_execs 
,(select dbms_lob.substr(sql_text,80,1) from DBA_HIST_SQLTEXT where sql_id = top_querys.sql_id AND dbid = top_querys.dbid and rownum = 1) sql_text
from (
SELECT /*+ RULE */
  sql1.sql_id                            sql_id
  ,sql1.dbid                            dbid
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            modulo_programa_o_aplicativo
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions
  ,sum(sql1.rows_processed_delta)              rows_processed
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_processed_x_exec
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ELAPSED_TIME_S"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ELAPSED_TIME_X_EXEC_MS"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_S"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_MS"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec
  ,sum(sql1.sorts_delta)                       sorts        
  ,sum(sql1.fetches_delta)                     fetches
  ,sum(sql1.direct_writes_delta)               direct_writes        
  --,sum(sql1.apwait_delta)                     apwait
  --,sum(sql1.ccwait_delta)                      ccwait
  --,sum(sql1.clwait_delta)                      clwait
  --,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count
  --,sum(sql1.invalidations_delta)               invalidations
  --,sum(round(sql1.iowait_delta/1000000,2))                "IOWAIT_TIME_S"
  --,round(sum(sql1.iowait_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2)  "IOWAIT_TIME_X_EXEC_MS"  
  --,sum(sql1.javexec_time_delta)                javexec_time
  --,sum(sql1.loads_delta)                       loads
  --,sum(sql1.parse_calls_delta)                 parse_calls
  --,sum(sql1.plsexec_time_delta)               plsexec_time
  --,sum(sql1.px_servers_execs_delta)            px_servers_execs
  ,round(sum(sql1.io_offload_elig_bytes_delta)/1024/1024,2)       "IO_OFFLOAD_ELIG_MB"
  ,round(sum(sql1.io_offload_elig_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_OFFLOAD_ELIG_BYTES_XEXEC"
  ,round(sum(sql1.io_offload_return_bytes_delta)/1024/1024,2)     "IO_OFFLOAD_RETURN_MB"
  ,round(sum(sql1.io_offload_return_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_OFFLOAD_RETURN_BYTES_XEXEC"
  ,round(sum(sql1.io_interconnect_bytes_delta)/1024/1024,2)       "IO_INTERCONNECT_MB"
  ,round(sum(sql1.io_interconnect_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "IO_INTERCONNECT_BYTES_XEXEC"
  ,round(sum(sql1.cell_uncompressed_bytes_delta)/1024/1024,2)     "CELL_UNCOMPRESSED_MB"
  ,round(sum(sql1.cell_uncompressed_bytes_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta))  ,2) "CELL_UNCOMPRESSED_BYTES_XEXEC"
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  and ( sn.begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  and ( sn.begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by  
   sql1.sql_id                            
  ,sql1.module                                           
  ,sql1.dbid                                                 
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  -- Se ordenara por la columna top (ejemplo cputime,elapsedtime,lecturas,etc)
  order by sum(sql1.cell_uncompressed_bytes_delta) desc
  ) top_querys where rownum <= 15
;



set markup html off
prompt <h2 id="Crecimientodelabasededatos__dh50912eyds">
set termout on
prompt * Crecimiento ultimo periodo de tiempo (ultimos 180 dias)
set termout off
prompt </h2>
prompt <p>(ERROR EN EL GRAFICO NO TOMAR EN CUENTA EL CHART)</p>

SET LINESIZE      1000
SET LONGCHUNKSIZE 30000
SET LONG          30000
SET FEEDBACK OFF
SET VERIFY   OFF
SET PAGESIZE 0
SET DEFINE OFF
SET HEADING OFF
set serveroutput on size unlimited


SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      ('
	  with group1 as (select /*+ materialize parallel(t,2) ordered */
		   to_char(s.begin_interval_time,''yyyymmdd'') get_date,
		   --v.name ts_name,
		--(round(max((t.tablespace_size*d.block_size))/1024/1024/1024,2)) size_gb,
		(round(max((tablespace_usedsize*d.block_size))/1024/1024/1024,2)) used_gb
		from
		   dba_hist_tbspc_space_usage t,
		   v$tablespace               v,
		   dba_hist_snapshot          s,
		   dba_tablespaces            d
		where
		   t.tablespace_id=v.ts#
		AND v.name=d.tablespace_name and d.contents = ''PERMANENT''
		and
		   t.snap_id=s.snap_id
		 and (s.begin_interval_time > sysdate - 60 OR s.end_interval_time > sysdate - 60)
		group by to_char(s.begin_interval_time,''yyyymmdd'')
		)
		select
		   to_char(to_date(get_date,''yyyymmdd''),''dd/mm'') BEGIN_TIME
		   ,''Tamano real utilizado (DBA_SEGMENTS)'' METRIC_NAME
		   ,''Crecimiento en GB'' METRIC_UNIT
		   ,sum(used_gb) YVAL
		   ,MIN(greatest((select min(used_gb) from group1),0)) YVAL_MIN
		   ,MAX(greatest((select max(used_gb) from group1),1)) YVAL_MAX
		from
		   group1
		group by get_date
		--,ts_name
		order by get_date asc
	  ')
,      XMLTYPE.CREATEXML
   (TO_CLOB(
    '<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">40</xsl:variable>
     <xsl:variable name="bar_width">5</xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="315+$margin_left"/></xsl:variable>
     <xsl:variable name="graph_height"><xsl:value-of select="100+$margin_top+$margin_bottom"/></xsl:variable>
     <xsl:variable name="graph_name"><xsl:value-of select="/descendant::METRIC_NAME[position()=1]"/></xsl:variable>
     <xsl:variable name="graph_unit"><xsl:value-of select="/descendant::METRIC_UNIT[position()=1]"/></xsl:variable>
     <xsl:variable name="yval_max"><xsl:value-of select="/descendant::YVAL_MAX[position()=1]"/></xsl:variable>
     <xsl:variable name="yval_min"><xsl:value-of select="/descendant::YVAL_MIN[position()=1]"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_height}">
           <text x="{$margin_left+1}" y="{($margin_top)-5}" style="fill: #000000; stroke: none;font-size:10px;text-anchor=start"><xsl:value-of select="$graph_name"/></text>
           <text x="{($margin_bottom)-($graph_height)}" y="10" transform="rotate(-90)" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="$graph_unit"/></text>
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-0}"   x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-0}"  style="stroke:lavender;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-25}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-25}" style="stroke:lavender;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-50}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-50}" style="stroke:lavender;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-75}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-75}" style="stroke:lavender;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-100}" x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lavender;stroke-width:1" />
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-2}"   style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round($yval_min)"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-25}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+(1*(($yval_max)-($yval_min)) div 4))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-50}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+((($yval_max)-($yval_min)) div 2))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-75}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+(3*(($yval_max)-($yval_min)) div 4))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-100}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round($yval_max)"/></text>
           <line x1="{$margin_left}" y1="{($graph_height)-($margin_bottom)}" x2="{$margin_left}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lavender;stroke-width:1" />'
           )
    ||
    TO_CLOB(
          '<xsl:for-each select="ROWSET/ROW/BEGIN_TIME">
             <xsl:choose>
               <xsl:when test="(position()-1) mod 5=0">
                 <text x="{($margin_left)-9+($bar_width*(position()-1))}" y="{($graph_height)-($margin_bottom)+12}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start" ><xsl:value-of select="self::node()"/></text>
                 <line x1="{($margin_left)+($bar_width*(position()-1))}" y1="{($graph_height)-($margin_bottom)+4}" x2="{($margin_left)+($bar_width*(position()-1))}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lavender;stroke-width:1" />
               </xsl:when>
             </xsl:choose>
           </xsl:for-each>
           <xsl:variable name="v_path">
             <xsl:for-each select="ROWSET/ROW/YVAL">
               <xsl:variable name="x_val">
                 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
               </xsl:variable>
               <xsl:variable name="y_val">
                 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
               </xsl:variable>
               <xsl:value-of select="concat($x_val,'','',$y_val,'' '')"/>
             </xsl:for-each>
           </xsl:variable>
           <polyline points="{$v_path}" style="fill:none;stroke:blue;stroke-width:1" />
         </svg>
       </xsl:template>
     </xsl:stylesheet>'
           )
   )
   )
FROM dual;



set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20


 with group1 as (select /*+ materialize parallel(t,2) ordered */
   to_char(s.begin_interval_time,'yyyymmdd') get_date,
   v.name ts_name,
(round(max((t.tablespace_size*d.block_size))/1024/1024/1024,2)) size_gb,
(round(max((tablespace_usedsize*d.block_size))/1024/1024/1024,2)) used_gb
from
   dba_hist_tbspc_space_usage t,
   v$tablespace               v,
   dba_hist_snapshot          s,
   dba_tablespaces            d
where
   t.tablespace_id=v.ts#
AND v.name=d.tablespace_name  and d.contents = 'PERMANENT'
and
   t.snap_id=s.snap_id
 and ( s.begin_interval_time > sysdate - 180 OR s.end_interval_time > sysdate - 180)
group by to_char(s.begin_interval_time,'yyyymmdd'), v.name)
select
   get_date datetime,
   --ts_name tablespace_name,
   sum(size_gb) total_alloc_gb,
   sum(used_gb) real_utilizado_gb
from
   group1
group by get_date
--,ts_name
order by get_date desc;



set markup html off
prompt <h2 id="Crecimientodelabasededatos__fhsyrywqteGcbsg14Tknjsu">
set define on
set termout on
prompt * Crecimiento BD periodo seleccionado no undo ni temp (para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
prompt * (ERROR EN EL GRAFICO NO TOMAR EN CUENTA EL CHART)
set termout off
prompt </h2>


SET LINESIZE      1000
SET LONGCHUNKSIZE 30000
SET LONG          30000
SET FEEDBACK OFF
SET VERIFY   OFF
SET PAGESIZE 0
SET DEFINE OFF
SET HEADING OFF
set serveroutput on size unlimited

set define on

SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      ('
	  with group1 as (select /*+ materialize parallel(t,2) ordered */
		   to_char(s.begin_interval_time,''yyyymmddhh24mi'') get_date,
		   --v.name ts_name,
		--(round(max((t.tablespace_size*d.block_size))/1024/1024/1024,2)) size_gb,
		(round(max((tablespace_usedsize*d.block_size))/1024/1024/1024,2)) used_gb
		from
		   dba_hist_tbspc_space_usage t,
		   v$tablespace               v,
		   dba_hist_snapshot          s,
		   dba_tablespaces            d
		where
		   t.tablespace_id=v.ts#
		AND v.name=d.tablespace_name and d.contents = ''PERMANENT''
		and
		   t.snap_id=s.snap_id
		 --and s.begin_interval_time > sysdate - 60
		 and ( s.BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR s.END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  		 and ( s.BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR s.END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
		group by to_char(s.begin_interval_time,''yyyymmddhh24mi'')
		)
		select
		   to_char(to_date(get_date,''yyyymmddhh24mi''),''hh24:mi'') BEGIN_TIME
		   ,''Tamano real utilizado (DBA_SEGMENTS)'' METRIC_NAME
		   ,''Crecimiento en GB'' METRIC_UNIT
		   ,sum(used_gb) YVAL
		   ,MIN(greatest((select min(used_gb) from group1),0)) YVAL_MIN
		   ,MAX(greatest((select max(used_gb) from group1),1)) YVAL_MAX
		from
		   group1
		group by get_date
		--,ts_name
		order by get_date asc
	  ')
,      XMLTYPE.CREATEXML
   (TO_CLOB(
    '<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">40</xsl:variable>
     <xsl:variable name="bar_width">5</xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="315+$margin_left"/></xsl:variable>
     <xsl:variable name="graph_height"><xsl:value-of select="100+$margin_top+$margin_bottom"/></xsl:variable>
     <xsl:variable name="graph_name"><xsl:value-of select="/descendant::METRIC_NAME[position()=1]"/></xsl:variable>
     <xsl:variable name="graph_unit"><xsl:value-of select="/descendant::METRIC_UNIT[position()=1]"/></xsl:variable>
     <xsl:variable name="yval_max"><xsl:value-of select="/descendant::YVAL_MAX[position()=1]"/></xsl:variable>
     <xsl:variable name="yval_min"><xsl:value-of select="/descendant::YVAL_MIN[position()=1]"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_height}">
           <text x="{$margin_left+1}" y="{($margin_top)-5}" style="fill: #000000; stroke: none;font-size:10px;text-anchor=start"><xsl:value-of select="$graph_name"/></text>
           <text x="{($margin_bottom)-($graph_height)}" y="10" transform="rotate(-90)" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="$graph_unit"/></text>
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-0}"   x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-0}"  style="stroke:lavender;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-25}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-25}" style="stroke:lavender;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-50}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-50}" style="stroke:lavender;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-75}"  x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-75}" style="stroke:lavender;stroke-width:1" />
           <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-100}" x2="{($graph_width)-1}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lavender;stroke-width:1" />
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-2}"   style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round($yval_min)"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-25}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+(1*(($yval_max)-($yval_min)) div 4))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-50}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+((($yval_max)-($yval_min)) div 2))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-75}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+(3*(($yval_max)-($yval_min)) div 4))"/></text>
           <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-100}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round($yval_max)"/></text>
           <line x1="{$margin_left}" y1="{($graph_height)-($margin_bottom)}" x2="{$margin_left}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lavender;stroke-width:1" />'
           )
    ||
    TO_CLOB(
          '<xsl:for-each select="ROWSET/ROW/BEGIN_TIME">
             <xsl:choose>
               <xsl:when test="(position()-1) mod 5=0">
                 <text x="{($margin_left)-9+($bar_width*(position()-1))}" y="{($graph_height)-($margin_bottom)+12}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start" ><xsl:value-of select="self::node()"/></text>
                 <line x1="{($margin_left)+($bar_width*(position()-1))}" y1="{($graph_height)-($margin_bottom)+4}" x2="{($margin_left)+($bar_width*(position()-1))}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lavender;stroke-width:1" />
               </xsl:when>
             </xsl:choose>
           </xsl:for-each>
           <xsl:variable name="v_path">
             <xsl:for-each select="ROWSET/ROW/YVAL">
               <xsl:variable name="x_val">
                 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
               </xsl:variable>
               <xsl:variable name="y_val">
                 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
               </xsl:variable>
               <xsl:value-of select="concat($x_val,'','',$y_val,'' '')"/>
             </xsl:for-each>
           </xsl:variable>
           <polyline points="{$v_path}" style="fill:none;stroke:blue;stroke-width:1" />
         </svg>
       </xsl:template>
     </xsl:stylesheet>'
           )
   )
   )
FROM dual;






set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20


 with group1 as (select /*+ materialize parallel(t,2) ordered */
   to_char(s.begin_interval_time,'yyyymmdd hh24:mi') get_date,
   v.name ts_name,
(round(max((t.tablespace_size*d.block_size))/1024/1024/1024,2)) size_gb,
(round(max((tablespace_usedsize*d.block_size))/1024/1024/1024,2)) used_gb
from
   dba_hist_tbspc_space_usage t,
   v$tablespace               v,
   dba_hist_snapshot          s,
   dba_tablespaces            d
where
   t.tablespace_id=v.ts#
AND v.name=d.tablespace_name  and d.contents = 'PERMANENT'
and
   t.snap_id=s.snap_id
 and (s.begin_interval_time > sysdate - 2 OR s.end_interval_time > sysdate - 2 )
group by to_char(s.begin_interval_time,'yyyymmdd hh24:mi'), v.name)
select
   get_date datetime,
   --ts_name tablespace_name,
   sum(size_gb) total_alloc_gb,
   sum(used_gb) real_utilizado_gb
from
   group1
group by get_date
--,ts_name
order by get_date desc;

--------------------------------------------------------------------------



set markup html off
prompt <h2 id="systime_model_ajsjd1832jBfjof93Hfuey67sj">
set termout on
prompt * SYS_TIME_MODEL analisis (24 Hrs)
set termout off
prompt </h2>
set markup html on

prompt http://blog.orapub.com/20140805/what-is-oracle-db-time-db-cpu-wall-time-and-non-idle-wait-time.html
prompt 
prompt We have enough detail to relate DB Time, DB CPU and non-idle wait time together... using a little math.
prompt DB Time = DB CPU + non_idle_wait_time
prompt And of course,
prompt non_idle_wait_time = DB Time - DB CPU



set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF

declare
	v_contenido xmltype;
begin
 FOR instancia IN (SELECT INST_ID,instance_name from GV$instance order by INST_ID )
  LOOP
    BEGIN
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '
	  with grafico as
                    (select /*+ MATERIALIZE */ * from
                    (select stat_name
                    , round(sum(value_delta)/1000000,2) value
                     --,rank() over (partition by stat_name order by sum(value_delta) desc) as    value_delta_rank
                     from
                    (select  --stm.snap_id,
                    s.begin_interval_time
                    ,stat_name
                    --,value
                     --,LAG(value, 1, 0) OVER (ORDER BY stm.snap_id ) AS value_prev
                     ,value - LAG(value, 1, 0) OVER (partition by stat_name ORDER BY stm.snap_id ) AS value_delta
                      from dba_hist_sys_time_model stm, dba_hist_snapshot s
                    where stm.snap_id = s.snap_id
					and stm.instance_number = '||instancia.inst_id||'
                    order by stm.snap_id, stat_name
                    ) where (begin_interval_time > sysdate -1 )--OR end_interval_time > sysdate -1)
                    group by stat_name
                    order by 2 desc
                ) where rownum <= 15
                )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''green'',2,''yellow''
              ,3,''blue'',4,''orange''
              ,5,''red'',6,''grey''
              ,7,''lightgreen'',8,''lightyellow''
              ,9,''lightred'',10,''lightorange''
              ,11,''lightblue'',12,''lightgrey''
               ,13,''darkblue'',14,''darkgrey''
                ,15,''darkblue'',16,''darkgrey''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico
                ) sum_value
             FROM grafico
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">150</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">[Instancia: '||instancia.instance_name||'] Clasificacion de de Systime model (ultimas 24hrs)</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   ) into v_contenido from dual;
		dbms_output.put_line(v_contenido.getClobVal);

		end;
	end loop;
end;
/


set markup html on
set heading on
set feedback on
set pagesize 20

select (select instance_name from GV$instance where inst_id = s.instance_number ) instance,stat_name,round(sum(value_diff)/1000000,2) "value_sum_seg."
from
(
select  --stm.snap_id
    sn.begin_interval_time
    --sn.snap_id
    ,stm1.instance_number
    ,stm1.stat_name
     --,stm1.value value_new
     --,stm2.value value_old
     ,greatest(stm1.value  - stm2.value,0) value_diff
      from dba_hist_sys_time_model stm1, dba_hist_sys_time_model stm2, dba_hist_snapshot sn
    WHERE sn.snap_id  =stm1.snap_id AND   sn.dbid=stm1.dbid AND   sn.instance_number=stm1.instance_number
  AND   sn.snap_id-1=stm2.snap_id AND   sn.dbid=stm2.dbid AND   sn.instance_number=stm2.instance_number
  and      stm1.stat_name = stm2.stat_name
    --order by 4 desc
    ) s where (begin_interval_time > sysdate -1 OR end_interval_time > sysdate -1)
    group by instance_number,stat_name
   order by 3 desc
   ;


---------------------------------------------------------------------------
set markup html off
prompt <h2 id="Objetostopenlecturaslogicas_HvnbfhThduwj58712Pmv">
set define on
set termout on
prompt * Top obj. lecturas logicas (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on


-- lecturas logicas
set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (select /*+ MATERIALIZE */ * from (
                      -- el campo dhsso.subobject_name es por si se trata de una tabla particionada 
                    select dhsso.object_name||nvl2(dhsso.subobject_name,'':''||dhsso.subobject_name,'''') stat_name
                    ,sum(LOGICAL_READS_DELTA) value
                    from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
                    where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                    					where   
                    						(BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  										and (BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                    			)
                          and dhsso.obj# = dhss.obj# 
                    group by dhsso.object_name,dhsso.subobject_name     
                      order by sum(LOGICAL_READS_DELTA) desc
                      ) where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">Objects % logical reads</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;



set markup html on

set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20
set define on

with top_objects as (select /*+ MATERIALIZE */
 dhsso.object_name object_name,dhsso.object_type,dhsso.owner,dhsso.subobject_name
,sum(LOGICAL_READS_DELTA) LOGICAL_READS
,sum(PHYSICAL_READS_DELTA) PHYSICAL_READS
,sum(DB_BLOCK_CHANGES_DELTA) DB_BLOCK_CHANGES
--,sum(TABLE_SCANS_DELTA) TABLE_SCANS
--,sum(ROW_LOCK_WAITS_DELTA) ROW_LOCK_WAITS
,sum(PHYSICAL_WRITES_DELTA) PHYSICAL_WRITES
--,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
,rank() over (partition by dhsso.object_name order by sum(LOGICAL_READS_DELTA) desc) as    LOGICAL_READS_rank
--,rank() over (partition by dhsso.object_name order by sum(PHYSICAL_READS_DELTA) desc) as    PHYSICAL_READS_rank
from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
where snap_id IN (select SNAP_ID from dba_hist_snapshot 
					  where 
					  		(BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  						and (BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
					)
      and dhsso.obj# = dhss.obj# --and dhsso.object_type = 'TABLE'
group by dhsso.object_name,dhsso.object_type,dhsso.owner,dhsso.subobject_name
)
select object_name,object_type,owner,subobject_name,to_char(LOGICAL_READS) LOGICAL_READS,to_char(PHYSICAL_READS) PHYSICAL_READS,to_char(PHYSICAL_WRITES) PHYSICAL_WRITES,to_char(DB_BLOCK_CHANGES) DB_BLOCK_CHANGES,  round(ratio_to_report(logical_reads) over ()*100,1) "Lecturas_logicas_%" from
(select * from top_objects where LOGICAL_READS_rank <= 15  order by LOGICAL_READS desc)
where rownum <= 15
/



set markup html off
prompt <h2 id="Objetostopenlecturasfisicas_Jvnm258PmvbaEqrwtTre32">
set define on
set termout on
prompt * Top obj. lecturas fisicas (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on

-- lectura fisicas
set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (select /*+ MATERIALIZE */ * from (
                      -- el campo dhsso.subobject_name es por si se trata de una tabla particionada 
                    select dhsso.object_name||nvl2(dhsso.subobject_name,'':''||dhsso.subobject_name,'''') stat_name
                    ,sum(PHYSICAL_READS_DELTA) value
                    from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
                    where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                    					where   
                    						(BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  										and (BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                    			)
                          and dhsso.obj# = dhss.obj# 
                    group by dhsso.object_name,dhsso.subobject_name     
                      order by sum(PHYSICAL_READS_DELTA) desc
                      ) where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">Objects % physical reads</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;

set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20
set define on

with top_objects as (select /*+ MATERIALIZE */
 dhsso.object_name object_name,dhsso.object_type,dhsso.owner,dhsso.subobject_name
,sum(LOGICAL_READS_DELTA) LOGICAL_READS
,sum(PHYSICAL_READS_DELTA) PHYSICAL_READS
,sum(DB_BLOCK_CHANGES_DELTA) DB_BLOCK_CHANGES
--,sum(TABLE_SCANS_DELTA) TABLE_SCANS
--,sum(ROW_LOCK_WAITS_DELTA) ROW_LOCK_WAITS
,sum(PHYSICAL_WRITES_DELTA) PHYSICAL_WRITES
--,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
--,rank() over (partition by dhsso.object_name order by sum(LOGICAL_READS_DELTA) desc) as    LOGICAL_READS_rank
,rank() over (partition by dhsso.object_name order by sum(PHYSICAL_READS_DELTA) desc) as    PHYSICAL_READS_rank
from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
where snap_id IN (select SNAP_ID from dba_hist_snapshot 
					  where ( BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  						and ( BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
					)
      and dhsso.obj# = dhss.obj# --and dhsso.object_type = 'TABLE'
group by dhsso.object_name,dhsso.object_type,dhsso.owner,dhsso.subobject_name
)
select object_name,object_type,owner,subobject_name,to_char(LOGICAL_READS) LOGICAL_READS,to_char(PHYSICAL_READS) PHYSICAL_READS,to_char(PHYSICAL_WRITES) PHYSICAL_WRITES,to_char(DB_BLOCK_CHANGES) DB_BLOCK_CHANGES,  round(ratio_to_report(physical_reads) over ()*100,1) "Lecturas_fisicas_%" from
(select * from top_objects where PHYSICAL_READS_rank <=15 order by PHYSICAL_READS desc)
where rownum <= 15
/






set markup html off
prompt <h2 id="Objetostopenescrituras_hsdHbsdhsgassdsdsw2">
set define on
set termout on
prompt * Top obj. escrituras fisicas (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on
-- escrituras fisicas
set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (select /*+ MATERIALIZE */ * from (
                      -- el campo dhsso.subobject_name es por si se trata de una tabla particionada 
                    select dhsso.object_name||nvl2(dhsso.subobject_name,'':''||dhsso.subobject_name,'''') stat_name
                    ,sum(PHYSICAL_WRITES_DELTA) value
                    from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
                    where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                    					where   
                    						( BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  										and ( BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                    			)
                          and dhsso.obj# = dhss.obj# 
                    group by dhsso.object_name,dhsso.subobject_name     
                      order by sum(PHYSICAL_WRITES_DELTA) desc
                      ) where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">Objects % physical writes</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;

set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20
set define on

with top_objects as (select /*+ MATERIALIZE */
 dhsso.object_name object_name,dhsso.owner,dhsso.object_type,dhsso.subobject_name
,sum(LOGICAL_READS_DELTA) LOGICAL_READS
,sum(PHYSICAL_READS_DELTA) PHYSICAL_READS
,sum(DB_BLOCK_CHANGES_DELTA) DB_BLOCK_CHANGES
--,sum(TABLE_SCANS_DELTA) TABLE_SCANS
--,sum(ROW_LOCK_WAITS_DELTA) ROW_LOCK_WAITS
,sum(PHYSICAL_WRITES_DELTA) PHYSICAL_WRITES
--,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
--,rank() over (partition by dhsso.object_name order by sum(LOGICAL_READS_DELTA) desc) as    LOGICAL_READS_rank
,rank() over (partition by dhsso.object_name order by sum(PHYSICAL_WRITES_DELTA) desc) as    PHYSICAL_WRITES_rank
from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
where snap_id IN (select SNAP_ID from dba_hist_snapshot 
					  where 
					  		( BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  						and ( BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi')) 
				)
      and dhsso.obj# = dhss.obj# --and dhsso.object_type = 'TABLE'
group by dhsso.object_name,dhsso.owner,dhsso.object_type,dhsso.subobject_name
)
select object_name,object_type,owner,subobject_name,to_char(LOGICAL_READS) LOGICAL_READS,to_char(PHYSICAL_READS) PHYSICAL_READS,to_char(PHYSICAL_WRITES) PHYSICAL_WRITES,to_char(DB_BLOCK_CHANGES) DB_BLOCK_CHANGES,  round(ratio_to_report(PHYSICAL_WRITES) over ()*100,1) "Escrituras_fisicas_%" from
(select * from top_objects where PHYSICAL_WRITES_rank <=15 order by PHYSICAL_WRITES desc)
where rownum <= 15
/










set markup html off
prompt <h2 id="rowlockwaitsjashcnshd123twet3ytehasj">
set define on
set termout on
prompt * Top obj. row lock waits (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on
set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '      with grafico_objetos as
                    (select /*+ MATERIALIZE */ * from (
                      -- el campo dhsso.subobject_name es por si se trata de una tabla particionada 
                    select dhsso.object_name||nvl2(dhsso.subobject_name,'':''||dhsso.subobject_name,'''') stat_name
                    ,sum(ROW_LOCK_WAITS_DELTA) value
                    from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
                    where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                    					where   
                    						( BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  										and ( BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                    			)
                          and dhsso.obj# = dhss.obj# 
                    group by dhsso.object_name,dhsso.subobject_name     
                      order by sum(ROW_LOCK_WAITS_DELTA) desc
                      ) where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">Objects % row lock waits</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;

set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20
set define on

with top_objects as (select /*+ MATERIALIZE */
 dhsso.object_name object_name,dhsso.owner,dhsso.object_type,dhsso.subobject_name
,sum(LOGICAL_READS_DELTA) LOGICAL_READS
,sum(PHYSICAL_READS_DELTA) PHYSICAL_READS
--,sum(DB_BLOCK_CHANGES_DELTA) DB_BLOCK_CHANGES
--,sum(TABLE_SCANS_DELTA) TABLE_SCANS
,sum(ROW_LOCK_WAITS_DELTA) ROW_LOCK_WAITS
,sum(PHYSICAL_WRITES_DELTA) PHYSICAL_WRITES
--,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
--,rank() over (partition by dhsso.object_name order by sum(LOGICAL_READS_DELTA) desc) as    LOGICAL_READS_rank
,rank() over (partition by dhsso.object_name order by sum(ROW_LOCK_WAITS_DELTA) desc) as    ROW_LOCK_WAITS_rank
from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
where snap_id IN (select SNAP_ID from dba_hist_snapshot 
					  where 
					  		( BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  						and ( BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
				)
      and dhsso.obj# = dhss.obj# --and dhsso.object_type = 'TABLE'
group by dhsso.object_name,dhsso.owner,dhsso.object_type,dhsso.subobject_name
)
select object_name,object_type,owner,subobject_name,to_char(LOGICAL_READS) LOGICAL_READS,to_char(PHYSICAL_READS) PHYSICAL_READS,to_char(PHYSICAL_WRITES) PHYSICAL_WRITES,to_char(ROW_LOCK_WAITS) ROW_LOCK_WAITS,  round(ratio_to_report(ROW_LOCK_WAITS) over ()*100,1) "ROW_LOCK_WAITS_%" from
(select * from top_objects where ROW_LOCK_WAITS_rank <= 15  order by ROW_LOCK_WAITS desc)
where rownum <= 15
/








set markup html off
prompt <h2 id="itlaysdg1632tetsdtqtwt1623tdf">
set define on
set termout on
prompt * Top obj. ITL waits (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
set markup html on
set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '       with grafico_objetos as
                    (select /*+ MATERIALIZE */ * from (
                      -- el campo dhsso.subobject_name es por si se trata de una tabla particionada 
                    select dhsso.object_name||nvl2(dhsso.subobject_name,'':''||dhsso.subobject_name,'''') stat_name
                    ,sum(ITL_WAITS_DELTA) value
                    from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
                    where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                    					where   
                    						( BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  										and ( BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                    			)
                          and dhsso.obj# = dhss.obj# 
                    group by dhsso.object_name,dhsso.subobject_name     
                      order by sum(ITL_WAITS_DELTA) desc
                      ) where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">Objects % itl waits</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;

set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20
set define on

with top_objects as (select /*+ MATERIALIZE */
 dhsso.object_name object_name,dhsso.owner,dhsso.object_type,dhsso.subobject_name
,sum(LOGICAL_READS_DELTA) LOGICAL_READS
,sum(PHYSICAL_READS_DELTA) PHYSICAL_READS
--,sum(DB_BLOCK_CHANGES_DELTA) DB_BLOCK_CHANGES
--,sum(TABLE_SCANS_DELTA) TABLE_SCANS
,sum(ITL_WAITS_DELTA) ITL_WAITS
,sum(PHYSICAL_WRITES_DELTA) PHYSICAL_WRITES
--,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
--,rank() over (partition by dhsso.object_name order by sum(LOGICAL_READS_DELTA) desc) as    LOGICAL_READS_rank
,rank() over (partition by dhsso.object_name order by sum(ITL_WAITS_DELTA) desc) as    ITL_WAITS_rank
from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
where snap_id IN (select SNAP_ID from dba_hist_snapshot 
					  where 
					  		( BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  						and ( BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
				)
      and dhsso.obj# = dhss.obj# --and dhsso.object_type = 'TABLE'
group by dhsso.object_name,dhsso.object_type,dhsso.owner,dhsso.subobject_name
)
select object_name,object_type,owner,subobject_name,to_char(LOGICAL_READS) LOGICAL_READS,to_char(PHYSICAL_READS) PHYSICAL_READS,to_char(PHYSICAL_WRITES) PHYSICAL_WRITES,to_char(ITL_WAITS) ITL_WAITS,  round(ratio_to_report(ITL_WAITS) over ()*100,1) "ITL_WAITS_%" from
(select * from top_objects where ITL_WAITS_rank <= 15  order by ITL_WAITS desc)
where rownum <= 15
/


set markup html off
prompt <h2 id="audhahbachhach172L_oaiscjnaPo">
set define on
set termout on
prompt * Top obj. com mayor cantidad de bloques modificados (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
prompt <p>
prompt Observacion: El Top de estos objetos es lo que mas termina impactando en la generacion de Redolog
prompt </p>
set markup html on
set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '       with grafico_objetos as
                    (select /*+ MATERIALIZE */ * from (
                      -- el campo dhsso.subobject_name es por si se trata de una tabla particionada 
                    select dhsso.object_name||nvl2(dhsso.subobject_name,'':''||dhsso.subobject_name,'''') stat_name
                    ,sum(DB_BLOCK_CHANGES_DELTA) value
                    from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
                    where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                    					where   
                    						( BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  										and ( BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                    			)
                          and dhsso.obj# = dhss.obj# 
                    group by dhsso.object_name,dhsso.subobject_name     
                      order by sum(DB_BLOCK_CHANGES_DELTA) desc
                      ) where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">Objects % db block changes</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;

set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20
set define on

with top_objects as (select /*+ MATERIALIZE */
 dhsso.object_name object_name,dhsso.owner,dhsso.object_type,dhsso.subobject_name
,sum(LOGICAL_READS_DELTA) LOGICAL_READS
,sum(PHYSICAL_READS_DELTA) PHYSICAL_READS
,sum(DB_BLOCK_CHANGES_DELTA) DB_BLOCK_CHANGES
--,sum(TABLE_SCANS_DELTA) TABLE_SCANS
,sum(ITL_WAITS_DELTA) ITL_WAITS
,sum(PHYSICAL_WRITES_DELTA) PHYSICAL_WRITES
--,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
--,rank() over (partition by dhsso.object_name order by sum(LOGICAL_READS_DELTA) desc) as    LOGICAL_READS_rank
,rank() over (partition by dhsso.object_name order by sum(DB_BLOCK_CHANGES_DELTA) desc) as    DB_BLOCK_CHANGES_rank
from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                      where 
                      			( BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
                          and 	( BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
                )
      and dhsso.obj# = dhss.obj# --and dhsso.object_type = 'TABLE'
group by dhsso.object_name,dhsso.object_type,dhsso.owner,dhsso.subobject_name
)
select object_name,object_type,owner,subobject_name,to_char(LOGICAL_READS) LOGICAL_READS,to_char(PHYSICAL_READS) PHYSICAL_READS,to_char(PHYSICAL_WRITES) PHYSICAL_WRITES,to_char(DB_BLOCK_CHANGES) DB_BLOCK_CHANGES,  round(ratio_to_report(DB_BLOCK_CHANGES) over ()*100,1) "DB_BLOCK_CHANGES_%" from
(select * from top_objects where DB_BLOCK_CHANGES_rank <= 15  order by DB_BLOCK_CHANGES desc)
where rownum <= 15
/


set markup html off
prompt <h2 id="19djajdahsdhh1d__d91jdjahsdhh">
set define on
set termout on
prompt * Top obj. com mayor cantidad esperas en buffer busy waits (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
prompt <p>
prompt This wait happens when a session wants to access a database block in the buffer cache but it cannot because the buffer is busy. Another session is modifying the block and the contents of the block are in flux during the modification. To guarantee that the reader has a coherent image of the block with either all of the changes or none of the changes, the session modifying the block marks the block header with a flag letting other users know a change is taking place and to wait until the complete change is applied.
prompt <a href=https://docs.oracle.com/cd/B16240_01/doc/doc.102/e16282/oracle_database_help/oracle_database_wait_bottlenecks_buffer_busy_waits_pct.html>https://docs.oracle.com/cd/B16240_01/doc/doc.102/e16282/oracle_database_help/oracle_database_wait_bottlenecks_buffer_busy_waits_pct.html</a>
prompt </p>
set markup html on
set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '       with grafico_objetos as
                    (select /*+ MATERIALIZE */ * from (
                      -- el campo dhsso.subobject_name es por si se trata de una tabla particionada 
                    select dhsso.object_name||nvl2(dhsso.subobject_name,'':''||dhsso.subobject_name,'''') stat_name
                    ,sum(BUFFER_BUSY_WAITS_DELTA) value
                    from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
                    where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                    					where   
                    						( BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  										and ( BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                    			)
                          and dhsso.obj# = dhss.obj# 
                    group by dhsso.object_name,dhsso.subobject_name     
                      order by sum(BUFFER_BUSY_WAITS_DELTA) desc
                      ) where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">Objects % buffer busy waits</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;

set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20
set define on

with top_objects as (select /*+ MATERIALIZE */
 dhsso.object_name object_name,dhsso.owner,dhsso.object_type,dhsso.subobject_name
,sum(LOGICAL_READS_DELTA) LOGICAL_READS
,sum(PHYSICAL_READS_DELTA) PHYSICAL_READS
,sum(DB_BLOCK_CHANGES_DELTA) DB_BLOCK_CHANGES
--,sum(TABLE_SCANS_DELTA) TABLE_SCANS
,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
,sum(PHYSICAL_WRITES_DELTA) PHYSICAL_WRITES
--,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
--,rank() over (partition by dhsso.object_name order by sum(LOGICAL_READS_DELTA) desc) as    LOGICAL_READS_rank
,rank() over (partition by dhsso.object_name order by sum(BUFFER_BUSY_WAITS_DELTA) desc) as    BUFFER_BUSY_WAITS_rank
from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                      where 
                      			( BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
                          and 	( BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
                )
      and dhsso.obj# = dhss.obj# --and dhsso.object_type = 'TABLE'
group by dhsso.object_name,dhsso.object_type,dhsso.owner,dhsso.subobject_name
)
select object_name,object_type,owner,subobject_name,to_char(LOGICAL_READS) LOGICAL_READS,to_char(PHYSICAL_READS) PHYSICAL_READS,to_char(PHYSICAL_WRITES) PHYSICAL_WRITES,to_char(BUFFER_BUSY_WAITS) BUFFER_BUSY_WAITS,  round(ratio_to_report(BUFFER_BUSY_WAITS) over ()*100,1) "BUFFER_BUSY_WAITS_%" from
(select * from top_objects where BUFFER_BUSY_WAITS_rank <= 15  order by BUFFER_BUSY_WAITS desc)
where rownum <= 15
/




set markup html off
prompt <h2 id="18djhahshGGhahsh_paoisjhdy1hy">
set define on
set termout on
prompt * Top obj. com mayor cantidad esperas en Global Cache Buffer busy waits (total para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr)
set termout off
prompt </h2>
prompt <p>
prompt This wait happens when a session wants to access a database block in the buffer cache but it cannot because the buffer is busy. Another session is modifying the block and the contents of the block are in flux during the modification. To guarantee that the reader has a coherent image of the block with either all of the changes or none of the changes, the session modifying the block marks the block header with a flag letting other users know a change is taking place and to wait until the complete change is applied.
prompt <a href=https://docs.oracle.com/cd/B16240_01/doc/doc.102/e16282/oracle_database_help/oracle_database_wait_bottlenecks_buffer_busy_waits_pct.html>https://docs.oracle.com/cd/B16240_01/doc/doc.102/e16282/oracle_database_help/oracle_database_wait_bottlenecks_buffer_busy_waits_pct.html</a>
prompt </p>
set markup html on
set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SELECT XMLTRANSFORM
   (DBMS_XMLGEN.GETXMLTYPE
      (
      '       with grafico_objetos as
                    (select /*+ MATERIALIZE */ * from (
                      -- el campo dhsso.subobject_name es por si se trata de una tabla particionada 
                    select dhsso.object_name||nvl2(dhsso.subobject_name,'':''||dhsso.subobject_name,'''') stat_name
                    ,sum(GC_BUFFER_BUSY_DELTA) value
                    from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
                    where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                    					where   
                    						( BEGIN_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME >= to_date(''&fecha_ini_awr'',''yyyymmdd_hh24mi''))
  										and ( BEGIN_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi'') OR END_INTERVAL_TIME <= to_date(''&fecha_fin_awr'',''yyyymmdd_hh24mi''))
                    			)
                          and dhsso.obj# = dhss.obj# 
                    group by dhsso.object_name,dhsso.subobject_name     
                      order by sum(GC_BUFFER_BUSY_DELTA) desc
                      ) where rownum <= 15
                    )
      SELECT TRUNC(COS(cumulative_percent*(3.141592653589*3.6/180)),15)      COS_CUMUL_PERCENT
       ,       TRUNC(SIN(cumulative_percent*(3.141592653589*3.6/180)),15)      SIN_CUMUL_PERCENT
       ,       TRUNC(COS(cumulative_percent_prev*(3.141592653589*3.6/180)),15) COS_CUMUL_PERCENT_PREV
       ,       TRUNC(SIN(CUMULATIVE_PERCENT_PREV*(3.141592653589*3.6/180)),15) SIN_CUMUL_PERCENT_PREV
       ,       DECODE(SIGN(percent_value-50),1,1,0) ARC_CODE
       ,       stat_name                            STAT_NAME
       ,       TRUNC(percent_value,2)               PERCENT_VALUE
       ,       DECODE(rownum,1,''#ff0000'',2,''#ff8000''
              ,3,''#ffbf00'',4,''#ffff00''
              ,5,''#bfff00'',6,''#00ff00''
              ,7,''#00ffbf'',8,''#00ffff''
              ,9,''#00bfff'',10,''#0080ff''
              ,11,''#0000ff'',12,''#8000ff''
               ,13,''#9933ff'',14,''#a64dff''
                ,15,''#bf80ff'',16,''#bf80ff''
               ,''null'') PIE_COLOR
       FROM (
          SELECT cumulative_percent
          ,      stat_name
          ,      LAG(cumulative_percent, 1, 0) OVER (ORDER BY value DESC, stat_name) AS cumulative_percent_prev
          ,      (value/sum_value*100) percent_value
          FROM (
             SELECT SUM(value) OVER ( ORDER BY value DESC, stat_name) /
                (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) * 100 cumulative_percent
             ,   stat_name
             ,   value
             ,  (
                   SELECT SUM(value)
                   FROM
                   grafico_objetos
                ) sum_value
             FROM grafico_objetos
             ORDER BY value DESC
               )
      )
      '
      )
,      XMLTYPE.CREATEXML
   (TO_CLOB('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
     <xsl:variable name="margin_top">20</xsl:variable>
     <xsl:variable name="margin_bottom">30</xsl:variable>
     <xsl:variable name="margin_left">10</xsl:variable>
     <xsl:variable name="margin_right">200</xsl:variable>
     <xsl:variable name="pie_radius">100</xsl:variable>
     <xsl:variable name="pie_x_center">110</xsl:variable>
     <xsl:variable name="pie_y_center">110</xsl:variable>
     <xsl:variable name="stat_nb"><xsl:value-of select="count(/descendant::STAT_NAME)"/></xsl:variable>
     <xsl:variable name="graph_width"><xsl:value-of select="600+$margin_left+$margin_right"/></xsl:variable>
     <xsl:variable name="graph_heigth"><xsl:value-of select="300+$margin_top+$margin_bottom"/></xsl:variable>
       <xsl:template match="/">
         <svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_heigth}">
           <text x="75" y="15" style="fill:#000000; stroke: none;font-size:11px;text-anchor=start">Objects % GC buffer busy waits</text>
           <xsl:for-each select="ROWSET/ROW">
             <text x="{($margin_left)+(2*($pie_radius))+33}" y="{($margin_top)+(8*(position()))}" style="fill:#000000; stroke: none;font-size:9px;text-anchor=start"><xsl:value-of select="(descendant::STAT_NAME)"/></text>
             <rect x="{($margin_left)+(2*($pie_radius))+20}" y="{($margin_top)+(8*(position()-1))+3}" width="{10}" height="{6}" fill="{(descendant::PIE_COLOR)}" stroke="black"/>
             <text x="{($margin_left)+(2*($pie_radius))+173}" y="{($margin_top)+(8*(position()))}" style="fill: #000000; stroke: none;font-size:9px;text-anchor=end"><xsl:value-of select="format-number((descendant::PERCENT_VALUE),''00.00'')"/></text>
           </xsl:for-each>
           <rect x="{($margin_left)+(2*($pie_radius))+15}" y="{($margin_top)}" width="{185}" height="{5+(($stat_nb)*8)}" fill="none" stroke="blue"/>
           <xsl:for-each select="ROWSET/ROW">
             <path d="M{($pie_x_center)+($margin_left)},{($pie_y_center)+($margin_top)} l{(descendant::COS_CUMUL_PERCENT_PREV)*($pie_radius)},{(descendant::SIN_CUMUL_PERCENT_PREV)*($pie_radius)*(-1)} a{($pie_radius)},{($pie_radius)} 0 {(descendant::ARC_CODE)},0
{(($pie_radius)*((descendant::COS_CUMUL_PERCENT)-(descendant::COS_CUMUL_PERCENT_PREV)))},{(($pie_radius)*((descendant::SIN_CUMUL_PERCENT_PREV)-(descendant::SIN_CUMUL_PERCENT)))} z" stroke="none" fill="{(descendant::PIE_COLOR)}" stroke-width="1"/>
           </xsl:for-each>
         </svg>
       </xsl:template>
     </xsl:stylesheet>')
   )
   )
FROM dual;

set markup html on
set heading on
SET FEEDBACK ON
SET PAGESIZE 20
set define on

with top_objects as (select /*+ MATERIALIZE */
 dhsso.object_name object_name,dhsso.owner,dhsso.object_type,dhsso.subobject_name
,sum(LOGICAL_READS_DELTA) LOGICAL_READS
,sum(PHYSICAL_READS_DELTA) PHYSICAL_READS
,sum(DB_BLOCK_CHANGES_DELTA) DB_BLOCK_CHANGES
--,sum(TABLE_SCANS_DELTA) TABLE_SCANS
,sum(GC_BUFFER_BUSY_DELTA) GC_BUFFER_BUSY
,sum(PHYSICAL_WRITES_DELTA) PHYSICAL_WRITES
--,sum(BUFFER_BUSY_WAITS_DELTA) BUFFER_BUSY_WAITS
--,rank() over (partition by dhsso.object_name order by sum(LOGICAL_READS_DELTA) desc) as    LOGICAL_READS_rank
,rank() over (partition by dhsso.object_name order by sum(GC_BUFFER_BUSY_DELTA) desc) as    GC_BUFFER_BUSY_rank
from DBA_HIST_SEG_STAT dhss, DBA_HIST_SEG_STAT_OBJ dhsso
where snap_id IN (select SNAP_ID from dba_hist_snapshot 
                      where 
                      			( BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
                          and 	( BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
                )
      and dhsso.obj# = dhss.obj# --and dhsso.object_type = 'TABLE'
group by dhsso.object_name,dhsso.object_type,dhsso.owner,dhsso.subobject_name
)
select object_name,object_type,owner,subobject_name,to_char(LOGICAL_READS) LOGICAL_READS,to_char(PHYSICAL_READS) PHYSICAL_READS,to_char(PHYSICAL_WRITES) PHYSICAL_WRITES,to_char(GC_BUFFER_BUSY) GC_BUFFER_BUSY,  round(ratio_to_report(GC_BUFFER_BUSY) over ()*100,1) "GC_BUFFER_BUSY_%" from
(select * from top_objects where GC_BUFFER_BUSY_rank <= 15  order by GC_BUFFER_BUSY desc)
where rownum <= 15
/
----------------


set markup html off
prompt <h2 id="GraficodewaitseventsultimosminutosASS_JDnvg36fdhagsdas">
set termout on
prompt * AWR chart waits events last minutes (ASS)
set termout off
prompt </h2>
set markup html on


/*
set markup html off
SET LINESIZE      1000
SET LONGCHUNKSIZE 30000
SET LONG          30000
SET FEEDBACK OFF
SET VERIFY   OFF
SET PAGESIZE 0
SET DEFINE OFF
SET HEADING OFF
set serveroutput on size unlimited
*/


set markup html off
SET LINESIZE      300
SET LONGCHUNKSIZE 300000
SET LONG          300000
SET FEEDBACK OFF
SET PAGESIZE 0
SET HEADING OFF
SET DEFINE OFF
set serveroutput on size unlimited

-- wait events, eventos de espera ultimos minutos (en microsegundos)
--prompt <div style = "all: default" >
--prompt <div style = "transform: scale(1.5);position:absolute;margin-left: 650px;margin-top: 95px;width: 8000px" >
declare
	v_contenido xmltype;
begin
 FOR instancia IN ( SELECT INST_ID,instance_name from GV$instance order by INST_ID )
 --FOR instancia IN ( SELECT INST_ID,'urp00x' instance_name from GV$VERSION  order by INST_ID )
  LOOP
    BEGIN
		SELECT XMLTRANSFORM
		   (DBMS_XMLGEN.GETXMLTYPE
			  ('SELECT TO_CHAR(begin_time,''HH24:MI'') BEGIN_TIME
				,      c_other          C_OTHER
				,      c_application    C_APPLICATION
				,      c_configuration  C_CONFIGURATION
				,      c_administrative C_ADMINISTRATIVE
				,      c_concurrency    C_CONCURRENCY
				,      c_commit         C_COMMIT
				,      c_network        C_NETWORK
				,      c_user_io        C_USER_IO
				,      c_system_io      C_SYSTEM_IO
				,      c_scheduler      C_SCHEDULER
				,      c_cluster        C_CLUSTER
				,      c_queueing       C_QUEUEING
				,      MAX(c_queueing) OVER() SUM_TIME_WAITED
				FROM (
				   SELECT *
				   FROM (
					  SELECT begin_time
					  ,      wait_class#
					  ,      SUM(time_waited) OVER (PARTITION BY begin_time ORDER BY wait_class#) sum_time_waited_acc
					  FROM Gv$waitclassmetric_history
					  WHERE wait_class# <> 6 and inst_id = '||instancia.inst_id||'
						) tb
				   PIVOT (
					  MAX(sum_time_waited_acc)
					  FOR wait_class# IN (0 AS c_other, 1 AS c_application,2 AS c_configuration,3 AS c_administrative,4 AS c_concurrency,5 AS c_commit,
										  7 AS c_network, 8 AS c_user_io, 9 AS c_system_io, 10 AS c_scheduler,11 AS c_cluster,12 AS c_queueing)
						 )
				   ORDER BY begin_time
					 )
				ORDER BY begin_time')
		,      XMLTYPE.CREATEXML
		   (TO_CLOB(
			'<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
			 <xsl:variable name="margin_top">20</xsl:variable>
			 <xsl:variable name="margin_bottom">30</xsl:variable>
			 <xsl:variable name="margin_left">40</xsl:variable>
			 <xsl:variable name="margin_right">100</xsl:variable>
			 <xsl:variable name="bar_width">5</xsl:variable>
			 <xsl:variable name="graph_width"><xsl:value-of select="300+$margin_left+$margin_right"/></xsl:variable>
			 <xsl:variable name="graph_height"><xsl:value-of select="100+$margin_top+$margin_bottom"/></xsl:variable>
			 <xsl:variable name="graph_name">[Instancia: '||instancia.instance_name||'] - Wait Classes</xsl:variable>
			 <xsl:variable name="graph_unit">Time waited (in microseconds)</xsl:variable>
			 <xsl:variable name="yval_max"><xsl:value-of select="/descendant::SUM_TIME_WAITED[position()=1]"/></xsl:variable>
			 <xsl:variable name="yval_min">0</xsl:variable>
			   <xsl:template match="/">'
				   )
			||
			TO_CLOB(
				 '<svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_height}">
				   <text x="{$margin_left+1}" y="{($margin_top)-5}" style="fill: #000000; stroke: none;font-size:10px;text-anchor=start"><xsl:value-of select="$graph_name"/></text>
				   <text x="{($margin_bottom)-($graph_height)}" y="10" transform="rotate(-90)" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="$graph_unit"/></text>
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-0}"   x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-0}"  style="stroke:lightblue;stroke-width:1" />
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-25}"  x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-25}" style="stroke:lightblue;stroke-width:1" />
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-50}"  x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-50}" style="stroke:lightblue;stroke-width:1" />
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-75}"  x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-75}" style="stroke:lightblue;stroke-width:1" />
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-100}" x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lightblue;stroke-width:1" />
				   <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-2}"   style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round($yval_min)"/></text>
				   <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-25}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+(1*(($yval_max)-($yval_min)) div 4))"/></text>
				   <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-50}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+((($yval_max)-($yval_min)) div 2))"/></text>
				   <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-75}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round(($yval_min)+(3*(($yval_max)-($yval_min)) div 4))"/></text>
				   <text x="{($margin_left)-20}" y="{($graph_height)-($margin_bottom)-100}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="round($yval_max)"/></text>
				   <line x1="{$margin_left}" y1="{($graph_height)-($margin_bottom)}" x2="{$margin_left}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lightblue;stroke-width:1" />'
				   )
			||
			TO_CLOB(
				  '<xsl:for-each select="ROWSET/ROW/BEGIN_TIME">
					 <xsl:choose>
					   <xsl:when test="(position()-1) mod 5=0">
						 <text x="{($margin_left)-9+($bar_width*(position()-1))}" y="{($graph_height)-($margin_bottom)+12}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="self::node()"/></text>
						 <line x1="{($margin_left)+($bar_width*(position()-1))}" y1="{($graph_height)-($margin_bottom)+4}" x2="{($margin_left)+($bar_width*(position()-1))}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lightblue;stroke-width:1" />
					   </xsl:when>
					 </xsl:choose>
				   </xsl:for-each>
				   <xsl:variable name="v_path0">
					 <xsl:for-each select="ROWSET/ROW/C_OTHER">
					   <xsl:variable name="x_val0">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val0">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val0,'','',$y_val0,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path0}" style="fill:none;stroke:hotpink;stroke-width:1" />
				   <xsl:variable name="v_path1">
					 <xsl:for-each select="ROWSET/ROW/C_APPLICATION">
					   <xsl:variable name="x_val1">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val1">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val1,'','',$y_val1,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path1}" style="fill:none;stroke:indianred;stroke-width:1" />
				   <xsl:variable name="v_path2">
					 <xsl:for-each select="ROWSET/ROW/C_CONFIGURATION">
					   <xsl:variable name="x_val2">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val2">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val2,'','',$y_val2,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path2}" style="fill:none;stroke:olive;stroke-width:1" />
				   <xsl:variable name="v_path3">
					 <xsl:for-each select="ROWSET/ROW/C_ADMINISTRATIVE">
					   <xsl:variable name="x_val3">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val3">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val3,'','',$y_val3,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path3}" style="fill:none;stroke:gray;stroke-width:1" />'
				   )
		   ||
		   TO_CLOB(
				  '<xsl:variable name="v_path4">
					 <xsl:for-each select="ROWSET/ROW/C_CONCURRENCY">
					   <xsl:variable name="x_val4">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val4">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val4,'','',$y_val4,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path4}" style="fill:none;stroke:sienna;stroke-width:1" />
				   <xsl:variable name="v_path5">
					 <xsl:for-each select="ROWSET/ROW/C_COMMIT">
					   <xsl:variable name="x_val5">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val5">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val5,'','',$y_val5,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path5}" style="fill:none;stroke:orange;stroke-width:1" />
				   <xsl:variable name="v_path6">
					 <xsl:for-each select="ROWSET/ROW/C_NETWORK">
					   <xsl:variable name="x_val6">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val6">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val6,'','',$y_val6,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path6}" style="fill:none;stroke:tan;stroke-width:1" />
				   <xsl:variable name="v_path7">
					 <xsl:for-each select="ROWSET/ROW/C_USER_IO">
					   <xsl:variable name="x_val7">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val7">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val7,'','',$y_val7,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path7}" style="fill:none;stroke:royalblue;stroke-width:1" />
				   <xsl:variable name="v_path8">
					 <xsl:for-each select="ROWSET/ROW/C_SYSTEM_IO">
					   <xsl:variable name="x_val8">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val8">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val8,'','',$y_val8,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path8}" style="fill:none;stroke:skyblue;stroke-width:1" />'
				   )
		   ||
		   TO_CLOB(
				  '<xsl:variable name="v_path9">
					 <xsl:for-each select="ROWSET/ROW/C_SCHEDULER">
					   <xsl:variable name="x_val9">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val9">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val9,'','',$y_val9,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path9}" style="fill:none;stroke:lightcyan;stroke-width:1" />
				   <xsl:variable name="v_path10">
					 <xsl:for-each select="ROWSET/ROW/C_CLUSTER">
					   <xsl:variable name="x_val10">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val10">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val10,'','',$y_val10,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path10}" style="fill:none;stroke:lightgray;stroke-width:1" />
				   <xsl:variable name="v_path11">
					 <xsl:for-each select="ROWSET/ROW/C_QUEUEING">
					   <xsl:variable name="x_val11">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val11">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val11,'','',$y_val11,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polyline points="{$v_path11}" style="fill:none;stroke:bisque;stroke-width:1" />
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+8}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Other</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+3}" width="{10}" height="{6}" fill="hotpink" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+16}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Application</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+11}" width="{10}" height="{6}" fill="indianred" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+24}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Configuration</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+19}" width="{10}" height="{6}" fill="olive" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+32}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Administrative</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+27}" width="{10}" height="{6}" fill="gray" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+40}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Concurrency</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+35}" width="{10}" height="{6}" fill="sienna" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+48}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Commit</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+43}" width="{10}" height="{6}" fill="orange" stroke="black"/>'
				   )
			||
			TO_CLOB(
				  '<text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+56}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Network</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+51}" width="{10}" height="{6}" fill="tan" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+64}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">User IO</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+59}" width="{10}" height="{6}" fill="royalblue" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+72}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">System IO</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+67}" width="{10}" height="{6}" fill="skyblue" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+80}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Scheduler</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+75}" width="{10}" height="{6}" fill="lightcyan" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+88}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Cluster</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+83}" width="{10}" height="{6}" fill="lightgray" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+96}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Queueing</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+91}" width="{10}" height="{6}" fill="bisque" stroke="black"/>
				 </svg>
			   </xsl:template>
			 </xsl:stylesheet>'
				   )
		   )
		   )
		into v_contenido from dual;
		dbms_output.put_line(v_contenido.getClobVal);
		end;
	end loop;
end;
/
--prompt </div>







-- numero de sesiones en espera + activas ultimos minutos
/*
prompt <br>
prompt <br>
prompt <br>
prompt <br>
prompt <br>
prompt <br>
*/





prompt <h2 id="Sesionesesperaactivechart_jahsNbru70pNds">
set termout on
prompt * AWR wait sessions + Active session (EM chart)
set termout off
prompt </h2>



--prompt <div style = "transform: scale(1.8)" >
--prompt <div style = "transform: scale(1.5);position:relative;margin-left: 360px;margin-top: 95px" >
--prompt <div style = "transform: scale(1.5);position:absolute;margin-left: 650px;margin-top: 95px; width: 8000px" >
--prompt <div style = "all: revert" >
declare
	v_contenido xmltype;
begin
 --FOR instancia IN (SELECT INST_ID,instance_name from GV$instance order by INST_ID )
  FOR instancia IN ( SELECT INST_ID, instance_name from GV$instance  order by INST_ID )
  LOOP
    BEGIN
		SELECT XMLTRANSFORM
		   (DBMS_XMLGEN.GETXMLTYPE
			  ('SELECT TO_CHAR(begin_time,''HH24:MI'') BEGIN_TIME
				,      c_cpu            C_CPU
				,      c_other          C_OTHER
				,      c_application    C_APPLICATION
				,      c_configuration  C_CONFIGURATION
				,      c_administrative C_ADMINISTRATIVE
				,      c_concurrency    C_CONCURRENCY
				,      c_commit         C_COMMIT
				,      c_network        C_NETWORK
				,      c_user_io        C_USER_IO
				,      c_system_io      C_SYSTEM_IO
				,      c_scheduler      C_SCHEDULER
				,      c_cluster        C_CLUSTER
				,      c_queueing       C_QUEUEING
				,      MAX(CEIL(c_queueing)) OVER() MAX_AVERAGE_WAITER_COUNT
				,      (SELECT value FROM Gv$parameter WHERE name=''cpu_count'' and inst_id = '||instancia.inst_id||') CPU_COUNT
				FROM (
				   SELECT *
				   FROM (
					  SELECT begin_time
					  ,      wait_class#
					  ,      SUM(average_waiter_count) OVER (PARTITION BY begin_time ORDER BY wait_class#) average_waiter_count_acc
					  FROM (
						 SELECT begin_time,
								wait_class#,
								average_waiter_count
						 FROM Gv$waitclassmetric_history
						 WHERE (wait_class# <> 6  and inst_id = '||instancia.inst_id||' )
						UNION
						 SELECT begin_time
						 ,      -1 wait_class#
						 ,      value/100 average_waiter_count
						 FROM Gv$sysmetric_history
						 WHERE metric_id = 2075
						   AND group_id = 2  and inst_id = '||instancia.inst_id||'
						   )
						) tb
				   PIVOT (
					  MAX(average_waiter_count_acc)
					  FOR wait_class# IN (-1 as c_cpu,0 AS c_other,1 AS c_application,2 AS c_configuration,3 AS c_administrative,4 AS c_concurrency,
										  5 AS c_commit,7 AS c_network, 8 AS c_user_io,9 AS c_system_io,10 AS c_scheduler,11 AS c_cluster,12 AS c_queueing)
						 )
				   ORDER BY begin_time
					 )
				ORDER BY begin_time')
		,      XMLTYPE.CREATEXML
		   (TO_CLOB(
			'<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
			 <xsl:variable name="margin_top">20</xsl:variable>
			 <xsl:variable name="margin_bottom">30</xsl:variable>
			 <xsl:variable name="margin_left">40</xsl:variable>
			 <xsl:variable name="margin_right">100</xsl:variable>
			 <xsl:variable name="bar_width">5</xsl:variable>
			 <xsl:variable name="graph_width"><xsl:value-of select="300+$margin_left+$margin_right"/></xsl:variable>
			 <xsl:variable name="graph_height"><xsl:value-of select="100+$margin_top+$margin_bottom"/></xsl:variable>
			 <xsl:variable name="graph_name">[Instancia: '||instancia.instance_name||'] -  Active Sessions - Waiting + Working</xsl:variable>
			 <xsl:variable name="graph_unit">Session Count</xsl:variable>
			 <xsl:variable name="yval_max"><xsl:value-of select="/descendant::MAX_AVERAGE_WAITER_COUNT[position()=1]"/></xsl:variable>
			 <xsl:variable name="yval_min">0</xsl:variable>
			 <xsl:variable name="cpu_count"><xsl:value-of select="/descendant::CPU_COUNT[position()=1]"/></xsl:variable>
			   <xsl:template match="/">'
				   )
			||
			TO_CLOB(
				 '<svg xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://www.w3.org/2000/svg" width="{$graph_width}" height="{$graph_height}">
				   <text x="{$margin_left+1}" y="{($margin_top)-5}" style="fill: #000000; stroke: none;font-size:10px;text-anchor=start"><xsl:value-of select="$graph_name"/></text>
				   <text x="{($margin_bottom)-($graph_height)}" y="10" transform="rotate(-90)" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="$graph_unit"/></text>
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-0}"   x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-0}"  style="stroke:lightblue;stroke-width:1" />
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-25}"  x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-25}" style="stroke:lightblue;stroke-width:1" />
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-50}"  x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-50}" style="stroke:lightblue;stroke-width:1" />
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-75}"  x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-75}" style="stroke:lightblue;stroke-width:1" />
				   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-100}" x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lightblue;stroke-width:1" />
				   <text x="{($margin_left)-24}" y="{($graph_height)-($margin_bottom)-2}"   style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="format-number(($yval_min),''00.00'')"/></text>
				   <text x="{($margin_left)-24}" y="{($graph_height)-($margin_bottom)-25}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="format-number((($yval_min)+(1*(($yval_max)-($yval_min)) div 4)),''00.00'')"/></text>
				   <text x="{($margin_left)-24}" y="{($graph_height)-($margin_bottom)-50}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="format-number((($yval_min)+((($yval_max)-($yval_min)) div 2)),''00.00'')"/></text>
				   <text x="{($margin_left)-24}" y="{($graph_height)-($margin_bottom)-75}"  style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="format-number((($yval_min)+(3*(($yval_max)-($yval_min)) div 4)),''00.00'')"/></text>
				   <text x="{($margin_left)-24}" y="{($graph_height)-($margin_bottom)-100}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="format-number(($yval_max),''00.00'')"/></text>
				   <line x1="{$margin_left}" y1="{($graph_height)-($margin_bottom)}" x2="{$margin_left}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lightblue;stroke-width:1" />'
				   )
			||
			TO_CLOB(
				  '<xsl:for-each select="ROWSET/ROW/BEGIN_TIME">
					 <xsl:choose>
					   <xsl:when test="(position()-1) mod 5=0">
						 <text x="{($margin_left)-9+($bar_width*(position()-1))}" y="{($graph_height)-($margin_bottom)+12}" style="fill: #000000; stroke: none;font-size:8px;text-anchor=start"><xsl:value-of select="self::node()"/></text>
						 <line x1="{($margin_left)+($bar_width*(position()-1))}" y1="{($graph_height)-($margin_bottom)+4}" x2="{($margin_left)+($bar_width*(position()-1))}" y2="{($graph_height)-($margin_bottom)-100}" style="stroke:lightblue;stroke-width:1" />
					   </xsl:when>
					 </xsl:choose>
				   </xsl:for-each>
				   <xsl:variable name="v_path0">
					 <xsl:for-each select="ROWSET/ROW/C_CPU">
					   <xsl:variable name="x_val0">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val0">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val0,'','',$y_val0,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path0} {$x_val0},{($graph_height)-($margin_bottom)} {$margin_left},{($graph_height)-($margin_bottom)}" style="fill:lightgreen;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path1">
					 <xsl:for-each select="ROWSET/ROW/C_OTHER">
					   <xsl:sort select="position()" order="descending" data-type="number"/>
					   <xsl:variable name="x_val1">
						 <xsl:value-of select="$margin_left+$bar_width*(last()-position())"/>
					   </xsl:variable>
					   <xsl:variable name="y_val1">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val1,'','',$y_val1,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path0}{$v_path1}" style="fill:hotpink;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path2">
					 <xsl:for-each select="ROWSET/ROW/C_APPLICATION">
					   <xsl:variable name="x_val2">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val2">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val2,'','',$y_val2,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path1}{$v_path2}" style="fill:indianred;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path3">
					 <xsl:for-each select="ROWSET/ROW/C_CONFIGURATION">
					   <xsl:sort select="position()" order="descending" data-type="number"/>
					   <xsl:variable name="x_val3">
						 <xsl:value-of select="$margin_left+$bar_width*(last()-position())"/>
					   </xsl:variable>
					   <xsl:variable name="y_val3">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val3,'','',$y_val3,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path2}{$v_path3}" style="fill:olive;stroke:none;stroke-width:1" />'
				   )
		   ||
		   TO_CLOB(
				  '<xsl:variable name="v_path4">
					 <xsl:for-each select="ROWSET/ROW/C_ADMINISTRATIVE">
					   <xsl:variable name="x_val4">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val4">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val4,'','',$y_val4,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path3}{$v_path4}" style="fill:gray;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path5">
					 <xsl:for-each select="ROWSET/ROW/C_CONCURRENCY">
					   <xsl:sort select="position()" order="descending" data-type="number"/>
					   <xsl:variable name="x_val5">
						 <xsl:value-of select="$margin_left+$bar_width*(last()-position())"/>
					   </xsl:variable>
					   <xsl:variable name="y_val5">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val5,'','',$y_val5,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path4}{$v_path5}" style="fill:sienna;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path6">
					 <xsl:for-each select="ROWSET/ROW/C_COMMIT">
					   <xsl:variable name="x_val6">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val6">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val6,'','',$y_val6,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path5}{$v_path6}" style="fill:orange;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path7">
					 <xsl:for-each select="ROWSET/ROW/C_NETWORK">
					   <xsl:sort select="position()" order="descending" data-type="number"/>
					   <xsl:variable name="x_val7">
						 <xsl:value-of select="$margin_left+$bar_width*(last()-position())"/>
					   </xsl:variable>
					   <xsl:variable name="y_val7">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val7,'','',$y_val7,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path6}{$v_path7}" style="fill:tan;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path8">
					 <xsl:for-each select="ROWSET/ROW/C_USER_IO">
					   <xsl:variable name="x_val8">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val8">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val8,'','',$y_val8,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path7}{$v_path8}" style="fill:royalblue;stroke:none;stroke-width:1" />'
				   )
		   ||
		   TO_CLOB(
				  '<xsl:variable name="v_path9">
					 <xsl:for-each select="ROWSET/ROW/C_SYSTEM_IO">
					   <xsl:sort select="position()" order="descending" data-type="number"/>
					   <xsl:variable name="x_val9">
						 <xsl:value-of select="$margin_left+$bar_width*(last()-position())"/>
					   </xsl:variable>
					   <xsl:variable name="y_val9">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val9,'','',$y_val9,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path8}{$v_path9}" style="fill:skyblue;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path10">
					 <xsl:for-each select="ROWSET/ROW/C_SCHEDULER">
					   <xsl:variable name="x_val10">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val10">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val10,'','',$y_val10,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path9}{$v_path10}" style="fill:lightcyan;stroke:none;stroke-width:1" />'
				   )
		   ||
		   TO_CLOB(
				  '<xsl:variable name="v_path11">
					 <xsl:for-each select="ROWSET/ROW/C_CLUSTER">
					   <xsl:sort select="position()" order="descending" data-type="number"/>
					   <xsl:variable name="x_val11">
						 <xsl:value-of select="$margin_left+$bar_width*(last()-position())"/>
					   </xsl:variable>
					   <xsl:variable name="y_val11">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val11,'','',$y_val11,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path10}{$v_path11}" style="fill:lightgray;stroke:none;stroke-width:1" />
				   <xsl:variable name="v_path12">
					 <xsl:for-each select="ROWSET/ROW/C_QUEUEING">
					   <xsl:variable name="x_val12">
						 <xsl:value-of select="$margin_left+$bar_width*(position()-1)"/>
					   </xsl:variable>
					   <xsl:variable name="y_val12">
						 <xsl:value-of select="round(($graph_height)-($margin_bottom)-((($yval_min)-(self::node()))*(100 div (($yval_min)-($yval_max)))))"/>
					   </xsl:variable>
					   <xsl:value-of select="concat($x_val12,'','',$y_val12,'' '')"/>
					 </xsl:for-each>
				   </xsl:variable>
				   <polygon points="{$v_path11}{$v_path12}" style="fill:bisque;stroke:none;stroke-width:1" />
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+5}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">CPU used</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+0}" width="{10}" height="{6}" fill="lightgreen" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+13}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Other</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+8}" width="{10}" height="{6}" fill="hotpink" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+21}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Application</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+16}" width="{10}" height="{6}" fill="indianred" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+29}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Configuration</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+24}" width="{10}" height="{6}" fill="olive" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+37}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Administrative</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+32}" width="{10}" height="{6}" fill="gray" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+45}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Concurrency</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+40}" width="{10}" height="{6}" fill="sienna" stroke="black"/>'
				   )
			||
			TO_CLOB(
				  '<text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+53}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Commit</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+48}" width="{10}" height="{6}" fill="orange" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+61}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Network</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+56}" width="{10}" height="{6}" fill="tan" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+69}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">User IO</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+64}" width="{10}" height="{6}" fill="royalblue" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+77}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">System IO</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+72}" width="{10}" height="{6}" fill="skyblue" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+85}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Scheduler</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+80}" width="{10}" height="{6}" fill="lightcyan" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+93}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Cluster</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+88}" width="{10}" height="{6}" fill="lightgray" stroke="black"/>
				   <text x="{($graph_width)-($margin_right)+33}" y="{($margin_top)+101}" style="fill:#000000; stroke: none;font-size:8px;text-anchor=start">Queueing</text>
				   <rect x="{($graph_width)-($margin_right)+20}" y="{($margin_top)+96}" width="{10}" height="{6}" fill="bisque" stroke="black"/>
				   <xsl:choose>
					 <xsl:when test="$yval_max&gt;$cpu_count">
					   <line x1="{($margin_left)-5}" y1="{($graph_height)-($margin_bottom)-((($yval_min)-($cpu_count))*(100 div (($yval_min)-($yval_max))))}" x2="{($graph_width)-($margin_right)+5}" y2="{($graph_height)-($margin_bottom)-((($yval_min)-($cpu_count))*(100 div (($yval_min)-($yval_max))))}" style="stroke-dasharray: 9, 5;stroke:red;stroke-width:1" />
					   <text x="{($margin_left)+2}" y="{($graph_height)-($margin_bottom)-((($yval_min)-($cpu_count))*(100 div (($yval_min)-($yval_max))))-2}" style="fill:red; stroke: none;font-size:8px;text-anchor=start">CPU cores</text>
					 </xsl:when>
					 <xsl:otherwise>
					   <text x="{($margin_left)-38}" y="{($graph_height)-($margin_bottom)-93}" style="fill:red; stroke: none;font-size:6px;text-anchor=start"><xsl:value-of select="format-number((($yval_max) div ($cpu_count))*100,''00'')"/>% cpu cores</text>
					 </xsl:otherwise>
				   </xsl:choose>
				 </svg>
			   </xsl:template>
			 </xsl:stylesheet>'
				   )
		   )
		   )
		into v_contenido from dual;
		dbms_output.put_line(v_contenido.getClobVal);

		end;
	end loop;
end;
/
--prompt </div>




set markup html off
prompt <h1 id="20190706_131800">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Indexacion automatica
set termout off
prompt </h1>
prompt <p>Revisar la siguiente nota: <a href=https://blogs.oracle.com/oraclemagazine/autonomous-indexing>https://blogs.oracle.com/oraclemagazine/autonomous-indexing</a> </p>
set markup html on



set markup html off
prompt <h2 id="20190706_131801">
set termout on
prompt * DBA_AUTO_INDEX_EXECUTIONS
set termout off
prompt </h2>
prompt <p>The history of Automatic Indexing task executions</p>
set markup html on
select * from DBA_AUTO_INDEX_EXECUTIONS
;


set markup html off
prompt <h2 id="20190706_131802">
set termout on
prompt * DBA_AUTO_INDEX_STATISTICS
set termout off
prompt </h2>
prompt <p>Statistics related to automatic indexes</p>
set markup html on
select * from DBA_AUTO_INDEX_STATISTICS
;

set markup html off
prompt <h2 id="20190706_131803">
set termout on
prompt * DBA_AUTO_INDEX_IND_ACTIONS
set termout off
prompt </h2>
prompt <p>Actions performed on automatic indexes</p>
set markup html on
select * from DBA_AUTO_INDEX_IND_ACTIONS
;


set markup html off
prompt <h2 id="20190706_131804">
set termout on
prompt * DBA_AUTO_INDEX_SQL_ACTIONS
set termout off
prompt </h2>
prompt <p>Actions performed on SQL to verify automatic indexes</p>
set markup html on
select * from DBA_AUTO_INDEX_SQL_ACTIONS
;


set markup html off
prompt <h2 id="20190706_131805">
set termout on
prompt * DBA_AUTO_INDEX_CONFIG
set termout off
prompt </h2>
prompt <p>The history of configuration settings related to automatic indexes</p>
set markup html on
select * from DBA_AUTO_INDEX_CONFIG
;

set markup html off
prompt <h2 id="20190707_112700">
set termout on
prompt * DBA_AUTO_INDEX_VERIFICATIONS
set termout off
prompt </h2>
prompt <p>...</p>
set markup html on
select * from DBA_AUTO_INDEX_VERIFICATIONS
;

set markup html off
prompt <h2 id="20190707_110900">
set termout on
prompt * cdb_auto_index_config
set termout off
prompt </h2>
prompt <p>Estara informacion estara disponible solo si nos conectamos a una PDB. The CDB_AUTO_INDEX_CONFIG view displays the current automatic indexing configuration</p>
set markup html on
select * from cdb_auto_index_config
;




/*
select * from (
select * from Gv$backup_async_io
where FILENAME IN (select name from V$datafile)
order by OPEN_TIME desc
) where rownum <= 15 ;
*/

set markup html off
set heading on feedback on pagesize 20
prompt <h1 id="Backupsdebasesdedatos__HDg485ohkbjdy64">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Respaldo, seguridad y auditoria
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="as1722ujeqnqaq1wenwehqeh1_2737v_6">
set termout on
prompt * Bloques corruptos (GV$DATABASE_BLOCK_CORRUPTION)
set termout off
prompt </h2>
set markup html on
select * from GV$DATABASE_BLOCK_CORRUPTION
;



set markup html off
prompt <h2 id="dhf1837fhjftsgat_usuarios_rol_DBA">
set termout on
prompt * Usuarios con rol DBA
set termout off
prompt </h2>
set markup html on
select * from dba_users where username in (
select grantee
 from dba_role_privs
where granted_role = 'DBA'
)
;


set markup html off
prompt <h2 id="hasyqhd7Hgsagashy1hdu9jsd_jasjajs">
set termout on
prompt * Privilegios de sistema (dba_sys_privs)
set termout off
prompt </h2>
set markup html on
select * from dba_sys_privs
order by grantee, privilege
;


set markup html off
prompt <h2 id="AuditoriaDBA_STMT_AUDIT_OPTS_ajvnhashy2623hgs">
set termout on
prompt * Auditoria DBA_STMT_AUDIT_OPTS
set termout off
prompt </h2>
set markup html on
select * from DBA_STMT_AUDIT_OPTS;


set markup html off
prompt <h2 id="AuditoriaDBA_PRIV_AUDIT_OPTS_ajdsnvh63hf712sd">
set termout on
prompt * Auditoria DBA_PRIV_AUDIT_OPTS
set termout off
prompt </h2>
set markup html on
select * from DBA_PRIV_AUDIT_OPTS;


set markup html off
prompt <h2 id="EventosdeBackupsorestoreencolados__fjnm48657fhsgte">
set termout on
prompt * Respaldos encolados
set termout off
prompt </h2>
set markup html on
SELECT s.sid||','||s.serial#||'@'||s.INST_ID "session",p.SPID, sw.EVENT, sw.SECONDS_IN_WAIT AS SEC_WAIT, sw.STATE, CLIENT_INFO
FROM GV$SESSION_WAIT sw, GV$SESSION s, GV$PROCESS p
WHERE (lower(sw.EVENT)  LIKE '%sbt%' or lower(sw.EVENT)  LIKE '%backup%' or lower(sw.EVENT)  LIKE '%res%' or lower(sw.EVENT)  LIKE '%rman%' )
       AND s.SID=sw.SID AND s.PADDR=p.ADDR;


set markup html off
prompt <h2 id="EventosdeBackupsorestoreenprogreso__fhB45yrTgdtw12j">
set termout on
prompt * Respaldos en progreso
set termout off
prompt </h2>
set markup html on
select sid,serial# serial, inst_id,to_char(start_time,'dd/mm/yyyy hh24:mi') inicio, (sofar/totalwork) * 100 pct_avance,TRUNC((TIME_REMAINING/60)/60) || ':' || trunc(((TIME_REMAINING/60) - TRUNC((TIME_REMAINING/60)/60)*60))  hrs_termino,ELAPSED_SECONDS/60 min_pasados
 ,to_char(start_time+((TIME_REMAINING/60)+(ELAPSED_SECONDS/60))/1440,'dd/mm/yyyy hh24:mi') FIN_APROXIMADO,opname--,context--,message
 from   gv$session_longops
 where   totalwork > sofar
 AND (lower(opname) LIKE '%aggre%' or lower(opname) like '%rman%' or lower(opname) like '%input%' or lower(opname) like '%datafile%'  )
order by opname;
-- GB escritos y leidos en relacion a la cinta
select recid, output_device_type, input_bytes/1024/1024/1024 input_gbytes, output_bytes/1024/1024/1024 output_gbytes
     --, (output_bytes/input_bytes*100) compression
,(mbytes_processed/dbsize_mbytes*100) complete
     , to_char(start_time + (sysdate-start_time)/(mbytes_processed/dbsize_mbytes),'DD-MON-YYYY HH24:MI:SS') est_complete
  from v$rman_status rs
	, (select sum(bytes)/1024/1024 dbsize_mbytes from v$datafile)
 where status='RUNNING' and output_device_type is not null;


set markup html off
prompt <h2 id="Backupsfulldelosultimosdias_bj57328hcbBdger4">
set termout on
prompt * Ultimos Respaldos full
set termout off
prompt </h2>
set markup html on
SELECT  /*+ rule */
	(select instance_name from V$instance) instance_name
	,(select host_name from V$instance) host_name,
decode(b.incremental_level,0,'FULL','INCR')||'_Niv.'||b.incremental_level "RESPALDO" ,STATUS,
to_char(START_TIME,'yyyymmdd_hh24:mi') inicio,
to_char(END_TIME,'yyyymmdd_hh24:mi')   fin,
elapsed_seconds/3600                   hrs,
         input_bytes_display tamano_entrada,
         output_bytes_display tamano_salida,
        INPUT_BYTES_PER_SEC/1024/1024*60 avg_MbXmin_in,
        OUTPUT_BYTES_PER_SEC/1024/1024*60 avg_MbXmin_out
from V$RMAN_BACKUP_JOB_DETAILS r inner join
(
select /*+ rule */ distinct session_stamp, incremental_level from v$backup_set_details
) b on r.session_stamp = b.session_stamp
where start_time > sysdate -60
--and input_type='DB INCR'
and b.incremental_level=0
order by START_TIME DESC;


set markup html off
prompt <h2 id="Backupsdiferencialesincrementalesdelosultimosdias_fjbndh564">
set termout on
prompt * Ultimos Respaldos inc/diff
set termout off
prompt </h2>
set markup html on
SELECT  /*+ rule */
	(select instance_name from V$instance) instance_name
	,(select host_name from V$instance) host_name,
decode(b.incremental_level,0,'FULL','INCR')||'_Niv.'||b.incremental_level "RESPALDO" ,STATUS,
to_char(START_TIME,'yyyymmdd_hh24:mi') inicio,
to_char(END_TIME,'yyyymmdd_hh24:mi')   fin,
elapsed_seconds/3600                   hrs,
         input_bytes_display tamano_entrada,
         output_bytes_display tamano_salida,
        INPUT_BYTES_PER_SEC/1024/1024*60 avg_MbXmin_in,
        OUTPUT_BYTES_PER_SEC/1024/1024*60 avg_MbXmin_out
from V$RMAN_BACKUP_JOB_DETAILS r inner join
(
select /*+ rule */ distinct session_stamp, incremental_level from v$backup_set_details
) b on r.session_stamp = b.session_stamp
where start_time > sysdate -7
--and input_type='DB INCR'
and b.incremental_level>0
order by START_TIME DESC;


set markup html off
prompt <h2 id="Backupsdearchivelogsdelosultimosdias__fhvnb6ur9912">
set termout on
prompt * Ultimos Respaldos archivelog
set termout off
prompt </h2>
set markup html on
select /*+ rule */
	(select instance_name from V$instance) instance_name
	,(select host_name from V$instance) host_name
	,input_type ,STATUS,
	to_char(START_TIME,'yyyymmdd_hh24:mi') start_time,
	to_char(END_TIME,'yyyymmdd_hh24:mi')   end_time,
	elapsed_seconds/3600                   hrs,
		 input_bytes_display tamano_entrada,
		 output_bytes_display tamano_salida
	from V$RMAN_BACKUP_JOB_DETAILS r
   inner join(select distinct session_stamp,incremental_level from v$backup_set_details) b
   on r.session_stamp = b.session_stamp
	where input_type='ARCHIVELOG'
	--and incremental_level is not null
	--and 	r.start_time > sysdate - 30
	--and b.incremental_level = 0
	and start_time > sysdate -2
order by START_TIME DESC;

set markup html off
prompt <h2 id="BACKUP_ASYNC_IO_sj5737fHshdy12">
set termout on
prompt * GV$BACKUP_ASYNC_IO
set termout off
prompt </h2>
set markup html on



set markup html off
prompt <hr>
set markup html on


set markup html off
set heading on feedback on pagesize 20
prompt <h1 id="asdasdq173hgnbmalor9273hdbcvhyg62i_18373hans">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Golden Gate
set termout off
prompt </h1>
prompt <p>
prompt Informacion y detalle acerca de las vistas con supplemental log:
prompt <br><a href="https://docs.oracle.com/database/121/SUTIL/GUID-48D9DB83-BBC0-45EE-A81E-7CD047C908C1.htm#SUTIL1596">
prompt https://docs.oracle.com/database/121/SUTIL/GUID-48D9DB83-BBC0-45EE-A81E-7CD047C908C1.htm#SUTIL1596</a>
prompt </p>
set markup html on


set markup html off
prompt <h2 id="hasy1638fh_812_8273dbay1ndhs">
set termout on
prompt * Tamano streams pool integrated extract
set termout off
prompt </h2>
set markup html on
Select * from Gv$sga_dynamic_components where lower(component) = 'streams pool';



set markup html off
prompt <h2 id="18djdhahahshdh__981jdhahdgcs">
set termout on
prompt * Parametros BD de golden gate
set termout off
prompt </h2>
set markup html on
Select * from GV$parameter
where name like '%goldengate%'
;

set markup html off
prompt <h2 id="djdhaUrqese8PldjanagF16sgs72">
set termout on
prompt * Supplemental log habilitado a nivel de BD
set termout off
prompt </h2>
prompt <p>
prompt Informacion y detalle acerca de las vistas con supplemental log:
prompt <br><a href="https://docs.oracle.com/database/121/SUTIL/GUID-48D9DB83-BBC0-45EE-A81E-7CD047C908C1.htm#SUTIL1596">
prompt https://docs.oracle.com/database/121/SUTIL/GUID-48D9DB83-BBC0-45EE-A81E-7CD047C908C1.htm#SUTIL1596</a>
prompt </p>
set markup html on
select  force_logging,supplemental_log_data_min log_data_min,supplemental_log_data_pk log_data_pk
,supplemental_log_data_ui log_data_ui,supplemental_log_data_fk log_data_fk
,supplemental_log_data_all log_data_all,supplemental_log_data_pl log_data_pl from V$database
;

set markup html off
prompt <h2 id="3848f_auufisau37_q8hvbacbh58_21">
set termout on
prompt * Automatic Conflict Detection and Resolution (ALL_GG_AUTO_CDR_COLUMN_GROUPS)
set termout off
prompt </h2>
prompt <p>
prompt <br>vista ALL_GG_AUTO_CDR_COLUMN_GROUPS
prompt <br>vista ALL_GG_AUTO_CDR_TABLES 
prompt <br>vista ALL_GG_AUTO_CDR_COLUMNS 
prompt </p>
set markup html on

select * from ALL_GG_AUTO_CDR_COLUMN_GROUPS;

select * from ALL_GG_AUTO_CDR_TABLES ;

select * from ALL_GG_AUTO_CDR_COLUMNS ;


set markup html off
prompt <h2 id="201902191712">
set termout on
prompt * DBA_LOG_GROUPS
set termout off
prompt </h2>
set markup html on
select * from DBA_LOG_GROUPS
;


set markup html off
prompt <h2 id="201907022014_01">
set termout on
prompt * DBA_GG_INBOUND_PROGRESS
set termout off
prompt </h2>
set markup html on
select * from DBA_GG_INBOUND_PROGRESS
;

set markup html off
prompt <h2 id="201907022014_02">
set termout on
prompt * DBA_GOLDENGATE_INBOUND
set termout off
prompt </h2>
set markup html on
select * from DBA_GOLDENGATE_INBOUND
;

set markup html off
prompt <h2 id="201907022014_03">
set termout on
prompt * DBA_GOLDENGATE_PRIVILEGES
set termout off
prompt </h2>
set markup html on
select * from DBA_GOLDENGATE_PRIVILEGES
;


set markup html off
prompt <h2 id="201907022014_04">
set termout on
prompt * DBA_GOLDENGATE_RULES
set termout off
prompt </h2>
set markup html on
select * from DBA_GOLDENGATE_RULES
;


set markup html off
prompt <h2 id="201907022014_05">
set termout on
prompt * DBA_GOLDENGATE_SUPPORT_MODE
set termout off
prompt </h2>
set markup html on
/*
-- Informacion que por ahora no es necesaria pero que esta tomando mucho tiempo
select * from DBA_GOLDENGATE_SUPPORT_MODE
;
*/


set markup html off
prompt <h2 id="201907022014_06">
set termout on
prompt * CDB_GG_INBOUND_PROGRESS
set termout off
prompt </h2>
set markup html on
select * from CDB_GG_INBOUND_PROGRESS
;


set markup html off
prompt <h2 id="201907022014_07">
set termout on
prompt * CDB_GOLDENGATE_INBOUND
set termout off
prompt </h2>
set markup html on
select * from CDB_GOLDENGATE_INBOUND
;

set markup html off
prompt <h2 id="201907022014_08">
set termout on
prompt * CDB_GOLDENGATE_PRIVILEGES
set termout off
prompt </h2>
set markup html on
select * from CDB_GOLDENGATE_PRIVILEGES
;

set markup html off
prompt <h2 id="201907022014_09">
set termout on
prompt * CDB_GOLDENGATE_RULES
set termout off
prompt </h2>
set markup html on
select * from CDB_GOLDENGATE_RULES
;

set markup html off
prompt <h2 id="201907022014_10">
set termout on
prompt * CDB_GOLDENGATE_SUPPORT_MODE
set termout off
prompt </h2>
set markup html on
select * from CDB_GOLDENGATE_SUPPORT_MODE
;

set markup html off
prompt <h2 id="201907022014_12">
set termout on
prompt * DBA_CAPTURE
set termout off
prompt </h2>
set markup html on
select * from DBA_CAPTURE
;

set markup html off
prompt <h2 id="201907022014_13">
set termout on
prompt * CDB_CAPTURE
set termout off
prompt </h2>
set markup html on
select * from CDB_CAPTURE
;


set markup html off
prompt <h2 id="201907022014_14">
set termout on
prompt * DBA_APPLY
set termout off
prompt </h2>
set markup html on
select * from DBA_APPLY
;


set markup html off
prompt <h2 id="201907022014_15">
set termout on
prompt * CDB_APPLY
set termout off
prompt </h2>
set markup html on
select * from CDB_APPLY
;

set markup html off
prompt <h2 id="201907022014_16">
set termout on
prompt * GV_$GOLDENGATE_CAPABILITIES
set termout off
prompt </h2>
set markup html on
select * from GV_$GOLDENGATE_CAPABILITIES
;


set markup html off
prompt <h2 id="201907022014_17">
set termout on
prompt * GV_$GOLDENGATE_CAPTURE
set termout off
prompt </h2>
set markup html on
select * from GV_$GOLDENGATE_CAPTURE
;


set markup html off
prompt <h2 id="201907022014_18">
set termout on
prompt * GV_$GOLDENGATE_MESSAGETRACKING
set termout off
prompt </h2>
set markup html on
select * from GV_$GOLDENGATE_MESSAGETRACKING
;


set markup html off
prompt <h2 id="201907022014_19">
set termout on
prompt * GV_$GOLDENGATE_TABLE_STATS
set termout off
prompt </h2>
set markup html on
select * from GV_$GOLDENGATE_TABLE_STATS
;

set markup html off
prompt <h2 id="201907022014_20">
set termout on
prompt * GV_$GOLDENGATE_TRANSACTION
set termout off
prompt </h2>
set markup html on
select * from GV_$GOLDENGATE_TRANSACTION
;






set markup html off
prompt <hr>
set markup html on


set markup html off
set heading on feedback on pagesize 20
prompt <h1 id="17whdays_1837fhn_oajshqh">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Flashback Logs y Restore Points
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="usnhahs_o18238hbdy_sjshans12">
set termout on
prompt * Restore Point Creados (V$RESTORE_POINT)
set termout off
prompt </h2>
set markup html on
select *  FROM V$RESTORE_POINT
;




set markup html off
set heading on feedback on pagesize 20
prompt <h1 id="hHgshahsdhau17dydgatGags__ajushdyahqywdga56">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set termout on
prompt Scripts de creacion de interes
set termout off
prompt </h1>
set markup html on

set markup html off
prompt <br>
prompt <h2 id="OHgshahsdhau17dydgatGags__ajushdyahqywdga13">
set define on
set termout on
prompt * Script de creacion de tablespaces 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
set heading off termout off
set markup html off
set define on
--col script_source format a120
prompt <p style=font-family:courier;color:#3463D0>
prompt <pre>

set feedback off
SET SERVEROUTPUT ON SIZE UNLIMITED
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',false);
execute DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
exec DBMS_METADATA.SET_TRANSFORM_PARAM (DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE',FALSE);
exec DBMS_METADATA.SET_TRANSFORM_PARAM (DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES',TRUE);
set long 2000000 longchunksize 2000000 pagesize 0 linesize 1000 feedback off verify off trimspool on
select 
--replace(replace(replace(replace(DBMS_METADATA.get_ddl('TABLESPACE',tablespace_name),' ','&espacio_en_blanco'),chr(10),'</br>'),',',',</br>'),';',';</br>')||'</br></br>' script_source 
DBMS_METADATA.get_ddl('TABLESPACE',tablespace_name) script_source 
from dba_tablespaces
where lower('&rescatar_scripts') = 's'
order by tablespace_name
; 
prompt </pre>
prompt </p>
set feedback on




set markup html off
prompt <br>
prompt <h2 id="19duuyauhashhy1uwhdahywd1udhhbdashghqw__182">
set define on
set termout on
prompt * Script de creacion de usuarios 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
set heading off termout off
set markup html off
set define on
--col script_source format a120
prompt <p style=font-family:courier;color:#3463D0>
prompt <pre>

set feedback off
SET SERVEROUTPUT ON SIZE UNLIMITED
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',false);
execute DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
exec DBMS_METADATA.SET_TRANSFORM_PARAM (DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE',FALSE);
exec DBMS_METADATA.SET_TRANSFORM_PARAM (DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES',TRUE);
set long 2000000 longchunksize 2000000 pagesize 0 linesize 1000 feedback off verify off trimspool on
select 
--replace(replace(replace(DBMS_METADATA.get_ddl('USER',username),' ','&espacio_en_blanco'),chr(10),'</br>'),',',',</br>')||'</br></br>' script_source 
DBMS_METADATA.get_ddl('USER',username) script_source
from dba_users
where lower('&rescatar_scripts') = 's'
order by username
; 
prompt </pre>
prompt </p>
set feedback on





set markup html off
prompt <br>
prompt <h2 id="u1udhdhy_ajsdnha_kasjci81_jsjcHHagd_jasncah">
set define on
set termout on
prompt * Script de creacion de db_links 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
set heading off termout off
set markup html off
set define on
--col script_source format a120
prompt <p style=font-family:courier;color:#3463D0>
prompt <pre>

set feedback off
SET SERVEROUTPUT ON SIZE UNLIMITED
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',false);
execute DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
exec DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE',FALSE);
exec DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES',TRUE);
set long 2000000 longchunksize 2000000 pagesize 0 linesize 1000 feedback off verify off trimspool on
select 
--replace(replace(replace(DBMS_METADATA.get_ddl('DB_LINK',db_link,owner),' ','&espacio_en_blanco'),chr(10),'</br>'),',',',</br>')||'</br></br>' script_source
DBMS_METADATA.get_ddl('DB_LINK',db_link,owner) script_source
from dba_db_links
where lower('&rescatar_scripts') = 's'
order by owner,db_link
; 
prompt </pre>
prompt </p>

set feedback on


set markup html off
set define on
prompt <p>
prompt  *********************************************<br>
prompt  * Comentarios o sugerencias a los correos:  <br>
prompt  * felipe.donoso@oracle.com                  <br>
prompt  * felipe@felipedonoso.cl                    <br>
prompt  *********************************************
prompt </p>
prompt <p>
prompt  * Fecha de ejecucion del reporte: &f_completa
prompt </p>


prompt			</div>
prompt		</main>

spool off
set termout on
set define on
prompt  
prompt  ~~~~~~~~~~~ FIN DEL REPORTE ~~~~~~~~~~~
prompt  * Abrir el archivo siguiente con un explorador que soporte html5: 
prompt  &page_start
prompt  *********************************************
prompt  * Comentarios o sugerencias a los correos:  *
prompt  * felipe.donoso@oracle.com                  *
prompt  * felipe@felipedonoso.cl                    * 
prompt  *********************************************
prompt  

-- reseteamos todas las configuraciones
@clear

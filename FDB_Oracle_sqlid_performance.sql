/*****************************************************************************************
 *
 * @author: Felipe Donoso Bastias, correos: felipe.donoso@oracle.com, felipe@felipedonoso.cl  
 *          (cualquier modificacion al script enviar mail)
 * @date  : 2017-02-18
 * @desc  : Permite obtener el rendimiento historico y estadisticas
 *			de performance para un sqlid en particular
 *			como las lecturas, escrituras, planes de ejecucion etc..
 * @param : Recibe como parametro el SQLID a investigar
 * @obs   : Se debe ejecutar con usuario de que pueda acceder
 *			 a todas las vistas del diccionario:
 *			 (o en lo posible ejecutar con usuario con rol DBA)      
 *
 *			Ejemplo de ejecucion:
 *			@FDB_Oracle_sqlid_performance  7fkm8ustbzdbt
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
 * @mod   : 2017-06-17 con el fin de evitar ver errores en los graficos numeros con el
 *          codigo: NaN se anade lo siguiente:
 *         ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. ';
 *
 *****************************************************************************************/

-- reseteamos todas las configuraciones
@clear
--clear scr

WHENEVER SQLERROR CONTINUE



set feedback off termout on 
--exec dbms_lock.sleep( 1 );
prompt  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
prompt  * Iniciando reporte de rendimiento para SQL_ID en particular   *
prompt  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
column fecha new_value f
select to_char(sysdate,'yyyymmdd_hh24mi') fecha from dual
;

column fecha_completa new_value f_completa
select to_char(sysdate,'dd-mm-yyyy hh24:mi') fecha_completa from dual
;

column solo_anio new_value anio
select to_char(sysdate,'yyyy') solo_anio from dual
;

column f_ini_2 new_value f2
select to_char(sysdate-15,'yyyymmdd_hh24mi') f_ini_2 from dual
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

/**************************************************************
 * Variables a definir y que daran nombre a los archivos      *
 *                                                            *
 **************************************************************/

--prompt Ingrese valor para el SQL_ID a revisar:
--define sqlid = &1
-- DIAS DE HISTORIA A INVESTIGAR en sqlid Import	ante este parametro
-- definira el comportamiento para todas las querys historicas
--define dias_de_historia="15"

--prompt Ingrese valor para el numero de dias a revisar:
--define dias_de_historia= &2
set termout on
set define on
accept sqlid char default &1 prompt '* ingrese el SQL_ID a analizar (Default &1):  '
accept fecha_ini_awr char default &f2 prompt '* Fecha INI de datos de AWR [yyyymmdd_hh24mi] (Default &2):  '
accept fecha_fin_awr char default &f prompt '* Fecha FIN de datos de AWR [yyyymmdd_hh24mi] (Default &3):  '

-- Esto es para los espacios en blanco no modificar
-- Es para visualizar correctamente y formateado
-- los planes de ejecucion en el reporte HTML
set define off
define espacio_en_blanco = "&nbsp;"
set define on

define page_start  =FDB_Oracle_sqlid_performance_&sqlid._bd_&h._&d._&i._&f..html
define page_index  =&page_start
define page_body   =&page_start

set termout on
prompt  
prompt  ~~~~~~~~~~~ INICIO DEL REPORTE ~~~~~~~~~~~
prompt  * Al finalizar el script abrir el siguiente archivo con explorador web
prompt  * que soporte HTML5:
prompt  * &page_start
prompt  
set termout off
set termout off
--exec dbms_lock.sleep( 3 );

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
set define on
prompt <TITLE>Rendimiento de sqlid &sqlid Base de datos &d</TITLE> 
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


prompt <br>* Rendimiento sql_id: &sqlid<br>* BD: &d <br>* Rol: &d_role<br>* Server: &h<br>* Plataforma: &d_platform<br>* &d_cores  &d_sockets <br>* Memoria: &d_memoria <br>* Version BD: &d_version <br>
prompt <br>Tildes omitidos intencionalmente<br>* Fecha ejecucion reporte:
prompt <br>* &f_completa<br>
prompt <br>Comentarios y sugerencias a:
prompt <br>* felipe.donoso@oracle.com
prompt <br>* felipe@felipedonoso.cl<br>
prompt  <h3 id="indice"><i>Indice:</i></h3>

--prompt <details>
--prompt <summary>
prompt <a    href="&page_body#qwquwqeuqweu172ygfbasksu17y2hajdajsda7127">+[RESUMEN QUERY &sqlid]</a></br>
--prompt </summary>
	prompt ... <a    href="&page_body#832jfnc10385mbvsspai3_183hfnshdy2nben"  >... Texto de la consulta</a></br>
    prompt ... <a    href="&page_body#1hHNgays761ghdTTqgqPPoajmsCch16371612"  >... Resumen de rendimiento de cada plan de ejecucion</a></br>
	prompt ... <a    href="&page_body#17123uqhaduyqhuqwdyy71274hfbmnauq712yhd">... Resumen general (por hora)</a></br>
	prompt ... <a    href="&page_body#3736ryqhfnbpoismvbj8iaj10284hfhwue_3j2" >... Resumen general (por dias)</a></br>
	prompt ... <a    href="&page_body#18duajMNhashdj__oaisnu1u3f8djhachayPia" >... dba_sql_plan_baselines</a></br>
--prompt </details>
prompt <hr>

prompt <a    href="&page_body#81238uqweujadjasdhasnqweuqwejasnczmxcmzxcjasjdnczjasd">+[PLANES DE EJECUCION]</a></br>
--prompt </summary>
	prompt ... <a    href="&page_body#918273haha67qhhhajd81hdhadnvls028rvhvnurtyetcvsks">... dbms_xplan.display_cursor</a></br>
	prompt ... <a    href="&page_body#1uUhahsgBag1y3hd810Ljahsn_aksuqshanaBhabh128hsh1h">... dbms_xplan.display_cursor(all last) ultima ejecucion</a></br>
	prompt ... <a    href="&page_body#uqwydhbvm1827rhfpamancja8173bhcgatwh17wgd"        >... dbms_xplan.display_awr</a></br>
--prompt </details>
prompt <hr>

prompt <a    href="&page_body#71236123yfgcsbsc_jshd61hgdg">+[REAL-TIME SQL MONITORING (BETA)]</a></br>
--prompt </summary>
	prompt ... <a    href="&page_body#17dhvnvbioy84h_272hdh_17dhvnb">... DBMS_SQLTUNE.report_sql_monitor</a></br>
--prompt </details>
prompt <hr>


prompt <a    href="&page_body#17dhGsgt16fkfa9_ajsnduy1heuy172a">+[VARIABLES BIND]</a></br>
--prompt </summary>
	prompt ... <a    href="&page_body#1ncjahmfpP_skJKhshG162_sjcfbvgBgst">... Bind utilizados </a></br>
--prompt </details>
prompt <hr>


--prompt <br>



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
prompt * Reporte de Rendimiento SQL_ID: &sqlid
prompt * Base de datos : &d , Servidor: &h 
set termout off
prompt <br>
set termout on
prompt * Este reporte tiene por objetivo mostrar el rendimiento
prompt * de una consulta en particular usando como fuente de informacion 
prompt * vistas de performance y de AWR.
set termout off
prompt <br><br>
set termout on
prompt 
set termout off
prompt <br>
set termout on
prompt Fecha: &f_completa
set termout off

prompt <br>
set termout on
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

set markup html off
prompt <h1 id="qwquwqeuqweu172ygfbasksu17y2hajdajsda7127">
set define on
set termout on
prompt RENDIMIENTO QUERY SQL_ID: &sqlid
set termout off
set define off
prompt </h1>
set markup html on

set markup html off
prompt <h2 id="832jfnc10385mbvsspai3_183hfnshdy2nben">
set define on
set termout on
prompt * Texto de la consulta con sqlid : &sqlid
set termout off
set define off
prompt </h2>
set markup html off
set heading off
set define on
set feedback off
set pages 0
col sql_text heading sql_text word_wrapped justify right format A80
prompt <p style=font-family:courier;color:#3463D0;font-weight:bold>
prompt <pre>
select dbms_lob.substr(sql_text, 4000, 1) sql_text from DBA_HIST_SQLTEXT where sql_id = '&sqlid' and rownum = 1
;
set feedback on
prompt </pre>
prompt </p>
prompt <br>
set feedback on



set markup html off
set pages 20
prompt <h2 id="1hHNgays761ghdTTqgqPPoajmsCch16371612">
set define on
set termout on
prompt * Resumen de rendimiento de cada plan de ejecucion (GV$SQL y dba_hist_sqlstat) para  sqlid &sqlid.
set termout off
prompt Usando como rango de horarios: &fecha_ini_awr y &fecha_fin_awr
set define off
prompt </h2>
prompt <p>
prompt <B>Estadisticas desde el ULTIMO REINICIO DEL MOTOR (GV$SQL Ordenadas por el plan mas eficiente en elapsed_time)</B>
prompt <br>El campo avg_ET_exec_(ms)_parall_query es solo valido para indicar el tiempo REAL de las consultas que se ejecutaron con parallel, pues el elapsed time en ese caso es inexacto. 
prompt <br>En este aspecto revisar script de Kerry Osborn, fsx.sql, ahi se explica lo siguiente:
prompt <br>(Note that the AVG_ETIME will not be acurate for parallel queries. The ELAPSED_TIME column contains the sum of all parallel slaves. So the script divides the value by the number of PX slaves used which gives an approximation)
prompt <br>Es decir el elapsed time es el valor acumulativo para todos los slaves, ojo con eso.
prompt <br>
prompt <br>Otro aspecto a tener en cuenta para los exadata es el valor de:
prompt <br><i>"columns that define the volume of data that may be saved by Offloading (IO_CELL_OFFLOAD_ELIGIBLE_BYTES) and the volume of data that was actually returned by the storage servers (IO_INTERCONNECT_BYTES)"</i>
prompt <br>Fuente de la informacion: Libro "Expert Oracle Exadata" de Tanel Poder, pagina 30.
prompt <br>
prompt </p>
set markup html on
set heading on
set define on
set feedback on
SELECT  sql_id
       ,plan_hash_value
       ,sql_profile
       ,child_number
       , executions
       ,round((elapsed_time)*0.001*0.001,2) "ET_total_(seg)"
       ,round((elapsed_time)/(greatest(executions,1))*0.001,2) "avg_ET_exec_(ms)"--,round((elapsed_time)/(greatest(executions,1))/1e6,2) "avg_ET_exec_(sec)"
       ,round((elapsed_time)/decode(nvl(executions,0),0,1,executions)/
decode(px_servers_executions,0,1,px_servers_executions/decode(nvl(executions,0),0,1,executions))*0.001,2) "avg_ET_exec_(ms)_parall_query"
       ,round((cpu_time)*0.001*0.001,2) "CPU_TOTAL_(seg)"
       ,round((cpu_time)/(greatest(executions,1))*0.001,2) "avg_CPU_exec_(ms)"   --,round((cpu_time)/(greatest(executions,1))/1e6,2) "avg_CPU_exec_(sec)"
       ,round((USER_IO_WAIT_TIME)/(greatest(executions,1))*0.001,2) "avg_IOw_exec_(ms)"      --,round((USER_IO_WAIT_TIME)/(greatest(executions,1))/1e6,2) "avg_IOw_exec_(sec)"
       ,round(IO_CELL_OFFLOAD_ELIGIBLE_BYTES/1024/1024,2) IO_CELL_OFFLOAD_ELIG_TOTAL_MB
       ,round(IO_INTERCONNECT_BYTES/1024/1024,2) IO_INTERCONNECT_TOTAL_MB
        ,round((IO_CELL_OFFLOAD_ELIGIBLE_BYTES)/(greatest((executions),1))/1024/1024,2) IO_CELL_OFFLOAD_ELIG_EXEC_MB
       ,round((IO_INTERCONNECT_BYTES)/(greatest((executions),1))/1024/1024,2) IO_INTERCONNECT_EXEC_MB 
       ,100*round(((IO_CELL_OFFLOAD_ELIGIBLE_BYTES-IO_INTERCONNECT_BYTES)/decode(IO_CELL_OFFLOAD_ELIGIBLE_BYTES,0,1,IO_CELL_OFFLOAD_ELIGIBLE_BYTES)),5) "IO_SAVED_APROX_%"
       ,round((cpu_time) * 100 /  greatest((elapsed_time),1),2) "%_total_time_in_CPU"
       ,round((USER_IO_WAIT_TIME) * 100 /  greatest((elapsed_time),1),2) "%_total_time_in_IO"
       ,100 
       - round((cpu_time) * 100 /  greatest((elapsed_time),1),2) - round((USER_IO_WAIT_TIME) * 100 /  greatest((elapsed_time),1),2) "%_total_time_in_others"
  FROM GV$SQL
 WHERE sql_id = TRIM('&sqlid')
 --  AND executions > 0
 --GROUP BY
 --      sql_id,plan_hash_value,sql_profile,IO_CELL_OFFLOAD_ELIGIBLE_BYTES,IO_INTERCONNECT_BYTES
  order by 6 asc
;

set markup html off
prompt <B>Estadisticas HISTORICAS totales (dba_hist_sqlstat) para el rango de horarios entre: &fecha_ini_awr y &fecha_fin_awr </B>
set markup html on
with sn as (select /*+ materialize */ snap_id from dba_hist_snapshot
        where 
        		(begin_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR end_interval_time >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
          and 	(begin_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR end_interval_time <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
)
SELECT  sql_id
       ,plan_hash_value
       ,sql_profile
       ,sum(executions_delta) executions
       ,round(SUM(elapsed_time_delta)*0.001*0.001,2) "ET_TOTAL_(seg)"
       ,round(SUM(elapsed_time_delta)/(greatest(sum(executions_delta),1))*0.001,2) "avg_ET_exec_(ms)"
       ,round(SUM(cpu_time_delta)*0.001*0.001,2) "CPU_TOTAL_(seg)"
       ,round(SUM(cpu_time_delta)/(greatest(sum(executions_delta),1))*0.001,2) "avg_CPU_exec_(ms)"   
       ,round(SUM(iowait_delta)/(greatest(sum(executions_delta),1))*0.001,2) "avg_IOw_exec_(ms)"      
       ,round(sum(IO_OFFLOAD_ELIG_BYTES_DELTA)/1024/1024,2) IO_CELL_OFFLOAD_ELIG_TOTAL_MB
       ,round(sum(IO_INTERCONNECT_BYTES_DELTA)/1024/1024,2) IO_INTERCONNECT_TOTAL_MB 
       ,round(sum(IO_OFFLOAD_ELIG_BYTES_DELTA)/(greatest(sum(executions_delta),1))/1024/1024,2) IO_CELL_OFFLOAD_ELIG_EXEC_MB
       ,round(sum(IO_INTERCONNECT_BYTES_DELTA)/(greatest(sum(executions_delta),1))/1024/1024,2) IO_INTERCONNECT_EXEC_MB 
       --,round(decode(sum(IO_OFFLOAD_ELIG_BYTES_DELTA),0,0,100*(sum(IO_OFFLOAD_ELIG_BYTES_DELTA)-sum(IO_INTERCONNECT_BYTES_DELTA))
       --  /decode(sum(IO_OFFLOAD_ELIG_BYTES_DELTA),0,1,sum(IO_OFFLOAD_ELIG_BYTES_DELTA))),2) "IO_SAVED_%"
       ,100*round(((sum(IO_OFFLOAD_ELIG_BYTES_DELTA)-sum(IO_INTERCONNECT_BYTES_DELTA))/decode(sum(IO_OFFLOAD_ELIG_BYTES_DELTA),0,1,sum(IO_OFFLOAD_ELIG_BYTES_DELTA))),5) "IO_SAVED_APROX_%"
       ,round(SUM(cpu_time_delta) * 100 /  greatest(sum(elapsed_time_delta),1),2) "%_total_time_in_CPU"
       ,round(SUM(iowait_delta) * 100 /  greatest(sum(elapsed_time_delta),1),2) "%_total_time_in_IO"
       ,100 
       - round(SUM(cpu_time_delta) * 100 /  greatest(sum(elapsed_time_delta),1),2) - round(SUM(cpu_time_delta) * 100 /  greatest(sum(elapsed_time_delta),1),2) "%_total_time_in_others"
       FROM dba_hist_sqlstat sql1, sn
 WHERE sql_id = TRIM('&sqlid')
 and sql1.snap_id = sn.snap_id
   AND executions_delta > 0
 GROUP BY
       sql_id,plan_hash_value,sql_profile
 order by 5 asc
;
set feedback on


set pages 20
set heading on
set markup html off
prompt <h2 id="17123uqhaduyqhuqwdyy71274hfbmnauq712yhd">
set define on
set termout on
prompt * Resumen general para &sqlid agrupado por hora, para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr
set termout off
set define off
prompt </h2>
prompt <p>
prompt Atención con lo siguiente respecto a las <b>Optimized Read Request</b>:
prompt <br>(<b>Source</b>: How to Interpret the "SQL ordered by Physical Reads (UnOptimized)" Section in AWR Reports (11.2 onwards) for Smart Flash Cache Database (Doc ID 1466035.1) ) 
prompt <br><i>What are 'Optimized Read Reqs'?
prompt <br>Optimized Read Requests are read requests that are satisfied from the Smart Flash Cache ( or the Smart Flash Cache in OracleExadata V2).
prompt <br><b>Note:</b> that despite same name, concept and use of  'Smart Flash Cache' in Exadata V2 is different from  'Smart Flash Cache' in Database Smart Flash Cache.</i>
prompt <br>
prompt <br> Con respecto a las <b>Physical Reads de AWR</b> estas representan al número de bloques leidos NO a las operaciones I/O eso lo diferencian de otras métricas como Optimized Read Request que si se refieren en ese caso a Operaciones I/O.
prompt </p>
set markup html on

set define on
SELECT /*+ rule */
  to_char(sn.begin_interval_time,'yyyymmdd_hh24mi') datetime_yyyymmddhhmi
  ,sql1.sql_id                            sql_id
  --,sql1.instance_number                   instance_number
  --,sql1.dbid                              dbid
  --,sql1.optimizer_cost                    optimizer_cost
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            "____modulo_o_programa____"
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions_delta
  ,sum(sql1.rows_processed_delta)              rows_processed_delta
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_process_x_exec_delta
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ET_TIME_DELTA(S)"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ET_TIME_X_EXEC_DELTA(MS)"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_DELTA(S)"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_DELTA(MS)"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets_delta
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec_delta
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec_delta
  --
   ,sum(sql1.physical_read_requests_delta)      physical_read_requests_delta
  ,round(sum(sql1.physical_read_requests_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) physical_read_requests_exec
  ,sum(sql1.optimized_physical_reads_delta)    optimized_physical_reads_delta
  ,round(sum(sql1.optimized_physical_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) optimized_physical_reads_exec
  ,sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta)    UNoptim_physical_reads_delta
  ,round((sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta)) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) Unoptim_physical_reads_exec
  --
  ,sum(sql1.sorts_delta)                       sorts_delta       
  ,sum(sql1.fetches_delta)                     fetches_delta
  ,sum(sql1.direct_writes_delta)               direct_writes_delta        
  --,sum(sql1.physical_read_bytes_delta)         physical_read_bytes        
  --,sum(sql1.physical_write_bytes_delta)        physical_write_bytes
  --,sum(sql1.physical_write_requests_delta)     physical_write_requests
  --,sum(sql1.cell_uncompressed_bytes_delta)     cell_uncompressed_bytes
  ,round(sum(sql1.io_offload_elig_bytes_delta)/1024/1024,2)       io_offload_elig_MB_delta
  ,round(sum(sql1.IO_OFFLOAD_ELIG_BYTES_DELTA)/(greatest(sum(sql1.executions_delta),1))/1024/1024,2) IO_CELL_OFFLOAD_ELIG_EXEC_MB
  ,round(sum(sql1.io_interconnect_bytes_delta)/1024/1024,2)       io_interconnect_MB_delta
  ,round(sum(sql1.IO_INTERCONNECT_BYTES_DELTA)/(greatest(sum(sql1.executions_delta),1))/1024/1024,2) IO_INTERCONNECT_EXEC_MB     
  ,sum(sql1.io_offload_return_bytes_delta)     io_offload_return_bytes_delta
  --
  --
  ,sum(sql1.apwait_delta)                      apwait_delta
  ,sum(sql1.ccwait_delta)                      ccwait_delta
  ,sum(sql1.clwait_delta)                      clwait_delta
  ,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count_delta
  ,sum(sql1.invalidations_delta)               invalidations_delta
  ,sum(sql1.iowait_delta)                      iowait_delta
  ,sum(sql1.javexec_time_delta)                javexec_time_delta
  ,sum(sql1.loads_delta)                       loads_delta
  ,sum(sql1.parse_calls_delta)                 parse_calls_delta
  ,sum(sql1.plsexec_time_delta)               plsexec_time_delta
  ,sum(sql1.px_servers_execs_delta)            px_servers_execs_delta
  --,dbms_lob.substr(st.sql_text,3000,1)        sql_text_full
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn--, DBA_HIST_SQLTEXT st
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  --AND   st.sql_id = sql1.sql_id AND   st.dbid = sql1.dbid AND   st.dbid = sn.dbid 
  and  sql1.sql_id='&sqlid'
  --and sn.begin_interval_time  > sysdate-2  
  and   (sn.BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  and   (sn.BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by 
  to_char(sn.begin_interval_time,'yyyymmdd_hh24mi') 
  ,sql1.sql_id                            
  ,sql1.module                            
  --,sql1.instance_number                   
  --,sql1.dbid                              
  --,sql1.optimizer_cost                    
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  order by 1 desc,2,3
  ;

set pages 20
set markup html off
prompt <h2 id="3736ryqhfnbpoismvbj8iaj10284hfhwue_3j2">
set define on
set termout on
prompt * Resumen general para &sqlid agrupado por dia, para rangos de fechas entre: &fecha_ini_awr y &fecha_fin_awr
set termout off
set define off
prompt </h2>
set markup html on
set define on
SELECT /*+ rule */
  to_char(sn.begin_interval_time,'yyyymmdd') datetime_yyyymmddhhmi
  ,sql1.sql_id                            sql_id
  --,sql1.instance_number                   instance_number
  --,sql1.dbid                              dbid
  --,sql1.optimizer_cost                    optimizer_cost
  ,sql1.plan_hash_value                   plan_hash_value
  ,sql1.module                            "____modulo_o_programa____"
  ,sql1.optimizer_mode                    optimizer_mode
  ,sql1.SQL_PROFILE                       SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME               PARSING_SCHEMA_NAME
  ,round(avg(sql1.SHARABLE_MEM)/1024,2)        KB_SHARABLE_MEM
  ,sum(sql1.executions_delta)                  executions_delta
  ,sum(sql1.rows_processed_delta)              rows_processed_delta
  ,round(sum(sql1.rows_processed_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) rows_process_x_exec_delta
  ,sum(round(sql1.elapsed_time_delta/1000000,2))                "ET_TIME_DELTA(S)"
  ,round(sum(sql1.elapsed_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "ET_TIME_X_EXEC_DELTA(MS)"
  ,sum(round(sql1.cpu_time_delta/1000000,2))                    "CPU_TIME_DELTA(S)"
  ,round(sum(sql1.cpu_time_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) / 1000 ,2) "CPU_TIME_X_EXEC_DELTA(MS)"        
  ,sum(sql1.buffer_gets_delta)                 buffer_gets_delta
  ,round(sum(sql1.buffer_gets_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) buffer_gets_x_exec_delta
  ,sum(sql1.disk_reads_delta)                 disk_reads
  ,round(sum(sql1.disk_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) disk_reads_x_exec_delta
  --
   ,sum(sql1.physical_read_requests_delta)      physical_read_requests_delta
  ,round(sum(sql1.physical_read_requests_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) physical_read_requests_exec
  ,sum(sql1.optimized_physical_reads_delta)    optimized_physical_reads_delta
  ,round(sum(sql1.optimized_physical_reads_delta) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) optimized_physical_reads_exec
  ,sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta)    UNoptim_physical_reads_delta
  ,round((sum(sql1.physical_read_requests_delta) - sum(sql1.optimized_physical_reads_delta)) / decode(sum(sql1.executions_delta),0,1,sum(sql1.executions_delta)) ,2) Unoptim_physical_reads_exec
  --
  ,sum(sql1.sorts_delta)                       sorts_delta       
  ,sum(sql1.fetches_delta)                     fetches_delta
  ,sum(sql1.direct_writes_delta)               direct_writes_delta        
  --,sum(sql1.physical_read_bytes_delta)         physical_read_bytes        
  --,sum(sql1.physical_write_bytes_delta)        physical_write_bytes
  --,sum(sql1.physical_write_requests_delta)     physical_write_requests
  --,sum(sql1.cell_uncompressed_bytes_delta)     cell_uncompressed_bytes
  ,round(sum(sql1.io_offload_elig_bytes_delta)/1024/1024,2)       io_offload_elig_MB_delta
  ,round(sum(sql1.IO_OFFLOAD_ELIG_BYTES_DELTA)/(greatest(sum(sql1.executions_delta),1))/1024/1024,2) IO_CELL_OFFLOAD_ELIG_EXEC_MB
  ,round(sum(sql1.io_interconnect_bytes_delta)/1024/1024,2)       io_interconnect_MB_delta
  ,round(sum(sql1.IO_INTERCONNECT_BYTES_DELTA)/(greatest(sum(sql1.executions_delta),1))/1024/1024,2) IO_INTERCONNECT_EXEC_MB     
  ,sum(sql1.io_offload_return_bytes_delta)     io_offload_return_bytes_delta
  --
  --
  ,sum(sql1.apwait_delta)                      apwait_delta
  ,sum(sql1.ccwait_delta)                      ccwait_delta
  ,sum(sql1.clwait_delta)                      clwait_delta
  ,sum(sql1.end_of_fetch_count_delta)          end_of_fetch_count_delta
  ,sum(sql1.invalidations_delta)               invalidations_delta
  ,sum(sql1.iowait_delta)                      iowait_delta
  ,sum(sql1.javexec_time_delta)                javexec_time_delta
  ,sum(sql1.loads_delta)                       loads_delta
  ,sum(sql1.parse_calls_delta)                 parse_calls_delta
  ,sum(sql1.plsexec_time_delta)               plsexec_time_delta
  ,sum(sql1.px_servers_execs_delta)            px_servers_execs_delta
  --,dbms_lob.substr(st.sql_text,3000,1)        sql_text_full
FROM  dba_hist_sqlstat sql1,  dba_hist_snapshot sn--, DBA_HIST_SQLTEXT st
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
  --AND   st.sql_id = sql1.sql_id AND   st.dbid = sql1.dbid AND   st.dbid = sn.dbid 
  and  sql1.sql_id='&sqlid'
  --and sn.begin_interval_time  > sysdate-2  
  and   (sn.BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  and   (sn.BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
 having sum(sql1.executions_delta) > 0  
group by 
  to_char(sn.begin_interval_time,'yyyymmdd') 
  ,sql1.sql_id                            
  ,sql1.module                            
  --,sql1.instance_number                   
  --,sql1.dbid                              
  --,sql1.optimizer_cost                    
  ,sql1.plan_hash_value                  
  ,sql1.optimizer_mode
  ,sql1.SQL_PROFILE
  ,sql1.PARSING_SCHEMA_NAME
  order by 1 desc,2,3
  ;



set pages 20
set markup html off
prompt <h2 id="18duajMNhashdj__oaisnu1u3f8djhachayPia">
set define on
set termout on
prompt * Lineas bases (dba_sql_plan_baselines) para sqlid: &sqlid
set termout off
set define off
prompt </h2>
set markup html on
set define on
select * from dba_sql_plan_baselines
where SQL_HANDLE like '%&sqlid%' or PLAN_NAME like '%&sqlid%'
order by 2,4
;











set heading on
set markup html off
prompt <h1 id="81238uqweujadjasdhasnqweuqwejasnczmxcmzxcjasjdnczjasd">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set define on
set termout on
prompt PLANES DE EJECUCION PARA SQL_ID: &sqlid
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="918273haha67qhhhajd81hdhadnvls028rvhvnurtyetcvsks">
set define on
set termout on
prompt * Planes de ejecucion (dbms_xplan.display_cursor)
set termout off
set define off
prompt </h2>
prompt <p>
prompt Poner atencion con respecto a los TABLE ACCESS STORAGE FULL en los Exadatas:
prompt <br>(es un extracto del siguiente link): <a href="https://www.oracle.com/technetwork/testcontent/o31exadata-354069.html">https://www.oracle.com/technetwork/testcontent/o31exadata-354069.html</a> 
prompt <br><i>"As you can see, Oracle Exadata storage indexes do not locate the areas of the table that contain the values of interest to the user; rather, they identify the areas that definitely will not contain the values, thus eliminating them from I/O processing. In a manner of speaking, they act as negative indexes, just the opposite of traditional database indexes, which are for locating not eliminating the database blocks that may contain the information."
prompt <br>"Storage indexes are not stored on disk; they are resident in the memory of the storage cell servers. They are created automatically after the storage cells receive repeated queries with predicates for columns. No user intervention is needed to create or maintain storage indexes. And because they are memory resident structures, they disappear when the storage cells are rebooted."</i>
prompt <br>
prompt <br>Revisar en el reporte MTV_Reporte_HTML_RDBMS que los parametros esten configurados asi:
prompt <br>* cell_offload_processing=true
prompt <br>* _kcfis_storageidx_disabled=false
prompt <br>Un dato importante a tener en cuenta es que si vemos en los planes el uso de STORAGE keyword significa que el smart scan es posible hacerlo pero que NO garantiza que se este llevando a cabo (mucho ojo con eso)
prompt <br>
prompt <br>Es importante tener en cuenta lo siguiente para los ambientes de exadata (fuente de informacion libro PDF: Oracle__________Tanel_Poder_Expert_Oracle_Exadata_.pdf):
prompt <br>Los <b>3 niveles de Optimizacion del Smart Scan</b> en Exadata se compone de:
prompt <br>1.- Column Projection
prompt <br>2.- Predicate Filtering
prompt <br>3.- Storage Index 
prompt <br>
prompt <br>El "Column Projection" permite limitar el volumen de datos a transferir desde el storage tier hacia el database tier, retornando solo las columnas de interes (las usadas en la clausula select y las necesarias para efectos del Join).
prompt <br>El "Predicate Filtering" en ambientes Exadadatas  (el retorno de las filas que sólo sean necesarias) durante el smart scan se realiza a nivel de de las celdas. En ambientes NO Exadadatas, El "Predicate Filtering" (el retorno de las filas que sólo sean necesarias) se realiza a nivel de Database Tier.
prompt <br>El "Storage Index" es una estructura de memoria que vive a nivel de celda exadata y mantiene los valores maximos y minimos por cada 1 MB de unidad de disco por hasta 8 columnas en una tabla (Es un verdadero mapa que permite eliminar regiones de busqueda en disco, es un índice pero inverso en vez de ayudar a ver que datos son los necesarios, el storage index indica que datos o regiones de disco no son necesarias para nuestra consulta). Estan disenados para reducir el tiempo que permanece la celda leyendo datos desde disco fisico.
prompt <br>
prompt <br>Para una mejor compresion de los planes consultar libro <b><i>"Troubleshooting Oracle Performance, Christian Atonigni"</i></b> Pagina 209, descripcion de un plan de ejecucion y pagina  224 (figura 6-3) para explicar la estructura de un plan y en que orden leer el plan.
prompt </p>

set markup html off
set heading off
set define on
-- verlo sin awr
--set pagesize 999 lines 500	
col plan_table_output format a220
set pages 0
prompt <p style=font-family:courier;color:#3463D0>
prompt <pre>
--version de Felipe Donoso
/*
select replace(replace(replace(plan_table_output,' ','&espacio_en_blanco')||'<br>',
	 'TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'STORAGE'||'&espacio_en_blanco'||'FULL'
		 ,'<b style=color:red>TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'STORAGE'||'&espacio_en_blanco'||'FULL</b>')
	,	 'TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'FULL'
		 ,'<b style=color:red>TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'FULL</b>') 
from TABLE(GV$(CURSOR(
select plan_table_output from
table(dbms_xplan.display_cursor('&sqlid',null,'ADVANCED ALLSTATS LAST')))))
;
*/
-- version de carlos sierra:
/*
SELECT RPAD('Inst: '||v.inst_id, 9)||' '||RPAD('Child: '||v.child_number, 11) inst_child, replace(replace(replace(plan_table_output,' ','&espacio_en_blanco')||'<br>',
	 'TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'STORAGE'||'&espacio_en_blanco'||'FULL'
		 ,'<b style=color:red>TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'STORAGE'||'&espacio_en_blanco'||'FULL</b>')
	,	 'TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'FULL'
		 ,'<b style=color:red>TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'FULL</b>')
 FROM gv$sql v,
 TABLE(DBMS_XPLAN.DISPLAY('gv$sql_plan_statistics_all', NULL, 'ADVANCED ALLSTATS LAST', 'inst_id = '||v.inst_id||' AND sql_id = '''||v.sql_id||''' AND child_number = '||v.child_number)) t
 WHERE v.sql_id = '&sqlid.'
 AND v.loaded_versions > 0;
 */

SELECT RPAD('Inst: '||v.inst_id, 9)||' '||RPAD('Child: '||v.child_number, 11) inst_child, plan_table_output
 FROM gv$sql v,
 TABLE(DBMS_XPLAN.DISPLAY('gv$sql_plan_statistics_all', NULL, 'ADVANCED ALLSTATS LAST', 'inst_id = '||v.inst_id||' AND sql_id = '''||v.sql_id||''' AND child_number = '||v.child_number)) t
 WHERE v.sql_id = '&sqlid.'
 AND v.loaded_versions > 0;

prompt </pre>
prompt </p>



set markup html off
prompt <h2 id="1uUhahsgBag1y3hd810Ljahsn_aksuqshanaBhabh128hsh1h">
set define on
set termout on
prompt * Planes de ejecucion  dbms_xplan.display_cursor(all last) ULTIMA EJECUCION
set termout off
set define off
prompt </h2>
set markup html off
set heading off
set define on
--set pagesize 999 lines 500
col plan_table_output format a220
prompt <p style=font-family:courier;color:#3463D0>
prompt <pre>
/*
select replace(replace(replace(plan_table_output,' ','&espacio_en_blanco')||'<br>',
	 'TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'STORAGE'||'&espacio_en_blanco'||'FULL'
		 ,'<b style=color:red>TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'STORAGE'||'&espacio_en_blanco'||'FULL</b>')
	,	 'TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'FULL'
		 ,'<b style=color:red>TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'FULL</b>')
from table (dbms_xplan.display_cursor('&sqlid',null,'all last'))
; */
select plan_table_output
from table (dbms_xplan.display_cursor('&sqlid',null,'all last'))
;
prompt </pre>
prompt </p>



set markup html off
prompt <h2 id="uqwydhbvm1827rhfpamancja8173bhcgatwh17wgd">
set define on
set termout on
prompt * Planes de ejecucion (dbms_xplan.display_awr)
set termout off
set define off
prompt </h2>
set markup html off
set heading off
set define on
--set pagesize 999 lines 500
col plan_table_output format a220
prompt <p style=font-family:courier;color:#3463D0>
prompt <pre>
/*
select replace(replace(replace(plan_table_output,' ','&espacio_en_blanco')||'<br>',
	 'TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'STORAGE'||'&espacio_en_blanco'||'FULL'
		 ,'<b style=color:red>TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'STORAGE'||'&espacio_en_blanco'||'FULL</b>')
	,	 'TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'FULL'
		 ,'<b style=color:red>TABLE'||'&espacio_en_blanco'||'ACCESS'||'&espacio_en_blanco'||'FULL</b>')
from table (dbms_xplan.display_awr('&sqlid',null,null,'ALL'))
;
*/
select plan_table_output
from table (dbms_xplan.display_awr('&sqlid',null,null,'ALL'))
;
prompt </pre>
prompt </p>






set heading on
set markup html off
prompt <h1 id="71236123yfgcsbsc_jshd61hgdg">
set termout on
prompt _________________________________________________________
set termout off
prompt <br>
set define on
set termout on
prompt REAL-TIME SQL MONITORING PARA SQL_ID: &sqlid (aun por terminar)
set termout off
prompt </h1>
set markup html on


set markup html off
prompt <h2 id="17dhvnvbioy84h_272hdh_17dhvnb">
set define on
set termout on
prompt * DBMS_SQLTUNE.report_sql_monitor
set termout off
set define off
prompt </h2>
set markup html off
set heading off
set define on
-- verlo sin awr
set pagesize 9999 lines 5000	
col report format a5000 WORD_WRAPPED
prompt <p style=font-family:courier;color:#3463D0>

-- estas opciones son necesarias sino la funcion 
-- report_sql_monitor mostrara solo algunos caracteres
SET LONG 1000000000
SET LONGCHUNKSIZE 1000000000

/*
SELECT replace(replace(
			DBMS_SQLTUNE.report_sql_monitor(
  				sql_id       => '&sqlid',
  				type         => 'TEXT',
  				report_level => 'ALL'),chr(10),'<br>'
  		),' ','&espacio_en_blanco') AS report
FROM dual
;
*/

/*
select * from (
SELECT 
			substr(DBMS_SQLTUNE.report_sql_monitor(
  				sql_id       => '&sqlid',
  				type         => 'TEXT',
  				report_level => 'ALL'),0,4000) AS report
FROM dual)
;

SELECT 
			DBMS_SQLTUNE.report_sql_monitor(
  				sql_id       => '&sqlid',
  				type         => 'TEXT',
  				report_level => 'ALL') AS report
FROM dual
;


SELECT DBMS_SQLTUNE.report_sql_monitor(
  				sql_id       => '&sqlid',
  				type         => 'HTML',
  				report_level => 'ALL') AS plan_table_output
FROM dual
;
*/

prompt </p>

set pages 20
set markup html off
prompt <h1 id="17dhGsgt16fkfa9_ajsnduy1heuy172a">
set define on
set termout on
prompt _________________________________________________________
prompt <br>
prompt VARIABLES BIND PARA SQL_ID: &sqlid
set termout off
set define off
prompt </h1>
set markup html on

set markup html off
prompt <h2 id="1ncjahmfpP_skJKhshG162_sjcfbvgBgst">
set define on
set termout on
prompt * Variables Bind ocupados para sqlid : &sqlid durante periodo de fechas entre: &fecha_ini_awr y &fecha_fin_awr
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on

select to_char(sn.begin_interval_time,'yyyymmdd_hh24mi') datetime_yyyymmdd_hh24mi
 ,sql1.instance_number
 ,SQL1.SQL_ID
 ,SQL1.NAME
 ,sql1.position
 ,sql1.dup_position
 ,sql1.datatype
 ,sql1.datatype_string
 ,sql1.character_sid
 ,sql1.precision
 ,sql1.scale
 ,sql1.max_length
 ,sql1.was_captured
 ,sql1.last_captured
 ,sql1.value_string
from dba_hist_sqlbind sql1, dba_hist_snapshot sn
WHERE sn.snap_id  =sql1.snap_id AND  sn.dbid=sql1.dbid AND   sn.instance_number=sql1.instance_number
and  sql1.sql_id='&sqlid'
  and   (sn.BEGIN_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi') OR sn.END_INTERVAL_TIME >= to_date('&fecha_ini_awr','yyyymmdd_hh24mi'))
  and   (sn.BEGIN_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi') OR sn.END_INTERVAL_TIME <= to_date('&fecha_fin_awr','yyyymmdd_hh24mi'))
--group by 
--  to_char(sn.begin_interval_time,'yyyymmdd_hh24mi')
order by 1, sql1.instance_number,sql1.position
;

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
prompt  * &page_start
prompt  
prompt  *********************************************
prompt  * Comentarios o sugerencias a los correos:  *
prompt  * felipe.donoso@oracle.com                  *
prompt  * felipe@felipedonoso.cl                    * 
prompt  *********************************************
prompt  

-- reseteamos todas las configuraciones
@clear

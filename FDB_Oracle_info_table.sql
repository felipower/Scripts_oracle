/*****************************************************************************************
 *
 * @author: Felipe Donoso Bastias, correos: felipe.donoso@oracle.com, felipe@felipedonoso.cl  
 *          (cualquier modificacion al script enviar mail)
 * @date  : 2017-02-18
 * @desc  : Permite obtener informacion de las tablas y sus indices
 *			como las columnas que componen un indice en particular
 *			, estadisticas, histogramas, etc..
 *
 * @param : Recibe como parametro el owner y la tabla a investigar
 * @obs   : Se debe ejecutar con usuario de que pueda acceder
 *			 a todas las vistas del diccionario:
 *			 (o en lo posible ejecutar con usuario con rol DBA)      
 *
 *			Ejemplo de ejecucion:
 *			@MTV_Reporte_HTML_INF_TABLAS_INDICES <OWNER> <TABLA>
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
prompt  * Iniciando reporte de informacion de tabla en particular      *
prompt  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--exec dbms_lock.sleep( 1 );

prompt          *********************************************
prompt          * Comentarios o sugerencias a los correos:  *
prompt			* felipe@felipedonoso.cl                    *
prompt          * felipe.donoso@oracle.com                  * 
prompt          *********************************************
prompt  
--exec dbms_lock.sleep( 2 );
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

prompt Ingrese el owner de la tabla a revisar:
define owner = &1
-- DIAS DE HISTORIA A INVESTIGAR en sqlid Import	ante este parametro
-- definira el comportamiento para todas las querys historicas
--define dias_de_historia="15"
prompt Ingrese el nombre de la tabla:
define tabla= &2

-- Esto es para los espacios en blanco no modificar
-- Es para visualizar correctamente y formateado
-- los planes de ejecucion en el reporte HTML
set define off
define espacio_en_blanco = "&nbsp;"
set define on

define page_start  =FDB_Oracle_info_table_&owner._&tabla._bd_&h._&d._&i._&f..html
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
exec dbms_lock.sleep( 3 );

set feedback off heading off VERIFY    off




/**************************************************************
 * Creacion de la hoja de estilo para el reporte              *
 *                                                            *
 **************************************************************/
SPOOL ON ENTMAP ON PREFORMAT OFF
set pagesize 50
set serveroutput on size unlimited
SET VERIFY    off



spool &page_start

set markup html off
set define off 
prompt <html>


prompt <head>
set define on
prompt <TITLE>Propiedades de la tabla &tabla y sus indices. Base de datos &d</TITLE> 
set define off
prompt <STYLE type='text/css'> 
prompt html, body {height:100%;} 
prompt html {display:table; width:100%;} 
prompt body {display:table-cell; text-align:left; vertical-align:top;counter-reset: section;} 
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
prompt counter-reset: subsection; /* */
prompt } /* */
prompt h1::before { /* */
prompt   counter-increment: section; /* */
prompt   content: "Section " counter(section) ": "; /* */
prompt } /* */
prompt h2{  /* */
prompt font-family: verdana, arial, sans-serif; /* */
prompt color:#6E6E6E; /* */
prompt font-size:13px; /* */
prompt } /* */
prompt h2::before { /* */
prompt   counter-increment: subsection; /* */
prompt   content: counter(section) "." counter(subsection) " "; /* */
prompt } /* */
prompt h4{  /* */
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


prompt <br>Propiedades de tabla: &owner..&tabla <br>* BD: &d <br>* Rol: &d_role<br>* Server: &h<br>* Plataforma: &d_platform<br>* &d_cores  &d_sockets <br>* Memoria: &d_memoria <br>* Version BD: &d_version <br>
prompt <br>Tildes omitidos intencionalmente<br>* Fecha ejecucion reporte:
prompt <br>* &f_completa<br>
prompt <br>Comentarios y sugerencias a:
prompt <br>* felipe.donoso@oracle.com
prompt <br>* felipe@felipedonoso.cl<br>
prompt  <h3 id="indice"><i>Indice:</i></h3>

--prompt <details>
--prompt <summary>
prompt <a    href="&page_body#qwquwqeuqweu172ygfbasksu17y2hajdajsda7127">+[INFO &owner...&tabla]</a></br>
--prompt </summary>
	prompt ... <a    href="&page_body#17dhasgyq7dy_91jen_7dhcbvoausna">dba_objects</a></br>
	prompt ... <a    href="&page_body#81hdhah_sudbvnue73_id92udjsjsnd">dba_tables</a></br>
	prompt ... <a    href="&page_body#9vny26_ducnsgs62_18hs_jfnuhhdu1">dba_indexes</a></br>
	prompt ... <a    href="&page_body#18fjvn_kvnahspqoeur_qunmajd162d">dba_tab_partitions</a></br>
	prompt ... <a    href="&page_body#nvnajdu481y_ua__iasnau172_un1u2">dba_ind_partitions</a></br>
	prompt ... <a    href="&page_body#yashgBGbasgs6gwtdgatwgdy12gdbGg">dba_triggers</a></br>
	prompt ... <a    href="&page_body#182jdHyahshGGGfstagst2dasjsdOOj">dba_constraints</a></br>
	prompt ... <a    href="&page_body#ajashd61hBBBsfsvTqrwasfasf1273V">dba_synonyms</a></br>
	prompt ... <a    href="&page_body#hdhBgatq_jsuq_2736_fhGdtg_jasqu">dba_dependencies</a></br>
	prompt ... <a    href="&page_body#1udjahsyBhagsyqh26dgFcposHhqsha">dba_tab_privs</a></br>
	prompt ... <a    href="&page_body#20191212_1214">dba_role_privs</a></br>
	prompt ... <a    href="&page_body#18wdyHgaysgqy27dgPoajsnbbasbabs">dba_tab_comments</a></br>
	prompt ... <a    href="&page_body#jdhahYgagsy162gdhahJhahsn_kajsi">dba_tab_columns</a></br>
	prompt ... <a    href="&page_body#1ydhGatsgcblaisjJsjauhdy6172dha">dba_tab_modifications</a></br>
	prompt ... <a    href="&page_body#udHhsydhUoqdpamNhasnahs12dhaHha">dba_tab_statistics</a></br>
	prompt ... <a    href="&page_body#82M_kajsjasu_ajssjufjhUyqwh_qhw">dba_ind_statistics</a></br>
	prompt ... <a    href="&page_body#17HgsgBcUqodoeuH12945827273182J">dba_tab_col_statistics</a></br>
	prompt ... <a    href="&page_body#y16dt1627392348Ghanhshayh2b1723">dba_tab_stat_prefs</a></br>
	prompt ... <a    href="&page_body#81827BBhashyqie__kasjj817237172">dba_tab_stats_history</a></br>
	prompt ... <a    href="&page_body#81737Gtqgdy173gdHhgas__jasjsh1u">dba_tab_histograms</a></br>
	prompt ... <a    href="&page_body#judha7172y36dtdgGfas__jasuqu9fd">dbms_stats.get_prefs</a></br>
--prompt </details>
prompt <hr>


prompt <a    href="&page_body#18237hahsgTgatsgKiaushGgats152">+[TAMANOS: &tabla]</a></br>
--prompt </summary>
	prompt ... <a    href="&page_body#172hdh_akjs81734hdgah_ajsh1h212">Tamano tabla</a></br>
	prompt ... <a    href="&page_body#83udha_nvnbvhgsgabGtsfsrqytPjwq">Tamano indices</a></br>
	prompt ... <a    href="&page_body#182jfhYgstag152ggadtaPiahsnfiOi">Tamano particiones</a></br>
--prompt </details>
prompt <hr>

prompt <a    href="&page_body#182h_sjfbbahtqYtqreThjhsbag12lkasjs_218">+[SCRIPTS (DBMS_METADATA.GET_DDL)]</a></br>
--prompt </summary>
	prompt ... <a    href="&page_body#kfj_kfjjJuhsgGfsyt_17dhsgat">Script de la tabla</a></br>
	prompt ... <a    href="&page_body#18dhJhahUhasTgsjhMnVcxvC125">Script de indices (normales y particionados)</a></br>
	prompt ... <a    href="&page_body#udHuqytEqwQasDeqdsrer1423da">Script de triggers</a></br>
	prompt ... <a    href="&page_body#18djdhahsJuahsy16gdFfsfFsfy">Script de constraints</a></br>
	prompt ... <a    href="&page_body#ushYgsgdtVmKp183___jashhquw">Script de objetos relacionados (dba_dependencies)</a></br>
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
prompt * Reporte de informacion de tabla: &owner.&tabla
prompt * Base de datos : &d , Servidor: &h 
set termout off
prompt <br>
set termout on
prompt * Este reporte tiene por objetivo mostrar la informacion
prompt *  de una tabla en particular (estadisticas, histogramas
prompt * , particiones, indices, etc..)
prompt *
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
prompt INFORMACION DE &owner..&tabla 
set termout off
set define off
prompt </h1>
set markup html on


set markup html off
prompt <br>
prompt <h2 id="17dhasgyq7dy_91jen_7dhcbvoausna">
set define on
set termout on
prompt * Objetos de la tabla como indices, particiones, etc.. (DBA_OBJECTS)
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_OBJECTS
where (owner = '&owner' and OBJECT_name = '&tabla')
union all
select * from DBA_OBJECTS
where (owner,object_name) in
    (
        select owner,index_name from dba_indexes
        where table_owner = '&owner' and table_name = '&tabla'
    )
;

set feedback on


set markup html off
prompt <br>
prompt <h2 id="81hdhah_sudbvnue73_id92udjsjsnd">
set define on
set termout on
prompt * Informacion de &owner..&tabla (DBA_TABLES) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_TABLES
where owner = '&owner' and table_name = '&tabla'
order by owner,table_name
;
set feedback on



set markup html off
prompt <br>
prompt <h2 id="9vny26_ducnsgs62_18hs_jfnuhhdu1">
set define on
set termout on
prompt * Indices &owner..&tabla (DBA_INDEXES) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_INDEXES
where table_owner = '&owner' and table_name = '&tabla'
order by owner,table_name,index_name
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="18fjvn_kvnahspqoeur_qunmajd162d">
set define on
set termout on
prompt * Particiones &owner..&tabla (DBA_TAB_PARTITIONS) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_TAB_PARTITIONS
where table_owner = '&owner' and table_name = '&tabla'
order by table_owner,table_name,partition_name
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="nvnajdu481y_ua__iasnau172_un1u2">
set define on
set termout on
prompt * Indices particionados &owner..&tabla (DBA_IND_PARTITIONS)
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_IND_PARTITIONS
where (index_owner,index_name) in
    (
        select owner,index_name from dba_indexes
        where table_owner = '&owner' and table_name = '&tabla'
    )
order by index_owner,index_name,partition_name
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="yashgBGbasgs6gwtdgatwgdy12gdbGg">
set define on
set termout on
prompt * Triggers &owner..&tabla (DBA_TRIGGERS) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_TRIGGERS
where table_owner = '&owner' and table_name = '&tabla'
order by owner, table_name,trigger_name
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="182jdHyahshGGGfstagst2dasjsdOOj">
set define on
set termout on
prompt * Constraints  &owner..&tabla (DBA_CONSTRAINTS) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_CONSTRAINTS
where owner = '&owner' and table_name = '&tabla'
order by owner, table_name,constraint_name
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="ajashd61hBBBsfsvTqrwasfasf1273V">
set define on
set termout on
prompt * Sinonimos &owner..&tabla (DBA_SYNONYMS) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_SYNONYMS
where table_owner = '&owner' and table_name = '&tabla'
order by table_owner, table_name
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="hdhBgatq_jsuq_2736_fhGdtg_jasqu">
set define on
set termout on
prompt * Referencias tabla: &owner..&tabla (dba_dependencies) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_dependencies
where referenced_owner = '&owner'
and referenced_name = '&tabla'
;
set feedback on



set markup html off
prompt <br>
prompt <h2 id="1udjahsyBhagsyqh26dgFcposHhqsha">
set define on
set termout on
prompt * Privilegios sobre &owner..&tabla (dba_tab_privs) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_tab_privs
where owner = '&owner'
and table_name = '&tabla'
order by 1,2
;


set markup html off
prompt <br>
prompt <h2 id="20191212_1214">
set define on
set termout on
prompt * Usuarios con roles asignados (dba_role_privs) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_role_privs
where granted_role in (
select grantee from dba_tab_privs
where owner = '&owner'
and table_name = '&tabla'
)
;



set markup html off
--set term off
--prompt <br>
prompt <h2 id="18wdyHgaysgqy27dgPoajsnbbasbabs">
set define on
set termout on
prompt * Comentarios sobre &owner..&tabla (dba_tab_comments) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_TAB_COMMENTS
where owner = '&owner'
and table_name = '&tabla'
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="jdhahYgagsy162gdhahJhahsn_kajsi">
set define on
set termout on
prompt * Columnas de &owner..&tabla (dba_tab_columns) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_tab_columns
where owner = '&owner'
and table_name = '&tabla'
;
set feedback on

set markup html off
prompt <br>
prompt <h2 id="1ydhGatsgcblaisjJsjauhdy6172dha">
set define on
set termout on
prompt * Modificaciones realizadas y % de cambios en &owner..&tabla (dba_tab_modifications) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from DBA_TAB_MODIFICATIONS
where table_owner = '&owner'
and table_name = '&tabla'
;
SELECT t.owner,t.table_name, m.partition_name, m.subpartition_name, t.monitoring,m.timestamp, m.inserts, m.updates, m.deletes,(m.inserts + m.updates + m.deletes) nb_modif, t.num_rows,
round(((m.inserts + m.updates + m.deletes)*100)/greatest(t.num_rows,1),2) percent_modif, t.last_analyzed
FROM dba_tab_modifications m, dba_tables t
WHERE t.table_name=m.table_name (+)
AND t.table_name = '&tabla' and t.owner = '&owner'
AND t.num_rows > 0
ORDER BY t.last_analyzed DESC
;
set feedback on



set markup html off
prompt <br>
prompt <h2 id="udHhsydhUoqdpamNhasnahs12dhaHha">
set define on
set termout on
prompt * Estadisticas de  &owner..&tabla (dba_tab_statistics) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_tab_statistics
where owner = '&owner'
and table_name = '&tabla'
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="82M_kajsjasu_ajssjufjhUyqwh_qhw">
set define on
set termout on
prompt * Estadisticas de indices en &owner..&tabla (dba_ind_statistics) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_ind_statistics
where table_owner = '&owner'
and table_name = '&tabla'
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="17HgsgBcUqodoeuH12945827273182J">
set define on
set termout on
prompt * Estadisticas de columnas &owner..&tabla (dba_tab_col_statistics) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_tab_col_statistics
where owner = '&owner'
and table_name = '&tabla'
;
set feedback on



set markup html off
prompt <br>
prompt <h2 id="y16dt1627392348Ghanhshayh2b1723">
set define on
set termout on
prompt * Ultima opcion usada en estadisticas &owner..&tabla (dba_tab_stat_prefs) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_tab_stat_prefs
where owner = '&owner'
and table_name = '&tabla'
;
set feedback on



set markup html off
prompt <br>
prompt <h2 id="81827BBhashyqie__kasjj817237172">
set define on
set termout on
prompt * Ultimas fechas de estadisticas &owner..&tabla (dba_tab_stats_history) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_tab_stats_history
where owner = '&owner'
and table_name = '&tabla'
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="81737Gtqgdy173gdHhgas__jasjsh1u">
set define on
set termout on
prompt * Histogramas de columnas &owner..&tabla (dba_tab_histograms) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select * from dba_tab_histograms
where owner = '&owner'
and table_name = '&tabla'
;
set feedback on


set markup html off
set term off
prompt <br>
prompt <h2 id="judha7172y36dtdgGfas__jasuqu9fd">
set define on
set termout on
prompt * Opciones y configuraciones  &owner..&tabla (dbms_stats.get_prefs) 
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select   dbms_stats.get_prefs('AUTOSTATS_TARGET', '&owner', '&tabla') AUTOSTATS_TARGET 
         ,dbms_stats.get_prefs('CASCADE', '&owner', '&tabla') CASCADE 
         ,dbms_stats.get_prefs('CONCURRENT', '&owner', '&tabla') CONCURRENT 
         ,dbms_stats.get_prefs('DEGREE', '&owner', '&tabla') DEGREE
         ,dbms_stats.get_prefs('ESTIMATE_PERCENT', '&owner', '&tabla') ESTIMATE_PERCENT
         ,dbms_stats.get_prefs('METHOD_OPT', '&owner', '&tabla') METHOD_OPT 
         ,dbms_stats.get_prefs('NO_INVALIDATE', '&owner', '&tabla') NO_INVALIDATE 
         ,dbms_stats.get_prefs('GRANULARITY', '&owner', '&tabla') GRANULARITY
         ,dbms_stats.get_prefs('PUBLISH', '&owner', '&tabla') PUBLISH 
         ,dbms_stats.get_prefs('INCREMENTAL', '&owner', '&tabla') INCREMENTAL 
         ,dbms_stats.get_prefs('STALE_PERCENT', '&owner', '&tabla') STALE_PERCENT
         ,dbms_stats.get_prefs('TABLE_CACHED_BLOCKS', '&owner', '&tabla') TABLE_CACHED_BLOCKS
         -- Estas variables son para 12c
         --,dbms_stats.get_prefs('INCREMENTAL_STALENESS', '&owner', '&tabla') INCREMENTAL_STALENESS
         --,dbms_stats.get_prefs('INCREMENTAL_LEVEL', '&owner', '&tabla') INCREMENTAL_LEVEL
         --,dbms_stats.get_prefs('GLOBAL_TEMP_TABLE_STATS', '&owner', '&tabla') GLOBAL_TEMP_TABLE_STATS
         --,dbms_stats.get_prefs('OPTIONS', '&owner', '&tabla') OPTIONS 
from dual
;

set define on
set termout off
prompt Estas son las configuraciones GLOBALES de la base de datos
set termout off
set define off

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

set feedback on




set markup html off
prompt <h1 id="18237hahsgTgatsgKiaushGgats152">
set define on
set termout on
prompt TAMANO TABLA, INDICES Y PARTICIONES  &owner..&tabla 
set termout off
set define off
prompt </h1>
set markup html on


set markup html off
prompt <br>
prompt <h2 id="172hdh_akjs81734hdgah_ajsh1h212">
set define on
set termout on
prompt * Tamano tabla
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select owner,segment_name table_name,segment_type , round(sum(bytes)/1024/1024,2) MB
from dba_segments
where owner = '&owner'
and segment_name = '&tabla'
group by owner,segment_name,segment_type
;
set feedback on


set markup html off
prompt <br>
prompt <h2 id="83udha_nvnbvhgsgabGtsfsrqytPjwq">
set define on
set termout on
prompt * Tamano Indices
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select owner,segment_name index_name,segment_type,partition_name , round(sum(bytes)/1024/1024,2) MB
from dba_segments
where (owner,segment_name) in 
(
    select owner,index_name from dba_indexes
    where table_owner = '&owner' and table_name = '&tabla' 
)
group by owner,segment_name,segment_type,partition_name
order by owner,segment_name,partition_name
;
set feedback on

set markup html off
prompt <br>
prompt <h2 id="182jfhYgstag152ggadtaPiahsnfiOi">
set define on
set termout on
prompt * Tamano Particiones
set termout off
set define off
prompt </h2>
set markup html on
set heading on
set define on
set feedback on
select owner,segment_name table_name,partition_name,segment_type , round(sum(bytes)/1024/1024,2) MB
from dba_segments
where (owner,segment_name,partition_name) in 
(
    select table_owner,table_name,partition_name from dba_tab_partitions
    where table_owner = '&owner' and table_name = '&tabla' 
)
group by owner,segment_name,partition_name,segment_type
order by owner,segment_name,partition_name
;
set feedback on






set markup html off
prompt <h1 id="182h_sjfbbahtqYtqreThjhsbag12lkasjs_218">
set define on
set termout on
prompt SCRIPTS RELACIONADO A TABLA &owner..&tabla 
set termout off
set define off
prompt </h1>
set markup html on


set markup html off
prompt <br>
prompt <h2 id="kfj_kfjjJuhsgGfsyt_17dhsgat">
set define on
set termout on
prompt * Script tabla &owner..&tabla (DBMS_METADATA.get_ddl)
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
--select replace(DBMS_METADATA.get_ddl('TABLE','&tabla','&owner'),', ',', </br>') script_source from dual; 
select DBMS_METADATA.get_ddl('TABLE','&tabla','&owner') script_source from dual; 

prompt </pre>
prompt </p>


set markup html off
prompt <br>
prompt <h2 id="18dhJhahUhasTgsjhMnVcxvC125">
set define on
set termout on
prompt * Scripts indices y particionados &owner..&tabla (DBMS_METADATA.get_ddl)
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
--select replace(replace(DBMS_METADATA.get_ddl('INDEX',INDEX_NAME,OWNER),' ','&espacio_en_blanco'),chr(10),'</br>')||'</br>' script_source from dba_indexes
select DBMS_METADATA.get_ddl('INDEX',INDEX_NAME,OWNER) script_source from dba_indexes
where table_owner = '&owner' and table_name = '&tabla'
order by index_name
; 
prompt </pre>
prompt </p>




set markup html off
prompt <br>
prompt <h2 id="udHuqytEqwQasDeqdsrer1423da">
set define on
set termout on
prompt * Script de triggers &owner..&tabla (DBMS_METADATA.get_ddl)
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
--select replace(replace(DBMS_METADATA.get_ddl('TRIGGER',TRIGGER_NAME,OWNER),' ','&espacio_en_blanco'),chr(10),'</br>')||'</br></br>' script_source from DBA_TRIGGERS
select DBMS_METADATA.get_ddl('TRIGGER',TRIGGER_NAME,OWNER) script_source from DBA_TRIGGERS
where table_owner = '&owner' and table_name = '&tabla'
order by trigger_name
;
prompt </pre>
prompt </p>

set markup html off
prompt <br>
prompt <h2 id="18djdhahsJuahsy16gdFfsfFsfy">
set define on
set termout on
prompt * Script de constraints : &owner..&tabla (DBMS_METADATA.get_ddl)
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
--select replace(replace(DBMS_METADATA.get_ddl('CONSTRAINT',CONSTRAINT_NAME,OWNER),' ','&espacio_en_blanco'),chr(10),'</br>')||'</br>' script_source from DBA_CONSTRAINTS
select DBMS_METADATA.get_ddl('CONSTRAINT',CONSTRAINT_NAME,OWNER) script_source from DBA_CONSTRAINTS
where owner = '&owner' and table_name = '&tabla'
order by CONSTRAINT_NAME
;
prompt </pre>
prompt </p>


set markup html off
prompt <br>
prompt <h2 id="ushYgsgdtVmKp183___jashhquw">
set define on
set termout on
prompt * Script objetos relacionados (packages, etc.) segun dba_dependencies (DBMS_METADATA.get_ddl)
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
set long 2000000 longchunksize 2000000 pagesize 0 linesize 5000 feedback off verify off trimspool on
--select replace(replace(DBMS_METADATA.get_ddl(replace(TYPE,' ','_'),NAME,OWNER),chr(32),'&espacio_en_blanco'),chr(10),'</br>')||'</br></br></br></br>' script_source from dba_dependencies
select DBMS_METADATA.get_ddl(replace(TYPE,' ','_'),NAME,OWNER) script_source from dba_dependencies
where referenced_owner = '&owner' and referenced_name = '&tabla'
order by owner,name,TYPE
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

#!/bin/bash

# Verifica argumentos

if ! [ $# -eq 4 ];then

        echo
        echo " Entre com a area (metarea5, antartica, etc.), o horario de simulacao \
(00, 12), o prognostico (00, 03, 06, etc.) e o tempo de integracao (24, 48, 72, 96, etc.). "
        echo

        exit 10
fi

export WRF_EM_CORE=1
export WRF_NMM_CORE=0
export WRF_DA_CORE=0
export WRFIO_NCD_LARGE_FILE_SUPPORT=1

ulimit -s unlimited
ulimit -v unlimited

#source /opt/intel/intel_2018/bin/compilervars.sh intel64

export -f module
module use /usr/share/modules/modulefiles
#mpt=`cat $HOME/wrf/invariantes/mpt_versao | head -1`
#module load mpt/${mpt}
module load mpi_intel/2018.2.199

export PATH=$PATH:/home/wrfoperador/local/bin:.
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/wrfoperador/local/lib
export NETCDF="/home/wrfoperador/local"

#mpi=/opt/hpe/hpc/mpt/mpt-${mpt}/bin/mpirun
mpi=mpirun
`which mpirun`

dplace=/usr/bin/dplace
time=/usr/bin/time

AREA=$1                                                         # AREA de simulacao. ex: metarea5, caribe, etc.
area=`echo $AREA | tr [A-Z] [a-z]`                              # Transforma maiusculas em minusculas.
HSIM=$2                                                         # Define o horario de simulacao, 00 ou 12.
HPROG=$3							# Define o prognostico a partir do qual a simulacao comecara.
HSTOP=$4                                                        # Define o horario limite dos dados do GFS. ex: 24, 48, 72, etc.

curr_date=`cat ~/datas/datacorrente${HSIM}`                     # Pega a data corrente no formato, ex: 20121121
curr_date=${curr_date}${HSIM}                                   # Transforma o formato acima em,   ex: 2012112100
YYYY=`echo $curr_date | cut -c1-4`                              # Extrai o ano do formato acima,   ex: 2012
MM=`echo $curr_date | cut -c5-6`                                # Extrai o mes do formato acima,   ex: 11
DD=`echo $curr_date | cut -c7-8`                                # Extrai o dia do formato acima,   ex: 21
HH=`echo $curr_date | cut -c9-10`                               # Extrai a hora do formato acima,  ex: 00
YYYY_end=${YYYY}
MM_end=${MM}
DD_end=${DD}
HH_end=${HH}

dormir=30							# numero de segundos para dormir.
HABORT=300                                                      # numero de ciclos para abortar a espera dos dados do GFS.

dir_gfs="${HOME}/DATA" 		                                # diretorio BASE dos dados do GFS. 
link_gfs="${dir_gfs}/GFS/data${HSIM}"                           # diretorio NFS onde os dados do GFS estao montados.
arq="gfs.t${HSIM}z.pgrb2.0p25.f"                                # modelo BASE Ndo nome do dado do GFS utilizado. ex: gfs.t00z.pgrb2f

if [ ${area} == "antartica" ] || [ ${area} == "antarticap" ];then

        raiz="/home/wrfoperador/wrf"
	dir_geog="${HOME}/geog"

elif  [ ${area} == "met510km" ];then

        raiz="/home/wrfoperador/wrf"
	dir_geog="${HOME}/geog"
else

        raiz="/home/wrfoperador/wrf"
	dir_geog="${HOME}/geog"

fi

dir_simulacao="${raiz}/wrf_${area}"
dir_wps="${dir_simulacao}/WPS"
dir_wrf="${dir_simulacao}/WRF"
dir_tmpl="${raiz}/templates"
dir_temp="${dir_simulacao}/temporarios/dados_${HSIM}" 		# diretorio de saida RESULTANTES do processo METGRID

if ! [ -d ${dir_simulacao} ];then

        echo
        echo "Esta AREA nao existe! Verifique no diretorio ${raiz}/invariantes "
        echo "o nome correto. Este nome tem que ser o mesmo dos arquivos presentes no "
        echo "diretorio, porem sem o TXT. Ex: arquivo metarea5.txt => AREA = metarea5 "
        echo
        exit 11

fi

# Verifica se a maquina eh de memoria
# DISTRIBUIDA ou COMPARTILHADA atraves do IP

maquina=`hostname`

if [ ${maquina} == "dpns01" ];then

	echo
	echo " Maquina de memoria COMPARTILHADA."
	MAQUINA="COMPARTILHADA"

else

	echo
	echo " Maquina de memoria DISTRIBUIDA."
	MAQUINA="DISTRIBUIDA"

	# A linha abaixo serve pois sem ela
	# o WRF nao roda na ICE para resolucao
	# maior que 20 km.
	# Eu tentei 1000 mas ainda n funcionou
	# Dai eu tentei 10000 e o WPS rodou.

	export MPI_GROUP_MAX=1024
	export MPI_BUFS_PER_PROC=1024
	export MPI_BUFS_PER_HOST=1024
#	export MPI_SHEPHERD=true

fi

####################################################################
#
# Carrega variaveis que serao utilizadas no WPS (namelist.wps)
#
####################################################################

TAM_MIN_METGRID=`grep TAM_MIN_METGRID ${raiz}/invariantes/${area}.txt	| cut -d" " -f2`
NDOMAIN=`grep MAX_DOM ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
INT_SEC=`grep INT_SEC ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
E_WE1=`grep E_WE1 ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
E_SN1=`grep E_SN1 ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
E_WE2=`grep E_WE2 ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
E_SN2=`grep E_SN2 ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
RES1=`grep RES1 ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
RES2=`grep RES2 ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
DX=`grep DX ${raiz}/invariantes/${area}.txt 				| cut -d" " -f2 | head -1`
DY=`grep DY ${raiz}/invariantes/${area}.txt 				| cut -d" " -f2 | head -1`
MAP_PROJ=`grep MAP_PROJ ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
REF_LAT=`grep REF_LAT ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
REF_LON=`grep REF_LON ${raiz}/invariantes/${area}.txt 			| cut -d" " -f2`
TRUELAT1=`grep TRUELAT1 ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
TRUELAT2=`grep TRUELAT2 ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
STAND_LON=`grep STAND_LON ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`

cd ${dir_wps}

sed s/NDOMAIN/${NDOMAIN}/g ${dir_tmpl}/tmpl.namelist.wps 	> temp1
sed s/INT_SEC/${INT_SEC}/g temp1 				> temp2
sed s/E_WE1/${E_WE1}/g temp2 					> temp1
sed s/E_SN1/${E_SN1}/g temp1 					> temp2
sed s/E_WE2/${E_WE2}/g temp2 					> temp1
sed s/E_SN2/${E_SN2}/g temp1 					> temp2
sed s/RES1/${RES1}/g temp2 					> temp1
sed s/RES2/${RES2}/g temp1 					> temp2
sed s/DX/${DX}/g temp2 						> temp1
sed s/DY/${DY}/g temp1 						> temp2
sed s/MAP_PROJ/${MAP_PROJ}/g temp2 				> temp1
sed s/REF_LAT/${REF_LAT}/g temp1 				> temp2
sed s/REF_LON/${REF_LON}/g temp2 				> temp1
sed s/TRUELAT1/${TRUELAT1}/g temp1 				> temp2
sed s/TRUELAT2/${TRUELAT2}/g temp2 				> temp1
sed s/STAND_LON/${STAND_LON}/g temp1 				> temp2
sed -e "s|DIRGEOG|${dir_geog}|g" temp2                   	> semi_template
rm temp1 temp2

###################################################################

nt=1

for HREF in `seq -f "%03g" ${HPROG} 3 ${HSTOP}`;do

	# Checar arquivos GFS SAFOS presentes

	cd ${dir_gfs}/${curr_date}

	arq_safo=${arq}${HREF}_SAFO

	FLAG=1

	while [ ${FLAG} -eq 1 ];do

		if [ -e  ${dir_gfs}/${curr_date}/${arq_safo} ];then

			echo
			echo " O arquivo ${arq_safo} esta na pasta."
			echo

			HREF_DATE=`${HOME}/local/bin/caldate ${curr_date} + ${HREF}h 'yyyymmddhh'`

			YYYY=`echo ${HREF_DATE} | cut -c1-4`                              # Extrai o ano do formato acima,   ex: 2012
			MM=`echo ${HREF_DATE} | cut -c5-6`                                # Extrai o mes do formato acima,   ex: 11
			DD=`echo ${HREF_DATE} | cut -c7-8`                                # Extrai o dia do formato acima,   ex: 21
			HH=`echo ${HREF_DATE} | cut -c9-10`                               # Extrai a hora do formato acima,  ex: 00
			YYYY_end=${YYYY}
			MM_end=${MM}
			DD_end=${DD}
			HH_end=${HH}

			# Passo 3.1 - Substituindo variaveis no tmpl_namelist.wps e
			# salvando tais substituicoes no namelist.wps

			cd ${dir_wps}

			rm temp* Vtable GRIBFILE.A* ungrib.log metgrid.log.* FILE*

			sed s/YYYY.END/$YYYY_end/g semi_template 	> temp1
			sed s/MM.END/$MM_end/g temp1 			> temp2
			sed s/DD.END/$DD_end/g  temp2 			> temp1
			sed s/HH.END/$HH_end/g  temp1 			> temp2
			sed s/YYYY/$YYYY/g  temp2 			> temp1
			sed s/MM/$MM/g  temp1 				> temp2
			sed s/DD/$DD/g  temp2 				> temp1
			sed s/HH/$HH/g temp1 				> namelist.wps


			# Verifica a necessidade de rodar o GEOGRID

			if ! [ -e ./geo_em.d01.nc ];then

				if [ ${MAQUINA} == "COMPARTILHADA" ];then

					echo
					echo " Rodadando o GEOGRID em memoria COMPARTILHADA."
					echo

					# Carrega os parametros do DPLACE
			
					N_GEO_PROC=`grep GEO_PROC ${raiz}/invariantes/${area}.txt | awk ' { print $2 } '`
					GEO_PROC=`grep GEO_PROC ${raiz}/invariantes/${area}.txt | awk ' { print $3 } '`

					$mpi -v -np ${N_GEO_PROC} $dplace -c ${GEO_PROC} ${dir_wps}/geogrid.exe
	
				else

                                        echo
                                        echo " Rodadando o GEOGRID em memoria DISTRIBUIDA."

#					$time $mpi -host `cat ${raiz}/invariantes/${area}/${area}_wpsarg | head -1` ${dir_wps}/geogrid.exe
					${time} $mpi -hostfile ${raiz}/invariantes/${area}/${area}_wpsarg ./geogrid.exe


				fi

				rm ./geogrid.log.*

			fi

			# Parte que roda o UNGRIB

        		if [ -f Vtable ];then

               			rm Vtable
				ln -sf ${raiz}/WPS/ungrib/Variable_Tables/Vtable.GFS ./Vtable

			else

				ln -sf ${raiz}/WPS/ungrib/Variable_Tables/Vtable.GFS ./Vtable

			fi

			./link_grib.csh ${link_gfs}/${arq}${HREF}

			${dir_wps}/ungrib.exe

			# Parte que roda o METGRID

			metgrid_arq="met_em.d01.${YYYY}-${MM}-${DD}_${HH}:00:00.nc"

			if [ ${MAQUINA} == "COMPARTILHADA" ];then

				echo
				echo " Rodando o METGRID em memoria COMPARTILHADA."
				echo

				# Carrega os parametros do DPLACE

				N_MET_PROC=`grep MET_PROC ${raiz}/invariantes/${area}.txt | awk ' { print $2 } '`
                		MET_PROC=`grep MET_PROC ${raiz}/invariantes/${area}.txt | awk ' { print $3 } '`

				time $mpi -np ${N_MET_PROC} $dplace -c ${MET_PROC} ./metgrid.exe

			else

				echo
				echo " Rodando o METGRID em memoria DISTRIBUIDA."

#				$mpi -host `cat ${raiz}/invariantes/${area}/${area}_wpsarg | head -1` ./metgrid.exe
				${time} $mpi -hostfile ${raiz}/invariantes/${area}/${area}_wpsarg ./metgrid.exe

			fi

			mv met_em.d01.* ${dir_temp}

			if ! [ ${HREF} -eq ${HSTOP} ];then

				echo
				echo " Arquivo ${arq_safo} processado. Passando para proximo horario."
				echo

			else

				echo
				echo " Fim do processo do WPS para o periodo."
				echo

			fi

			FLAG=0		

		else

			nt=$((nt+1))


			if [ ${nt} == ${HABORT} ];then

				echo " Esperei por ${HABORT} Ciclos de ${dormir} segundos, mas o arquivo "
				echo " ${arq_safo} nao chegou na pasta. Abortando o roda_ungrib_metgrid.sh."

				exit 11

			fi

			echo " Arquivo ${arq_safo} nao existe. "
			echo " Esperando ${dormir} segundos "

			sleep ${dormir}
		
		fi
	done

	if [ ${HREF} -eq ${HSTOP} ];then

		cd ${dir_wps}

		rm semi_template temp* Vtable GRIBFILE.AAA ungrib.log metgrid.log.* FILE*

	fi

done

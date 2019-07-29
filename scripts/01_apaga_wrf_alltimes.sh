#!/bin/bash

########################################################
#
# Script para MATAR rodadas que estao sendo executadas ou
# para APAGAR dados antes de se executar novas rodadas. 
#
# Criado em: 11AGO2013		Alterado em: 20NOV2013
#
#
# Autor: 1T(T) Alexandre Gadelha
#
########################################################

# Verifica argumentos

if ! [ $# -eq 3 ];then

        echo
        echo " Entre com a funcao (mata ou apaga),"
	echo " a area (metarea5, antartica, caribe e libano) "
	echo " e o horario de simulacao (00 e 12 UTC)."
        echo

        exit 10
fi

FUNC=$1
AREA=$2                                                         # AREA de simulacao. ex: metarea5, caribe, etc.
area=`echo $AREA | tr [A-Z] [a-z]`                              # Transforma maiusculas em minusculas.
HSIM=$3                                                         # Define o horario de simulacao, 00 ou 12.

if [ ${area} == "antartica" ] || [ ${area} == "antarticap" ];then
	raiz="${HOME}/wrf"
else
	raiz="${HOME}/wrf"
fi

dir_gfs="${HOME}/DATA" 						# diretorio BASE dos dados do GFS. 
dir_simulacao="${raiz}/wrf_${area}"
dir_wps="${dir_simulacao}/WPS"
dir_temp="${dir_simulacao}/temporarios/dados_${HSIM}"
dir_wrf="${dir_simulacao}/WRF"
dir_prod="${dir_simulacao}/produtos"
dir_met="${dir_prod}/meteogramas_${HSIM}"
dir_vent="${dir_prod}/vento_${HSIM}"
dir_upp="${dir_simulacao}/UPP"

curr_date=`cat ~/datas/datacorrente${HSIM}`                     # Pega a data corrente no formato, ex: 20121121
curr_dateHH=${curr_date}${HSIM}                                   # Transforma o formato acima em,   ex: 2012112100

data_ant=`${HOME}/local/bin/caldate ${curr_dateHH} - 24h 'yyyymmddhh'`     # Data utilizada para apagar o diretorio de dados do GFS do dia anterior.


####---####---####---####---####---####---####---####---####---####---####---####---####

case ${FUNC} in

mata)

	if [ $HOSTNAME == "dpns01" ];then

		echo
		echo " Matando processos em maquina de memoria COMPARTILHADA."

	        echo " Matando processos atrelados ao termo wrf.exe."
		kill -9 `ps -ef | grep wrf.exe | awk '{print $2}'`

		echo " Matando processos atrelados ao termo real.exe."
		kill -9 `ps -ef | grep real.exe | awk '{print $2}'`

	        echo " Matando processos atrelados ao termo unipost.exe."
		kill -9 `ps -ef | grep unipost.exe | awk '{print $2}'`

                echo " Matando processos atrelados ao termo gplt para o GEMPAK"
                kill -9 `ps -ef | grep gplt | awk ' {print $2} '`

	        echo " Matando processos atrelados ao termo ${AREA}."
		for arq in `ps -ef | grep  ${AREA} | awk ' { print $2 } '`; do kill -9 $arq; done

	else

		echo
		echo " Matando processos em maquina de memoria DISTRIBUIDA."
                echo " Matando processos atrelados ao termo wrf.exe."

#		arqs=`ps -ef | grep ${area} | grep -v "grep" | grep -v "01_apaga_wrf.sh"`
#		kill -9 ${arqs}

		for i in `seq 0 0`;do

			for no in `seq 0 17`;do

				ssh r1i${i}n${no} "ps -ef | grep wrf.exe; killall wrf.exe"
				ssh r1i${i}n${no} "ps -ef | grep real.exe; killall real.exe"
				ssh r1i${i}n${no} "ps -ef | grep unipost.exe; killall unipost.exe"
			done

		done

	fi
;;

apaga)

# Entra no diretorio do GFS e apaga diretorios anteriores a data da rodada

cd ${dir_gfs}

alvo=`ls -ltr ${dir_gfs} | awk ' { print $9 } '`

for alvo_del in ${alvo};do

	if ! [ ${alvo_del} == "GFS" ];then

	alvo_del2=`echo ${alvo_del} | cut -c1-8`

	fi
	
	if ! [ ${alvo_del} == "GFS" ] && ! [ ${alvo_del2} == "GFS_dpns" ]&& ! [ ${alvo_del2} == ${curr_date} ];then

	echo
	echo " O alvo ${alvo_del} sera apagado."

	rm -rf ${alvo_del}

	fi
done

# Entra no diretorio do WPS e apaga arquivos

cd ${dir_wps}

	if [ -f geogrid.log ];then echo " Removendo geogrid.log*"; rm ./geogrid.log* ; else echo " Nao existe GEOGRID a apagar." ; fi

	if [ -f ungrib.log ];then echo " Removendo ungrib.log*"; rm ./ungrib.log* ; else echo " Nao existe UNGRIB a apagar." ; fi

	if [ -f metgrid.log ];then echo " Removendo metgrid.log*"; rm ./metgrid.log* ; else echo " Nao existe METGRID a apagar." ; fi

# Entra no diretorio temporario e apaga arquivos

cd ${dir_temp}

	arq=`ls ${dir_temp}/met_em* 2> /dev/null | wc -l`
	if [ ${arq} != 0 ]; then rm ${dir_temp}/* ; else echo " Nao existe TEMPORARIOS a apagar." ; fi

# Entra no diretorio do WRF e apaga arquivos

cd ${dir_wrf}

	arq=`ls ${dir_wrf}/met_em.* 2> /dev/null | wc -l`
	if [ ${arq} != 0 ]; then rm ${dir_wrf}/met_em.* ; else echo " Nao existem links METGRID a apagar." ; fi

	arq=`ls ${dir_wrf}/wrfrst* 2> /dev/null | wc -l`
	if [ ${arq} != 0 ]; then rm ${dir_wrf}/wrfrst*; rm ${dir_wrf}/namelist* ; else echo " Nao existem WRFRST a apagar." ; fi

# Entra no diretorio de produtos e apaga arquivos


	arq=`ls ${dir_prod}/dados_${HSIM}/wrfout* 2> /dev/null | wc -l`
	if [ ${arq} != 0 ]; then rm ${dir_prod}/dados_${HSIM}/wrfout* ; else echo " Nao existe WRFOUT a apagar." ; fi

	arq=`ls ${dir_prod}/grib_${HSIM}/wrf_${area}_* 2> /dev/null | wc -l`
	if [ ${arq} != 0 ]; then rm ${dir_prod}/grib_${HSIM}/wrf_${area}_* ; else echo " Nao existe GRIB a apagar." ; fi

        arq=`ls ${dir_met}/* 2> /dev/null | wc -l`
        if [ ${arq} != 0 ]; then rm ${dir_met}/* ; else echo " Nao existe METEOGRAMAS a apagar." ; fi

        arq=`ls ${dir_vent}/* 2> /dev/null | wc -l`
        if [ ${arq} != 0 ]; then rm ${dir_vent}/* ; else echo " Nao existe GRIB de VENTO a apagar." ; fi

# Entra no diretorio do UPP e apaga arquivos

	arq=`ls ${dir_upp}/postprd/* 2> /dev/null | wc -l`
	if [ ${arq} != 0 ]; then rm ${dir_upp}/postprd/* ; else echo " Nao existe UPP a apagar." ; fi
;;
esac


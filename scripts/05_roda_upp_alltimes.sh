#!/bin/bash

# Verifica argumentos

if ! [ $# -eq 5 ];then

        echo
        echo " Entre com:"
        echo " 1 - A area (met510km, antartica),"
        echo " 2 - o horario de simulacao (00, 12),"
        echo " 3 - o prognostico inicial (00, 03, 06, etc.)"
        echo " 4 - o tempo de integracao (24, 48, 72, 96, etc.), e"
        echo " 5 - a flag de esperar o cosmo 2.2 (operacional ou manual)."
        echo ""
        echo " Se o quinto parametro for MANUAL, o presente script assumirah"
        echo " que nao ha rodada do cosmo em andamento e entao disparara"
        echo " os scripts 01, 02, 03, 04 e 05 do WRF."
        echo ""
        echo " Ja se o quinto parametro for OPERACIONAL, o presente script disparara"
        echo " os scripts 01, 02, e 03, realizando o pre processamento do WRF"
        echo " em algum noh nao utilizado pelo cosmo2.2, enquanto aguarda o termino"
        echo " da rodada do cosmo. Quando o prognostico 48 do cosmo for encontrado,"
        echo " o script entenderah que o cosmo2.2 terminou e entao disparara os scripts 04 e 05."
        echo ""

        exit 1
fi

AREA=$1                                                         # AREA de simulacao. ex: metarea5, caribe, etc.
area=`echo $AREA | tr [A-Z] [a-z]`                              # Transforma maiusculas em minusculas.
HSIM=$2                                                         # Define o horario de simulacao, 00 ou 12.
HPROG=$3                                                        # Define o prognostico a partir do qual a simulacao comecara.
HSTOP=$4                                                        # Define o horario limite de integracao. ex: 24, 48, 72, etc.
HINT="03"                                                       # Intervalo de incremento entre horarios de simulacao.
PENULT_PROG=`expr ${HSTOP} - ${HINT}`                           # Calculo do penultimo horario
DECISAO=$5
decisao=`echo ${DECISAO} | tr [A-Z] [a-z]`

ulimit -s unlimited
ulimit -v unlimited

/opt/intel/bin/compilervars.sh intel64

export -f module
module use /usr/share/modules/modulefiles
#mpt=`cat $HOME/wrf/invariantes/mpt_versao | head -1`
#module load mpt/${mpt}
module load mpi_intel/2018.2.199
mpi=mpirun

curr_date0=`cat ~/datas/datacorrente${HSIM}`                     # Pega a data corrente no formato, ex: 20121121
curr_date=${curr_date0}${HSIM}                                   # Transforma o formato acima em,   ex: 2012112100
YYYY=`echo $curr_date | cut -c1-4`                              # Extrai o ano do formato acima,   ex: 2012
MM=`echo $curr_date | cut -c5-6`                                # Extrai o mes do formato acima,   ex: 11
DD=`echo $curr_date | cut -c7-8`                                # Extrai o dia do formato acima,   ex: 21
HH=`echo $curr_date | cut -c9-10`                               # Extrai a hora do formato acima,  ex: 00
YYYY_end=${YYYY}
MM_end=${MM}
DD_end=${DD}
HH_end=${HH}

YYrod=${YYYY}
MMrod=${MM}
DDrod=${DD}

dormir=40 							# numero de segundos para dormir.
HABORT=180                                                      # numero de ciclos para abortar a espera dos dados do GFS.

if [ ${area} == "antartica" ];then

	raiz="${HOME}/wrf"  

else

	raiz="${HOME}/wrf"

fi

dir_scr="${HOME}/scripts"
wrf_out="wrfout_d0"						# modelo BASE do nome do dado de saida do WRF.
dir_simulacao="${raiz}/wrf_${area}"
dir_wrf_comp="${raiz}/WRFV3"
dir_produtos="${dir_simulacao}/produtos"
dir_dados="${dir_produtos}/dados_${HSIM}"
dir_gribs="${dir_produtos}/grib_${HSIM}"
dir_dat="${dir_produtos}/dat_${HSIM}"
dir_tmpl="${raiz}/templates"
dir_wrf="${dir_simulacao}/WRF"
dir_upp="${dir_simulacao}/UPP"
dir_arw="${dir_simulacao}/ARW"
upparg=${raiz}/invariantes/${area}/${area}_upparg

# Verifica a consistencia do quinto parametro.

if [ "${decisao}" == "operacional" ] || [ "${decisao}" == "manual" ];then

        echo " O quinto parametro estah CORRETO."

else

        echo " O quinto parametro estah INCORRETO."
        exit 2

fi

if ! [ -d ${dir_simulacao} ];then

        echo
        echo "Esta AREA nao existe! Verifique no diretorio ${raiz}/invariantes "
	echo "o nome correto. Este nome tem que ser o mesmo dos arquivos presentes no "
	echo "diretorio, porem sem o TXT. Ex: arquivo metarea5.txt => AREA = metarea5 "
        echo
        exit 11

fi

####################################################################
#
# Carrega variaveis que serao utilizadas no UPP
#
####################################################################

cd ${dir_upp}/postprd

if [ ${area} == "antartica" ];then

	sed -e "s|RAIZ|${raiz}|g" ${dir_tmpl}/tmpl.run_unipost.antartica 	> temp1
#	sed -e "s|RAIZ|${raiz}|g" ${dir_tmpl}/tmpl.run_unipost 	> temp1

else

	sed -e "s|RAIZ|${raiz}|g" ${dir_tmpl}/tmpl.run_unipost  > temp1

fi

sed -e "s|SIMU|${dir_upp}|g" temp1 				> temp2
sed -e "s|DIRWRF|${dir_wrf_comp}|g" temp2 			> temp1
sed -e "s|SETMPI|${mpi}|g" temp1 				> temp2
sed -e "s|UPPARGS|${upparg}|g" temp2	 			> ${dir_upp}/semi_template

#rm ${dir_upp}/postprd/temp1 ${dir_upp}/postprd/temp2

####################################################################
#
# Carrega variaveis que serao utilizadas no ARW
#
####################################################################

INT_SEC=`grep INT_SEC ${raiz}/invariantes/${area}.txt | cut -d" " -f2`

###################################################################

for HREF in `seq ${HPROG} ${HINT} ${HSTOP}`;do

	echo " | | | | | | | | | | | | | | | | | | | "
	echo " V V V V V V V V V V V V V V V V V V V "
	echo
	echo " Inicio do LOOP de ${HPROG} ate ${HSTOP}"

	# Ajusta os ZEROS a direita do HREF

        if [ ${HREF} -le 9 ];then

		HREF=0${HREF}

        else

		HREF=${HREF}

	fi

        # Ajuste no HREFalt para salvar os arquivos com PROG em 3 digitos

        DIG="0"

	if [ ${HREF} -le 99 ];then

		HREFalt=${DIG}${HREF}

	else

		HREFalt=${HREF}

	fi

	# Checar arquivos wrfout*** presentes

	# Calcula o horario ATUAL e carrega variaveis

	HREF_DATE=`${HOME}/local/bin/caldate ${curr_date} + ${HREF}h 'yyyymmddhh'`
	echo
	echo  " Horario inicial do processo eh ${HREF_DATE}"

	YYYYi=`echo ${HREF_DATE} | cut -c1-4`                              # Extrai o ano do formato acima,   ex: 2012
	MMi=`echo ${HREF_DATE} | cut -c5-6`                                # Extrai o mes do formato acima,   ex: 11
	DDi=`echo ${HREF_DATE} | cut -c7-8`                                # Extrai o dia do formato acima,   ex: 21
	HHi=`echo ${HREF_DATE} | cut -c9-10`                               # Extrai a hora do formato acima,  ex: 00

	YYYY_end=${YYYYi}
	MM_end=${MMi}
	DD_end=${DDi}
	HH_end=${HHi}

	arq_wrfout1=${wrf_out}1_${YYYYi}-${MMi}-${DDi}_${HHi}:00:00
	arq_wrfout2=${wrf_out}1_${YYYYi}-${MMi}-${DDi}_${HHi}_00_00

	FLAG=1
	nt=1

	while [ ${FLAG} -eq 1 ];do

		if [ -f ${dir_wrf}/${arq_wrfout1} ];then
#		if [ -f ${dir_dados}/${arq_wrfout1} ];then

			echo
			echo " Encontrei o arquivo ${dir_wrf}/${arq_wrfout1} e vou processa-lo."

			if [ ${decisao} == "operacional" ];then

				echo " Vou esperar ${dormir} segundos para certificar que o modelo acabou de escreve-lo."
				sleep ${dormir}

			else

				echo " A rodada eh MANUAL, logo nao vou fazer o sleep pois presumo que os dados jah estao no local."

			fi

			echo " Dando prosseguimento a conversao do dado."
			echo

			# Movendo o arquivo do diretorio ${dir_wrf} para ${dir_dados}

			mv ${dir_wrf}/${arq_wrfout1} ${dir_dados}/${arq_wrfout1}

			# Substituindo variaveis no semi_template e
			# salvando tais substituicoes no run_unipost

			sed -e 's|HREF_DATE|'${curr_date}'|g' ${dir_upp}/semi_template > temp1
			sed s/HH.END/${HREF}/g  temp1 > temp2
			sed s/HH.INI/${HREF}/g  temp2 > temp1
			sed s/HINT/${HINT}/g temp1 > temp2
			sed s/HSIM/${HSIM}/g temp2 > temp1
			sed -e 's|PRODUTOS|'${dir_dados}'|g' temp1 > ${dir_upp}/postprd/run_unipost

			rm ${dir_upp}/postprd/temp1 ${dir_upp}/postprd/temp2

			chmod u+x ${dir_upp}/postprd/run_unipost

			echo
			echo " rodando o UNIPOST "
		
			cd ${dir_upp}/postprd

			time ${dir_upp}/postprd/run_unipost

			if [ ${area} == "antartica" ] || [ ${area} == "antarticap" ];then

# As duas proximas linhas sao as originais. Preciso ver o impacto dessa alteracao. CT(T) Alexandre Gadelha 18JAN19
##				mv ${dir_upp}/postprd/wrfprs_d01.${HREF} ${dir_gribs}/wrf_${area}_${HSIM}_${curr_date0}${HREFalt}
##				rm ${dir_upp}/postprd/WRFPRS_d01.${HREF}
				mv ${dir_upp}/postprd/WRFPRS_d01.${HREF} ${dir_gribs}/wrf_${area}_${HSIM}_${curr_date0}${HREFalt}
				rm ${dir_upp}/postprd/wrfprs_d01.${HREF}

			else

				mv ${dir_upp}/postprd/WRFPRS_d01.${HREF} ${dir_gribs}/wrf_${area}_${HSIM}_${curr_date0}${HREFalt}
				rm ${dir_upp}/postprd/wrfprs_d01.${HREF}
#				rm ${dir_upp}/postprd/*
			fi

			FLAG=0		

		else

			nt=$((nt+1))

			if [ ${nt} == ${HABORT} ];then

				echo
				echo " Esperei por ${HABORT} Ciclos de ${dormir} segundos, mas o arquivo "
				echo " ${dir_dados}/${arq_wrfout1} nao chegou na pasta. Abortando o roda_real_wrf.sh."
				echo

				echo $date
				exit 11

			fi

			echo " Arquivo ${dir_dados}/${arq_wrfout1} nao existe. "

			echo " Esperando ${dormir} segundos "
			sleep ${dormir}
		
		fi
	done

nt=$((nt+1))

done
exit 05
# Script que extrai os dados de vento a 10 metros
# para inicializacao do WW3 apos o termino da rodada.

#${dir_scr}/05.1_extrai_grib_vento.sh ${AREA} ${HSIM} 00 ${HSTOP}
#${dir_scr}/05.2_extrai_grib_gempak.sh ${AREA} ${HSIM} 00 ${HSTOP}

if [ ${area} == "antartica" ]; then
        ${dir_scr}/05.3_extrai_grib_zygrib.sh antartica ${HSIM} 00 ${HSTOP} zoom
        ${dir_scr}/05.3_extrai_grib_zygrib.sh antartica ${HSIM} 00 ${HSTOP} drake
else
        ${dir_scr}/05.3_extrai_grib_zygrib.sh metarea5 ${HSIM} 00 ${HSTOP} dragao
fi

#!/bin/bash -x

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
HPROG=$3							# Define o prognostico a partir do qual a simulacao comecara.
HSTOP=$4                                                        # Define o horario limite de integracao. ex: 24, 48, 72, etc.
HINT=`echo "${HSTOP} - ${HPROG}" | bc`				# Intervalo de incremento entre horarios de simulacao.
DECISAO=$5
decisao=`echo ${DECISAO} | tr [A-Z] [a-z]`

export WRF_EM_CORE=1
export WRF_NMM_CORE=0
export WRF_DA_CORE=0
export WRFIO_NCD_LARGE_FILE_SUPPORT=1

ulimit -s unlimited
ulimit -v unlimited

source /opt/intel/intel_2018/bin/compilervars.sh intel64

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

dplace=/usr/bin/dplace
time=/usr/bin/time

datacorrente=`cat ~/datas/datacorrente${HSIM}`
curr_date=${datacorrente} 		                     # Pega a data corrente no formato, ex: 20121121
curr_date=${curr_date}${HSIM}                                # Transforma o formato acima em,   ex: 2012112100
YYYY=`echo $curr_date | cut -c1-4`                           # Extrai o ano do formato acima,   ex: 2012
MM=`echo $curr_date | cut -c5-6`                             # Extrai o mes do formato acima,   ex: 11
DD=`echo $curr_date | cut -c7-8`                             # Extrai o dia do formato acima,   ex: 21
HH=`echo $curr_date | cut -c9-10`                            # Extrai a hora do formato acima,  ex: 00

dormir=60							# numero de segundos para dormir.
HABORT=180                                                      # numero de ciclos para abortar a espera dos dados do GFS.

if [ ${area} == "antartica" ];then

        raiz="${HOME}/wrf"

elif  [ ${area} == "metarea5" ];then

        raiz="${HOME}/wrf"

else

        raiz="${HOME}/wrf"

fi

dir_inv="${raiz}/invariantes"
dir_scr="${raiz}/scripts"
arq="met_em.d0"							# modelo BASE do nome do dado do metgrid. ex: met_em.d01.2012-11-24_03:00:00.nc
wrf_out="wrfout_d0"						# modelo BASE do nome do dado de saida do WRF.
dir_gfs="${raiz}/DATA"						# diretorio onde os dados do GFS chegam. 
dir_simulacao="${raiz}/wrf_${area}"
dir_produtos="${dir_simulacao}/produtos/dados_${HSIM}"
dir_tmpl="${raiz}/templates"
dir_wrf="${dir_simulacao}/WRF"
dir_wps="${dir_simulacao}/WPS"
dir_temp="${dir_simulacao}/temporarios/dados_${HSIM}"

# Verifica a consistencia do quinto parametro.

if [ "${decisao}" == "operacional" ] || [ "${decisao}" == "manual" ];then

        echo " O quinto parametro estah CORRETO."

else

        echo " O quinto parametro estah INCORRETO."
        exit 2

fi

# Calcula o ultimo arquivo para utilizar de comparacao
# no final do script

ULT_PROG=`${HOME}/local/bin/caldate ${curr_date} + ${HSTOP}h 'yyyymmddhh'`

YYYY_end=`echo ${ULT_PROG} | cut -c1-4`                              # Extrai o ano do formato acima,   ex: 2012
MM_end=`echo ${ULT_PROG} | cut -c5-6`                                # Extrai o mes do formato acima,   ex: 11
DD_end=`echo ${ULT_PROG} | cut -c7-8`                                # Extrai o dia do formato acima,   ex: 21
HH_end=`echo ${ULT_PROG} | cut -c9-10`                               # Extrai a hora do formato acima,  ex: 00

ARQ_FIM=${arq}1.${YYYY_end}-${MM_end}-${DD_end}_${HH_end}:00:00.nc

# A linha abaixo serve pois sem ela
# o WRF nao roda na ICE para resolucao
# maior que 20 km.
# Eu tentei 1000 mas ainda n funcionou
# Dai eu tentei 10000 e o WPS rodou.
export MPI_GROUP_MAX=1024
export MPI_BUFS_PER_PROC=1024
export MPI_BUFS_PER_HOST=1024
export MPI_DSM_DISTRIBUTE=1

if ! [ -d ${dir_simulacao} ];then

        echo
        echo "Esta AREA nao existe! Verifique no diretorio ${raiz}/invariantes "
	echo "o nome correto. Este nome tem que ser o mesmo dos arquivos presentes no "
	echo "diretorio, porem sem o TXT. Ex: arquivo metarea5.txt => AREA = metarea5 "
        echo
        exit 041

fi

####################################################################
#
# Carrega variaveis que serao utilizadas no WRF (namelist.input.baixo)
#
####################################################################

HIS_INT=`grep HIS_INT ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
FRAMES=`grep FRAMES ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
TPASSO=`grep TPASSO ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
ADAPT_TS=`grep ADAPT_TS ${raiz}/invariantes/${area}.txt         | cut -d" " -f2`
MAX_TS=`grep MAX_TS ${raiz}/invariantes/${area}.txt             | cut -d" " -f2`
MIN_TS=`grep MIN_TS ${raiz}/invariantes/${area}.txt             | cut -d" " -f2`
INT_SEC=`grep INT_SEC ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2` 	# Aplicado no namelist.input.cima
NDOMAIN=`grep MAX_DOM ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
E_WE1=`grep E_WE1 ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
E_SN1=`grep E_SN1 ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
E_WE2=`grep E_WE2 ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2` 	# So usado se houver aninhamento (ainda nao pronto)
E_SN2=`grep E_SN2 ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2` 	# So usado se houver aninhamento (ainda nao pronto)
EVERT=`grep EVERT ${raiz}/invariantes/${area}.txt 		| cut -d" " -f2`
NSOILEVEL=`grep NSOILEVEL ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
MAP_PROJ=`grep MAP_PROJ ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`

# Se MAP_PROJ for lat-lon, o WRF precisa tirar a resolucao dos
# arquivos geo_em.d0*. Caso seja lambert ou mercator, pega a
# resolucao do arquivo dentro do diretorio invariantes

if ! [ ${MAP_PROJ} == "lat-lon" ];then

DX_1=`grep DX_1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
DX_2=`grep DX_2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
DY_1=`grep DY_1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
DY_2=`grep DY_2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`

else

cd ${dir_wps}

DX_1=`ncdump -h geo_em.d01.nc | grep ":DX " | cut -d" " -f3 | cut -d"f" -f1`
DY_1=`ncdump -h geo_em.d01.nc | grep ":DY " | cut -d" " -f3 | cut -d"f" -f1`

	if [ -e geo_em.d02.nc ];then

	DX_2=`ncdump -h geo_em.d02.nc | grep ":DX " | cut -d" " -f3 | cut -d"f" -f1`
        DY_2=`ncdump -h geo_em.d02.nc | grep ":DY " | cut -d" " -f3 | cut -d"f" -f1`

	else

	DX_2=`grep DX_2 ${raiz}/invariantes/${area}.txt | cut -d" " -f2`
	DY_2=`grep DY_2 ${raiz}/invariantes/${area}.txt | cut -d" " -f2`

	fi
fi

# Se houver a variavel ETALEV no arquivo TXT da area
# o script ira comparar o numero de niveis do modelo
# definido em EVERT com o numero de niveis eta
# definidos no arquivo TXT apos o termo ETA_LEVS.
# Se estiver diferente ele vai alertar do erro e abortar. Caso
# esteja igual ele vai adicionar a linha eta_levels logo abaixo 
# do termo domains no namelist.input baixo

ETALEV=`grep ETALEV ${raiz}/invariantes/${area}.txt     | cut -d" " -f2`

if [ ${ETALEV} == "sim" ];then

	# Numero de niveis eta descrito no arquivo TXT
	# AQUI HA UM MACETE. Para carregar a lista de niveis eta vou
	# comecar a contar da segunda coluna em diante na linha do termo ETA_LEVS.
	# Entao vou precisar de n+1 termos para cortar a string e somar o numero de niveis eta.
	# Meio confuso. rsrs Me pergunte antes deu morrer. CT(T) Alexandre Gadelha 15MAI18

	nlevs0=`grep ETA_LEVS ${raiz}/invariantes/${area}.txt | wc -w`

	# Retirando o primeiro termo da variavel nlevs acima pois
	# equivale a propria palavra ETA_LEVS

	nlevs=`echo "(${nlevs0} - 1)" | bc`

	if ! [ ${nlevs} -eq ${EVERT} ];then

		echo " Ja que voce quer utilizar niveis eta no modelo"
		echo " O numero de EVERT deve ser igual numero de ETA_LEVS"
		echo " Segundo o namelist EVERT eh ${EVERT} e ETA_LEVS ${nlevs}."
		echo " Vou abortar por aqui e voce ajusta essa bagunca."
		exit 042

	else
		# Observar que estou utilizando a variavel nlevs0 que tem um termo a mais
		# para compensar que vou comecar a utilizar a linha a parter do campo 2
		ETA_LEVS=`grep ETA_LEVS ${raiz}/invariantes/${area}.txt | cut -d" " -f2-${nlevs0}`

	fi
fi

MPPHY1=`grep MPPHY1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
ROL1=`grep ROL1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
ROC1=`grep ROC1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
PRAD1=`grep PRAD1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
PSOLO1=`grep PSOLO1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
PSUP1=`grep PSUP1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
CLIM1=`grep CLIM1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
CUMU1=`grep CUMU1 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
NCASOL=`grep NCASOL ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`

MPPHY2=`grep MPPHY2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
ROL2=`grep ROL2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
ROC2=`grep ROC2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
PRAD2=`grep PRAD2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
PSOLO2=`grep PSOLO2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
PSUP2=`grep PSUP2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
CLIM2=`grep CLIM2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
CUMU2=`grep CUMU2 ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
NCASOL=`grep NCASOL ${raiz}/invariantes/${area}.txt 	| cut -d" " -f2`
NLANDCAT=`grep NLANDCAT ${raiz}/invariantes/${area}.txt | cut -d" " -f2`

cd ${dir_wrf}

sed s/TPASSO/${TPASSO}/g ${dir_tmpl}/tmpl.namelist.input.baixo 	> temp1
if [ ${ETALEV} == "sim" ];then
	sed -e "/domains/a\\ eta_levels = ${ETA_LEVS}" temp1	> temp2
	mv temp2 temp1
fi
sed s/ADAPT_TS/${ADAPT_TS}/g temp1 				> temp2
sed s/MAX_TS/${MAX_TS}/g temp2 					> temp1
sed s/MIN_TS/${MIN_TS}/g temp1 					> temp2
sed s/MAX_DOM/${NDOMAIN}/g temp2 				> temp1
sed s/E_WE1/${E_WE1}/g temp1 					> temp2
sed s/E_SN1/${E_SN1}/g temp2 					> temp1
sed s/E_WE2/${E_WE2}/g temp1 					> temp2
sed s/E_SN2/${E_SN2}/g temp2 					> temp1
sed s/EVERT/${EVERT}/g temp1 					> temp2
sed s/NSOILEVEL/${NSOILEVEL}/g temp2 				> temp1
sed s/DX_1/${DX_1}/g temp1 					> temp2
sed s/DY_1/${DY_1}/g temp2 					> temp1
sed s/DX_2/${DX_2}/g temp1 					> temp2
sed s/DY_2/${DY_2}/g temp2 					> temp1
sed s/MPPHY1/${MPPHY1}/g temp1 					> temp2
sed s/MPPHY2/${MPPHY2}/g temp2 					> temp1
sed s/ROL1/${ROL1}/g temp1 					> temp2
sed s/ROL2/${ROL2}/g temp2 					> temp1
sed s/ROC1/${ROC1}/g temp1 					> temp2
sed s/ROC2/${ROC2}/g temp2 					> temp1
sed s/PRAD1/${PRAD1}/g temp1 					> temp2
sed s/PRAD2/${PRAD2}/g temp2 					> temp1
sed s/PSOLO1/${PSOLO1}/g temp1 					> temp2
sed s/PSOLO2/${PSOLO2}/g temp2 					> temp1
sed s/PSUP1/${PSUP1}/g temp1 					> temp2
sed s/PSUP2/${PSUP2}/g temp2 					> temp1
sed s/CLIM1/${CLIM1}/g temp1 					> temp2
sed s/CLIM2/${CLIM2}/g temp2 					> temp1
sed s/CUMU1/${CUMU1}/g temp1 					> temp2
sed s/CUMU2/${CUMU2}/g temp2 					> temp1
sed s/NCASOL/${NCASOL}/g temp1 					> temp2
sed s/NLANDCAT/${NLANDCAT}/g temp2                              > namelist.input.baixo

rm temp1 temp2

nt=1

for HREF in `seq -f "%03g" ${HPROG} 3 ${HSTOP}`;do

	echo " | | | | | | | | | | | | | | | | | | | "
	echo " V V V V V V V V V V V V V V V V V V V "
	echo
	echo " Inicio do LOOP de ${HPROG} ate ${HSTOP}"

	# Checar arquivos met_em.d01???.nc presentes

	cd ${dir_wrf}

	if [ ${HREF} == 000 ];then

		# Calcula o horario ATUAL e carrega variaveis

		HREF_DATE=`${HOME}/local/bin/caldate ${curr_date} + ${HREF}h 'yyyymmddhh'`
		echo
		echo  " Horario inicial do processo eh ${HREF_DATE}"

		HINI=${HREF}
		YYYY=`echo ${HREF_DATE} | cut -c1-4`                              # Extrai o ano do formato acima,   ex: 2012
		MM=`echo ${HREF_DATE} | cut -c5-6`                                # Extrai o mes do formato acima,   ex: 11
		DD=`echo ${HREF_DATE} | cut -c7-8`                                # Extrai o dia do formato acima,   ex: 21
		HH=`echo ${HREF_DATE} | cut -c9-10`                               # Extrai a hora do formato acima,  ex: 00

                arq_met1=${arq}1.${YYYY}-${MM}-${DD}_${HH}:00:00.nc
                arq_met1_nocomma=${arq}1.${YYYY}-${MM}-${DD}_${HH}_00_00.nc


	else

		# Calcula horario SEGUINTE e carrega variaveis

		NEXT_PROG=`${HOME}/local/bin/caldate ${HREF_DATE} + ${HREF}h 'yyyymmddhh'`
		echo " Horario final do processo eh   ${NEXT_PROG}"
		echo

		YYYY_NXT=`echo ${NEXT_PROG} | cut -c1-4`                          # Extrai o ano do formato acima,   ex: 2012
	        MM_NXT=`echo ${NEXT_PROG} | cut -c5-6`                            # Extrai o mes do formato acima,   ex: 11
	        DD_NXT=`echo ${NEXT_PROG} | cut -c7-8`                            # Extrai o dia do formato acima,   ex: 21
	        HH_NXT=`echo ${NEXT_PROG} | cut -c9-10`                           # Extrai a hora do formato acima,  ex: 00

		arq_met2=${arq}1.${YYYY_NXT}-${MM_NXT}-${DD_NXT}_${HH_NXT}:00:00.nc
		arq_met2_nocomma=${arq}1.${YYYY_NXT}-${MM_NXT}-${DD_NXT}_${HH_NXT}_00_00.nc

	fi

	FLAG=1

	while [ ${FLAG} -eq 1 ];do

		if [ ${HREF} == 000 ];then

			if [ -e ${dir_temp}/${arq_met1} ];then

				ln -sf ${dir_temp}/${arq_met1} ./${arq_met1}
#				ln -sf ${dir_temp}/${arq_met1} ./${arq_met1_nocomma}
				FLAG=0

			else
                                echo " Nao encontrei o arquivo ${dir_temp}/${arq_met1} "
                                echo " Vou aguardar ${dormir} segundos. "
                                sleep ${dormir}

                                nt=$((nt+1))

                                if [ ${nt} -eq ${HABORT} ];then

                                echo " Esperei por ${HABORT} ciclos de ${nt} segundos pelo arquivo ${dir_temp}/${arq_met1}."
                                echo " Vou abortar a rodada."
                                exit 043

                                fi

			fi

		else

			if [ -e ${dir_temp}/${arq_met2} ];then

				ln -sf ${dir_temp}/${arq_met2} ./${arq_met2}
#				ln -sf ${dir_temp}/${arq_met2} ./${arq_met2_nocomma}
				FLAG=0

			else

				echo " Nao encontrei o arquivo ${dir_temp}/${arq_met2} "
				echo " Vou aguardar ${dormir} segundos. "
				sleep ${dormir}

				nt=$((nt+1))

				if [ ${nt} -eq ${HABORT} ];then

				echo " Esperei por ${HABORT} ciclos de ${nt} segundos pelo arquivo ${dir_temp}/${arq_met2}."
				echo " Vou abortar a rodada."
				exit 045

				fi
			fi
		fi

	done
done

# Substituindo variaveis no tmpl_namelist.input.cima e
# salvando tais substituicoes no namelist.input.cima

sed s/YYYY.END/${YYYY_end}/g ${dir_tmpl}/tmpl.namelist.input.cima > temp1
sed s/MM.END/${MM_end}/g 					temp1 > temp2
sed s/DD.END/${DD_end}/g 					temp2 > temp1
sed s/HH.END/${HH_end}/g 					temp1 > temp2
sed s/YYYY/${YYYY}/g 						temp2 > temp1
sed s/MM/${MM}/g 						temp1 > temp2
sed s/DD/${DD}/g 						temp2 > temp1
sed s/HH/${HH}/g 						temp1 > temp2
sed s/RESTFLAG/.false./g 					temp2 > temp1
							cp	temp1   temp2
sed s/HSTOP/${HINT}/g 						temp2 > temp1
sed s/HIS_INT/${HIS_INT}/g 					temp1 > temp2
sed s/FRAMES/${FRAMES}/g 					temp2 > temp1
sed s/RESTFLAG/${RESTFLAG}/g 					temp1 > temp2
sed s/INT_SEC2/${INT_SEC}/g 					temp2 > namelist.input.cima

# Aglutina as duas partes do namelist.input

mv namelist.input.cima namelist.input
cat namelist.input.baixo >> namelist.input

echo "O ${area}_realarg eh:"
echo
numhosts=`cat ${raiz}/invariantes/${area}/${area}_realarg`
${time} $mpi -machinefile ${raiz}/invariantes/${area}/${area}_realarg ./real.exe

mv rsl.error.* rsl.out.* ./real_out

###################################################################
#
# Verifica o termino da rodada do COSMO antes de disparar o
# wrf.exe do met510km.
#
###################################################################

if [ ${decisao} == "operacional" ];then

	if [ ${HSIM} == "00" ];then

                RFILE1=/home/admcosmo/cosmo/sse/data/prevdata${HSIM}/cosmo_sse22_${HSIM}_${datacorrente}048

        else

                RFILE1=/home/admcosmo/cosmo/antartica/data/prevdata${HSIM}/cosmo_ant_${HSIM}_${datacorrente}096

        fi

        nmax=240
        n1=0

        flag=1

        while [ $flag -eq 1 ];do

                if [ -e ${RFILE1} ]; then

                        echo " Encontrei o arquivo ${RFILE1} que eh o ultimo horario do COSMO. Vou disparar o WRF"
                        flag=0

                else

                        echo ""
                        echo " Verifica o ultimo prognostico feito do COSMO."

                        if [ ${HSIM} == "00" ];then

                                ultprog=`ls -ltr /home/admcosmo/cosmo/sse/data/prevdata${HSIM} | tail -1 | awk -F" " '{print $9}'`

                        else

                                ultprog=`ls -ltr /home/admcosmo/cosmo/antartica/data/prevdata${HSIM} | tail -1 | awk -F" " '{print $9}'`

                        fi

                        echo ""
                        echo " O ultimo prognostico do COSMO encontrado foi: ${ultprog}."
                        echo " Nao encontrei o arquivo ${RFILE1} que eh o ultimo horario do COSMO SSE. Vou esperar por 60 segundos e fazer uma nova verificacao."

                        n1=`expr $n1 + 1`
                        echo "n1= ${n1} de nmax= ${nmax}"

                        sleep 60

                fi

                if [ $n1 -ge $nmax ];then

                        echo " Aguardei o arquivo ${RFILE1} do COSMO por $nmax minutos. Vou abortar o lancamento do WRF."
                        echo " Houston, we have a BIG problem!!!"

                        kill -9 `ps -ef | grep wrf | awk ' { print $2 } '`
                        flag=2
                        exit 5

                fi

        done

	echo "O ${area}_wrfarg eh:"
	echo
	numhosts=`cat ${raiz}/invariantes/${area}/${area}_wrfarg`
	echo
	${time} $mpi -machinefile ${raiz}/invariantes/${area}/${area}_wrfarg ./wrf.exe

	mv rsl.error.* rsl.out.* ./wrf_out

	rm wrfinput_d01 wrfbdy_d01

elif [ ${decisao} == "manual" ];then

        echo "O ${area}_wrfarg eh:"
        echo
        numhosts=`cat ${raiz}/invariantes/${area}/${area}_wrfarg`
        echo
        ${time} $mpi -machinefile ${raiz}/invariantes/${area}/${area}_wrfarg ./wrf.exe

        mv rsl.error.* rsl.out.* ./wrf_out

        rm wrfinput_d01 wrfbdy_d01

fi

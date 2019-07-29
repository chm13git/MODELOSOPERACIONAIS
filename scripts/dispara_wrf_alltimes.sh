#!/bin/bash -x

# Script para disparar os scripts do WRF

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
	echo " em algum noh nao utilizado pelo COSMO, enquanto aguarda o termino"
	echo " da rodada do cosmo. Quando os prognosticos de referencia do cosmo forem encontrados,"
	echo " o script entenderah que o cosmo terminou e entao disparara os scripts 04 e 05."
	echo ""

        exit 1
fi

AREA=$1
area=`echo ${AREA} | tr [A-Z] [a-z]`
HSIM=$2
HSTA=$3
HSTO=$4
DECISAO=$5
decisao=`echo ${DECISAO} | tr [A-Z] [a-z]`

RODADA="Teste"  # trocar para operacional quando pag Status ok

export WRF_EM_CORE=1
export WRF_NMM_CORE=0
export WRF_DA_CORE=0
export WRFIO_NCD_LARGE_FILE_SUPPORT=1

ulimit -s unlimited
ulimit -v unlimited

source /opt/intel/intel_2018/bin/compilervars.sh intel64

export -f module
module use /usr/share/modules/modulefiles
module load mpi_intel/2018.2.199

export PATH=$PATH:/home/wrfoperador/local/bin:.
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/wrfoperador/local/lib
export NETCDF="/home/wrfoperador/local"

mpi=mpirun

if [ ${area} == "antartica" ];then

	raiz="/home/wrfoperador/wrf"
	dormir=300

else

	raiz="/home/wrfoperador/wrf"
	dormir=600

fi

dir_simulacao="${raiz}/wrf_${area}"
dir_wps="${dir_simulacao}/WPS"
dir_inv="${raiz}/invariantes"
arq_wrf="${dir_inv}/arq_wrf"
arq_base=`echo ${dir_inv}/${area}.txt | cut -d"/" -f6 | cut -d"." -f1`

# Verifica a consistencia do quinto parametro.

if [ "${decisao}" == "operacional" ] || [ "${decisao}" == "manual" ];then

	echo " O quinto parametro estah CORRETO."

else

	echo " O quinto parametro estah INCORRETO."
	exit 2

fi

# Ve se a area coincide com o descrito 
# no nome do arquivo no diretorio invariantes

if ! [ ${arq_base} == ${area} ];then

	echo
        echo " Variavel area NAO confere com algum nome de "
        echo " arquivo dentro do diretorio INVARIANTES."
        echo " Verifique o nome da area e tente de novo."
        echo
	exit 3

else

	echo
        echo " Area confere com arquivo ${arq_base} dentro do diretorio invariantes."
	echo
        echo " Utilizando informacoes deste arquivo."
	echo

        AREA2=`echo $AREA | cut -c1-3 |  tr [a-z] [A-Z]`
        MSG="PROCESSAMENTO WRF${AREA2} ${datahoje} ${HSIM}Z INICIADO"
        /usr/bin/input_status.php  WRF${AREA2} ${HSIM} ${RODADA} AMARELO "$MSG"

	echo ""
	echo " Inicio do script 01_apaga_wrf_alltimes.sh."
	echo ""

	${HOME}/scripts/01_apaga_wrf_alltimes.sh   apaga 	${area} ${HSIM}
	echo ""
	echo " Termino do script 01_apaga_wrf_alltimes.sh."
	echo ""
	echo " Inicio do script 02_verif_gfs.sh."
	echo ""
	${HOME}/scripts/02_verif_gfs.sh            		${area} ${HSIM}         ${HSTO} > ${raiz}/wrf_${AREA}/log/02.log 2> ${raiz}/wrf_${AREA}/log/02.log &
	echo ""
	echo " Termino do script 02_verif_gfs.sh."
	echo ""

	wpsarg=`cat ${raiz}/invariantes/${area}/${area}_wpsarg`
	realarg=`cat ${raiz}/invariantes/${area}/${area}_realarg`
	wrfarg=`cat ${raiz}/invariantes/${area}/${area}_wrfarg`
	upparg=`cat ${raiz}/invariantes/${area}/${area}_upparg`

	echo "################################################"
	echo "#"
	echo "# Serao utilizados os seguintes nos para o WPS."
	echo "#"
	echo ${wpsarg}
	echo "################################################"

        echo "################################################"
        echo "#"
        echo "# Serao utilizados os seguintes nos para o REAL."
        echo "#"
        echo ${realarg}
        echo "################################################"

        echo "################################################"
        echo "#"
        echo "# Serao utilizados os seguintes nos para o WRF."
        echo "#"
        echo ${wrfarg}
        echo "################################################"

        echo "################################################"
        echo "#"
        echo "# Serao utilizados os seguintes nos para o UPP."
        echo "#"
        echo ${upparg}
        echo "################################################"

        ###################################################################
        #
        # Verifica o termino da rodada do VERIF do COSMO antes de
        # disparar o pre processamento do WRF.
        # O motivo eh que o pre processamento utiliza os mesmos nos do VERIF
	#
        # Para a rodada de 00Z o parametro eh o COSMO SSE, jah para
	# a simulacao de 12Z o parametro eh o COSMO ANT.
	#
        ###################################################################

	datacorrente=`cat ${HOME}/datas/datacorrente${HSIM}`

        if [ ${decisao} == "operacional" ];then

		if [ ${HSIM} == "00" ];then

	                RFILE0=/home/admcosmo/cosmo/sse/data/init_cond${HSIM}/lbff02000000

		else

			RFILE0=/home/admcosmo/cosmo/antartica/data/init_cond${HSIM}/lbff04000000

		fi

                nmax=240
                n=0

                flag=1

                while [ $flag -eq 1 ];do

                        if [ -e ${RFILE0} ]; then

                                echo " Encontrei o arquivo ${RFILE0} que eh o ultimo horario do VERIF do COSMO. Vou disparar o WRF"
                                flag=0

                        else
                                echo ""
                                echo " Verifica o ultimo prognostico feito do VERIF do COSMO."

				if [ ${HSIM} == "00" ];then

                                	ultprogverif=`ls -ltr /home/admcosmo/cosmo/sse/data/init_cond${HSIM} | tail -1 | awk -F" " '{print $9}'`

				else

					
                                	ultprogverif=`ls -ltr /home/admcosmo/cosmo/antartica/data/init_cond${HSIM} | tail -1 | awk -F" " '{print $9}'`

				fi

                                echo ""
                                echo " O ultimo prognostico do VERIF do COSMO encontrado foi: ${ultprogverif}."

				echo " Nao encontrei o arquivo ${RFILE0} que eh o ultimo horario do VERIF do COSMO. Vou esperar por 60 segundos e fazer uma nova verificacao."

                                n=`expr $n + 1`
				echo "n= ${n} de nmax= ${nmax}"

                                sleep 60

                        fi

                        if [ $n -ge $nmax ];then

                                echo " Aguardei o arquivo ${RFILE0} do COSMO por $nmax minutos. Vou abortar o lancamento do WRF."
                                echo " Houston, we have a problem!!!"

                                kill -9 `ps -ef | grep wrf | awk ' { print $2 } '`
                                flag=2
                                exit 4

                        fi

                done

        	###################################################################
        	#
        	# Limpando a memoria CACHE antes da rodada
        	#
		echo ""
		echo " Limpando memoria chache da maquina."
		echo ""
        	ssh root@10.13.100.31 'bash -s' < /home/wrfoperador/scripts/04.2_limpa_cache.sh
        	#
        	###################################################################

		echo ""
		echo " Inicio do script 03_roda_ungrib_metgrid.sh."
		echo ""
		(. /home/wrfoperador/.bashrc; ${HOME}/scripts/03_roda_ungrib_metgrid.sh 	${area} ${HSIM} ${HSTA} ${HSTO} > ${raiz}/wrf_${AREA}/log/03.log 2> ${raiz}/wrf_${AREA}/log/03.log &)
		echo ""
		echo " Colocando o script acima em background e partindo para o 04_roda_real_wrf_alltimes.sh"

		# O sleep abaixo eh uma estimativa do tempo necessario para
		# o WPS gerar o preprocessamento para que o WRF rode.
		# Aproximadamente 15 min.

		sleep 900

                (. /home/wrfoperador/.bashrc; ${HOME}/scripts/04_roda_real_wrf_alltimes.sh 	${area} ${HSIM} ${HSTA} ${HSTO} operacional > ${raiz}/wrf_${AREA}/log/04.log 2> ${raiz}/wrf_${AREA}/log/04.log &)

                # O sleep abaixo eh uma estimativa entre o tempo que o REAL
                # demora para rodar mais o tempo que o WRF demora para gerar
                # o primeiro prognostico. Em media esse tempo eh de 20 min.

                sleep 1200

                (. /home/wrfoperador/.bashrc; ${HOME}/scripts/05_roda_upp_alltimes.sh 		${area} ${HSIM} ${HSTA} ${HSTO} operacional > ${raiz}/wrf_${AREA}/log/05.log 2> ${raiz}/wrf_${AREA}/log/05.log &)

	elif [ ${decisao} == "manual" ];then

	        ###################################################################
	        #
	        # Limpando a memoria CACHE antes da rodada
	        #
                echo ""
                echo " Limpando memoria chache da maquina."
                echo ""
	        ssh root@10.13.100.31 'bash -s' < /home/wrfoperador/scripts/04.2_limpa_cache.sh
	        #
	        ###################################################################

                echo ""
                echo " Inicio do script 03_roda_ungrib_metgrid.sh."
                echo ""
                ${HOME}/scripts/03_roda_ungrib_metgrid.sh               ${area} ${HSIM} ${HSTA} ${HSTO} > ${raiz}/wrf_${AREA}/log/03.log 2> ${raiz}/wrf_${AREA}/log/03.log &
                echo ""
                echo " Colocando o script acima em background e partindo para o 04_roda_real_wrf_alltimes.sh"

		# O sleep abaixo eh o tempo necessario ao script 03 gerar o pre processamento 
		# necessario ao script 04. Dai o script 03 precisa de um tempo para gerar 
		# tais arquivos antes que o script 04 possa rodar.
	
		sleep ${dormir}

		(. /home/wrfoperador/.bashrc; ${HOME}/scripts/04_roda_real_wrf_alltimes.sh        ${area} ${HSIM} ${HSTA} ${HSTO} manual > ${raiz}/wrf_${AREA}/log/04.log 2> ${raiz}/wrf_${AREA}/log/04.log &)

                # O sleep abaixo eh uma estimativa entre o tempo que o REAL
                # demora para rodar mais o tempo que o WRF demora para gerar
                # o primeiro prognostico. Em media esse tempo eh de 20 min.

                sleep 1200

                echo ""
                echo " Inicio do script 05_roda_upp_alltimes.sh"
                echo ""

		(. /home/wrfoperador/.bashrc; ${HOME}/scripts/05_roda_upp_alltimes.sh 		 ${area} ${HSIM} ${HSTA} ${HSTO} manual > ${raiz}/wrf_${AREA}/log/05.log 2> ${raiz}/wrf_${AREA}/log/05.log &)


	fi

fi

exit 6

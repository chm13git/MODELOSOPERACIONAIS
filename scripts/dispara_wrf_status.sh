#!/bin/bash

# Script para disparar os scripts do WRF

AREA=$1
area=`echo $AREA | tr [A-Z] [a-z]`
HSIM=$2
HSTA=$3
HSTO=$4

export WRF_EM_CORE=1
export WRFIO_NCD_LARGE_FILE_SUPPORT=1

#export LIBDWD_BITMAP_TYPE=ASCII

export MPI_DSM_DISTRIBUTE=1
export MPI_IB_RAILS=2

# A linha abaixo serve pois sem ela
# o WRF nao roda na ICE para resolucao
# maior que 20 km.
# Eu tentei 1000 mas ainda n funcionou
# Dai eu tentei 10000 e o WPS rodou.
MPI_GROUP_MAX=1024
MPI_BUFS_PER_PROC=1024
MPI_BUFS_PER_HOST=1024

mpt=`cat $HOME/wrf/invariantes/mpt_versao | head -1`
ulimit -s unlimited
ulimit -v unlimited

. /home/wrfoperador/.bashrc
source /opt/intel/bin/compilervars.sh intel64
. /usr/share/modules/init/bash
module load mpt/${mpt}

export NETCDF="/home/wrfoperador/local"
export WRFIO_NCD_LARGE_FILE_SUPPORT="1"

export PATH=$PATH:/home/wrfoperador/local/bin:.
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/wrfoperador/local/lib

# Verifica argumentos

if ! [ $# -eq 4 ];then

        echo
        echo " Entre com a area (metarea5, antartica), o horario de simulacao \
(00, 12), o prognostico (00, 03, 06, etc.) e o tempo de integracao (24, 48, 72, 96, etc.). "
        echo

        exit 10
fi

area=`echo $AREA | tr [A-Z] [a-z]`

if [ ${area} == "antartica" ];then

	raiz="/home/wrfoperador/wrf"

else

	raiz="/home/wrfoperador/wrf"

fi

dir_simulacao="${raiz}/wrf_${area}"
dir_wps="${dir_simulacao}/WPS"
dir_inv="${raiz}/invariantes"
arq_wrf="${dir_inv}/arq_wrf"
arq_base=`echo ${dir_inv}/${area}.txt | cut -d"/" -f6 | cut -d"." -f1`

# Ve se a area coincide com o descrito 
# no nome do arquivo no diretorio invariantes

if ! [ ${arq_base} == ${area} ];then

	echo
        echo " Variavel area NAO confere com algum nome de "
        echo " arquivo dentro do diretorio INVARIANTES."
        echo " Verifique o nome da area e tente de novo."
        echo

else

	echo
        echo " Area confere com arquivo ${arq_base} dentro do diretorio invariantes."
	echo
        echo " Utilizando informacoes deste arquivo."
	echo

	${HOME}/scripts/02_verif_gfs.sh            ${area} ${HSIM}         ${HSTO} > ${raiz}/wrf_${AREA}/log/02.log 2> ${raiz}/wrf_${AREA}/log/02.log &
	${HOME}/scripts/03_roda_ungrib_metgrid.sh  ${area} ${HSIM} ${HSTA} ${HSTO} > ${raiz}/wrf_${AREA}/log/03.log 2> ${raiz}/wrf_${AREA}/log/03.log &

	# Esse Sleep eh porque as vezes eu removo (na mao) um arquivo 
	# Criado pelo script 03 e necessario ao script 04. Dai o script 03
	# precisa de uns segundos para gerar tal arquivo antes que o script
	# 04 possa rodar. PS: o arquivo eh o geo_em.d01.nc

	sleep 60
	
	(. /home/wrfoperador/.bashrc; ${HOME}/scripts/04_roda_real_wrf.sh        ${area} ${HSIM} ${HSTA} ${HSTO} > ${raiz}/wrf_${AREA}/log/04.log 2> ${raiz}/wrf_${AREA}/log/04.log &)
	(. /home/wrfoperador/.bashrc; ${HOME}/scripts/05_roda_upp.sh 		 ${area} ${HSIM} ${HSTA} ${HSTO} > ${raiz}/wrf_${AREA}/log/05.log 2> ${raiz}/wrf_${AREA}/log/05.log &)

fi

exit 34

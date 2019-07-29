#!/bin/bash -x

# Script para disparar WRF apos a execucao do COSMO
#
# 1 - METAREA5 	(10KM)
# 2 - CARTA	(10KM)

HSIM=$1

if ! [ $# -eq 1 ];then

	echo
	echo " Entre com o horario de simulacao."
	echo

	exit 22

fi

# Para o horario de 00Z, dispara consecutivamente a METAREA5 e CARTA
# Para o horario de 12Z, somente METAREA5 e CARTA.

if [ ${HSIM} -eq 00 ];then

        ###################################################################
        #
        # Verifica o termino da rodada do COSMO ANT antes de disparar o
        # WRF met510km.
        #
        ###################################################################

        datacorrente=`cat ${HOME}/datas/datacorrente${HSIM}`

        RFILE=/home/admcosmo/cosmo/antartica/data/prevdata${HSIM}/cosmo_ant_${HSIM}_${datacorrente}096
        nmax=240
        n=0

        flag=1

        while [ $flag -eq 1 ];do

                if [ -e ${RFILE} ]; then

                        echo " Encontrei o arquivo ${RFILE} que eh o ultimo horario do COSMO ANT. Vou disparar o WRF"
                        flag=0

                else

                        n=`expr $n + 1`
                        sleep 60

                fi

                if [ $n -ge $nmax ];then

                        echo " Aguardei o arquivo ${RFILE} do COSMO por $nmax minutos. Vou abortar o lancamento do WRF."
                        kill -9 `ps -ef | grep wrf | awk ' { print $2 } '`
                        flag=2
                        exit 222

                fi

	done

	/home/wrfoperador/scripts/dispara_wrf_alltimes.sh met510km 	${HSIM} 00 120 > ${HOME}/scripts/logs/wrf_met510km_${HSIM}.log

#	/home/wrfoperador/scripts/dispara_wrf_alltimes.sh carta 	${HSIM} 00 24 > ${HOME}/scripts/logs/wrf_carta_${HSIM}.log

else

        ###################################################################
        #
        # Verifica o termino da rodada do COSMO ANT antes de disparar o
        # WRF met510km.
        #
        ###################################################################

        datacorrente=`cat ${HOME}/datas/datacorrente${HSIM}`

        RFILE=/home/admcosmo/cosmo/antartica/data/prevdata${HSIM}/cosmo_ant_${HSIM}_${datacorrente}096
        nmax=240
        n=0

        flag=1

        while [ $flag -eq 1 ];do

                if [ -e ${RFILE} ]; then

                        echo " Encontrei o arquivo ${RFILE} que eh o ultimo horario do COSMO ANT. Vou disparar o WRF"
                        flag=0

                else

                        n=`expr $n + 1`
                        sleep 60

                fi

                if [ $n -ge $nmax ];then

                        echo " Aguardei o arquivo ${RFILE} do COSMO por $nmax minutos. Vou abortar o lancamento do WRF."
                        kill -9 `ps -ef | grep wrf | awk ' { print $2 } '`
                        flag=2
                        exit 222

                fi

	done

        /home/wrfoperador/scripts/dispara_wrf_alltimes.sh met510km      ${HSIM} 00 120 > ${HOME}/scripts/logs/wrf_met510km_${HSIM}.log

#        /home/wrfoperador/scripts/dispara_wrf_alltimes.sh carta         ${HSIM} 00 24 > ${HOME}/scripts/logs/wrf_carta_${HSIM}.log


fi

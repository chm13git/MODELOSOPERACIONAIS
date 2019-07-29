#!/bin/bash

#########################################
#
# Verificar os arquivos do GFS e gerar 
# arquivos de checagem para rodar o
# WPS.
#
# Criado em 14/11/2012
#
# Autor: 1T(T) Alexandre Gadelha
#
#########################################

# Verifica argumentos

if ! [ $# -eq 3 ];then

	echo
	echo " Entre com a area (metarea5, antartica, etc.), o horario de simulacao \
(00, 12) e o tempo de integracao (24, 48, 72, 96, etc.). "
	echo

	exit
fi

AREA=$1								# AREA de simulacao. ex: metarea5, caribe, etc.
area=`echo $AREA | tr [A-Z] [a-z]`				# Transforma maiusculas em minusculas.
HSIM=$2								# Define o horario de simulacao, 00 ou 12.
HSTOP=$3							# Define o horario limite dos dados do GFS. ex: 24, 48, 72, etc.

data_avn=`cat ~/datas/datacorrente${HSIM}`			# Pega a data corrente no formato, ex: 20121121
curr_date=`cat ~/datas/datacorrente${HSIM}`			# Pega a data corrente no formato, ex: 20121121
curr_date=${curr_date}${HSIM}					# Transforma o formato acima em,   ex: 2012112100
YYYY=`echo $curr_date | cut -c1-4`				# Extrai o ano do formato acima,   ex: 2012
MM=`echo $curr_date | cut -c5-6`				# Extrai o mes do formato acima,   ex: 11
DD=`echo $curr_date | cut -c7-8`				# Extrai o dia do formato acima,   ex: 21
HH=`echo $curr_date | cut -c9-10`				# Extrai a hora do formato acima,  ex: 00

data_ant=`${HOME}/local/bin/caldate ${curr_date} - 24h 'yyyymmddhh'`     # Data utilizada para apagar o diretorio de dados do GFS do dia anterior.

#HABORT=1							# numero de ciclos para abortar a espera dos dados do GFS.
HABORT=240							# numero de ciclos para abortar a espera dos dados do GFS.
dormir=60							# Controla o tempo de sleep (em segundos).
dir_gfs="${HOME}/DATA"						# diretorio BASE de verificacao do GFS. 
#link_gfs="${dir_gfs}/GFS/data${HSIM}"				# diretorio NFS onde os dados do GFS chegam.


link_gfs="${dir_gfs}/GFS"					# diretorio NFS onde os dados do GFS chegam.
#link_gfs="${dir_gfs}"
arq1="gfs.t${HSIM}z.pgrb2.0p25.f"
arq2="avn${data_avn}_${HSIM}_"

cd ${link_gfs}
verif_link=`pwd -P`
maquina=`echo ${verif_link} | awk -F"/" '{print $4}'`

# O nome do arquivo do GFS muda de acordo com a maquina de download
# para as variaveis arq1 e arq2 declaradas acima, por isso eh necessario 
# Identificar qual maquina de origem do dado.

if [ ${maquina} == "dpns01" ];then

	echo "A maquina eh a dpns01"

	arq=${arq1}

	# A parte -f "%0Ng" dentro do seq no comando abaixo serve
	# para ajustar o numero de digitos do HREF, nao precisando
	# fazer um IF para tal.

	for HREF in `seq -f "%03g" 00 3 $HSTOP`;do

		FLAG=1
		nt=1

		echo
		echo " ########################################################"
		echo " # Segundo os arquivos de data, hoje eh dia ${DD}-${MM}-${YYYY}. #"
		echo " ########################################################"
		echo

		# Para cada horario HREF, verifica se o arquivo do GFS chegou ou nao e
		# caso tenha chegado, verifica a data e tamanho do mesmo, criando
		# arquivos com sufixo SAFO dentro do diretorio dos dados do GFS ou abortando
		# caso exceda o tempo limite.

		while [ ${FLAG} -eq 1 ] && [ ${nt} -le ${HABORT} ];do

			if [ -e ${link_gfs}/data${HSIM}/${arq}${HREF} ];then

				grib_data=`${HOME}/local/bin/wgrib2 -v ${link_gfs}/data${HSIM}/${arq}${HREF} | head -1 | cut -d":" -f3 | cut -d"=" -f2`
	
				if [ ${grib_data} == ${curr_date} ];then	

					echo " O arquivo ${arq}${HREF} eh da data atual"

					sleep 2						# Esse sleep eh porque o arquivo pode ter sido criado
											# mas nao estar completo. Sem ele o verif_gfs.sh gera
											# um LOG grande com a frase "O arquivo ${arq}${HREF} eh
											# da data atual", enquanto o arquivo ainda estiver chegando.

	                		# Compara a data atual com a data de dentro do arquivo do GFS

					mkdir -p ${dir_gfs}/${curr_date}

	                        	# Ajusta o tamanho_minimo para os dados de analise e previsao do GFS
	                        	# Esses valores sao achados executando manualmente o comando stat -c%s
	                        	# no arquivo de analise e de previsoes do GFS.

	                       		if [ ${arq}${HREF} == ${arq}000 ];then

						nvar_ref=354

                        		else

						nvar_ref=417

                        		fi

					# Compara tamanho do arquivo com o tamanho_minimo

					nvar=`${HOME}/local/bin/wgrib2 ${link_gfs}/data${HSIM}/${arq}${HREF} | wc -l`

					if [ ${nvar} -lt ${nvar_ref} ];then

						echo
						echo " Arquivo ${arq}${HREF} menor que o Padrao. Deve estar chegando."
						echo

						nt=$((nt+1))

		                                if [ ${nt} -eq ${HABORT} ];then

		                        	        echo " Apos ${HABORT} ciclos, ABORTEI esperar pelo arquivo ${arq}${HREF} ATUAL. "
							echo " Sainda por EXIT 01."

		                        	        exit 01

		                                fi				

						sleep ${dormir}

					else

						echo " Arquivo ${arq}${HREF}_SAFO gerado."
						echo ${arq}${HREF} > ${dir_gfs}/${curr_date}/${arq}${HREF}_SAFO
						FLAG=0

						# BOM MOMENTO PRA DIZER QUE O ARQUIVO PROG DO GFS TA SAFO AMARELO
						MSG="Dados do GFS ${DD}${MM}${YYYY} HREF${HREF} ${HSIM}Z PRONTIFICADO"

						if [ ${AREA} == metarea5 ];then
 
							/usr/bin/input_status.php VERIF_GFS ${HSIM} Teste Cinza "$MSG"

						fi
						nt=$((nt+1))

					fi

				else

					# O arquivo existe mas as datas sao diferentes, possivelmente arquivo antigo.
	
					echo " Arquivo ${arq}${HREF} esta na pasta mas nao eh de hoje. Ciclo ${nt} de ${HABORT} para atualizar."

					if [ ${nt} -eq ${HABORT} ];then
			
						echo " Apos ${HABORT} ciclos, ABORTEI esperar pelo arquivo ${arq}${HREF} ATUAL. "
						echo " Saindo por EXIT 02."
						# BOM MOMENTO PRA DIZER QUE PEGOU NO PROG ALGUMA COISA VERMELHO
						exit 02

					fi

					sleep ${dormir}
					nt=$((nt+1))

				fi

			else

				# O arquivo nao existe e nao chegou durante o horario de espera.

				echo " O arquivo ${arq}${HREF} nao existe. Ciclo ${nt} de ${HABORT} para esperar."

				if [ ${nt} -ge ${HABORT} ];then

					echo " Apos ${HABORT} ciclos, ABORTEI esperar pelo arquivo ${arq}${HREF} "
					echo " Saindo poe EXIT 03."

					# BOM MOMENTO PRA DIZER QUE PEGOU VERMELHO
					MSG="Dados do GFS  ${DD}${MM}${YYYY} ${HREF} ${HSIM}Z ABORTEI A RODADA"
					/usr/bin/input_status.php Verif_gfs ${HSIM} Teste Vermelho "$MSG"
	
					exit 03

				fi

				sleep ${dormir}
				nt=$((nt+1))

			fi

		done


	done

else

	echo "A maquina eh a dpns31"

        # A parte -f "%0Ng" dentro do seq no comando abaixo serve
        # para ajustar o numero de digitos do HREF, nao precisando
        # fazer um IF para tal.

	for HREF in `seq -f "%02g" 00 3 $HSTOP`;do

	        arq0=${arq2}
		arqi="${arq2}00.grib2"
	        arq="${arq0}${HREF}.grib2"

		FLAG=1
		nt=1

		echo
		echo " ########################################################"
		echo " # Segundo os arquivos de data, hoje eh dia ${DD}-${MM}-${YYYY}. #"
		echo " ########################################################"
		echo

		# Para cada horario HREF, verifica se o arquivo do GFS chegou ou nao e
		# caso tenha chegado, verifica a data e tamanho do mesmo, criando
		# arquivos com sufixo SAFO dentro do diretorio dos dados do GFS ou abortando
		# caso exceda o tempo limite.

		while [ ${FLAG} -eq 1 ] && [ ${nt} -le ${HABORT} ];do

			if [ -e ${link_gfs}/${data_avn}/${arq} ];then

				grib_data=`${HOME}/local/bin/wgrib2 -v ${link_gfs}/${data_avn}/${arq} | head -1 | cut -d":" -f3 | cut -d"=" -f2`
	
				if [ ${grib_data} == ${curr_date} ];then	

					echo " O arquivo ${arq} eh da data atual"

					sleep 2						# Esse sleep eh porque o arquivo pode ter sido criado
											# mas nao estar completo. Sem ele o verif_gfs.sh gera
											# um LOG grande com a frase "O arquivo ${arq}${HREF} eh
											# da data atual", enquanto o arquivo ainda estiver chegando.

	                		# Compara a data atual com a data de dentro do arquivo do GFS

					mkdir -p ${dir_gfs}/${curr_date}

	                        	# Ajusta o tamanho_minimo para os dados de analise e previsao do GFS
	                        	# Esses valores sao achados executando manualmente o comando stat -c%s
	                        	# no arquivo de analise e de previsoes do GFS.

	                       		if [ ${arq} == ${arqi} ];then

						nvar_ref=354

	                        	else

						nvar_ref=417

	                        	fi

					# Compara tamanho do arquivo com o tamanho_minimo

					nvar=`${HOME}/local/bin/wgrib2 ${link_gfs}/${data_avn}/${arq} | wc -l`

					if [ ${nvar} -lt ${nvar_ref} ];then

						echo
						echo " Arquivo ${arq} menor que o Padrao. Deve estar chegando."
						echo

						nt=$((nt+1))

		                                if [ ${nt} -eq ${HABORT} ];then

		                        	        echo " Apos ${HABORT} ciclos, ABORTEI esperar pelo arquivo ${arq}${HREF} ATUAL. "
							echo " Sainda por EXIT 01."

		                        	        exit 01

		                                fi				

						sleep ${dormir}

					else

						echo " Arquivo ${arq}_SAFO gerado."

						# Manipulacao de digitos para evitar erro de octal do numero 009.
						dig3=`printf "%03d\n" $((10#${HREF}))`

						# Se o rquivo passou nos testes de data e tamanho acima sera criado um link 
						# para um diretorio com o mesmo nome do arquivo oriundo da dpns01.
						# Isso eh necessario para nao ter que modificar o script 03 de rodada do WPS.

						ln -sf ${link_gfs}/${data_avn}/${arq} ${link_gfs}/data${HSIM}/${arq1}${dig3}
						echo ${arq} > ${dir_gfs}/${curr_date}/${arq1}${dig3}_SAFO

						FLAG=0

						# BOM MOMENTO PRA DIZER QUE O ARQUIVO PROG DO GFS TA SAFO AMARELO
						MSG="Dados do GFS ${DD}${MM}${YYYY} HREF${HREF} ${HSIM}Z PRONTIFICADO"
						if [ ${AREA} == metarea5 ];then
 
							/usr/bin/input_status.php VERIF_GFS ${HSIM} Teste Cinza "$MSG"
						fi
						nt=$((nt+1))

					fi

				else

					# O arquivo existe mas as datas sao diferentes, possivelmente arquivo antigo.
	
					echo " Arquivo ${arq} esta na pasta mas nao eh de hoje. Ciclo ${nt} de ${HABORT} para atualizar."

					if [ ${nt} -eq ${HABORT} ];then
			
						echo " Apos ${HABORT} ciclos, ABORTEI esperar pelo arquivo ${arq} ATUAL. "
						echo " Saindo por EXIT 02."
						# BOM MOMENTO PRA DIZER QUE PEGOU NO PROG ALGUMA COISA VERMELHO
						exit 02

					fi

					sleep ${dormir}
					nt=$((nt+1))

				fi

			else

				# O arquivo nao existe e nao chegou durante o horario de espera.

				echo " O arquivo ${arq} nao existe. Ciclo ${nt} de ${HABORT} para esperar."

				if [ ${nt} -ge ${HABORT} ];then

					echo " Apos ${HABORT} ciclos, ABORTEI esperar pelo arquivo ${arq} "
					echo " Saindo poe EXIT 03."

					# BOM MOMENTO PRA DIZER QUE PEGOU VERMELHO
					MSG="Dados do GFS  ${DD}${MM}${YYYY} ${HREF} ${HSIM}Z ABORTEI A RODADA"
					/usr/bin/input_status.php Verif_gfs ${HSIM} Teste Vermelho "$MSG"
	
					exit 03

				fi

				sleep ${dormir}
				nt=$((nt+1))

			fi

		done

	done

fi

#BOM MOMENTO PRA DIZER QUE TA SAFO VERIFGFS VERDE	        
#MSG="Dados do GFS ${DD}${MM}${YYYY} ${HSIM} RODADA FINALIZADA"
sleep 1
if [ -e ${dir_gfs}/${curr_date}/${arq}${HSTOP}_SAFO ] && [ ${AREA} == metarea5 ]
then
MSG="Dados do GFS ${DD}${MM}${YYYY} ${HSIM} RODADA FINALIZADA"
/usr/bin/input_status.php Verif_gfs ${HSIM} Teste Cinza "$MSG"
fi

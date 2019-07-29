/!/bin/bash -x

# Script para lidar com arquivos para confeccao
# de meteogramas. Dependendo do numero de parametros
# passados ele executa determinada tarefa.

# Parte a ser executada para renomear os arquivos 
# de saida do tslist durante a rodada

AREA=$1
area=`echo $AREA | tr [A-Z] [a-z]`
HSIM=$2
HREF=$3

if [ ${area} == "antartica" ] || [ ${area} == "antarticap" ]
then
	raiz1="/home/wrfoperador/pwrf"
else
	raiz1="/home/wrfoperador/wrf"
fi

dir_simulacao1="${raiz1}/wrf_${area}"
dir_wrf1="${dir_simulacao1}/WRF"
dir_produtos1="${dir_simulacao1}/produtos"
dir_met1="${dir_produtos1}/meteogramas_${HSIM}"
dir_inv1="${raiz1}/invariantes/${area}"

if ! [ $# -eq 3 ];then

echo " Entre com a AREA, o horario de SIMULACAO e o horario A SER PROCESSADO."
exit 411

fi

tslist_area=`cat ${dir_wrf1}/tslist`

if [ -e ${dir_wrf1}/tslist ];then

	echo
	echo " Vou procurar os arquivos que estao sendo gerados "
	echo " durante o horario ${HREF} para renomea-los."

	cabecalho=3
	n_linha=`cat ${dir_wrf1}/tslist | wc -l`
	n_estac=`echo "${n_linha} - ${cabecalho}" | bc`
	lista_estac=`cat ${dir_wrf1}/tslist | tail -${n_estac} | awk ' { print $2 } ' | cut -c1-5`
	lista_suf="PH QV TH TS UU VV"

		# Loop nas ESTACOES de acordo com $lista_estac

		for estac in ${lista_estac};
		do

			# Loop nos SUFIXOS de acordo com $lista_suf

			for suf in ${lista_suf};
			do

			mv ${dir_wrf1}/${estac}.d01.${suf} ${dir_met1}/${estac}.${HREF}.${suf}

			done

		done

	rm ${dir_wrf1}/tslist

else

	echo " Nao existe o arquivo ${dir_wrf1}/tslist."

fi

#!/bin/bash -x

############################################
#
# Script para gerar estrutura de diretorios
# e arquivos para novas simulacoes
#
############################################

# Define o diretorio raiz a partir do qual a
# estrutura sera criada.

# verifica o numero de parametros e carrega a 
# area de simulacao em letras MINUSCULAS

if [ $# -ne 1 ];then

	echo
	echo "Entre com o nome da nova AREA de simulacao ex. metarea5, caribe, libano."
	echo
	exit 00
fi

AREA=$1

area=`echo $AREA | tr [A-Z] [a-z]`

if [ ${area} == "antartica" ] || [ ${area} == "antarticap" ];then

	raiz="/home/wrfoperador/wrf"

elif  [ ${area} == "met510km" ];then

	raiz="/home/wrfoperador/wrf"

else

	raiz="/home/wrfoperador/wrf"

fi

# Define diretorio de simulacao e verifica se
# o mesmo existe, criando-o se necessario.
# Tambem cria outros subdiretorios e copia
# arquivos dos diretorios base

dir_simulacao="${raiz}/wrf_${area}"
dir_wps="${dir_simulacao}/WPS"
dir_wrf="${dir_simulacao}/WRF"
dir_upp="${dir_simulacao}/UPP"
dir_produtos="${dir_simulacao}/produtos"
dir_met="${dir_produtos}/meteogramas"
dir_vent="${dir_produtos}/vento"
dir_temp="${dir_simulacao}/temporarios"
dir_inv="${raiz}/invariantes"
run_wrf="${raiz}/WRFV3/run"

arq_base=`cat ${raiz}/invariantes/${area}.txt | grep DOMINIO | cut -d" " -f2`

if [ -d ${dir_simulacao} ]
then

	echo
	echo "Esta AREA ja existe, defina outro nome!"
	echo
	exit 11
else

	if ! [ -d ${dir_simulacao} ] && [ ${arq_base} == ${area} ];then

	echo " Area confere com arquivo ${arq_base} dentro do diretorio invariantes."
	echo " Utilizando informacoes deste arquivo."

	echo
	echo " Criando diretorio de simulacao: ${dir_simulacao} e outros."
	echo
	mkdir -p ${dir_simulacao} ${dir_wps} ${dir_wrf} ${dir_upp} ${dir_wrf}/real_out				\
	${dir_wrf}/wrf_out ${dir_produtos} ${dir_simulacao}/log ${dir_temp}/dados_00 ${dir_temp}/dados_12			\
	${dir_met}_00 ${dir_met}_12 ${dir_vent}_00 ${dir_vent}_12 ${dir_upp}/postprd ${dir_upp}/parm ${dir_produtos}/dados_00	\
	${dir_produtos}/dados_12 ${dir_produtos}/grib_00 ${dir_produtos}/grib_12 ${dir_produtos}/dat_00	${dir_produtos}/dat_12  \
	${dir_produtos}/zygrib_00 ${dir_produtos}/zygrib_12 ${dir_produtos}/gempak_00 ${dir_produtos}/gempak_12

	echo

	# copia arquivos para o diretorio do WPS

	cp ${raiz}/WPS/link_grib.csh ${dir_wps}

	ln -sf ${raiz}/WPS/geogrid/src/geogrid.exe ${dir_wps}/geogrid.exe
	ln -sf ${raiz}/WPS/geogrid/GEOGRID.TBL.ARW ${dir_wps}/GEOGRID.TBL

	ln -sf ${raiz}/WPS/ungrib/src/ungrib.exe ${dir_wps}/ungrib.exe
	ln -sf ${raiz}/WPS/ungrib/Variable_Tables/Vtable.GFS ${dir_wps}/Vtable

	ln -sf ${raiz}/WPS/metgrid/src/metgrid.exe ${dir_wps}/metgrid.exe
	ln -sf ${raiz}/WPS/metgrid/METGRID.TBL ${dir_wps}/METGRID.TBL


	# Copia arquivos basicos para o diretorio do WRF
	# preservando os links para o diretorio original.

	cp -d ${run_wrf}/* ${dir_wrf}
	rm ${dir_wrf}/*.exe
	ln -sf ${raiz}/WRFV3/main/*.exe ${dir_wrf}

	# Copia arquivos para o diretorio do UPP

	cp -d ${raiz}/UPPV3.2/parm/wrf_cntrl.parm ${dir_upp}/parm
	cp -d ${raiz}/UPPV3.2/scripts/run_unipost ${dir_upp}/postprd

	fi
fi

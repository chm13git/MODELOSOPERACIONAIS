#!/bin/bash 

#############################################
#
# Script para extracao de dados GRIB, visando
# gerar arquivos de inut do WRF para o WW3.
# o diretorio de origem dos dados sera o da
# rodada operacional do WRF definido como
# $DIRDADOSORI. Esta pronto para remover os 
# dados de vento do dia corrente.
#
# Escrito em 21MAR2012
#
# Alterado em 11FEV2014
#
# Autor: 1T(T) Alexandre Gadelha
#
#############################################

#############################################
#
# Verifica se foi passado o horario da rodada
#
#############################################

if [ "$#" -ne 4 ]
then
     echo "Entre com a area (metarea5, antartica), o horario da rodada (00 ou 12), o horario inicial e o horario final !"
     exit 12
fi

AREA=$1
area=`echo $AREA | tr [A-Z] [a-z]`                              # Transforma maiusculas em minusculas.
HSIM=$2
HSTART=$3
HSTOP=$4

#############################################
#
# DIRDADOSORI eh o diretorio de origem de onde
# serao extraidos os dados do GRIB
#
# DIRDADOSEXT eh o diretorio de destino para
# onde serao salvos os dados extraidos.
#
# HSTOP2 eh o periodo que sera extraido. O WRF
# gera 120 horas e por isso HSTOP2=120.
#
#############################################

curr_date=`cat ~/datas/datacorrente${HSIM}`

if [ ${area} == "antartica" ] || [ ${area} == "antarticap" ]
then
	raiz="/home/wrfoperador/pwrf"
else
	raiz="/home/wrfoperador/wrf"
fi

wrf_out="wrfout_d0"                                             # modelo BASE do nome do dado de saida do WRF.
dir_simulacao="${raiz}/wrf_${AREA}"
dir_produtos="${dir_simulacao}/produtos"
dir_gribs="${dir_produtos}/grib_${HSIM}"

DIRDADOSORI=${dir_gribs}
DIRDADOSEXT=${dir_produtos}/vento_${HSIM}
DADOSORIPREF="wrf_${AREA}_${HSIM}_$curr_date"
DADOSDESPREF="wrf_${AREA}_${HSIM}_$curr_date"

DIG='0'

for HREF2 in `seq ${HSTART} 3 ${HSTOP}`
do

   if [ $HREF2 -lt 10 ];then
      HORA=0$DIG$HREF2
   elif [ $HREF2 -lt 100 ];then
      HORA=$DIG$HREF2
   else
      HORA=$HREF2
   fi

   str2="${str2} ${HORA}"

done

###################################################
#
# Remove arquivos antigos do diretorio de destino
#
###################################################

cd ${DIRDADOSEXT}

rm ${DIRDADOSEXT}/*

###################################################
#
# Entra no diretorio de origem e executa o WGRIB 
# para todos os horarios dentro de $str2
#
###################################################

cd ${DIRDADOSORI}

for HORA in `echo ${str2}`
do
	
###################################################
#
# Significado das linhas abaixo:
#
# kpds5=1:kpds6=1	Extrai a pressao a superficie
# kpds5=11:kpds6=105	Extrai a T2m
# kpds5=17:kpds6=105	Extrai a TD2m
# kpds5=33:kpds6=105	Extrai U_10M
# kpds5=34:kpds6=105	Extrai V_10M
# kpds5=71		Extrai Cobertura Total de Nuvens
#
###################################################

	echo
	echo " Extraindo os dados de vento do horario ${HORA}"

	 wgrib ${DADOSORIPREF}${HORA} | egrep "(kpds5=33:kpds6=105|kpds5=34:kpds6=105)" \
       | wgrib -i -grib ${DADOSORIPREF}${HORA} -o ${DIRDADOSEXT}/${DADOSDESPREF}${HORA}

#	wgrib ${DADOSORIPREF}${HORA} | egrep "(kpds5=1:kpds6=1|kpds5=11:kpds6=105|kpds5=17:kpds6=105|kpds5=33:kpds6=105|kpds5=34:kpds6=105|kpds5=71)" | wgrib -i -grib ${DADOSORIPREF}${HORA} -o ${DIRDADOSEXT}/${DADOSDESPREF}${HORA}


done

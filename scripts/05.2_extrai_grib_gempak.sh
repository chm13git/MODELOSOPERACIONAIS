#!/bin/bash -x

#############################################
#
# Script para extracao de dados GRIB, visando
# gerar arquivos do WRF para visualizao no GEMPAK.
# o diretorio de origem dos dados sera o da
# rodada operacional do WRF definido como
# $DIRDADOSORI.
#
# Escrito em 21MAR2012
#
# Alterado em 12MAI2016
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
wgrb_date=`cat ~/datas/extrdatacorr${HSIM}`${HSIM}

if [ ${area} == "antartica" ] || [ ${area} == "antarticap" ];then
	raiz="/home/wrfoperador/pwrf"
else
	raiz="/home/wrfoperador/wrf"
fi

wrf_out="wrfout_d0"                                             # modelo BASE do nome do dado de saida do WRF.
dir_simulacao="${raiz}/wrf_${AREA}"
dir_produtos="${dir_simulacao}/produtos"
dir_gribs="${dir_produtos}/grib_${HSIM}"

DIRDADOSORI=${dir_gribs}
DIRDADOSEXT=${dir_produtos}/gempak_${HSIM}
DADOSORIPREF="wrf_${AREA}_${HSIM}_$curr_date"
DADOSDESPREF="wrf_${AREA}_${HSIM}_$curr_date"
DADOSDESGEMP="wrf_${AREA}_${curr_date}${HSIM}"

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
# 1:0:d=${wgrb_date}:PRMSL:kpds5=2:kpds6=102:kpds7=0	Extrai pressao reduzida a superficie
# kpds5=11:kpds6=105					Extrai a T2m (K)
# kpds5=17:kpds6=105					Extrai a TD2m (K)
# kpds5=33:kpds6=105					Extrai U_10M (m/s)
# kpds5=34:kpds6=105					Extrai V_10M (m/s)
# kpds5=71						Extrai Cobertura Total de Nuvens
# kpds5=20:kpds6=1      				Extrai Visibilidade (m)
# kpds5=180:kpds6=1     				Extrai Rajadas (m/s)
# kpds5=7:kpds6=100:kpds7=500 				Extrai Altura geopotencial em  500 hpa
# kpds5=7:kpds6=100:kpds7=850 				Extrai Altura geopotencial em  850 hpa
# kpds5=7:kpds6=100:kpds7=1000				Extrai Altura geopotencial em 1000 hpa
# kpds5=41:kpds6=100:kpds7=500				Extrai Vort Abs em 500 hpa
# kpds5=33:kpds6=100:kpds7=850  			Extrai comp U em 850 hpa
# kpds5=34:kpds6=100:kpds7=850  			Extrai comp V em 850 hpa
# kpds5=33:kpds6=100:kpds7=500  			Extrai comp U em 500 hpa
# kpds5=34:kpds6=100:kpds7=500  			Extrai comp V em 500 hpa
# kpds5=33:kpds6=100:kpds7=250  			Extrai comp U em 250 hpa
# kpds5=34:kpds6=100:kpds7=250  			Extrai comp V em 250 hpa
# kpds5=65:kpds6=1 					Extrai neve acumulada kg/m2
# kpds5=79:kpds6=1					Extrai Neve de escala de grade
# kpds5=214:kpds6=1					Extrai taxa de prec. convectiva ((kg/(m2 x s))
# kpds5=59:kpds6=1					Extrai taxa de prec. ((kg/(m2 x s))
# kpds5=61:kpds6=1					Extrai Prec. total kg/m2
# kpds5=63:kpds6=1					Extrai Prec. Convectiva kg/m2
# kpds5=157:kpds6=1					Extrai CAPE J/kg
# kpds5=73:kpds6=214					Extrai Cobert. de nuvem baixa %
# kpds5=74:kpds6=224					Extrai Cobert. de nuvem media %
# kpds5=75:kpds6=234					Extrai Cobert. de nuvem alta  %
# kpds5=71:kpds6=200					Extrai Cobert. total de nuvens %
#
###################################################
echo " Extraindo os dados do horario ${HORA}"

#wgrib ${DADOSORIPREF}${HORA} | egrep "(1:0:d=${wgrb_date}:PRMSL:kpds5=2:kpds6=102:kpds7=0)" \
#| wgrib -i -grib ${DADOSORIPREF}${HORA} -o ${DIRDADOSEXT}/${DADOSDESPREF}${HORA}


wgrib ${DADOSORIPREF}${HORA} | egrep "(1:0:d=${wgrb_date}:PRMSL:kpds5=2:kpds6=102:kpds7=0|kpds5=11:kpds6=105|kpds5=33:kpds6=105|kpds5=34:kpds6=105|kpds5=7:kpds6=100:kpds7=1000|kpds5=7:kpds6=100:kpds7=850|kpds5=7:kpds6=100:kpds7=500|kpds5=41:kpds6=100:kpds7=500|kpds5=33:kpds6=100:kpds7=850|kpds5=34:kpds6=100:kpds7=850|kpds5=33:kpds6=100:kpds7=500|kpds5=34:kpds6=100:kpds7=500|kpds5=33:kpds6=100:kpds7=250|kpds5=34:kpds6=100:kpds7=250|kpds5=61:kpds6=1)" \
| wgrib -i -grib ${DADOSORIPREF}${HORA} -o ${DIRDADOSEXT}/${DADOSDESPREF}${HORA}

done

cd ${DIRDADOSEXT}

/home/wrfoperador/local/bin/cdo merge ${DADOSDESPREF}* ${DADOSDESGEMP}

. /home/gempak/NAWIPS/Gemenviron.profile

/home/gempak/GEMPAK6.10/os/linux64/bin/nagrib<< EOF
GBFILE=$DADOSDESGEMP
GDOUTF=LIST
MAXGRD=3000
CPYFIL=gds
OUTPUT=t
GBTBLS=
GAREA=dset
PROJ=
KXKY=
run

GBFILE=$DADOSDESGEMP
GDOUTF=$DADOSDESGEMP.grd
r

exit
EOF

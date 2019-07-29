#!/bin/bash
#
#  script ledata_corr.sh
#
#  leitura da data-corrente
#
#  CF Costa Neves 17FEV2005
#  Atualização:30JAN06 para ser usado na DPN5 - CT NILZA BARROS 
#               
# ---------------------------------------------------------
# Passo 1: Verifica a hora de referencia
if [ $# -ne 1 ]
then
     echo "Entre com o horario de referencia (00 ou 12)!!!!!"
     exit
fi
HH=$1
#
# ---------------------------------------------------------
# Passo 2: Cria arquivos
#
rm -f ~/datas/datacorrente$HH
rm -f ~/datas/ANO${HH}
rm -f ~/datas/ano${HH}
rm -f ~/datas/mes${HH}
rm -f ~/datas/dia${HH}
rm -f ~/datas/diacorrente$HH
rm -f ~/datas/datacorrente_grads${HH}
#
#  le data corrente e copia para arquivo
#
date +%Y%m%d > ~/datas/datacorrente$HH
date +%Y >  ~/datas/ANO${HH}
date +%y >  ~/datas/ano${HH}
date +%m >  ~/datas/mes${HH}
date +%d >  ~/datas/dia${HH}
date +%d > ~/datas/diacorrente$HH

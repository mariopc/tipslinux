FECHA=$1
FECHAFIN=$2
SEGINI=$(date -d $FECHA +%s)
SEGFIN=$(date -d $FECHAFIN +%s)

if [ $SEGINI -ge $SEGFIN ]; then
 echo "La fecha fin debe ser mayor a la fecha ini"
 exit 1
fi


echo "Comienzo proceso: $(date)"
while [ $SEGFIN -ge $SEGINI ]; do

FECHA=$(date -d "$FECHA+1day" +%Y-%m-%d)
SEGINI=$(date -d $FECHA +%s)
done
echo "Fin proceso: $(date)"

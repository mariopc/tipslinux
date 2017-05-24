#!/bin/sh
#
# Autor: Mario Peña
# Objetivo shell: Encender o Apagar la interaccion del IBO con el SOS
# Para esto se realizar un cambio de puerto en la tabla "external_platform" de la BD iboamec
# luego se realiza un reinicio del proceso relacionado con el SOS

####
# Definicion de Variables:
####

PG_PASS="iboamec"
PG_USER="iboamec"
PG_HOST="pizote"
PG_DB="iboamec"
ID_PROC=30
PROCBOSS="/home/iboamec/IBOamec/bin/procBoss"

####
# Definicion de Funciones:
####

function llamaHelp {
	echo -e "ERR: No se han pasado los argumentos correctos\nLas posibnilidades son:\n\t$0 [on|off]"
}

function realizarUpdate {
        ACCION=${1}	
	if [ $ACCION == "on" ]; then
		echo -e "Se realizará el UPDATE a la BD para ENCENDER la interacción del IBO con el SOS"
		QUERY="UPDATE external_platform SET host = '10.56.40.7', port='4444' WHERE id = 1"
	else
		echo -e "Se realizará el UPDATE a la BD para APAGAR la interacción del IBO con el SOS"
		QUERY="UPDATE external_platform SET host = '127.0.0.1', port='1111' WHERE id = 1"
	fi
	PGPASSWORD=${PG_PASS} psql -U${PG_USER} -h${PG_HOST} ${PG_DB} -c "$QUERY"
	if [ $? -ne 0 ]; then
		echo -e "El update a la BD no se pudo efectuar, favor revisar la query:\n$QUERY"	
		exit 255
	else
		echo -e "El update fue ejecutado correctamente, la query fue la siguiente:\n$QUERY"
	fi
}

function killProcess {
	PID=$($PROCBOSS status $ID_PROC | jq '.[] | .procOS')
	while true; do
		PS=$(ps -fea | grep $PID | grep -v grep)
	        if [ $? -ne 0 ]; then
	                echo -e "El proceso no esta arriba, procediendo a subir..."
			break
		else
			echo -e "-Empezando Operacion para matar el proceso:\n\n\t-PID: $PID\n\t-Instrucción a ejecutar: kill -9 $PID\n\t-Proceso en el sistema: $PS\n"
			kill -9 $PID
	        fi
		sleep 2
	done
		
}

function bajarProceso {
	COUNT=1
	while true; do
		PROCESS_STATE=$($PROCBOSS status $ID_PROC | jq '.[] | .status')
		if [ $PROCESS_STATE == "\"0\"" ]; then
			echo -e "El proceso esta arriba, bajando... [Intento n°$COUNT de 3]"
			$PROCBOSS stop $ID_PROC | jq '.[] | .status'
			COUNT=$(($COUNT + 1))
		else
			echo -e "Proceso detenido, procediendo a subir..."
			return 0
			break
		fi
		if [ $COUNT -eq 4 ]; then
			sleep 1
			echo -e "El proceso no pudo se detenido a traves del procBoss, intentando kill"
			return 1
			break
		fi
		sleep 5
	done
	
}

function iniciarProceso {
	COUNT=1
        while true; do
                PROCESS_STATE=$($PROCBOSS status $ID_PROC | jq '.[] | .status')
                if [ $PROCESS_STATE == "\"0\"" ]; then
                        echo -e "El proceso esta arriba - OK"
			break
                else                        
			echo -e "El proceso esta abajo, subiendo... [Intento n°$COUNT de 3]"
                        $PROCBOSS start $ID_PROC | jq '.[] | .status'
                        COUNT=$(($COUNT + 1))
                fi
                if [ $COUNT -eq 4 ]; then
                        sleep 1
                        echo -e "El proceso no pudo ser iniciado a traves del procBoss, favor revisar..."
                        return 1
                        break
                fi
                sleep 2
        done
}

####
# Main:
####

echo -e "--------------------------\nInicio del proceso: $(date)"

if [ $# -eq 1 ]; then
	ACCION=$1
else
	llamaHelp
	exit 255
fi

if [ $ACCION == "on" ] || [ $ACCION == "off" ]; then
	realizarUpdate $ACCION
	echo "Bajando Proceso ID: $ID_PROC"
	bajarProceso
	if [ $? -ne 0 ]; then
		killProcess
		if [ $? -eq 0 ]; then
			iniciarProceso
		fi
	else
		iniciarProceso
	fi
else
	llamaHelp
	exit 255
fi
echo -e "Fin del proceso: $(date)\n--------------------------"

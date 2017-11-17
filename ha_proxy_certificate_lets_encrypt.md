# Configuración de HA-Proxy con certificado digital por Let's Encrypt (It's Free!) #

1) Instalación HA-Proxy:

Obtener rpm de la versión 1.7 e instalar (Centos 7 o Red-Hat 7)

>yum install haproxy-1.7.5-1.el7.x86_64.rpm

2) Instalación certbot (cliente por consola de Let's Encrypt)

Obtener rpm e instalar:

>yum install certbot-0.18.2-2.el7.noarch.rpm

3) Comprar dominio(s) y apuntarlos a la IP del server.

4) Obtener Certificado(s):

Verificar si el puerto 80 está abierto.

Si lo está, se debe cerrar (bajando lo que sea que lo tenga abierto)

>netstat -na | grep ':80.*LISTEN'

Ejecutar el siguiente comando para cada dominio (se debe reemplazar lo que está en negrita):

>certbot certonly --standalone --preferred-challenges http --http-01-port 80 -d **domain.exmaple.com**

El comando anterior devolverá como resultado lo siguiente:

>IMPORTANT NOTES:
>-Congratulations! Your certificate and chain have been saved at:
>/etc/letsencrypt/live/domain.example.com/fullchain.pem
>Your key file has been saved at:
>**/etc/letsencrypt/live/domain.example.com/privkey.pem**
>Your cert will expire on **2017-12-26**. To obtain a new or tweaked
>version of this certificate in the future, simply run certbot
>again. To non-interactively renew *all* of your certificates, run
>"certbot renew"
>
>-If you like Certbot, please consider supporting our work by:
>Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
> Donating to EFF:                    https://eff.org/donate-le

La primera parte en negrita, es el directorio donde quedan los links simbólicos a los archivos del certificado, estos son:

> - cert.pem -> Certificado de Dominio
> - chain.pem -> Certificado de Let's Encrypt
> - fullchain.pem -> cert.pem y chain.pem combinados
> - privkey.pem -> Llave privada de tu certificado

Para indicarle al HA Proxy cuales son los certificados que debe usar, primero debemos combinar los archivos `fullchain.pem` y `privkey.pem`

Primero creamos un directorio dentro del directorio del haproxy:

>mkdir /etc/haproxy/certs

Para combinar los archivos, debemos ejecutar esta sentencia por cada dominio al cual le hayamos generado un certificado (debemos cambiar lo que aparece en negrita por el nombre de dominio con el que estemos trabajando):

>cat /etc/letsencrypt/live/**domain.example.com**/fullchain.pem /etc/letsencrypt/live/**domain.example.com**/privkey.pem > /etc/haproxy/certs/**domain.example.com.pem**

Cambiamos los permisos del directorio y sus archivos para que sea mas seguro:

>chmod -R go-rwx /etc/haproxy/certs

La segunda parte en negrita, indica la fecha de expiración del certificado (después veremos la renovación)

5) Modificamos el archivo /etc/haproxy/haproxy.cfg y dejamos lo siguiente en la sección de frontend:

~~~
frontend http-in
		mode http
		bind 0.0.0.0:80
		redirect scheme https if !{ ssl_fc }

	frontend https-in
   		mode http
   		bind 0.0.0.0:443 ssl crt /etc/haproxy/certs/domain.example.com.pem crt /etc/haproxy/certs/api.domain.example.com.pem crt /etc/haproxy/certs/m.domain.example.com.pem
   		reqadd X-Forwarded-Proto:\ https
   		#ACL para renovar los certificados
   		acl letsencrypt-acl path_beg /.well-known/acme-challenge/
   		use_backend letsencrypt-backend if letsencrypt-acl
   		use_backend backend_app if { ssl_fc_sni domain.example.com }
   		use_backend backend_app_api if { ssl_fc_sni api.domain.example.com }
   		use_backend backend_app_m if { ssl_fc_sni m.domain.example.com }
~~~

El primer frontend llamado "http-in" realiza un bind en el puerto 80 (escucha en ese puerto) y luego redirecciona el trafico hacia el puerto 443 (osea hacia https)

El segundo frontend llamado "https-in" realiza un bind en el puerto 443 (escucha en ese puerto) y toma los certificados anteriormente generados. Luego:
 
Se declara un acl (Acces List) que se usa para renovar los certificados, este compara el parth de la URL, si este es igual a: "/.well-known/acme-challenge/", entonces el acl es igual a true.

Si el acl es true, entonces el trafico es enviado al backend llamado "letsencrypt-backend"

Luego vienen las re-direcciones hacia los diferentes backend dependiendo del dominio.

Si el dominio es domain.example.com, entonces, el trafico se redirigirá al backend llamado "backend_app" y así sucesivamente.

En la sección de backends pondremos lo siguiente:

~~~
backend letsencrypt-backend
    server letsencrypt 127.0.0.1:54328

backend backend_app
    mode http
   	server srv1 127.0.0.1:8080

backend backend_app_api
	mode http
	server srv2 127.0.0.1:12340

backend backend_app_m
   	mode http
   	server srv3 127.0.0.1:12340
~~~

El primer backend sirve para la renovación de los certificados y dirige el trafico al puerto 54328 (se puede elegir cualquier puerto que no se vaya a utilizar ni este en uso)

Los otros tres dirigen el trafico hacia donde se les configure, sintaxis:

>server <nombre_server> IP:PUERTO

6) Iniciar el HA Proxy:

>systemctl start haproxy

Con esto ya deberíamos tener los certificados y la re-dirección funcionando, ahora veremos como renovar los certificados automáticamente.

7) Renovación de Certificados:

Debemos crear un script que ejecutará la combinación de los archivos 'fullchain.pem' y 'privkey.pem', para este caso, como es mas de un dominio es script seria algo así:

>cat /usr/local/bin/renew.sh

~~~
	#!/bin/sh

	DOMANIS=("domain.example.com" "api.domain.example.com" "m.domain.example.com")

	for domain in "${DOMANIS[@]}"
	do
		cd /etc/letsencrypt/live/${domain}
		cat fullchain.pem privkey.pem > /etc/haproxy/certs/${domain}.pem
	done

	# reload haproxy
	systemctl restart haproxy
~~~

Para el caso de que sea un solo dominio, hay que adaptar el script para que ejecute solo una vez la combinación.

Le damos permisos de ejecución al archivo: `chmod u+x /usr/local/bin/renew.sh`

Ahora debemos cambiar la configuración del certbot renew, esto ya que por defecto queda apuntando al puerto 80, por lo tanto, debemos cambiar los archivos (cambiar lo está en negrita por el nombre de dominio):

>/etc/letsencrypt/renewal/**dominio.com.conf**

Dentro del o los archivos debemos buscar y modificar el valor de la variable `http01_port` por el puerto que se definió antes en el backend de letsencrypt (54328)

Guardamos el archivo y ejecutamos lo siguiente:

>certbot renew --dry-run

Este comando no debería arrojarnos errores, si lo hace se debe revisar la razón (con el flag `--dry-run` no ejecutamos la actualización solo probamos).

Finalizando, debemos crear un cron job que ejecute el proceso:

>30 2 * * * /usr/bin/certbot renew --renew-hook "/usr/local/bin/renew.sh" >> /var/log/letsencrypt-renewal.log 2>&1

El comando solo ejecutara el "hook" -> /usr/local/bin/renew.sh cuando renueve los certificados.

PD: El comando `certbot renew` solo renueva cuando quedan 30 o menos días para que el certificado expire.

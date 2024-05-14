# sysadmin-sergi
Práctica sysadmin Sergi Castillo Tiñena

## Instrucciones

### Configuración inicial

1. Clona este repositorio en tu máquina local.
2. Asegúrate de tener instalado Vagrant en tu sistema.
3. Abre una terminal en la ubicación del repositorio clonado.

### Levantando las máquinas virtuales

4. Ejecuta `vagrant up` para inicializar las máquinas virtuales proporcionadas.

### Verificación

5. Una vez veas el mensaje "El script se ha ejecutado correctamente", confirma la conectividad accediendo a:
   - Wordpress: [192.168.70.2:8081](http://192.168.70.2:8081)
   - Elasticsearch: [192.168.70.3:5601](http://192.168.70.3:5601)

### Acceso a Elastic y Configuración

6. En la VM2, para obtener la contraseña de administrador de Elastic, ejecuta el siguiente comando:
   'admin=$(cat admin.txt)'
Las contraseñas generadas durante el script no se almacenan en variables después de la ejecución. Este comando extrae las contraseñas de un archivo y las asigna a una variable.

7. Verifica la contraseña ejecutando `echo $admin`. Utiliza el usuario 'elastic' para iniciar sesión en Elasticsearch.

### Configuración de Analytics en Elasticsearch

8. Accede a la página principal de Elasticsearch.
9. En el menú lateral, haz clic en 'Discover' dentro de Analytics.
10. Crea un nuevo data view.
11. Completa el formulario con el nombre deseado y el índice de patrones copiando el índice generado automáticamente en la parte derecha.
12. Guarda el data view y verás todos los logs inmediatamente.




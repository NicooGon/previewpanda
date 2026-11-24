# Uso de IA en PreviewPanda

Usamos **ChatGPT** y **Claude** como apoyo para entender el alcance de la consigna, ordenar el trabajo del equipo y preparar la documentación. Nos sirvieron para distinguir los entregables obligatorios, identificar dependencias entre las tareas y explicar el flujo de los entornos de prueba por PR.

## Ejemplos de prompts

Estos ejemplos resumen consultas hechas durante el proyecto.

1. «Revisá la consigna y el estado del repositorio. Para Persona C, separá lo que ya está cubierto, lo que falta documentar y lo que depende de otras personas del equipo».
2. «Proponé qué diagramas conviene usar para explicar la arquitectura y el ciclo de un PR. Primero definamos qué muestra cada uno».
3. «Contrastá el informe con los workflows actuales y el CSV del PR #26. Marcá qué quedó desactualizado y qué resultados puedo respaldar con el repositorio».
4. «Siendo la Persona C, ¿qué puedo hacer ya y para qué tengo que esperar a los de infra o CI/CD?».
5. «Leé el estado de la Persona B y la consigna. Separá lo que ya está hecho, lo que falta y lo que depende de A, de C o del admin del repo. Proponé el orden de los próximos pasos del pipeline de preview y avancemos de a uno»
6. «Armame una prueba manual del ciclo completo: abrir el PR, hacer un push vacío, mergear y revisar el CSV y el comentario del PR. Decime cual sería el resultado esperado de cada paso para darlo por bueno»

## Lineamientos de uso

- Tomamos la consigna del curso y lo acordado por el equipo como referencia para decidir el alcance y el reparto de tareas.
- Usamos las sugerencias para organizar y redactar la documentación. Contrastamos los detalles técnicos con los archivos del repositorio, en particular los workflows, antes de describir un paso como implementado.
- Para los resultados de la demo, nos apoyamos en la captura de CloudWatch del PR #24 y en los registros del CSV del PR #26. El [informe](informe.md) distingue lo observado en AWS de lo estimado.
- Evitamos compartir credenciales, tokens o datos sensibles en las consultas. El equipo revisa la versión que incorpora al repositorio.
 